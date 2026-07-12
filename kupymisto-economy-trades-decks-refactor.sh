#!/usr/bin/env bash
set -euo pipefail

if [ ! -f frontend/src/components/GameScreen.tsx ] || [ ! -f backend/cmd/api/main.go ]; then
  echo "Запусти файл у корені kupymisto після всіх попередніх оновлень."
  exit 1
fi

cat > frontend/src/components/TradePanel.tsx <<'EOF'
import { useMemo, useState } from 'react'
import { ArrowLeftRight, Check, X } from 'lucide-react'
import { api, type Room, type User } from '../api'
import { makeCells } from './ClassicBoard3D'

type Props={room:Room;user:User;onRoom:(room:Room)=>void;onClose:()=>void}
export default function TradePanel({room,user,onRoom,onClose}:Props){
 const cells=useMemo(()=>makeCells(room.boardSize),[room.boardSize])
 const others=room.players.filter(p=>p.id!==user.id)
 const mine=Object.entries(room.ownership||{}).filter(([,id])=>id===user.id).map(([i])=>Number(i))
 const [to,setTo]=useState(others[0]?.id||'')
 const theirs=Object.entries(room.ownership||{}).filter(([,id])=>id===to).map(([i])=>Number(i))
 const [giveCell,setGiveCell]=useState('')
 const [wantCell,setWantCell]=useState('')
 const [giveMoney,setGiveMoney]=useState(0)
 const [wantMoney,setWantMoney]=useState(0)
 const [error,setError]=useState('')
 const send=async()=>{try{const {room:next}=await api.createTrade(room.code,{to,giveCell:giveCell===''?-1:Number(giveCell),wantCell:wantCell===''?-1:Number(wantCell),giveMoney,wantMoney});onRoom(next);onClose()}catch(e){setError(e instanceof Error?e.message:'Угоду не створено')}}
 return <aside className="tradePanel"><button className="tradeClose" onClick={onClose}><X/></button><span>ОБМІН МІЖ ГРАВЦЯМИ</span><h2>Зібрати угоду</h2>{others.length===0?<p>Для обміну потрібен ще один гравець.</p>:<><label>Кому<select value={to} onChange={e=>{setTo(e.target.value);setWantCell('')}}>{others.map(p=><option value={p.id} key={p.id}>{p.name}</option>)}</select></label><div className="tradeColumns"><div><strong>Ти віддаєш</strong><label>Клітинка<select value={giveCell} onChange={e=>setGiveCell(e.target.value)}><option value="">Без клітинки</option>{mine.map(i=><option value={i} key={i}>{cells[i]?.name}</option>)}</select></label><label>Гроші<input type="number" min="0" value={giveMoney} onChange={e=>setGiveMoney(Math.max(0,Number(e.target.value)))}/></label></div><ArrowLeftRight/><div><strong>Ти отримуєш</strong><label>Клітинка<select value={wantCell} onChange={e=>setWantCell(e.target.value)}><option value="">Без клітинки</option>{theirs.map(i=><option value={i} key={i}>{cells[i]?.name}</option>)}</select></label><label>Гроші<input type="number" min="0" value={wantMoney} onChange={e=>setWantMoney(Math.max(0,Number(e.target.value)))}/></label></div></div>{error&&<p className="tradeError">{error}</p>}<button className="sendTrade" onClick={send}>Запропонувати угоду</button></>}</aside>
}

export function IncomingTrades({room,user,onRoom}:{room:Room;user:User;onRoom:(room:Room)=>void}){const incoming=(room.trades||[]).filter(t=>t.to===user.id&&t.status==='pending');if(!incoming.length)return null;return <div className="incomingTrades">{incoming.map(t=><article key={t.id}><ArrowLeftRight/><span><strong>Нова угода</strong><small>{room.players.find(p=>p.id===t.from)?.name||'Гравець'} пропонує обмін</small></span><button onClick={async()=>onRoom((await api.answerTrade(room.code,t.id,true)).room)}><Check/></button><button onClick={async()=>onRoom((await api.answerTrade(room.code,t.id,false)).room)}><X/></button></article>)}</div>}
EOF

python3 <<'PY'
from pathlib import Path

# Client types and API.
p=Path('frontend/src/api.ts');s=p.read_text(encoding='utf-8')
s=s.replace("export type Room = {", "export type Trade={id:string;from:string;to:string;giveCell:number;wantCell:number;giveMoney:number;wantMoney:number;status:'pending'|'accepted'|'rejected';expiresAt:string}\nexport type Room = {")
s=s.replace("ownership: Record<string,string>; houses:", "ownership: Record<string,string>; balances:Record<string,number>; trades:Trade[]; turnSeconds:number; decisionSeconds:number; houses:")
s=s.replace("  updateRoom: (code: string, body: { ageGroup: AgeGroup; boardSize: BoardSize })", "  updateRoom: (code: string, body: { boardSize: BoardSize; turnSeconds:number; decisionSeconds:number })")
s=s.replace("  drawBadLuck:", "  createTrade:(code:string,body:{to:string;giveCell:number;wantCell:number;giveMoney:number;wantMoney:number})=>request<{room:Room}>(`/api/rooms/${code}/trades`,{method:'POST',body:JSON.stringify(body)}),\n  answerTrade:(code:string,id:string,accept:boolean)=>request<{room:Room}>(`/api/rooms/${code}/trades/${id}`,{method:'PATCH',body:JSON.stringify({accept})}),\n  drawBadLuck:")
p.write_text(s, encoding='utf-8')

# Room settings: remove age selector and add turn / decision times.
p=Path('frontend/src/components/LobbyScreen.tsx');s=p.read_text(encoding='utf-8')
s=s.replace("import { api, clearToken, type AgeGroup, type BoardSize, type Room, type User } from '../api'", "import { api, clearToken, type BoardSize, type Room, type User } from '../api'")
s=s.replace("  const [ageGroup, setAgeGroup] = useState<AgeGroup>('14-15')\n","")
s=s.replace("<span className=\"sectionNo\">ПРИВАТНА КІМНАТА · ВІК {room.ageGroup}</span>","<span className=\"sectionNo\">ПРИВАТНА КІМНАТА</span>")
# Replace settings block if present.
start=s.find('<div className="insideRoomSettings">')
if start!=-1:
 end=s.find('</div><p>Власник:',start)
 if end!=-1:
  block='''<div className="insideRoomSettings"><span>НАЛАШТУВАННЯ ГРИ</span><label>Розмір карти<select value={room.boardSize} disabled={host?.id !== user.id} onChange={async e=>setRoom((await api.updateRoom(room.code,{boardSize:e.target.value as BoardSize,turnSeconds:room.turnSeconds,decisionSeconds:room.decisionSeconds})).room)}><option value="standard">Стандартна, 40 клітинок</option><option value="large">Велика, 56 клітинок</option></select></label><label>Час на хід<select value={room.turnSeconds} disabled={host?.id!==user.id} onChange={async e=>setRoom((await api.updateRoom(room.code,{boardSize:room.boardSize,turnSeconds:Number(e.target.value),decisionSeconds:room.decisionSeconds})).room)}><option value="30">30 секунд</option><option value="45">45 секунд</option><option value="60">60 секунд</option><option value="90">90 секунд</option></select></label><label>Час на рішення<select value={room.decisionSeconds} disabled={host?.id!==user.id} onChange={async e=>setRoom((await api.updateRoom(room.code,{boardSize:room.boardSize,turnSeconds:room.turnSeconds,decisionSeconds:Number(e.target.value)})).room)}><option value="20">20 секунд</option><option value="30">30 секунд</option><option value="45">45 секунд</option><option value="60">60 секунд</option></select></label></div><p>Власник:'''
  s=s[:start]+block+s[end+len('</div><p>Власник:'):]
p.write_text(s, encoding='utf-8')

# Board: remove ownership platform entirely, add thin outline using edges-like rails; deck click callbacks.
p=Path('frontend/src/components/ClassicBoard3D.tsx');s=p.read_text(encoding='utf-8')
# Remove platform/house visual block.
start=s.find("{ownerColor(index)&&<group position={[0,.34,0]}>")
if start!=-1:
 depth=0;end=-1
 for i in range(start,len(s)):
  if s.startswith('<group',i): depth+=1
  if s.startswith('</group>',i):
   depth-=1
   if depth==0:
    end=i+8;break
 if end!=-1:
  replacement="""{ownerColor(index)&&<group position={[0,.19,0]}>
          <mesh position={[0,0,-.54]}><boxGeometry args={[corner?1.1:.84,.055,.035]}/><meshStandardMaterial color={ownerColor(index)!}/></mesh>
          <mesh position={[0,0,.54]}><boxGeometry args={[corner?1.1:.84,.055,.035]}/><meshStandardMaterial color={ownerColor(index)!}/></mesh>
          <mesh position={[-(corner?.55:.42),0,0]}><boxGeometry args={[.035,.055,1.08]}/><meshStandardMaterial color={ownerColor(index)!}/></mesh>
          <mesh position={[(corner?.55:.42),0,0]}><boxGeometry args={[.035,.055,1.08]}/><meshStandardMaterial color={ownerColor(index)!}/></mesh>
          {Array.from({length:houses[String(index)]||0}).map((_,h)=><mesh key={h} position={[-.22+h*.22,.17,-.08]} castShadow><boxGeometry args={[.16,.22,.16]}/><meshStandardMaterial color={ownerColor(index)!}/></mesh>)}
        </group>}"""
  s=s[:start]+replacement+s[end:]
# Simplify deck: expose click target. Add callbacks to props.
s=s.replace("function ChanceDeck({drawNonce}:{drawNonce:number})", "function ChanceDeck({drawNonce,onClick}:{drawNonce:number;onClick:()=>void})")
s=s.replace("return <group>\n    {Array.from({length:7})", "return <group onClick={(e)=>{e.stopPropagation();onClick()}}>\n    {Array.from({length:7})")
s=s.replace("onSelectCell,drawNonce,houses}", "onSelectCell,drawNonce,houses,onChanceDeckClick,onBadDeckClick}")
s=s.replace("drawNonce:number;houses:Record<string,number>}", "drawNonce:number;houses:Record<string,number>;onChanceDeckClick:()=>void;onBadDeckClick:()=>void}")
s=s.replace("<ChanceDeck drawNonce={drawNonce}/>", "<ChanceDeck drawNonce={drawNonce} onClick={onChanceDeckClick}/><group position={[-1.55,.02,-.45]}><ChanceDeck drawNonce={drawNonce} onClick={onBadDeckClick}/></group>")
s=s.replace("drawNonce:number;houses:Record<string,number>})", "drawNonce:number;houses:Record<string,number>;onChanceDeckClick:()=>void;onBadDeckClick:()=>void})")
p.write_text(s, encoding='utf-8')
PY

# Replace GameScreen with a coherent synchronized economy flow while retaining 3D board.
cat > frontend/src/components/GameScreen.tsx <<'EOF'
import { useEffect,useMemo,useRef,useState } from 'react'
import { AnimatePresence,motion } from 'framer-motion'
import { ArrowLeftRight,Clock3,LogOut,Settings,Volume2 } from 'lucide-react'
import { api,type Room,type User } from '../api'
import { playDiceRoll,playPawnMove,unlockAudio } from '../audio'
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
 const draw=async(kind:'chance'|'bad')=>{if(pendingDeck!==kind||players[turn]?.id!==user.id)return;const result=kind==='chance'?await api.drawChance(room.code):await api.drawBadLuck(room.code);setLiveRoom(result.room);setPendingDeck(null);setPhase('card')}
 const closeCard=async()=>{setChance(null);if(players[turn]?.id===user.id){await api.clearChance(room.code).catch(()=>null);finishTurn()}}
 const buy=async()=>{if(!standing||ownerId||balance<(current.price||0))return;setLiveRoom((await api.purchaseProperty(room.code,{cellIndex:selected,price:current.price||0})).room);finishTurn()}
 const canBuy=standing&&current.kind==='city'&&!ownerId&&balance>=(current.price||0)
 return <main className="classicGame"><header className="classicHeader"><div className="gameBrand"><span>КупиМісто</span><small>{room.code}</small></div><div className="topTurn"><strong>{players[turn]?.id===user.id?'ВАШ ХІД':`ХІД: ${players[turn]?.name}`}</strong><span><Clock3/>{phase==='moving'?'рух':phase==='card'?'картка':`${timeLeft} с`}</span></div><div className="gameTools"><button><Volume2/></button><button onClick={()=>setTradeOpen(true)}><ArrowLeftRight/><span>Обмін</span></button><button><Settings/></button><button onClick={onExit}><LogOut/><span>Вийти</span></button></div></header><section className="boardOnly"><div className="rotateHint">Права кнопка: обертання. Колесо: масштаб</div><div className="gameBalanceHud"><small>МІЙ БАЛАНС</small><strong className={balance<0?'negativeBalance':''}>{balance} ₴</strong></div><ClassicBoard3D size={liveRoom.boardSize} positions={positions} players={players} dice={dice} rolling={rolling} onSelectCell={i=>{setSelected(i);setPropertyOpen(true)}} ownership={liveRoom.ownership||{}} houses={liveRoom.houses||{}} drawNonce={drawNonce} onChanceDeckClick={()=>void draw('chance')} onBadDeckClick={()=>void draw('bad')}/>{pendingDeck&&<div className={`deckInstruction ${pendingDeck}`}><small>{pendingDeck==='chance'?'ШАНС':'ХАЛЕПА'}</small><strong>Натисни на {pendingDeck==='chance'?'синю':'червону'} колоду на полі</strong></div>}<div className="diceAction"><span>{dice[0]} + {dice[1]}</span><button onClick={roll} disabled={rolling||phase!=='roll'||players[turn]?.id!==user.id}>{rolling?'Кубики летять':'Кинути кубики'}</button></div><IncomingTrades room={liveRoom} user={user} onRoom={setLiveRoom}/><AnimatePresence>{tradeOpen&&<TradePanel room={liveRoom} user={user} onRoom={setLiveRoom} onClose={()=>setTradeOpen(false)}/>}</AnimatePresence><AnimatePresence>{chance&&<ChanceCard event={chance} onContinue={closeCard}/>}</AnimatePresence><AnimatePresence>{propertyOpen&&<motion.aside className="propertyPanel" initial={{opacity:0,x:60}} animate={{opacity:1,x:0}} exit={{opacity:0,x:60}}><button className="propertyClose" onClick={()=>setPropertyOpen(false)}>×</button><div className="propertyBand" style={{background:current.color}}/><span className="propertyType">{current.kind==='city'?'МІСЬКА ВЛАСНІСТЬ':'ІНФОРМАЦІЯ'}</span><h2>{current.name}</h2>{current.kind==='city'&&<><div className="propertyPrice"><span>Ціна</span><strong>{current.price} ₴</strong></div><p className="propertyNote">{ownerId?`Власник: ${players.find(p=>p.id===ownerId)?.name||'гравець'}`:standing?'Ти стоїш на цій клітинці.':'Перегляд клітинки.'}</p>{standing&&!ownerId&&phase==='decision'&&<div className="propertyActions"><button className="buyProperty" disabled={!canBuy} onClick={buy}>{balance<(current.price||0)?'Недостатньо коштів':`Купити за ${current.price} ₴`}</button><button className="skipProperty" onClick={finishTurn}>Не купувати</button></div>}</>}</motion.aside>}</AnimatePresence></section></main>
}
EOF

python3 <<'PY'
from pathlib import Path
# Backend models and endpoints.
p=Path('backend/cmd/api/main.go');s=p.read_text(encoding='utf-8')
s=s.replace('type Room struct {', 'type Trade struct { ID string `json:"id"`; From string `json:"from"`; To string `json:"to"`; GiveCell int `json:"giveCell"`; WantCell int `json:"wantCell"`; GiveMoney int `json:"giveMoney"`; WantMoney int `json:"wantMoney"`; Status string `json:"status"`; ExpiresAt time.Time `json:"expiresAt"` }\ntype Room struct {')
s=s.replace('Ownership map[string]string `json:"ownership"`; Houses', 'Ownership map[string]string `json:"ownership"`; Balances map[string]int `json:"balances"`; Trades []Trade `json:"trades"`; TurnSeconds int `json:"turnSeconds"`; DecisionSeconds int `json:"decisionSeconds"`; Houses')
s=s.replace('Ownership:map[string]string{},Houses:', 'Ownership:map[string]string{},Balances:map[string]int{user.ID:1500},Trades:[]Trade{},TurnSeconds:60,DecisionSeconds:45,Houses:')
# Joining initializes balance.
s=s.replace('room.Players=append(room.Players,Player{ID:user.ID,Name:user.Name});writeJSON', 'room.Players=append(room.Players,Player{ID:user.ID,Name:user.Name});if _,ok:=room.Balances[user.ID];!ok{room.Balances[user.ID]=1500};writeJSON')
# Settings struct and validation, age ignored/commented out.
s=s.replace('var in struct{AgeGroup string `json:"ageGroup"`;BoardSize string `json:"boardSize"`}', 'var in struct{BoardSize string `json:"boardSize"`;TurnSeconds int `json:"turnSeconds"`;DecisionSeconds int `json:"decisionSeconds"`}')
s=s.replace('!validAgeGroup(in.AgeGroup)||(in.BoardSize!="standard"&&in.BoardSize!="large")', '(in.BoardSize!="standard"&&in.BoardSize!="large")||in.TurnSeconds<30||in.TurnSeconds>90||in.DecisionSeconds<20||in.DecisionSeconds>60')
s=s.replace('room.AgeGroup=in.AgeGroup;room.BoardSize=in.BoardSize', 'room.BoardSize=in.BoardSize;room.TurnSeconds=in.TurnSeconds;room.DecisionSeconds=in.DecisionSeconds')
# Purchases deduct server balance.
s=s.replace('room.Ownership[key]=user.ID;writeJSON', 'if room.Balances[user.ID]<in.Price{fail(w,409,"Недостатньо коштів");return};room.Balances[user.ID]-=in.Price;room.Ownership[key]=user.ID;writeJSON')
# Houses deduct.
s=s.replace('room.Houses[key]++;writeJSON', 'if room.Balances[user.ID]<100{fail(w,409,"Недостатньо коштів");return};room.Balances[user.ID]-=100;room.Houses[key]++;writeJSON')
# Card draws apply amount once on server.
s=s.replace('room.CurrentChance=&card\n        writeJSON', 'room.CurrentChance=&card;room.Balances[user.ID]+=card.Amount\n        writeJSON')
s=s.replace('room.CurrentChance=&card;writeJSON', 'room.CurrentChance=&card;room.Balances[user.ID]+=card.Amount;writeJSON')
# Trade endpoints.
routes='''    protected.HandleFunc("POST /api/rooms/{code}/trades",func(w http.ResponseWriter,r *http.Request){var in struct{To string `json:"to"`;GiveCell int `json:"giveCell"`;WantCell int `json:"wantCell"`;GiveMoney int `json:"giveMoney"`;WantMoney int `json:"wantMoney"`};if readJSON(r,&in)!=nil||in.GiveMoney<0||in.WantMoney<0{fail(w,400,"Некоректна угода");return};code:=strings.ToUpper(r.PathValue("code"));u:=mustUser(r);store.mu.Lock();defer store.mu.Unlock();room:=store.rooms[code];if room==nil||!containsPlayer(room,u.ID){fail(w,404,"Кімнату не знайдено");return};if in.GiveCell>=0&&room.Ownership[strconv.Itoa(in.GiveCell)]!=u.ID{fail(w,403,"Ця клітинка не твоя");return};if in.WantCell>=0&&room.Ownership[strconv.Itoa(in.WantCell)]!=in.To{fail(w,409,"Клітинка вже не належить гравцю");return};if room.Balances[u.ID]<in.GiveMoney{fail(w,409,"Недостатньо коштів для пропозиції");return};trade:=Trade{ID:randomString(10,codeAlphabet),From:u.ID,To:in.To,GiveCell:in.GiveCell,WantCell:in.WantCell,GiveMoney:in.GiveMoney,WantMoney:in.WantMoney,Status:"pending",ExpiresAt:time.Now().Add(time.Duration(room.DecisionSeconds)*time.Second)};room.Trades=append(room.Trades,trade);writeJSON(w,201,map[string]any{"room":room})})
    protected.HandleFunc("PATCH /api/rooms/{code}/trades/{id}",func(w http.ResponseWriter,r *http.Request){var in struct{Accept bool `json:"accept"`};if readJSON(r,&in)!=nil{fail(w,400,"Некоректна відповідь");return};code:=strings.ToUpper(r.PathValue("code"));u:=mustUser(r);store.mu.Lock();defer store.mu.Unlock();room:=store.rooms[code];if room==nil{fail(w,404,"Кімнату не знайдено");return};for i:=range room.Trades{t:=&room.Trades[i];if t.ID!=r.PathValue("id"){continue};if t.To!=u.ID||t.Status!="pending"{fail(w,403,"Угода недоступна");return};if !in.Accept{t.Status="rejected";writeJSON(w,200,map[string]any{"room":room});return};if time.Now().After(t.ExpiresAt)||room.Balances[t.From]<t.GiveMoney||room.Balances[t.To]<t.WantMoney{t.Status="rejected";fail(w,409,"Угода прострочена або баланс змінився");return};if t.GiveCell>=0&&room.Ownership[strconv.Itoa(t.GiveCell)]!=t.From{fail(w,409,"Власність змінилась");return};if t.WantCell>=0&&room.Ownership[strconv.Itoa(t.WantCell)]!=t.To{fail(w,409,"Власність змінилась");return};room.Balances[t.From]+=t.WantMoney-t.GiveMoney;room.Balances[t.To]+=t.GiveMoney-t.WantMoney;if t.GiveCell>=0{room.Ownership[strconv.Itoa(t.GiveCell)]=t.To};if t.WantCell>=0{room.Ownership[strconv.Itoa(t.WantCell)]=t.From};t.Status="accepted";writeJSON(w,200,map[string]any{"room":room});return};fail(w,404,"Угоду не знайдено")})
'''
anchor='    protected.HandleFunc("POST /api/rooms/{code}/bad-luck"'
s=s.replace(anchor,routes+anchor)
p.write_text(s, encoding='utf-8')
PY

cat >> frontend/src/styles.css <<'EOF'
/* Simplified decks and trading */
.deckInstruction{position:absolute;z-index:14;left:50%;top:18%;transform:translateX(-50%);background:var(--paper);border:3px solid var(--ink);border-radius:13px;padding:11px 16px;box-shadow:5px 5px 0 var(--ink);display:grid;text-align:center;pointer-events:none}.deckInstruction small{font-size:9px;font-weight:900;letter-spacing:.12em}.deckInstruction strong{font-size:12px}.deckInstruction.bad{background:oklch(76% .12 28)}.tradePanel{position:absolute;z-index:25;right:20px;top:20px;width:min(520px,calc(100vw - 40px));background:var(--paper);border:3px solid var(--ink);border-radius:18px;padding:24px;box-shadow:9px 9px 0 var(--ink)}.tradePanel>span{font-size:9px;font-weight:900;letter-spacing:.12em}.tradePanel h2{font-family:Unbounded;font-size:28px;margin:8px 0 20px}.tradeClose{position:absolute;right:10px;top:10px;width:36px;height:36px;border:2px solid var(--ink);border-radius:50%;background:var(--paper)}.tradeClose svg{width:16px}.tradePanel label{display:grid;gap:5px;font-size:10px;font-weight:900;margin-top:10px}.tradePanel select,.tradePanel input{height:42px;border:2px solid var(--ink);border-radius:8px;background:var(--paper);padding:0 9px;font-weight:750}.tradeColumns{display:grid;grid-template-columns:1fr 30px 1fr;gap:10px;align-items:center;margin-top:18px}.tradeColumns>svg{width:22px}.tradeColumns>div>strong{font-size:12px}.sendTrade{width:100%;min-height:46px;margin-top:18px;border:3px solid var(--ink);border-radius:10px;background:var(--yellow);font-weight:900}.tradeError{font-size:11px;color:var(--red);font-weight:800}.incomingTrades{position:absolute;z-index:18;left:20px;bottom:82px;display:grid;gap:8px}.incomingTrades article{background:var(--paper);border:3px solid var(--ink);border-radius:12px;padding:8px;display:flex;align-items:center;gap:9px;box-shadow:4px 4px 0 var(--ink)}.incomingTrades article>svg{width:20px}.incomingTrades span{display:grid}.incomingTrades strong{font-size:11px}.incomingTrades small{font-size:9px}.incomingTrades button{width:34px;height:34px;border:2px solid var(--ink);border-radius:8px;background:var(--green)}.incomingTrades button:last-child{background:var(--red)}.incomingTrades button svg{width:15px}.gameBalanceHud .negativeBalance{color:oklch(72% .2 28)}
@media(max-width:700px){.tradePanel{right:10px;top:10px;width:calc(100vw - 20px);max-height:calc(100% - 20px);overflow:auto}.tradeColumns{grid-template-columns:1fr}.tradeColumns>svg{transform:rotate(90deg);justify-self:center}}
EOF

(cd backend && gofmt -w cmd/api/main.go && go test ./...)
npm --prefix frontend run build

git add frontend/src/api.ts frontend/src/components/LobbyScreen.tsx frontend/src/components/GameScreen.tsx frontend/src/components/ClassicBoard3D.tsx frontend/src/components/TradePanel.tsx frontend/src/styles.css backend/cmd/api/main.go
git commit -m "refactor: sync economy, simplify decks and add property trading" || true
git push || echo "Виконай git push вручну"

echo "Готово. Перезапусти: docker compose down && docker compose up --build"
