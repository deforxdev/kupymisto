import { useEffect, useMemo, useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { Building2, Check, Clock3, Home, LogOut, Settings, Volume2, X } from 'lucide-react'
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
  const [selectedCell,setSelectedCell] = useState(0)
  const [owned,setOwned] = useState<number[]>([])
  const [balance,setBalance] = useState(1500)
  const [cardOpen,setCardOpen] = useState(false)
  const [phase,setPhase] = useState<'roll'|'moving'|'decision'>('roll')
  const [timeLeft,setTimeLeft] = useState(30)
  const [meme,setMeme] = useState('')
  const cells = useMemo(() => makeCells(room.boardSize),[room.boardSize])

  useEffect(() => {
    setTimeLeft(phase === 'decision' ? 15 : phase === 'roll' ? 30 : 0)
  }, [phase, turn])

  useEffect(() => {
    if (phase === 'moving' || timeLeft <= 0) return
    const timer = window.setTimeout(() => setTimeLeft(value => Math.max(0, value - 1)), 1000)
    return () => window.clearTimeout(timer)
  }, [phase, timeLeft])


  const finishTurn = () => {
    setCardOpen(false)
    setPhase('roll')
    setTurn(value => (value + 1) % players.length)
  }

  useEffect(() => {
    if (timeLeft > 0) return
    if (phase === 'roll') {
      if (players[turn]?.id === user.id) void roll()
      else finishTurn()
    }
    if (phase === 'decision') finishTurn()
  }, [timeLeft])

  const roll = async () => {
    if (rolling || phase !== 'roll' || players[turn]?.id !== user.id) return
    await unlockAudio()
    setPhase('moving')
    setRolling(true); playDiceRoll()
    window.setTimeout(() => {
      const a=1+Math.floor(Math.random()*6), b=1+Math.floor(Math.random()*6)
      setDice([a,b]); setRolling(false)
      window.setTimeout(() => {
        const destination=(positions[turn]+a+b)%cells.length
        const landed=cells[destination]
        setSelectedCell(destination)
        playPawnMove(a+b)
        setPositions(old=>old.map((p,i)=>i===turn?destination:p))
        window.setTimeout(()=>{
          if (landed.kind==='city') {
            setCardOpen(true)
            setPhase('decision')
          } else {
            if (landed.kind==='chance') {
              const lines=['Доброго вечора, ми з КупиМіста. Банк дарує 100 ₴.','Пес Патрон тримає район. Отримай 80 ₴ за безпечний маршрут.','Бавовна цін на оренду: отримай компенсацію 120 ₴.']
              setMeme(lines[Math.floor(Math.random()*lines.length)])
              window.setTimeout(()=>setMeme(''),2800)
            }
            finishTurn()
          }
        },Math.max(900,(a+b)*190+260))
      }, 1000)
    },700)
  }

  const selected=cells[selectedCell]
  const userPlayerIndex=Math.max(0,players.findIndex(player=>player.id===user.id))
  const userPosition=positions[userPlayerIndex]??0
  const standingOnSelected=userPosition===selectedCell
  const baseRent=selected.price ? Math.max(10,Math.round(selected.price*.12/5)*5) : 0
  const oneHouse=baseRent*3
  const twoHouses=baseRent*7
  const threeHouses=baseRent*12
  const canBuy=standingOnSelected&&selected.kind==='city'&&!owned.includes(selectedCell)&&balance>=(selected.price||0)
  const buy=()=>{if(!canBuy)return;setBalance(value=>value-(selected.price||0));setOwned(value=>[...value,selectedCell]);playUiSound('success');finishTurn()}

  return <main className="classicGame">
    <header className="classicHeader"><div className="gameBrand"><span>КупиМісто</span><small>{room.code}</small></div><div className="topTurn"><strong>{players[turn]?.id===user.id?'ВАШ ХІД':`ХІД: ${players[turn]?.name}`}</strong><span><Clock3/>{phase==='moving'?'Фішка рухається':`${timeLeft} с`}</span></div><div className="gameTools"><button><Volume2/></button><button><Settings/></button><button onClick={onExit}><LogOut/><span>Вийти</span></button></div></header>
    <section className="boardOnly">
      <div className="rotateHint">Права кнопка: обертання. Колесо: масштаб</div>
      <div className="gameBalanceHud"><small>МІЙ БАЛАНС</small><strong>{balance} ₴</strong></div>
      <ClassicBoard3D size={room.boardSize} positions={positions} players={players} dice={dice} rolling={rolling} onSelectCell={(index)=>{setSelectedCell(index);setCardOpen(true)}}/>
      {players.slice(0,6).map((player,index)=><div key={player.id} className={`cornerPlayer corner${index+1} ${turn===index?'current':''}`}>
        <div className={`cornerAvatar ${colors[index]}`}>{player.name.slice(0,1).toUpperCase()}<i/></div><span><strong>{player.name}</strong><small>{turn===index?'Зараз ходить':'1500 ₴'}</small></span>
      </div>)}
      <div className="diceAction"><span>{dice[0]} + {dice[1]}</span><button onClick={roll} disabled={rolling||phase!=='roll'||players[turn]?.id!==user.id}>{rolling?'Кубики летять':'Кинути кубики'}</button></div>
      <AnimatePresence>{meme&&<motion.div className="memeToast" initial={{opacity:0,y:18}} animate={{opacity:1,y:0}} exit={{opacity:0,y:-18}}>{meme}</motion.div>}</AnimatePresence>
      <AnimatePresence>{cardOpen&&<motion.aside className="propertyPanel" initial={{opacity:0,x:60}} animate={{opacity:1,x:0}} exit={{opacity:0,x:70}} transition={{duration:.36,ease:[.16,1,.3,1]}}>
        <button className="propertyClose" onClick={()=>setCardOpen(false)} aria-label="Закрити картку"><X/></button>
        <div className="propertyBand" style={{background:selected.color}}/>
        <span className="propertyType">{selected.kind==='city'?'МІСЬКА ВЛАСНІСТЬ':selected.kind==='station'?'ТРАНСПОРТ':selected.kind==='chance'?'ПОДІЯ':selected.kind==='tax'?'МІСЬКИЙ ЗБІР':'КУТОВА КЛІТИНКА'}</span>
        <h2>{selected.name}</h2>
        {selected.kind==='city'&&<>
          <div className="propertyPrice"><span>Ціна ділянки</span><strong>{selected.price} ₴</strong></div>
          <div className="rentTable"><div><span>Без будинку</span><b>{baseRent} ₴</b></div><div><span><Home/> 1 будинок</span><b>{oneHouse} ₴</b></div><div><span><Home/> 2 будинки</span><b>{twoHouses} ₴</b></div><div><span><Building2/> 3 будинки</span><b>{threeHouses} ₴</b></div></div>
          <p className="propertyNote">{standingOnSelected?'Твоя фішка стоїть тут. Ділянку можна придбати.':'Це режим перегляду. Купівля доступна лише тоді, коли твоя фішка зупинилась на цій клітинці.'}</p>
          {owned.includes(selectedCell)?<div className="ownedLabel"><Check/> Це твоя власність</div>:standingOnSelected&&phase==='decision'?<div className="propertyActions"><button className="buyProperty" disabled={!canBuy} onClick={buy}>{balance<(selected.price||0)?'Недостатньо коштів':`Купити за ${selected.price} ₴`}</button><button className="skipProperty" onClick={finishTurn}>Не купувати</button><small className="decisionTimer"><Clock3/> На рішення: {timeLeft} с</small></div>:null}
        </>}
        {selected.kind!=='city'&&<p className="specialCellText">Ця клітинка не продається. Її дія спрацює після завершення ходу.</p>}
        <div className="panelBalance">Баланс: <strong>{balance} ₴</strong></div>
      </motion.aside>}</AnimatePresence>
    </section>
  </main>
}
