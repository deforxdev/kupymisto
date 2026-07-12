import { useEffect, useMemo, useState } from 'react'
import { motion } from 'framer-motion'
import { X } from 'lucide-react'
import { api, type Room } from '../api'
import { makeCells } from './ClassicBoard3D'

interface AdminPanelProps {
  room: Room
  adminId: string
  onRoom: (room: Room) => void
  onClose: () => void
}

const buttonMotion = { whileTap: { scale: 0.96, y: 2 }, transition: { type: 'spring' as const, stiffness: 400, damping: 10 } }

export default function AdminPanel({ room, adminId, onRoom, onClose }: AdminPanelProps) {
  const cells = useMemo(() => makeCells(room.boardSize), [room.boardSize])
  const propertyCells = useMemo(() => cells.map((cell, index) => ({ cell, index })).filter(({ cell }) => cell.kind === 'city'), [cells])
  const players = room.players
  const [playerId, setPlayerId] = useState(players.find((player) => player.id !== adminId)?.id ?? players[0]?.id ?? '')
  const [cellIndex, setCellIndex] = useState(propertyCells[0]?.index ?? 0)
  const [houseCount, setHouseCount] = useState(room.houses?.[String(cellIndex)] ?? 0)
  const [delta, setDelta] = useState(100)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  useEffect(() => {
    if (!players.some((player) => player.id === playerId) || playerId === adminId) setPlayerId(players.find((player) => player.id !== adminId)?.id ?? '')
  }, [players, playerId, adminId])

  const run = async (operation: () => Promise<{ room: Room }>, success: string) => {
    setError('')
    setMessage('')
    try {
      const result = await operation()
      onRoom(result.room)
      setMessage(success)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Адмінську дію не виконано')
    }
  }

  const selectedOwner = room.ownership?.[String(cellIndex)]
  const selectCell = (value: string) => {
    const next = Number(value)
    setCellIndex(next)
    setHouseCount(room.houses?.[String(next)] ?? 0)
  }

  return (
    <aside className="adminPanel">
      <button className="tradeClose" onClick={onClose} aria-label="Закрити адмін-панель"><X /></button>
      <span className="adminEyebrow">АДМІН-КЕРУВАННЯ</span>
      <h2>Керування грою</h2>
      <p className="adminHint">Зміни застосовуються одразу для всіх гравців.</p>

      <label>Гравець
        <select value={playerId} onChange={(event) => setPlayerId(event.target.value)}>
          {players.map((player) => <option value={player.id} key={player.id}>{player.name}</option>)}
        </select>
      </label>
      <motion.button className="adminDanger adminWide" {...buttonMotion} disabled={!playerId || playerId === adminId || players.length < 2} onClick={() => {
        if (window.confirm(`Кікнути ${players.find((player) => player.id === playerId)?.name ?? 'гравця'} з гри?`)) {
          void run(() => api.adminKickPlayer(room.code, playerId), 'Гравця кікнуто, його клітинки звільнено')
        }
      }}>Кікнути гравця</motion.button>

      <section className="adminSection">
        <strong>Власність клітинки</strong>
        <select value={cellIndex} onChange={(event) => selectCell(event.target.value)}>
          {propertyCells.map(({ cell, index }) => <option value={index} key={index}>{index}. {cell.name}{room.ownership?.[String(index)] ? ` — ${players.find((player) => player.id === room.ownership[String(index)])?.name ?? 'власник'}` : ''}</option>)}
        </select>
        <div className="adminActions">
          <motion.button className="adminPrimary" {...buttonMotion} onClick={() => void run(() => api.adminSetOwnership(room.code, { playerId, cellIndex, action: 'grant' }), 'Власність додано')}>Дати клітинку</motion.button>
          <motion.button className="adminDanger" {...buttonMotion} onClick={() => void run(() => api.adminSetOwnership(room.code, { playerId, cellIndex, action: 'revoke' }), 'Власність забрано')}>Забрати</motion.button>
        </div>
      </section>

      <section className="adminSection">
        <strong>Будинки</strong>
        <select value={houseCount} onChange={(event) => setHouseCount(Number(event.target.value))}>
          {[0, 1, 2, 3].map((count) => <option value={count} key={count}>{count} будинків</option>)}
        </select>
        <motion.button className="adminPrimary adminWide" {...buttonMotion} disabled={!selectedOwner} onClick={() => void run(() => api.adminSetHouses(room.code, { cellIndex, count: houseCount }), selectedOwner ? 'Кількість будинків змінено' : 'Спочатку дай клітинку гравцю')}>Застосувати будинки</motion.button>
      </section>

      <section className="adminSection">
        <strong>Баланс: {room.balances?.[playerId] ?? 0} ₴</strong>
        <input type="number" value={delta} onChange={(event) => setDelta(Number(event.target.value))} placeholder="Сума" />
        <p className="adminHint">Плюс додає гроші, мінус забирає.</p>
        <motion.button className="adminPrimary adminWide" {...buttonMotion} disabled={!delta} onClick={() => void run(() => api.adminAdjustBalance(room.code, { playerId, delta }), 'Баланс змінено')}>Змінити баланс</motion.button>
      </section>

      {message && <p className="adminSuccess" role="status">{message}</p>}
      {error && <p className="tradeError" role="alert">{error}</p>}
    </aside>
  )
}
