import { useEffect, useMemo, useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { LogOut, Settings, Volume2 } from 'lucide-react'
import type { Room, User } from '../api'
import { playDiceRoll, playPawnMove, unlockAudio } from '../audio'
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
  const cells = useMemo(() => makeCells(room.boardSize),[room.boardSize])


  const roll = async () => {
    if (rolling || players[turn]?.id !== user.id) return
    await unlockAudio()
    setRolling(true); playDiceRoll()
    window.setTimeout(() => {
      const a=1+Math.floor(Math.random()*6), b=1+Math.floor(Math.random()*6)
      setDice([a,b]); setPositions(old=>old.map((p,i)=>i===turn?(p+a+b)%cells.length:p)); setRolling(false); playPawnMove(a+b)
      window.setTimeout(()=>{ setTurn(value=>(value+1)%players.length); setTurnNoticeId(value=>value+1) },Math.max(900,(a+b)*190+260))
    },700)
  }

  return <main className="classicGame">
    <header className="classicHeader"><div className="gameBrand"><span>КупиМісто</span><small>{room.code}</small></div><div className="topTurn">Хід {players[turn]?.name}</div><div className="gameTools"><button><Volume2/></button><button><Settings/></button><button onClick={onExit}><LogOut/><span>Вийти</span></button></div></header>
    <section className="boardOnly">
      <div className="rotateHint">Права кнопка: обертання. Колесо: масштаб</div>
      <ClassicBoard3D size={room.boardSize} positions={positions} players={players} dice={dice} rolling={rolling}/>
      {players.slice(0,6).map((player,index)=><div key={player.id} className={`cornerPlayer corner${index+1} ${turn===index?'current':''}`}>
        <div className={`cornerAvatar ${colors[index]}`}>{player.name.slice(0,1).toUpperCase()}<i/></div><span><strong>{player.name}</strong><small>{turn===index?'Зараз ходить':'1500 ₴'}</small></span>
      </div>)}
      <AnimatePresence>{<motion.div key={turnNoticeId} className="turnAnnouncement" initial={{opacity:0,scale:.9,y:26}} animate={{opacity:[0,1,1,0],scale:[.9,1,1,.82],y:[26,0,0,-260]}} transition={{duration:1.75,times:[0,.16,.62,1],ease:[.16,1,.3,1]}}><small>НАСТУПНИЙ ХІД</small><strong>{players[turn]?.id===user.id?'Твій хід':`Хід: ${players[turn]?.name}`}</strong></motion.div>}</AnimatePresence>
      <div className="diceAction"><span>{dice[0]} + {dice[1]}</span><button onClick={roll} disabled={rolling||players[turn]?.id!==user.id}>{rolling?'Кубики летять':'Кинути кубики'}</button></div>
    </section>
  </main>
}
