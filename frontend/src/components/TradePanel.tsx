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

export function IncomingTrades({room,user,onRoom}:{room:Room;user:User;onRoom:(room:Room)=>void}){const cells=useMemo(()=>makeCells(room.boardSize),[room.boardSize]),incoming=(room.trades||[]).filter(t=>t.to===user.id&&t.status==='pending');if(!incoming.length)return null;const cellName=(index:number)=>index>=0?cells[index]?.name||`Клітинка ${index}`:'без клітинки',money=(amount:number)=>amount>0?`${amount} ₴`:'';return <div className="incomingTrades">{incoming.map(t=><article key={t.id}><ArrowLeftRight/><span><strong>Нова угода від {room.players.find(p=>p.id===t.from)?.name||'гравця'}</strong><div className="tradeDetails"><small>Ти віддаєш: {cellName(t.wantCell)} {money(t.wantMoney)}</small><small>Отримуєш: {cellName(t.giveCell)} {money(t.giveMoney)}</small></div></span><button aria-label="Прийняти угоду" onClick={async()=>onRoom((await api.answerTrade(room.code,t.id,true)).room)}><Check/></button><button aria-label="Відхилити угоду" onClick={async()=>onRoom((await api.answerTrade(room.code,t.id,false)).room)}><X/></button></article>)}</div>}
