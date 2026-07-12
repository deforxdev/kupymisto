import { useMemo, useState } from 'react'
import { motion } from 'framer-motion'
import { Banknote, Building2, CircleDollarSign, Dice5, Flag, LogOut, MapPin, Settings, Volume2 } from 'lucide-react'
import type { Room, User } from '../api'
import { playUiSound } from '../audio'

type Props = { room: Room; user: User; onExit: () => void }
type Cell = { name: string; type: 'city' | 'chance' | 'tax' | 'start'; price?: number; color: string }

const ageCopy = {
  '10-12': { event: 'Тобі випав міський бонус: новий скейт-парк приносить 200 ₴.', center: 'МІСТО ПРИГОД', label: 'Легкий режим' },
  '14-15': { event: 'Твій район залетів у рекомендації. Банк нарахував 200 ₴.', center: 'МІСТО В ТРЕНДІ', label: 'Трендовий режим' },
  '18-20': { event: 'Повернення податку за каву не існує, але банк дарує 200 ₴.', center: 'МІСТО НА ОРЕНДІ', label: 'Студентський режим' },
} as const

const cells: Cell[] = [
  { name: 'СТАРТ', type: 'start', color: 'yellow' },
  { name: 'Львів', type: 'city', price: 180, color: 'blue' },
  { name: 'Шанс', type: 'chance', color: 'paper' },
  { name: 'Ужгород', type: 'city', price: 140, color: 'green' },
  { name: 'Податок', type: 'tax', color: 'red' },
  { name: 'Київ', type: 'city', price: 320, color: 'blue' },
  { name: 'Шанс', type: 'chance', color: 'paper' },
  { name: 'Чернігів', type: 'city', price: 160, color: 'green' },
  { name: 'Паркінг', type: 'chance', color: 'yellow' },
  { name: 'Харків', type: 'city', price: 240, color: 'red' },
  { name: 'Банк', type: 'chance', color: 'paper' },
  { name: 'Дніпро', type: 'city', price: 230, color: 'blue' },
  { name: 'Аеропорт', type: 'tax', color: 'red' },
  { name: 'Одеса', type: 'city', price: 260, color: 'green' },
  { name: 'Шанс', type: 'chance', color: 'paper' },
  { name: 'Чернівці', type: 'city', price: 150, color: 'yellow' },
]

const boardPositions = [
  [4,4],[4,3],[4,2],[4,1],[4,0],[3,0],[2,0],[1,0],[0,0],[0,1],[0,2],[0,3],[0,4],[1,4],[2,4],[3,4]
]

function CellIcon({ type }: { type: Cell['type'] }) {
  if (type === 'start') return <Flag />
  if (type === 'city') return <Building2 />
  if (type === 'tax') return <Banknote />
  return <CircleDollarSign />
}

export default function GameScreen({ room, user, onExit }: Props) {
  const [position, setPosition] = useState(0)
  const [dice, setDice] = useState<[number, number]>([1, 1])
  const [rolling, setRolling] = useState(false)
  const [balance, setBalance] = useState(1500)
  const [notice, setNotice] = useState('Твій хід. Кидай кубики.')
  const copy = ageCopy[room.ageGroup]
  const players = useMemo(() => room.players.length ? room.players : [{ id: user.id, name: user.name, host: true, ready: true }], [room.players, user])

  const roll = () => {
    if (rolling) return
    setRolling(true)
    playUiSound('click')
    window.setTimeout(() => {
      const first = Math.floor(Math.random() * 6) + 1
      const second = Math.floor(Math.random() * 6) + 1
      const next = (position + first + second) % cells.length
      setDice([first, second]); setPosition(next); setRolling(false)
      const cell = cells[next]
      if (cell.type === 'city') setNotice(`${cell.name}: можна придбати за ${cell.price} ₴.`)
      else if (cell.type === 'tax') { setBalance(value => Math.max(0, value - 100)); setNotice('Міський збір: сплачено 100 ₴.') }
      else if (cell.type === 'start') { setBalance(value => value + 200); setNotice('Нове коло: банк видав 200 ₴.') }
      else { setBalance(value => value + 200); setNotice(copy.event) }
      playUiSound('success')
    }, 620)
  }

  return <main className="gameScreen">
    <header className="gameHeader">
      <div className="gameBrand"><span>КупиМісто</span><small>{room.code}</small></div>
      <div className="turnStatus"><i /> Твій хід</div>
      <div className="gameTools"><button aria-label="Звук"><Volume2 /></button><button aria-label="Налаштування"><Settings /></button><button onClick={onExit}><LogOut /><span>Вийти</span></button></div>
    </header>

    <section className="gameLayout">
      <aside className="gamePlayers">
        <div className="gameAsideTitle"><span>ГРАВЦІ</span><b>{players.length}/{room.maxPlayers}</b></div>
        {players.map((player, index) => <article className={player.id === user.id ? 'active' : ''} key={player.id}>
          <div className={`playerPortrait portrait${index % 4}`}><span>{player.name.slice(0, 1).toUpperCase()}</span><i /></div>
          <div><strong>{player.name}</strong><small>{player.id === user.id ? 'Твій хід' : 'Очікує'}</small></div>
          <b>{player.id === user.id ? balance : 1500} ₴</b>
        </article>)}
        <div className="gameLog"><span>ПОДІЇ</span><p>{notice}</p></div>
      </aside>

      <div className="boardStage">
        <motion.div className="gameBoard" initial={{ opacity: 0, rotateX: 48, rotateZ: -4, scale: .88 }} animate={{ opacity: 1, rotateX: 51, rotateZ: -4, scale: 1 }} transition={{ duration: .9, ease: [0.16,1,0.3,1] }}>
          <div className="boardCenter"><MapPin /><small>{copy.label}</small><strong>{copy.center}</strong><span>Код кімнати: {room.code}</span></div>
          {cells.map((cell, index) => {
            const [row, column] = boardPositions[index]
            return <div className={`boardCell ${cell.color}`} style={{ gridRow: row + 1, gridColumn: column + 1 }} key={`${cell.name}-${index}`}>
              <CellIcon type={cell.type}/><strong>{cell.name}</strong>{cell.price && <small>{cell.price} ₴</small>}
              {position === index && <motion.div className="piece" layoutId="main-piece" transition={{ duration: .55, ease: [0.16,1,0.3,1] }}><i/><span/></motion.div>}
            </div>
          })}
        </motion.div>
      </div>

      <aside className="turnPanel">
        <span className="turnLabel">ХІД 01</span><h2>{user.name}, твоя черга</h2>
        <div className={`dicePair ${rolling ? 'rolling' : ''}`}><div>{dice[0]}</div><div>{dice[1]}</div></div>
        <button className="primary rollButton" onClick={roll} disabled={rolling}><Dice5 />{rolling ? 'Кубики летять' : 'Кинути кубики'}</button>
        <div className="balance"><span>Твій баланс</span><strong>{balance} ₴</strong></div>
        <button className="buyButton" disabled={cells[position].type !== 'city' || balance < (cells[position].price || 0)} onClick={() => { const price=cells[position].price||0; setBalance(v=>v-price); setNotice(`${cells[position].name} тепер твій район.`); playUiSound('success') }}>Придбати район</button>
      </aside>
    </section>
  </main>
}
