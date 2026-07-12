import { useEffect, useMemo, useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { Building2, Check, Home, LogOut, Settings, Volume2, X } from 'lucide-react'
import type { Room, User } from '../api'
import { playDiceRoll, playPawnMove, playUiSound, unlockAudio } from '../audio'
import ClassicBoard3D, { makeCells } from './ClassicBoard3D'

type Props = { room: Room; user: User; onExit: () => void }
const colors = ['blue','red','green','yellow','purple','orange']

export default function GameScreen({ room, user, onExit }: Props) {
  const players = useMemo(() => room.players.length ? room.players : [{ id:user.id,name:user.name,host:true,ready:true }], [room.players,user])
  const [positions,setPositions] = useState(players.map(() => 0))
  const [dice,setDice] = useState<[number,number]>([1,1])
  const [rolling,setRolling] = useState(false)
  const [turn,setTurn] = useState(0)
  const [turnNoticeId,setTurnNoticeId] = useState(1)
  const [selectedCell,setSelectedCell] = useState(0)
  const [owned,setOwned] = useState<number[]>([])
  const [balance,setBalance] = useState(1500)
  const [cardOpen,setCardOpen] = useState(false)
  const cells = useMemo(() => makeCells(room.boardSize),[room.boardSize])


  const roll = async () => {
    if (rolling || players[turn]?.id !== user.id) return
    await unlockAudio()
    setRolling(true); playDiceRoll()
    window.setTimeout(() => {
      const a=1+Math.floor(Math.random()*6), b=1+Math.floor(Math.random()*6)
      setDice([a,b]); setRolling(false)
      window.setTimeout(() => {
        const destination=(positions[turn]+a+b)%cells.length
        setSelectedCell(destination)
        setCardOpen(true)
        playPawnMove(a+b)
        setPositions(old=>old.map((p,i)=>i===turn?destination:p))
        window.setTimeout(()=>{ setTurn(value=>(value+1)%players.length); setTurnNoticeId(value=>value+1) },Math.max(900,(a+b)*190+260))
      }, 1000)
    },700)
  }

  const selected=cells[selectedCell]
  const baseRent=selected.price ? Math.max(10,Math.round(selected.price*.12/5)*5) : 0
  const oneHouse=baseRent*3
  const twoHouses=baseRent*7
  const threeHouses=baseRent*12
  const canBuy=selected.kind==='city'&&!owned.includes(selectedCell)&&balance>=(selected.price||0)
  const buy=()=>{if(!canBuy)return;setBalance(value=>value-(selected.price||0));setOwned(value=>[...value,selectedCell]);playUiSound('success')}

  return <main className="classicGame">
    <header className="classicHeader"><div className="gameBrand"><span>КупиМісто</span><small>{room.code}</small></div><div className="topTurn">Хід {players[turn]?.name}</div><div className="gameTools"><button><Volume2/></button><button><Settings/></button><button onClick={onExit}><LogOut/><span>Вийти</span></button></div></header>
    <section className="boardOnly">
      <div className="rotateHint">Права кнопка: обертання. Колесо: масштаб</div>
      <ClassicBoard3D size={room.boardSize} positions={positions} players={players} dice={dice} rolling={rolling} onSelectCell={(index)=>{setSelectedCell(index);setCardOpen(true)}}/>
      {players.slice(0,6).map((player,index)=><div key={player.id} className={`cornerPlayer corner${index+1} ${turn===index?'current':''}`}>
        <div className={`cornerAvatar ${colors[index]}`}>{player.name.slice(0,1).toUpperCase()}<i/></div><span><strong>{player.name}</strong><small>{turn===index?'Зараз ходить':'1500 ₴'}</small></span>
      </div>)}
      <AnimatePresence>{<motion.div key={turnNoticeId} className="turnAnnouncement" initial={{opacity:0,scale:.9,y:26}} animate={{opacity:[0,1,1,0],scale:[.9,1,1,.82],y:[26,0,0,-260]}} transition={{duration:1.75,times:[0,.16,.62,1],ease:[.16,1,.3,1]}}><small>НАСТУПНИЙ ХІД</small><strong>{players[turn]?.id===user.id?'Твій хід':`Хід: ${players[turn]?.name}`}</strong></motion.div>}</AnimatePresence>
      <div className="diceAction"><span>{dice[0]} + {dice[1]}</span><button onClick={roll} disabled={rolling||players[turn]?.id!==user.id}>{rolling?'Кубики летять':'Кинути кубики'}</button></div>
      <AnimatePresence>{cardOpen&&<motion.aside className="propertyPanel" initial={{opacity:0,x:60}} animate={{opacity:1,x:0}} exit={{opacity:0,x:70}} transition={{duration:.36,ease:[.16,1,.3,1]}}>
        <button className="propertyClose" onClick={()=>setCardOpen(false)} aria-label="Закрити картку"><X/></button>
        <div className="propertyBand" style={{background:selected.color}}/>
        <span className="propertyType">{selected.kind==='city'?'МІСЬКА ВЛАСНІСТЬ':selected.kind==='station'?'ТРАНСПОРТ':selected.kind==='chance'?'ПОДІЯ':selected.kind==='tax'?'МІСЬКИЙ ЗБІР':'КУТОВА КЛІТИНКА'}</span>
        <h2>{selected.name}</h2>
        {selected.kind==='city'&&<>
          <div className="propertyPrice"><span>Ціна ділянки</span><strong>{selected.price} ₴</strong></div>
          <div className="rentTable"><div><span>Без будинку</span><b>{baseRent} ₴</b></div><div><span><Home/> 1 будинок</span><b>{oneHouse} ₴</b></div><div><span><Home/> 2 будинки</span><b>{twoHouses} ₴</b></div><div><span><Building2/> 3 будинки</span><b>{threeHouses} ₴</b></div></div>
          <p className="propertyNote">Повний комплект одного кольору збільшує оренду. Вартість будинків додамо на етапі економіки.</p>
          {owned.includes(selectedCell)?<div className="ownedLabel"><Check/> Це твоя власність</div>:<div className="propertyActions"><button className="buyProperty" disabled={!canBuy} onClick={buy}>Купити за {selected.price} ₴</button><button className="skipProperty" onClick={()=>setCardOpen(false)}>Не купувати</button></div>}
        </>}
        {selected.kind!=='city'&&<p className="specialCellText">Ця клітинка не продається. Її дія спрацює після завершення ходу.</p>}
        <div className="panelBalance">Баланс: <strong>{balance} ₴</strong></div>
      </motion.aside>}</AnimatePresence>
    </section>
  </main>
}
