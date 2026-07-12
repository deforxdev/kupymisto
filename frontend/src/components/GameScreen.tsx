import { useEffect,useMemo,useRef,useState } from 'react'
import { AnimatePresence,motion } from 'framer-motion'
import { ArrowLeftRight,Clock3,LogOut,Settings,Volume2 } from 'lucide-react'
import { api,type Room,type User } from '../api'
import { playAssetSound,playDiceRoll,playPawnMove,playUiSound,unlockAudio } from '../audio'
import ClassicBoard3D,{makeCells} from './ClassicBoard3D'
import ChanceCard,{type ChanceEvent} from './ChanceCard'
import TradePanel,{IncomingTrades} from './TradePanel'

type Props={room:Room;user:User;onExit:()=>void}
export default function GameScreen({room,user,onExit}:Props){
 const [liveRoom,setLiveRoom]=useState(room),players=liveRoom.players
 const cells=useMemo(()=>makeCells(liveRoom.boardSize),[liveRoom.boardSize])
 const [positions,setPositions]=useState(players.map(()=>0)),[dice,setDice]=useState<[number,number]>([1,1]),[rolling,setRolling]=useState(false),[turn,setTurn]=useState(0)
 const [phase,setPhase]=useState<'roll'|'moving'|'decision'|'card'>('roll'),[timeLeft,setTimeLeft]=useState(liveRoom.turnSeconds||60)
 const [selected,setSelected]=useState(0),[propertyOpen,setPropertyOpen]=useState(false),[pendingDeck,setPendingDeck]=useState<'chance'|'bad'|null>(null),[chance,setChance]=useState<ChanceEvent|null>(null),[drawNonce,setDrawNonce]=useState(0),[tradeOpen,setTradeOpen]=useState(false)
 const shownNonce=useRef(0),meIndex=Math.max(0,players.findIndex(p=>p.id===user.id)),balance=liveRoom.balances?.[user.id]??1500,current=cells[selected],ownerId=liveRoom.ownership?.[String(selected)],standing=(positions[meIndex]??0)===selected
 const finishTurn=()=>{setPropertyOpen(false);setPendingDeck(null);setPhase('roll');setTurn(v=>(v+1)%players.length)}
 useEffect(()=>{const t=setInterval(()=>api.getRoom(room.code).then(({room:r})=>{setLiveRoom(r);if(r.currentChance&&r.currentChance.nonce!==shownNonce.current){shownNonce.current=r.currentChance.nonce;setDrawNonce(r.currentChance.nonce);setChance(r.currentChance)}}).catch(()=>null),900);return()=>clearInterval(t)},[room.code])
 useEffect(()=>{setTimeLeft(phase==='roll'?(liveRoom.turnSeconds||60):phase==='decision'?(liveRoom.decisionSeconds||45):0)},[phase,turn,liveRoom.turnSeconds,liveRoom.decisionSeconds])
 useEffect(()=>{if(phase==='moving'||phase==='card')return;if(timeLeft<=0){finishTurn();return}const t=setTimeout(()=>setTimeLeft(v=>v-1),1000);return()=>clearTimeout(t)},[timeLeft,phase])
 const roll=async()=>{if(rolling||phase!=='roll'||players[turn]?.id!==user.id)return;await unlockAudio();setPhase('moving');setRolling(true);playDiceRoll();setTimeout(()=>{const a=1+Math.floor(Math.random()*6),b=1+Math.floor(Math.random()*6),dest=((positions[turn]||0)+a+b)%cells.length;setDice([a,b]);setRolling(false);setTimeout(()=>{playPawnMove(a+b);setPositions(v=>v.map((p,i)=>i===turn?dest:p));setSelected(dest);setTimeout(()=>{const landed=cells[dest];if(landed.kind==='city'){setPropertyOpen(true);setPhase('decision')}else if(landed.kind==='chance'){setPendingDeck('chance');setPhase('card')}else if(landed.kind==='tax'){setPendingDeck('bad');setPhase('card')}else finishTurn()},(a+b)*190+250)},1000)},700)}
 const draw=async(kind:'chance'|'bad')=>{
  if(pendingDeck!==kind||players[turn]?.id!==user.id)return
  await unlockAudio()
  void playAssetSound('card-draw.ogg',()=>playUiSound('select'))
  const result=kind==='chance'?await api.drawChance(room.code):await api.drawBadLuck(room.code)
  setLiveRoom(result.room);setPendingDeck(null);setPhase('card')
  if(result.room.currentChance){
   shownNonce.current=result.room.currentChance.nonce
   setDrawNonce(result.room.currentChance.nonce)
   setChance(result.room.currentChance)
  }
 }
 const closeCard=async()=>{setChance(null);if(players[turn]?.id===user.id){await api.clearChance(room.code).catch(()=>null);finishTurn()}}
 const buy=async()=>{if(!standing||ownerId||balance<(current.price||0))return;setLiveRoom((await api.purchaseProperty(room.code,{cellIndex:selected,price:current.price||0})).room);finishTurn()}
 const canBuy=standing&&current.kind==='city'&&!ownerId&&balance>=(current.price||0)
 return <main className="classicGame"><header className="classicHeader"><div className="gameBrand"><span>КупиМісто</span><small>{room.code}</small></div><div className="topTurn"><strong>{players[turn]?.id===user.id?'ВАШ ХІД':`ХІД: ${players[turn]?.name}`}</strong><span><Clock3/>{phase==='moving'?'рух':phase==='card'?'картка':`${timeLeft} с`}</span></div><div className="gameTools"><button><Volume2/></button><button onClick={()=>setTradeOpen(true)}><ArrowLeftRight/><span>Обмін</span></button><button><Settings/></button><button onClick={onExit}><LogOut/><span>Вийти</span></button></div></header><section className="boardOnly"><div className="rotateHint">Права кнопка: обертання. Колесо: масштаб</div><div className="gameBalanceHud"><small>МІЙ БАЛАНС</small><strong className={balance<0?'negativeBalance':''}>{balance} ₴</strong></div><ClassicBoard3D size={liveRoom.boardSize} positions={positions} players={players} dice={dice} rolling={rolling} onSelectCell={i=>{setSelected(i);setPropertyOpen(true)}} ownership={liveRoom.ownership||{}} houses={liveRoom.houses||{}} drawNonce={drawNonce} onChanceDeckClick={()=>void draw('chance')} onBadDeckClick={()=>void draw('bad')}/>{pendingDeck&&<div className={`deckInstruction ${pendingDeck}`}><small>{pendingDeck==='chance'?'ШАНС':'ХАЛЕПА'}</small><strong>Натисни на {pendingDeck==='chance'?'синю':'червону'} колоду на полі</strong></div>}<div className="diceAction"><span>{dice[0]} + {dice[1]}</span><button onClick={roll} disabled={rolling||phase!=='roll'||players[turn]?.id!==user.id}>{rolling?'Кубики летять':'Кинути кубики'}</button></div><IncomingTrades room={liveRoom} user={user} onRoom={setLiveRoom}/><AnimatePresence>{tradeOpen&&<TradePanel room={liveRoom} user={user} onRoom={setLiveRoom} onClose={()=>setTradeOpen(false)}/>}</AnimatePresence><AnimatePresence>{chance&&<ChanceCard event={chance} onContinue={closeCard}/>}</AnimatePresence><AnimatePresence>{propertyOpen&&<motion.aside className="propertyPanel" initial={{opacity:0,x:60}} animate={{opacity:1,x:0}} exit={{opacity:0,x:60}}><button className="propertyClose" onClick={()=>setPropertyOpen(false)}>×</button><div className="propertyBand" style={{background:current.color}}/><span className="propertyType">{current.kind==='city'?'МІСЬКА ВЛАСНІСТЬ':'ІНФОРМАЦІЯ'}</span><h2>{current.name}</h2>{current.kind==='city'&&<><div className="propertyPrice"><span>Ціна</span><strong>{current.price} ₴</strong></div><p className="propertyNote">{ownerId?`Власник: ${players.find(p=>p.id===ownerId)?.name||'гравець'}`:standing?'Ти стоїш на цій клітинці.':'Перегляд клітинки.'}</p>{standing&&!ownerId&&phase==='decision'&&<div className="propertyActions"><button className="buyProperty" disabled={!canBuy} onClick={buy}>{balance<(current.price||0)?'Недостатньо коштів':`Купити за ${current.price} ₴`}</button><button className="skipProperty" onClick={finishTurn}>Не купувати</button></div>}</>}</motion.aside>}</AnimatePresence></section></main>
}
