#!/usr/bin/env bash
set -euo pipefail

if [ ! -f frontend/src/App.tsx ] || [ ! -f backend/cmd/api/main.go ]; then
  echo "Запусти цей файл у корені репозиторію kupymisto."
  exit 1
fi

cat > frontend/src/api.ts <<'EOF'
export type User = { id: string; name: string; email: string }
export type Player = { id: string; name: string; host: boolean; ready: boolean }
export type Room = { code: string; name: string; maxPlayers: number; players: Player[]; createdAt: string }

type ApiError = { error?: string }

const TOKEN_KEY = 'kupymisto_token'
export const getToken = () => localStorage.getItem(TOKEN_KEY)
export const setToken = (token: string) => localStorage.setItem(TOKEN_KEY, token)
export const clearToken = () => localStorage.removeItem(TOKEN_KEY)

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = getToken()
  const response = await fetch(path, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...init.headers,
    },
  })
  const data = await response.json().catch(() => ({})) as T & ApiError
  if (!response.ok) throw new Error(data.error || 'Щось пішло не так')
  return data
}

export const api = {
  register: (body: { name: string; email: string; password: string }) => request<{ token: string; user: User }>('/api/auth/register', { method: 'POST', body: JSON.stringify(body) }),
  login: (body: { email: string; password: string }) => request<{ token: string; user: User }>('/api/auth/login', { method: 'POST', body: JSON.stringify(body) }),
  me: () => request<{ user: User }>('/api/auth/me'),
  createRoom: (body: { name: string; maxPlayers: number }) => request<{ room: Room }>('/api/rooms', { method: 'POST', body: JSON.stringify(body) }),
  joinRoom: (code: string) => request<{ room: Room }>(`/api/rooms/${code}/join`, { method: 'POST' }),
  getRoom: (code: string) => request<{ room: Room }>(`/api/rooms/${code}`),
  toggleReady: (code: string) => request<{ room: Room }>(`/api/rooms/${code}/ready`, { method: 'POST' }),
  leaveRoom: (code: string) => request<{ ok: boolean }>(`/api/rooms/${code}/leave`, { method: 'POST' }),
}
EOF

cat > frontend/src/components/AuthScreen.tsx <<'EOF'
import { useState, type FormEvent } from 'react'
import { motion } from 'framer-motion'
import { ArrowUpRight, Eye, EyeOff, LockKeyhole } from 'lucide-react'
import { api, setToken, type User } from '../api'
import { playUiSound } from '../audio'

type Props = { onSuccess: (user: User) => void; onBack: () => void }

export default function AuthScreen({ onSuccess, onBack }: Props) {
  const [mode, setMode] = useState<'login' | 'register'>('register')
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  async function submit(event: FormEvent) {
    event.preventDefault()
    setError('')
    setLoading(true)
    try {
      const result = mode === 'register'
        ? await api.register({ name: name.trim(), email: email.trim(), password })
        : await api.login({ email: email.trim(), password })
      setToken(result.token)
      playUiSound('success')
      onSuccess(result.user)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Не вдалося продовжити')
    } finally { setLoading(false) }
  }

  const changeMode = (next: 'login' | 'register') => {
    setMode(next); setError(''); playUiSound('select')
  }

  return <main className="authScreen">
    <button className="backLink" onClick={onBack}>Назад на головну</button>
    <motion.section className="authPanel" initial={{ opacity: 0, y: 28 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: .65, ease: [0.16, 1, 0.3, 1] }}>
      <div className="authArt" aria-hidden="true">
        <LockKeyhole />
        <p>Свої люди.<br/>Свої правила.<br/><span>Своє місто.</span></p>
        <div className="authBlock blockOne"/><div className="authBlock blockTwo"/><div className="authBlock blockThree"/>
      </div>
      <div className="authFormWrap">
        <div className="authTabs" role="tablist">
          <button className={mode === 'register' ? 'active' : ''} onClick={() => changeMode('register')}>Реєстрація</button>
          <button className={mode === 'login' ? 'active' : ''} onClick={() => changeMode('login')}>Вхід</button>
        </div>
        <h1>{mode === 'register' ? 'Створи акаунт' : 'З поверненням'}</h1>
        <p>{mode === 'register' ? 'Один акаунт для кімнат, друзів і майбутніх перемог.' : 'Твоє місто нікуди не поділося.'}</p>
        <form onSubmit={submit}>
          {mode === 'register' && <label>Ім’я<input value={name} onChange={e => setName(e.target.value)} autoComplete="name" minLength={2} maxLength={30} required placeholder="Як тебе називати у грі" /></label>}
          <label>Email<input type="email" value={email} onChange={e => setEmail(e.target.value)} autoComplete="email" required placeholder="you@example.com" /></label>
          <label>Пароль<span className="passwordField"><input type={showPassword ? 'text' : 'password'} value={password} onChange={e => setPassword(e.target.value)} autoComplete={mode === 'register' ? 'new-password' : 'current-password'} minLength={8} required placeholder="Мінімум 8 символів"/><button type="button" onClick={() => setShowPassword(!showPassword)} aria-label={showPassword ? 'Сховати пароль' : 'Показати пароль'}>{showPassword ? <EyeOff/> : <Eye/>}</button></span></label>
          {error && <p className="formError" role="alert">{error}</p>}
          <button className="primary authSubmit" disabled={loading}>{loading ? 'Зачекай...' : mode === 'register' ? 'Створити акаунт' : 'Увійти'}<ArrowUpRight /></button>
        </form>
      </div>
    </motion.section>
  </main>
}
EOF

cat > frontend/src/components/LobbyScreen.tsx <<'EOF'
import { useEffect, useState, type FormEvent } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { ArrowRight, Check, Copy, DoorOpen, LogOut, Plus, Users, X } from 'lucide-react'
import { api, clearToken, type Room, type User } from '../api'
import { playUiSound } from '../audio'

type Props = { user: User; onLogout: () => void }

export default function LobbyScreen({ user, onLogout }: Props) {
  const [room, setRoom] = useState<Room | null>(null)
  const [roomName, setRoomName] = useState(`${user.name}, місто і компанія`)
  const [maxPlayers, setMaxPlayers] = useState(4)
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

  if (room) {
    const me = room.players.find(player => player.id === user.id)
    const host = room.players.find(player => player.host)
    return <main className="roomScreen">
      <header className="lobbyHeader"><a className="brand" href="#"><span>Купи<span>Місто</span></span></a><button className="quietButton" onClick={leave}><X/> Вийти з кімнати</button></header>
      <motion.section className="roomLobby" initial={{ opacity: 0, y: 24 }} animate={{ opacity: 1, y: 0 }}>
        <div className="roomTop">
          <div><span className="sectionNo">ПРИВАТНА КІМНАТА</span><h1>{room.name}</h1><p>Гравці заходять напряму за кодом. Ніякого пошуку в загальному списку.</p></div>
          <button className="roomCode" onClick={copyCode} aria-label="Скопіювати код кімнати"><small>КОД ДЛЯ ВХОДУ</small><strong>{room.code}</strong><span>{copied ? <Check/> : <Copy/>}{copied ? 'Скопійовано' : 'Скопіювати'}</span></button>
        </div>
        <div className="roomContent">
          <div className="playersList"><div className="listTitle"><h2>Гравці</h2><span>{room.players.length}/{room.maxPlayers}</span></div>
            {room.players.map((player, index) => <motion.article key={player.id} initial={{ opacity: 0, x: -18 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: index * .06 }}><div className={`avatar avatar${index % 4}`}>{player.name.slice(0, 1).toUpperCase()}</div><div><strong>{player.name}</strong><small>{player.host ? 'Власник кімнати' : player.ready ? 'Готовий грати' : 'Ще думає'}</small></div><span className={player.ready ? 'ready yes' : 'ready'}>{player.ready ? 'ГОТОВИЙ' : 'НЕ ГОТОВИЙ'}</span></motion.article>)}
            {Array.from({ length: Math.max(0, room.maxPlayers - room.players.length) }).map((_, i) => <article className="emptyPlayer" key={i}><div className="avatar"><Plus/></div><div><strong>Вільне місце</strong><small>Надішли код другу</small></div></article>)}
          </div>
          <aside className="roomActions"><p>Власник: <strong>{host?.name}</strong></p><button className={`primary readyButton ${me?.ready ? 'isReady' : ''}`} onClick={() => void run(() => api.toggleReady(room.code))}>{me?.ready ? 'Я готовий' : 'Позначити готовність'}<Check/></button><button className="startButton" disabled={!host || host.id !== user.id || room.players.length < 2 || room.players.some(p => !p.ready)}>Почати гру<ArrowRight/></button><small>{room.players.length < 2 ? 'Потрібно хоча б двоє гравців.' : room.players.some(p => !p.ready) ? 'Чекаємо готовності всіх гравців.' : host?.id === user.id ? 'Усі готові. Можна починати.' : 'Власник кімнати може почати гру.'}</small></aside>
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
EOF

python3 <<'PY'
from pathlib import Path
p=Path('frontend/src/App.tsx')
s=p.read_text(encoding='utf-8')
s=s.replace("import { useEffect, useState } from 'react'", "import { useEffect, useState } from 'react'")
s=s.replace("import { playUiSound, startAmbience, stopAmbience } from './audio'", "import { playUiSound, startAmbience, stopAmbience } from './audio'\nimport AuthScreen from './components/AuthScreen'\nimport LobbyScreen from './components/LobbyScreen'\nimport { api, clearToken, getToken, type User } from './api'")
s=s.replace("  const [buttonState, setButtonState] = useState('Створити кімнату')", "  const [buttonState, setButtonState] = useState('Створити кімнату')\n  const [screen, setScreen] = useState<'home' | 'auth' | 'lobby'>('home')\n  const [user, setUser] = useState<User | null>(null)")
needle="  useEffect(() => {\n    if (reduceMotion) return"
insert="""  useEffect(() => {
    if (!getToken()) return
    api.me().then(({ user }) => { setUser(user); setScreen('lobby') }).catch(() => clearToken())
  }, [])

"""
s=s.replace(needle, insert+needle)
start=s.index("  const createRoom = async () => {")
end=s.index("\n  const selectAge", start)
s=s[:start]+"""  const openGame = () => {
    if (sound) playUiSound('click')
    setScreen(user ? 'lobby' : 'auth')
  }
"""+s[end:]
s=s.replace("  return <>\n    <AnimatePresence>", "  if (screen === 'auth') return <AuthScreen onBack={() => setScreen('home')} onSuccess={(nextUser) => { setUser(nextUser); setScreen('lobby') }} />\n  if (screen === 'lobby' && user) return <LobbyScreen user={user} onLogout={() => { setUser(null); setScreen('home') }} />\n\n  return <>\n    <AnimatePresence>")
s=s.replace('onClick={createRoom}', 'onClick={openGame}')
p.write_text(s, encoding='utf-8')
PY

cat >> frontend/src/styles.css <<'EOF'

/* Authentication */
.authScreen,.lobbyScreen,.roomScreen{min-height:100svh;background:var(--paper)}.backLink{position:fixed;left:28px;top:24px;border:0;background:transparent;font-weight:900;cursor:pointer;z-index:3}.authPanel{min-height:100svh;display:grid;grid-template-columns:.92fr 1.08fr}.authArt{background:var(--yellow);border-right:3px solid var(--ink);padding:9vw 6vw;position:relative;overflow:hidden;display:flex;flex-direction:column;justify-content:center}.authArt>svg{width:54px;height:54px;margin-bottom:32px}.authArt p{font-family:Unbounded;font-size:clamp(38px,5vw,74px);line-height:1.03;letter-spacing:-.06em;position:relative;z-index:2}.authArt p span{color:var(--blue)}.authBlock{position:absolute;border:3px solid var(--ink);box-shadow:7px 7px 0 var(--ink);transform:rotate(12deg)}.blockOne{width:110px;height:110px;background:var(--red);right:8%;top:13%}.blockTwo{width:78px;height:78px;background:var(--green);right:23%;bottom:12%;transform:rotate(-18deg)}.blockThree{width:42px;height:150px;background:var(--blue);left:8%;bottom:-35px;transform:rotate(38deg)}.authFormWrap{padding:11vh clamp(28px,8vw,120px);display:flex;flex-direction:column;justify-content:center}.authTabs{display:flex;border-bottom:2px solid oklch(21% .035 278/.2);gap:28px;margin-bottom:50px}.authTabs button{border:0;background:transparent;padding:0 0 12px;font-weight:900;color:var(--muted);cursor:pointer;position:relative}.authTabs button.active{color:var(--ink)}.authTabs button.active::after{content:"";position:absolute;left:0;right:0;bottom:-2px;height:4px;background:var(--blue)}.authFormWrap h1{font-size:clamp(38px,4vw,64px);margin:0 0 16px;line-height:1}.authFormWrap>p{color:var(--muted);font-weight:700;line-height:1.5;max-width:46ch}.authFormWrap form{display:grid;gap:20px;margin-top:36px}.authFormWrap label,.lobbyForms label{display:grid;gap:8px;font-size:12px;font-weight:900;text-transform:uppercase;letter-spacing:.08em}.authFormWrap input,.lobbyForms input,.lobbyForms select{width:100%;min-height:54px;border:2px solid var(--ink);border-radius:11px;background:oklch(98% .01 96);padding:0 15px;font-size:16px;font-weight:700;text-transform:none;letter-spacing:0}.passwordField{position:relative}.passwordField input{padding-right:50px}.passwordField button{position:absolute;right:7px;top:5px;width:42px;height:42px;border:0;background:transparent;display:grid;place-items:center;cursor:pointer}.passwordField svg{width:20px}.authSubmit{margin-top:8px;justify-content:center}.authSubmit:disabled,.primary:disabled{opacity:.48;cursor:not-allowed;transform:none;box-shadow:none}.formError,.lobbyError{background:oklch(90% .06 25);border:2px solid var(--red);border-radius:10px;padding:12px!important;color:var(--ink)!important;font-size:13px!important;font-weight:800!important}

/* Private lobby home */
.lobbyHeader{height:82px;display:flex;align-items:center;justify-content:space-between;padding:0 clamp(20px,5vw,76px);border-bottom:2px solid var(--ink)}.userMenu{display:flex;align-items:center;gap:11px}.miniAvatar{width:42px;height:42px;border:2px solid var(--ink);border-radius:12px;background:var(--yellow);display:grid;place-items:center;font-family:Unbounded;font-weight:800}.userMenu>span{display:grid}.userMenu strong{font-size:13px}.userMenu small{font-size:11px;color:var(--muted)}.userMenu button{border:0;background:transparent;margin-left:12px;cursor:pointer}.userMenu svg{width:20px}.lobbyHome{padding:84px clamp(20px,6vw,96px) 100px}.lobbyIntro{display:grid;grid-template-columns:1.25fr .75fr;align-items:end;gap:7vw}.lobbyIntro .sectionNo{grid-column:1/-1}.lobbyIntro h1{font-size:clamp(48px,6.6vw,98px);margin:10px 0 0}.lobbyIntro h1 em{color:var(--blue)}.lobbyIntro p{font-size:18px;line-height:1.55;font-weight:700;color:var(--muted);padding-bottom:10px}.lobbyForms{display:grid;grid-template-columns:1fr 64px 1fr;margin-top:72px;border-block:3px solid var(--ink)}.lobbyForms form{padding:38px 4vw 44px;display:grid;gap:18px;align-content:start}.lobbyForms h2{font-family:Unbounded;font-size:clamp(25px,3vw,40px);letter-spacing:-.05em}.lobbyForms form>p{color:var(--muted);font-weight:700;line-height:1.5;min-height:48px}.formIcon{width:54px;height:54px;border:2px solid var(--ink);border-radius:13px;background:var(--yellow);display:grid;place-items:center;box-shadow:4px 4px 0 var(--ink);margin-bottom:8px}.formIcon.blue{background:var(--blue);color:var(--paper)}.formDivider{border-inline:2px solid var(--ink);display:grid;place-items:center}.formDivider span{background:var(--paper);font-size:11px;font-weight:900;padding:12px 0;writing-mode:vertical-rl}.lobbyForms .primary{justify-content:center;margin-top:10px}.blueButton{background:var(--blue);color:var(--paper)}.codeInput{font-family:Unbounded!important;font-size:24px!important;letter-spacing:.12em!important;text-transform:uppercase!important}.lobbyError{max-width:620px;margin:28px auto 0;text-align:center}

/* Room waiting lobby */
.quietButton{display:flex;align-items:center;gap:8px;border:0;background:transparent;font-weight:900;cursor:pointer}.quietButton svg{width:20px}.roomLobby{padding:74px clamp(20px,6vw,96px) 100px}.roomTop{display:grid;grid-template-columns:1fr auto;gap:5vw;align-items:end;padding-bottom:56px;border-bottom:3px solid var(--ink)}.roomTop h1{font-size:clamp(42px,6vw,82px);margin:13px 0 16px;max-width:13ch}.roomTop>div>p{color:var(--muted);font-weight:700;line-height:1.5;max-width:56ch}.roomCode{min-width:310px;border:3px solid var(--ink);border-radius:18px;background:var(--yellow);padding:20px 26px;text-align:left;box-shadow:7px 7px 0 var(--ink);cursor:pointer;transition:transform .15s var(--ease),box-shadow .15s var(--ease)}.roomCode:hover{transform:translate(3px,3px);box-shadow:4px 4px 0 var(--ink)}.roomCode small{font-weight:900;letter-spacing:.1em}.roomCode strong{display:block;font-family:Unbounded;font-size:38px;letter-spacing:.1em;margin:8px 0}.roomCode>span{display:flex;align-items:center;gap:7px;font-size:12px;font-weight:900}.roomCode svg{width:17px}.roomContent{display:grid;grid-template-columns:1fr 340px;gap:8vw;padding-top:56px}.listTitle{display:flex;align-items:center;justify-content:space-between;margin-bottom:22px}.listTitle h2{font-family:Unbounded;font-size:30px}.listTitle span{font-weight:900}.playersList article{min-height:82px;border-top:2px solid var(--ink);display:grid;grid-template-columns:56px 1fr auto;align-items:center;gap:16px}.playersList article:last-child{border-bottom:2px solid var(--ink)}.avatar{width:45px;height:45px;border:2px solid var(--ink);border-radius:12px;display:grid;place-items:center;font-family:Unbounded;font-weight:800;background:var(--paper)}.avatar svg{width:19px}.avatar0{background:var(--yellow)}.avatar1{background:var(--blue);color:var(--paper)}.avatar2{background:var(--green)}.avatar3{background:var(--red);color:var(--paper)}.playersList article>div:nth-child(2){display:grid}.playersList article small{font-size:11px;color:var(--muted);font-weight:700}.ready{font-size:10px;font-weight:900;border:1px solid var(--ink);border-radius:20px;padding:6px 9px;color:var(--muted)}.ready.yes{background:var(--green);color:var(--ink)}.emptyPlayer{opacity:.5}.roomActions{background:var(--blue);color:var(--paper);border:3px solid var(--ink);border-radius:20px;padding:28px;height:max-content;box-shadow:8px 8px 0 var(--ink)}.roomActions>p{font-size:13px;margin-bottom:24px}.roomActions button{width:100%;justify-content:center}.readyButton{background:var(--paper);color:var(--ink)}.readyButton.isReady{background:var(--green)}.startButton{min-height:52px;border:2px solid var(--paper);border-radius:13px;background:var(--ink);color:var(--paper);margin-top:14px;font-weight:900;display:flex;align-items:center;justify-content:center;gap:10px;cursor:pointer}.startButton:disabled{opacity:.35;cursor:not-allowed}.roomActions>small{display:block;margin-top:16px;line-height:1.5;font-weight:700;color:oklch(89% .025 257)}
@media(max-width:820px){.authPanel{grid-template-columns:1fr}.authArt{display:none}.authFormWrap{padding:100px 24px 50px}.lobbyIntro{grid-template-columns:1fr}.lobbyForms{grid-template-columns:1fr;border:0;gap:18px}.lobbyForms form{border:3px solid var(--ink);border-radius:18px}.formDivider{border:0}.formDivider span{writing-mode:horizontal-tb;padding:0}.roomTop{grid-template-columns:1fr}.roomCode{min-width:0;width:100%}.roomContent{grid-template-columns:1fr}.userMenu>span{display:none}}
EOF

cat > backend/go.mod <<'EOF'
module github.com/deforxdev/kupymisto/backend

go 1.24

require golang.org/x/crypto v0.40.0
EOF

cat > backend/cmd/api/main.go <<'EOF'
package main

import (
    "crypto/rand"
    "encoding/base64"
    "encoding/json"
    "errors"
    "log"
    "net/http"
    "regexp"
    "strings"
    "sync"
    "time"

    "golang.org/x/crypto/bcrypt"
)

type User struct { ID string `json:"id"`; Name string `json:"name"`; Email string `json:"email"`; PasswordHash []byte `json:"-"` }
type Player struct { ID string `json:"id"`; Name string `json:"name"`; Host bool `json:"host"`; Ready bool `json:"ready"` }
type Room struct { Code string `json:"code"`; Name string `json:"name"`; MaxPlayers int `json:"maxPlayers"`; Players []Player `json:"players"`; CreatedAt time.Time `json:"createdAt"` }
type Store struct { mu sync.RWMutex; users map[string]User; sessions map[string]string; rooms map[string]*Room }

type contextKey string
const userKey contextKey = "user"
var emailPattern = regexp.MustCompile(`^[^\s@]+@[^\s@]+\.[^\s@]+$`)
var codeAlphabet = []byte("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

func randomString(size int, alphabet []byte) string { b:=make([]byte,size); raw:=make([]byte,size); if _,err:=rand.Read(raw);err!=nil { panic(err) }; for i:=range b { b[i]=alphabet[int(raw[i])%len(alphabet)] }; return string(b) }
func token() string { b:=make([]byte,32); if _,err:=rand.Read(b);err!=nil { panic(err) }; return base64.RawURLEncoding.EncodeToString(b) }
func writeJSON(w http.ResponseWriter,status int,value any){w.Header().Set("Content-Type","application/json; charset=utf-8");w.WriteHeader(status);_ = json.NewEncoder(w).Encode(value)}
func readJSON(r *http.Request,value any) error { dec:=json.NewDecoder(http.MaxBytesReader(nil,r.Body,1<<20));dec.DisallowUnknownFields();return dec.Decode(value) }
func fail(w http.ResponseWriter,status int,message string){writeJSON(w,status,map[string]string{"error":message})}

func main(){
    store:=&Store{users:map[string]User{},sessions:map[string]string{},rooms:map[string]*Room{}}
    mux:=http.NewServeMux()
    mux.HandleFunc("GET /api/health",func(w http.ResponseWriter,_ *http.Request){writeJSON(w,200,map[string]string{"status":"ok"})})

    mux.HandleFunc("POST /api/auth/register",func(w http.ResponseWriter,r *http.Request){
        var in struct{Name string `json:"name"`;Email string `json:"email"`;Password string `json:"password"`};if readJSON(r,&in)!=nil{fail(w,400,"Перевір введені дані");return}
        in.Name=strings.TrimSpace(in.Name);in.Email=strings.ToLower(strings.TrimSpace(in.Email))
        if len([]rune(in.Name))<2||len([]rune(in.Name))>30{fail(w,400,"Ім’я має містити від 2 до 30 символів");return};if !emailPattern.MatchString(in.Email){fail(w,400,"Вкажи правильний email");return};if len(in.Password)<8{fail(w,400,"Пароль має містити щонайменше 8 символів");return}
        hash,err:=bcrypt.GenerateFromPassword([]byte(in.Password),bcrypt.DefaultCost);if err!=nil{fail(w,500,"Не вдалося створити акаунт");return}
        store.mu.Lock();defer store.mu.Unlock();if _,exists:=store.users[in.Email];exists{fail(w,409,"Акаунт із таким email уже існує");return}
        user:=User{ID:randomString(12,codeAlphabet),Name:in.Name,Email:in.Email,PasswordHash:hash};store.users[in.Email]=user;session:=token();store.sessions[session]=user.ID;writeJSON(w,201,map[string]any{"token":session,"user":user})
    })
    mux.HandleFunc("POST /api/auth/login",func(w http.ResponseWriter,r *http.Request){
        var in struct{Email string `json:"email"`;Password string `json:"password"`};if readJSON(r,&in)!=nil{fail(w,400,"Перевір введені дані");return};email:=strings.ToLower(strings.TrimSpace(in.Email));store.mu.RLock();user,ok:=store.users[email];store.mu.RUnlock();if !ok||bcrypt.CompareHashAndPassword(user.PasswordHash,[]byte(in.Password))!=nil{fail(w,401,"Неправильний email або пароль");return};session:=token();store.mu.Lock();store.sessions[session]=user.ID;store.mu.Unlock();writeJSON(w,200,map[string]any{"token":session,"user":user})
    })

    protected:=http.NewServeMux()
    protected.HandleFunc("GET /api/auth/me",func(w http.ResponseWriter,r *http.Request){writeJSON(w,200,map[string]any{"user":mustUser(r)})})
    protected.HandleFunc("POST /api/rooms",func(w http.ResponseWriter,r *http.Request){
        var in struct{Name string `json:"name"`;MaxPlayers int `json:"maxPlayers"`};if readJSON(r,&in)!=nil{fail(w,400,"Перевір налаштування кімнати");return};in.Name=strings.TrimSpace(in.Name);if len([]rune(in.Name))<3||len([]rune(in.Name))>40||in.MaxPlayers<2||in.MaxPlayers>6{fail(w,400,"Некоректні налаштування кімнати");return};user:=mustUser(r);store.mu.Lock();defer store.mu.Unlock();code:="";for{code=randomString(8,codeAlphabet);if _,exists:=store.rooms[code];!exists{break}};room:=&Room{Code:code,Name:in.Name,MaxPlayers:in.MaxPlayers,Players:[]Player{{ID:user.ID,Name:user.Name,Host:true}},CreatedAt:time.Now()};store.rooms[code]=room;writeJSON(w,201,map[string]any{"room":room})
    })
    protected.HandleFunc("POST /api/rooms/{code}/join",func(w http.ResponseWriter,r *http.Request){
        code:=strings.ToUpper(r.PathValue("code"));user:=mustUser(r);store.mu.Lock();defer store.mu.Unlock();room,ok:=store.rooms[code];if !ok{fail(w,404,"Кімнату з таким кодом не знайдено");return};for _,p:=range room.Players{if p.ID==user.ID{writeJSON(w,200,map[string]any{"room":room});return}};if len(room.Players)>=room.MaxPlayers{fail(w,409,"У кімнаті вже немає місць");return};room.Players=append(room.Players,Player{ID:user.ID,Name:user.Name});writeJSON(w,200,map[string]any{"room":room})
    })
    protected.HandleFunc("GET /api/rooms/{code}",func(w http.ResponseWriter,r *http.Request){code:=strings.ToUpper(r.PathValue("code"));user:=mustUser(r);store.mu.RLock();defer store.mu.RUnlock();room,ok:=store.rooms[code];if !ok||!containsPlayer(room,user.ID){fail(w,404,"Кімнату не знайдено");return};writeJSON(w,200,map[string]any{"room":room})})
    protected.HandleFunc("POST /api/rooms/{code}/ready",func(w http.ResponseWriter,r *http.Request){code:=strings.ToUpper(r.PathValue("code"));user:=mustUser(r);store.mu.Lock();defer store.mu.Unlock();room,ok:=store.rooms[code];if !ok{fail(w,404,"Кімнату не знайдено");return};for i:=range room.Players{if room.Players[i].ID==user.ID{room.Players[i].Ready=!room.Players[i].Ready;writeJSON(w,200,map[string]any{"room":room});return}};fail(w,403,"Спочатку увійди в кімнату")})
    protected.HandleFunc("POST /api/rooms/{code}/leave",func(w http.ResponseWriter,r *http.Request){code:=strings.ToUpper(r.PathValue("code"));user:=mustUser(r);store.mu.Lock();defer store.mu.Unlock();room,ok:=store.rooms[code];if !ok{writeJSON(w,200,map[string]bool{"ok":true});return};next:=room.Players[:0];wasHost:=false;for _,p:=range room.Players{if p.ID==user.ID{wasHost=p.Host;continue};next=append(next,p)};room.Players=next;if len(room.Players)==0{delete(store.rooms,code)}else if wasHost{room.Players[0].Host=true};writeJSON(w,200,map[string]bool{"ok":true})})

    mux.Handle("/api/auth/me",auth(store,protected));mux.Handle("/api/rooms",auth(store,protected));mux.Handle("/api/rooms/",auth(store,protected))
    server:=&http.Server{Addr:":8080",Handler:securityHeaders(mux),ReadHeaderTimeout:5*time.Second,ReadTimeout:10*time.Second,WriteTimeout:10*time.Second,IdleTimeout:60*time.Second};log.Println("Kupymisto API listening on :8080");log.Fatal(server.ListenAndServe())
}

func containsPlayer(room *Room,id string)bool{for _,p:=range room.Players{if p.ID==id{return true}};return false}
func mustUser(r *http.Request)User{user,ok:=r.Context().Value(userKey).(User);if !ok{panic(errors.New("missing authenticated user"))};return user}
func auth(store *Store,next http.Handler)http.Handler{return http.HandlerFunc(func(w http.ResponseWriter,r *http.Request){header:=r.Header.Get("Authorization");if !strings.HasPrefix(header,"Bearer "){fail(w,401,"Потрібно увійти в акаунт");return};session:=strings.TrimPrefix(header,"Bearer ");store.mu.RLock();id,ok:=store.sessions[session];var user User;if ok{for _,candidate:=range store.users{if candidate.ID==id{user=candidate;break}}};store.mu.RUnlock();if !ok||user.ID==""{fail(w,401,"Сесія завершилась, увійди ще раз");return};next.ServeHTTP(w,r.WithContext(contextWithUser(r,user)))})}
func contextWithUser(r *http.Request,user User)*http.Request{return r.WithContext(context.WithValue(r.Context(),userKey,user))}
func securityHeaders(next http.Handler)http.Handler{return http.HandlerFunc(func(w http.ResponseWriter,r *http.Request){w.Header().Set("X-Content-Type-Options","nosniff");w.Header().Set("X-Frame-Options","DENY");w.Header().Set("Referrer-Policy","no-referrer");next.ServeHTTP(w,r)})}
EOF

python3 <<'PY'
from pathlib import Path
p=Path('backend/cmd/api/main.go')
s=p.read_text(encoding='utf-8').replace('"crypto/rand"','"context"\n    "crypto/rand"')
p.write_text(s, encoding='utf-8')
PY

(cd backend && go mod tidy && gofmt -w cmd/api/main.go && go test ./...)
npm --prefix frontend run build

git add frontend/src/App.tsx frontend/src/styles.css frontend/src/api.ts frontend/src/components/AuthScreen.tsx frontend/src/components/LobbyScreen.tsx backend/go.mod backend/go.sum backend/cmd/api/main.go
git commit -m "feat: add authentication and private code-based room lobby" || true
git push || echo "Push не пройшов автоматично. Виконай: git push"

echo "Готово. Перезапусти: docker compose down && docker compose up"
