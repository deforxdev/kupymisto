import { useEffect, useState, type FormEvent } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { ArrowRight, Check, Copy, DoorOpen, LogOut, Plus, Users, X } from 'lucide-react'
import { api, clearToken, type AgeGroup, type BoardSize, type Room, type User } from '../api'
import GameScreen from './GameScreen'
import { playUiSound } from '../audio'

type Props = { user: User; onLogout: () => void }

export default function LobbyScreen({ user, onLogout }: Props) {
  const [room, setRoom] = useState<Room | null>(null)
  const [roomName, setRoomName] = useState(`${user.name}, місто і компанія`)
  const [maxPlayers, setMaxPlayers] = useState(4)
  const [ageGroup, setAgeGroup] = useState<AgeGroup>('14-15')
  const [boardSize, setBoardSize] = useState<BoardSize>('standard')
  const [gameStarted, setGameStarted] = useState(false)
  const [joinCode, setJoinCode] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    if (!room) return
    const timer = window.setInterval(async () => {
      try { setRoom((await api.getRoom(room.code)).room) } catch { /* room may be closing */ }
    }, 2500)
    return () => window.clearInterval(timer)
  }, [room?.code])

  const run = async (action: () => Promise<{ room: Room }>) => {
    setError(''); setLoading(true)
    try { const result = await action(); setRoom(result.room); playUiSound('success') }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Не вдалося') }
    finally { setLoading(false) }
  }

  const createRoom = (event: FormEvent) => { event.preventDefault(); void run(() => api.createRoom({ name: roomName.trim(), maxPlayers })) }
  const joinRoom = (event: FormEvent) => { event.preventDefault(); void run(() => api.joinRoom(joinCode.replace(/[^a-z0-9]/gi, '').toUpperCase())) }
  const copyCode = async () => { if (!room) return; await navigator.clipboard.writeText(room.code); setCopied(true); playUiSound('select'); window.setTimeout(() => setCopied(false), 1600) }
  const leave = async () => { if (!room) return; await api.leaveRoom(room.code).catch(() => null); setRoom(null) }
  const logout = () => { clearToken(); onLogout() }

  if (room && gameStarted) return <GameScreen room={room} user={user} onExit={() => setGameStarted(false)} />

  if (room) {
    const me = room.players.find(player => player.id === user.id)
    const host = room.players.find(player => player.host)
    return <main className="roomScreen">
      <header className="lobbyHeader"><a className="brand" href="#"><span>Купи<span>Місто</span></span></a><button className="quietButton" onClick={leave}><X/> Вийти з кімнати</button></header>
      <motion.section className="roomLobby" initial={{ opacity: 0, y: 24 }} animate={{ opacity: 1, y: 0 }}>
        <div className="roomTop">
          <div><span className="sectionNo">ПРИВАТНА КІМНАТА · ВІК {room.ageGroup}</span><h1>{room.name}</h1><p>Гравці заходять напряму за кодом. Ніякого пошуку в загальному списку.</p></div>
          <button className="roomCode" onClick={copyCode} aria-label="Скопіювати код кімнати"><small>КОД ДЛЯ ВХОДУ</small><strong>{room.code}</strong><span>{copied ? <Check/> : <Copy/>}{copied ? 'Скопійовано' : 'Скопіювати'}</span></button>
        </div>
        <div className="roomContent">
          <div className="playersList"><div className="listTitle"><h2>Гравці</h2><span>{room.players.length}/{room.maxPlayers}</span></div>
            {room.players.map((player, index) => <motion.article key={player.id} initial={{ opacity: 0, x: -18 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: index * .06 }}><div className={`avatar avatar${index % 4}`}>{player.name.slice(0, 1).toUpperCase()}</div><div><strong>{player.name}</strong><small>{player.host ? 'Власник кімнати' : player.ready ? 'Готовий грати' : 'Ще думає'}</small></div><span className={player.ready ? 'ready yes' : 'ready'}>{player.ready ? 'ГОТОВИЙ' : 'НЕ ГОТОВИЙ'}</span></motion.article>)}
            {Array.from({ length: Math.max(0, room.maxPlayers - room.players.length) }).map((_, i) => <article className="emptyPlayer" key={i}><div className="avatar"><Plus/></div><div><strong>Вільне місце</strong><small>Надішли код другу</small></div></article>)}
          </div>
          <aside className="roomActions"><div className="insideRoomSettings"><span>НАЛАШТУВАННЯ ГРИ</span><label>Віковий режим<select value={room.ageGroup} disabled={host?.id !== user.id} onChange={async e => { const ageGroup=e.target.value as AgeGroup; setAgeGroup(ageGroup); setRoom((await api.updateRoom(room.code,{ageGroup,boardSize:room.boardSize})).room) }}><option value="10-12">10–12 років</option><option value="14-15">14–15 років</option><option value="18-20">18–20 років</option></select></label><label>Розмір карти<select value={room.boardSize} disabled={host?.id !== user.id} onChange={async e => { const boardSize=e.target.value as BoardSize; setBoardSize(boardSize); setRoom((await api.updateRoom(room.code,{ageGroup:room.ageGroup,boardSize})).room) }}><option value="standard">Стандартна, 40 клітинок</option><option value="large">Велика, 56 клітинок</option></select></label></div><p>Власник: <strong>{host?.name}</strong></p><button className={`primary readyButton ${me?.ready ? 'isReady' : ''}`} onClick={() => void run(() => api.toggleReady(room.code))}>{me?.ready ? 'Я готовий' : 'Позначити готовність'}<Check/></button><button className="startButton" onClick={() => setGameStarted(true)} disabled={!host || host.id !== user.id}>Почати тестову гру<ArrowRight/></button><small>{host?.id === user.id ? 'Тестовий режим: можна почати навіть одному.' : 'Власник кімнати може почати гру.'}</small></aside>
        </div>
      </motion.section>
    </main>
  }

  return <main className="lobbyScreen">
    <header className="lobbyHeader"><a className="brand" href="#"><span>Купи<span>Місто</span></span></a><div className="userMenu"><div className="miniAvatar">{user.name.slice(0, 1).toUpperCase()}</div><span><strong>{user.name}</strong><small>{user.email}</small></span><button onClick={logout} aria-label="Вийти з акаунта"><LogOut/></button></div></header>
    <motion.section className="lobbyHome" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
      <div className="lobbyIntro"><span className="sectionNo">ІГРОВЕ ЛОБІ</span><h1>Збирай своїх.<br/><em>Без зайвих очей.</em></h1><p>Створи приватну кімнату або введи код, який надіслав друг. Публічного списку кімнат тут немає, і це правильно.</p></div>
      <div className="lobbyForms">
        <form className="createRoomForm" onSubmit={createRoom}><div className="formIcon"><Plus/></div><h2>Створити кімнату</h2><p>Ти станеш власником і отримаєш унікальний код.</p><label>Назва<input value={roomName} onChange={e => setRoomName(e.target.value)} minLength={3} maxLength={40} required/></label><label>Гравців<select value={maxPlayers} onChange={e => setMaxPlayers(Number(e.target.value))}><option value={2}>2 гравці</option><option value={3}>3 гравці</option><option value={4}>4 гравці</option><option value={5}>5 гравців</option><option value={6}>6 гравців</option></select></label><button className="primary" disabled={loading}>Створити<ArrowRight/></button></form>
        <div className="formDivider"><span>АБО</span></div>
        <form className="joinRoomForm" onSubmit={joinRoom}><div className="formIcon blue"><DoorOpen/></div><h2>Увійти за кодом</h2><p>Код має вигляд <strong>KTTYCTT6</strong>. Вводь без пробілів.</p><label>Код кімнати<input className="codeInput" value={joinCode} onChange={e => setJoinCode(e.target.value.toUpperCase().slice(0, 8))} pattern="[A-Za-z0-9]{8}" minLength={8} maxLength={8} placeholder="KTTYCTT6" required/></label><button className="primary blueButton" disabled={loading || joinCode.length !== 8}>Увійти<ArrowRight/></button></form>
      </div>
      <AnimatePresence>{error && <motion.p className="lobbyError" initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}>{error}</motion.p>}</AnimatePresence>
    </motion.section>
  </main>
}
