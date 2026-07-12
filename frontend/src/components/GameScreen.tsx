import { useEffect,useMemo,useRef,useState } from 'react'
import { AnimatePresence,motion } from 'framer-motion'
import { ArrowLeftRight,Clock3,LogOut,Settings,Volume2 } from 'lucide-react'
import { api,type Room,type User } from '../api'
import { playAssetSound,playDiceRoll,playPawnMove,playUiSound,unlockAudio } from '../audio'
import ClassicBoard3D,{makeCells} from './ClassicBoard3D'
import ChanceCard,{type ChanceEvent} from './ChanceCard'
import TradePanel,{IncomingTrades} from './TradePanel'

type Props={room:Room;user:User;onExit:()=>void}
const safeDice=(dice?:[number,number]):[number,number]=>dice&&dice.every(value=>value>=1&&value<=6)?dice:[1,1]
export default function GameScreen({room,user,onExit}:Props){
 const [liveRoom,setLiveRoom]=useState(room),players=liveRoom.players
 const cells=useMemo(()=>makeCells(liveRoom.boardSize),[liveRoom.boardSize])
 const [positions,setPositions]=useState(room.positions?.length===players.length?room.positions:players.map(()=>0)),[dice,setDice]=useState<[number,number]>(safeDice(room.dice)),[rolling,setRolling]=useState(false),[gameError,setGameError]=useState(''),[moneyToast,setMoneyToast]=useState<string|null>(null)
 const turn=liveRoom.turn||0
 const [phase,setPhase]=useState<'roll'|'moving'|'decision'|'card'>('roll'),[timeLeft,setTimeLeft]=useState(liveRoom.turnSeconds||60)
 const [selected,setSelected]=useState(0),[propertyOpen,setPropertyOpen]=useState(false),[pendingDeck,setPendingDeck]=useState<'chance'|'bad'|null>(null),[chance,setChance]=useState<ChanceEvent|null>(null),[drawNonce,setDrawNonce]=useState(0),[tradeOpen,setTradeOpen]=useState(false)
 const shownNonce=useRef(0),finishing=useRef(false),previousBalance=useRef(liveRoom.balances?.[user.id]??1500),meIndex=Math.max(0,players.findIndex(p=>p.id===user.id)),balance=liveRoom.balances?.[user.id]??1500,current=cells[selected],ownerId=liveRoom.ownership?.[String(selected)],standing=(positions[meIndex]??0)===selected
 useEffect(()=>{
  if(balance===previousBalance.current)return
  const delta=balance-previousBalance.current
  previousBalance.current=balance
  setMoneyToast(`${delta>0?'Отримано':'Сплачено'} ${delta>0?'+':''}${delta} ₴`)
  void unlockAudio()
  playUiSound(delta>0?'success':'select')
  const timeout=window.setTimeout(()=>setMoneyToast(null),2600)
  return()=>window.clearTimeout(timeout)
 },[balance])
 const finishTurn=()=>{
  if(finishing.current)return
  finishing.current=true
  setPropertyOpen(false)
  setPendingDeck(null)
  setChance(null)
  setPhase('roll')
  setTimeLeft(liveRoom.turnSeconds||60)
  void api.finishTurn(room.code).then(({room:r})=>{setLiveRoom(r)}).catch(()=>null).finally(()=>{finishing.current=false})
 }
 useEffect(()=>{const t=setInterval(()=>api.getRoom(room.code).then(({room:r})=>{setLiveRoom(r);if(r.positions?.length===players.length)setPositions(r.positions);setDice(safeDice(r.dice));if(r.currentChance&&r.currentChance.nonce!==shownNonce.current){shownNonce.current=r.currentChance.nonce;setDrawNonce(r.currentChance.nonce);setChance(r.currentChance)}}).catch(()=>null),900);return()=>clearInterval(t)},[room.code,players.length])
 // Only (re)arm timers for timed phases. Never force timeLeft=0 on moving/card — that used to
 // open the property/chance UI and immediately call finishTurn on the same paint.
 useEffect(()=>{
  if(phase==='roll') setTimeLeft(liveRoom.turnSeconds||60)
  else if(phase==='decision') setTimeLeft(liveRoom.decisionSeconds||45)
 },[phase,turn,liveRoom.turnSeconds,liveRoom.decisionSeconds])
 useEffect(()=>{
  if(phase!=='roll'&&phase!=='decision') return
  if(players[turn]?.id!==user.id) return
  if(timeLeft<=0){
   finishTurn()
   return
  }
  const t=setTimeout(()=>setTimeLeft(v=>v-1),1000)
  return()=>clearTimeout(t)
 },[timeLeft,phase])
 const roll=async()=>{
  if(rolling||phase!=='roll'||players[turn]?.id!==user.id)return
  await unlockAudio()
  setPhase('moving')
  setRolling(true)
  setGameError('')
  playDiceRoll()
  try{
   const result=await api.roll(room.code)
   const nextRoom=result.room
   const nextDice=safeDice(nextRoom.dice)
   const nextPosition=nextRoom.positions?.[turn]??positions[turn]??0
   const autoFinished=result.autoFinished
   setLiveRoom(nextRoom)
   setDice(nextDice)
   setPositions(nextRoom.positions)
   setRolling(false)
   setTimeout(()=>{
    playPawnMove(nextDice[0]+nextDice[1])
    setSelected(nextPosition)
    setTimeout(()=>{
     const landed=cells[nextPosition]
     if(autoFinished){setPhase('roll');setTimeLeft(nextRoom.turnSeconds||60)}
     else if(landed.kind==='city'){const decision=nextRoom.decisionSeconds||45;setPropertyOpen(true);setTimeLeft(decision);setPhase('decision')}
     else if(landed.kind==='chance'){setPendingDeck('chance');setPhase('card')}
     else if(landed.kind==='tax'){setPendingDeck('bad');setPhase('card')}
     else finishTurn()
    },(nextDice[0]+nextDice[1])*190+250)
   },1000)
  }catch(cause){
   setRolling(false)
   setPhase('roll')
   setGameError(cause instanceof Error?cause.message:'Не вдалося кинути кубики')
  }
 }
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
 const buildHouse=async()=>{if(ownerId!==user.id||!current.price||balance<100||(liveRoom.houses?.[String(selected)]||0)>=3)return;setLiveRoom((await api.buildHouse(room.code,{cellIndex:selected})).room)}
 const propertyRent=current.price?Math.max(Math.floor(current.price/4)+(liveRoom.houses?.[String(selected)]||0)*50,25):0
 const canBuy=standing&&current.kind==='city'&&!ownerId&&balance>=(current.price||0)
 return <main className="classicGame"><header className="classicHeader"><div className="gameBrand"><span>КупиМісто</span><small>{room.code}</small></div><div className="topTurn"><strong>{players[turn]?.id===user.id?'ВАШ ХІД':`ХІД: ${players[turn]?.name}`}</strong><span><Clock3/>{phase==='moving'?'рух':phase==='card'?'картка':`${timeLeft} с`}</span></div><div className="gameTools"><button><Volume2/></button><button onClick={()=>setTradeOpen(true)}><ArrowLeftRight/><span>Обмін</span></button><button><Settings/></button><button onClick={onExit}><LogOut/><span>Вийти</span></button></div></header><section className="boardOnly"><AnimatePresence>{moneyToast&&<motion.div className="memeToast" initial={{opacity:0,y:-18}} animate={{opacity:1,y:0}} exit={{opacity:0,y:-18}}>{moneyToast}</motion.div>}</AnimatePresence><div className="rotateHint">Права кнопка: обертання. Колесо: масштаб</div><div className="gameBalanceHud"><small>МІЙ БАЛАНС</small><strong className={balance<0?'negativeBalance':''}>{balance} ₴</strong></div><ClassicBoard3D size={liveRoom.boardSize} positions={positions} players={players} dice={dice} rolling={rolling} onSelectCell={i=>{setSelected(i);setPropertyOpen(true)}} ownership={liveRoom.ownership||{}} houses={liveRoom.houses||{}} drawNonce={drawNonce} onChanceDeckClick={()=>void draw('chance')} onBadDeckClick={()=>void draw('bad')}/>{pendingDeck&&<div className={`deckInstruction ${pendingDeck}`}><small>{pendingDeck==='chance'?'ШАНС':'ХАЛЕПА'}</small><strong>Натисни на {pendingDeck==='chance'?'синю':'червону'} колоду на полі</strong></div>}<div className="diceAction"><span>{dice[0]} + {dice[1]}</span><button onClick={roll} disabled={rolling||phase!=='roll'||players[turn]?.id!==user.id}>{rolling?'Кубики летять':'Кинути кубики'}</button></div>{gameError&&<p className="formError" role="alert">{gameError}</p>}<IncomingTrades room={liveRoom} user={user} onRoom={setLiveRoom}/><AnimatePresence>{tradeOpen&&<TradePanel room={liveRoom} user={user} onRoom={setLiveRoom} onClose={()=>setTradeOpen(false)}/>}</AnimatePresence><AnimatePresence>{chance&&<ChanceCard event={chance} onContinue={closeCard}/>}</AnimatePresence><AnimatePresence>{propertyOpen&&<motion.aside className="propertyPanel" initial={{opacity:0,x:60}} animate={{opacity:1,x:0}} exit={{opacity:0,x:60}}><button className="propertyClose" onClick={()=>setPropertyOpen(false)}>×</button><div className="propertyBand" style={{background:current.color}}/><span className="propertyType">{current.kind==='city'?'МІСЬКА ВЛАСНІСТЬ':'ІНФОРМАЦІЯ'}</span><h2>{current.name}</h2>{current.kind==='city'&&<><div className="propertyPrice"><span>Ціна</span><strong>{current.price} ₴</strong></div><div className="propertyRent"><span>Оренда зараз</span><strong>{propertyRent} ₴</strong></div><p className="propertyNote">{ownerId?`Власник: ${players.find(p=>p.id===ownerId)?.name||'гравець'}`:standing?'Ти стоїш на цій клітинці.':'Перегляд клітинки.'}</p>{ownerId===user.id&&<button className="buildHouseButton" disabled={balance<100||(liveRoom.houses?.[String(selected)]||0)>=3} onClick={()=>void buildHouse()}>Поставити будинок — 100 ₴</button>}{standing&&!ownerId&&phase==='decision'&&<div className="propertyActions"><button className="buyProperty" disabled={!canBuy} onClick={buy}>{balance<(current.price||0)?'Недостатньо коштів':`Купити за ${current.price} ₴`}</button><button className="skipProperty" onClick={finishTurn}>Не купувати</button></div>}</>}</motion.aside>}</AnimatePresence></section></main>
}
