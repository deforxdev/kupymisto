#!/usr/bin/env bash
set -euo pipefail

if [ ! -f frontend/src/components/LobbyScreen.tsx ] || [ ! -f backend/cmd/api/main.go ]; then
  echo "Запусти файл у корені репозиторію kupymisto після попередніх оновлень."
  exit 1
fi

cat > frontend/src/components/GameScreen.tsx <<'EOF'
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
EOF

python3 <<'PY'
from pathlib import Path

p = Path('frontend/src/api.ts')
s = p.read_text(encoding='utf-8')
s = s.replace("export type Room = { code: string; name: string; maxPlayers: number; players: Player[]; createdAt: string }", "export type AgeGroup = '10-12' | '14-15' | '18-20'\nexport type Room = { code: string; name: string; maxPlayers: number; ageGroup: AgeGroup; players: Player[]; createdAt: string }")
s = s.replace("createRoom: (body: { name: string; maxPlayers: number })", "createRoom: (body: { name: string; maxPlayers: number; ageGroup: AgeGroup })")
p.write_text(s, encoding='utf-8')

p = Path('frontend/src/components/LobbyScreen.tsx')
s = p.read_text(encoding='utf-8')
s = s.replace("import { api, clearToken, type Room, type User } from '../api'", "import { api, clearToken, type AgeGroup, type Room, type User } from '../api'\nimport GameScreen from './GameScreen'")
s = s.replace("  const [maxPlayers, setMaxPlayers] = useState(4)", "  const [maxPlayers, setMaxPlayers] = useState(4)\n  const [ageGroup, setAgeGroup] = useState<AgeGroup>('14-15')\n  const [gameStarted, setGameStarted] = useState(false)")
s = s.replace("api.createRoom({ name: roomName.trim(), maxPlayers })", "api.createRoom({ name: roomName.trim(), maxPlayers, ageGroup })")

marker = "  if (room) {"
s = s.replace(marker, "  if (room && gameStarted) return <GameScreen room={room} user={user} onExit={() => setGameStarted(false)} />\n\n" + marker)

s = s.replace("<span className=\"sectionNo\">ПРИВАТНА КІМНАТА</span><h1>{room.name}</h1>", "<span className=\"sectionNo\">ПРИВАТНА КІМНАТА · ВІК {room.ageGroup}</span><h1>{room.name}</h1>")
old_button = "<button className=\"startButton\" disabled={!host || host.id !== user.id || room.players.length < 2 || room.players.some(p => !p.ready)}>Почати гру<ArrowRight/></button><small>{room.players.length < 2 ? 'Потрібно хоча б двоє гравців.' : room.players.some(p => !p.ready) ? 'Чекаємо готовності всіх гравців.' : host?.id === user.id ? 'Усі готові. Можна починати.' : 'Власник кімнати може почати гру.'}</small>"
new_button = "<button className=\"startButton\" onClick={() => setGameStarted(true)} disabled={!host || host.id !== user.id}>Почати тестову гру<ArrowRight/></button><small>{host?.id === user.id ? 'Тестовий режим: можна почати навіть одному.' : 'Власник кімнати може почати гру.'}</small>"
if old_button not in s:
    raise SystemExit('Не знайдено кнопку старту. Переконайся, що попередній update-скрипт застосовано.')
s = s.replace(old_button, new_button)

old_fields = "<label>Гравців<select value={maxPlayers} onChange={e => setMaxPlayers(Number(e.target.value))}><option value={2}>2 гравці</option><option value={3}>3 гравці</option><option value={4}>4 гравці</option><option value={5}>5 гравців</option><option value={6}>6 гравців</option></select></label><button className=\"primary\" disabled={loading}>"
new_fields = "<div className=\"roomSettingsRow\"><label>Гравців<select value={maxPlayers} onChange={e => setMaxPlayers(Number(e.target.value))}><option value={2}>2 гравці</option><option value={3}>3 гравці</option><option value={4}>4 гравці</option><option value={5}>5 гравців</option><option value={6}>6 гравців</option></select></label><label>Віковий режим<select value={ageGroup} onChange={e => setAgeGroup(e.target.value as AgeGroup)}><option value=\"10-12\">10–12 років</option><option value=\"14-15\">14–15 років</option><option value=\"18-20\">18–20 років</option></select></label></div><p className=\"ageModeHint\">Від вікового режиму залежать картки, жарти, ілюстрації та мемні відсилки в грі.</p><button className=\"primary\" disabled={loading}>"
if old_fields not in s:
    raise SystemExit('Не знайдено налаштування гравців.')
s = s.replace(old_fields, new_fields)
p.write_text(s, encoding='utf-8')

p = Path('backend/cmd/api/main.go')
s = p.read_text(encoding='utf-8')
s = s.replace('type Room struct { Code string `json:"code"`; Name string `json:"name"`; MaxPlayers int `json:"maxPlayers"`; Players []Player `json:"players"`; CreatedAt time.Time `json:"createdAt"` }', 'type Room struct { Code string `json:"code"`; Name string `json:"name"`; MaxPlayers int `json:"maxPlayers"`; AgeGroup string `json:"ageGroup"`; Players []Player `json:"players"`; CreatedAt time.Time `json:"createdAt"` }')
s = s.replace('var in struct{Name string `json:"name"`;MaxPlayers int `json:"maxPlayers"`}', 'var in struct{Name string `json:"name"`;MaxPlayers int `json:"maxPlayers"`;AgeGroup string `json:"ageGroup"`}')
s = s.replace('if len([]rune(in.Name))<3||len([]rune(in.Name))>40||in.MaxPlayers<2||in.MaxPlayers>6{fail(w,400,"Некоректні налаштування кімнати");return}', 'if len([]rune(in.Name))<3||len([]rune(in.Name))>40||in.MaxPlayers<2||in.MaxPlayers>6||!validAgeGroup(in.AgeGroup){fail(w,400,"Некоректні налаштування кімнати");return}')
s = s.replace('room:=&Room{Code:code,Name:in.Name,MaxPlayers:in.MaxPlayers,Players:', 'room:=&Room{Code:code,Name:in.Name,MaxPlayers:in.MaxPlayers,AgeGroup:in.AgeGroup,Players:')
insert = 'func validAgeGroup(value string)bool{return value=="10-12"||value=="14-15"||value=="18-20"}\n'
s = s.replace('func containsPlayer(room *Room,id string)bool{', insert + 'func containsPlayer(room *Room,id string)bool{')
p.write_text(s, encoding='utf-8')
PY

cat >> frontend/src/styles.css <<'EOF'

/* Room age mode */
.roomSettingsRow{display:grid;grid-template-columns:.72fr 1.28fr;gap:14px}.ageModeHint{min-height:auto!important;background:oklch(91% .045 91);border:2px solid var(--ink);border-radius:10px;padding:11px 13px;font-size:12px;line-height:1.45!important;color:var(--ink)!important}

/* Playable game prototype */
.gameScreen{min-height:100svh;background:oklch(92% .028 151);color:var(--ink);overflow:hidden}.gameHeader{height:72px;background:var(--paper);border-bottom:3px solid var(--ink);display:grid;grid-template-columns:1fr auto 1fr;align-items:center;padding:0 24px;position:relative;z-index:5}.gameBrand{display:flex;align-items:baseline;gap:12px}.gameBrand>span{font-family:Unbounded;font-size:18px;font-weight:800;letter-spacing:-.06em}.gameBrand small{font-family:Unbounded;font-size:10px;letter-spacing:.12em;color:var(--muted)}.turnStatus{font-size:12px;font-weight:900;display:flex;align-items:center;gap:8px}.turnStatus i{width:9px;height:9px;border-radius:50%;background:var(--green);border:1px solid var(--ink);box-shadow:0 0 0 4px oklch(70% .15 151/.2)}.gameTools{justify-self:end;display:flex;gap:5px}.gameTools button{height:40px;border:2px solid transparent;background:transparent;border-radius:9px;display:flex;align-items:center;gap:7px;font-size:12px;font-weight:900;cursor:pointer}.gameTools button:hover{border-color:var(--ink);background:var(--yellow)}.gameTools svg{width:18px}.gameLayout{height:calc(100svh - 72px);display:grid;grid-template-columns:260px minmax(500px,1fr) 280px}.gamePlayers{background:var(--paper);border-right:3px solid var(--ink);padding:24px 18px;overflow:auto}.gameAsideTitle{display:flex;justify-content:space-between;font-size:10px;font-weight:900;letter-spacing:.09em;margin-bottom:18px}.gamePlayers article{display:grid;grid-template-columns:45px 1fr auto;gap:10px;align-items:center;padding:12px 8px;border-top:2px solid oklch(21% .035 278/.15);position:relative}.gamePlayers article.active{background:var(--yellow);border:2px solid var(--ink);border-radius:12px;box-shadow:3px 3px 0 var(--ink);margin-bottom:3px}.playerPortrait{width:42px;height:42px;border:2px solid var(--ink);border-radius:50%;display:grid;place-items:center;font-family:Unbounded;font-weight:800;position:relative;background:var(--blue);color:var(--paper)}.portrait1{background:var(--red)}.portrait2{background:var(--green);color:var(--ink)}.portrait3{background:var(--yellow);color:var(--ink)}.playerPortrait i{position:absolute;width:10px;height:10px;border:2px solid var(--ink);border-radius:50%;background:var(--green);right:-1px;bottom:0}.gamePlayers article>div:nth-child(2){display:grid}.gamePlayers article small{font-size:10px;color:var(--muted);font-weight:800}.gamePlayers article>b{font-size:11px;font-variant-numeric:tabular-nums}.gameLog{margin-top:26px;border-top:3px solid var(--ink);padding-top:16px}.gameLog span{font-size:10px;font-weight:900;letter-spacing:.1em}.gameLog p{font-size:12px;line-height:1.5;font-weight:750;margin-top:10px}.boardStage{display:grid;place-items:center;perspective:1100px;overflow:hidden;background-image:radial-gradient(oklch(30% .03 151/.16) 1px,transparent 1px);background-size:20px 20px}.gameBoard{width:min(68vh,720px);aspect-ratio:1;display:grid;grid-template-columns:repeat(5,1fr);grid-template-rows:repeat(5,1fr);gap:6px;background:var(--ink);border:7px solid var(--ink);border-radius:25px;padding:6px;box-shadow:0 48px 40px oklch(20% .04 151/.22);transform-style:preserve-3d}.boardCell{position:relative;background:var(--paper);border-radius:8px;padding:8px 7px;display:flex;flex-direction:column;justify-content:space-between;align-items:flex-start;min-width:0}.boardCell.blue{background:var(--blue);color:var(--paper)}.boardCell.green{background:var(--green)}.boardCell.red{background:var(--red);color:var(--paper)}.boardCell.yellow{background:var(--yellow)}.boardCell>svg{width:18px;height:18px}.boardCell strong{font-family:Unbounded;font-size:clamp(7px,.72vw,11px);line-height:1.15;max-width:100%;overflow:hidden}.boardCell small{font-size:9px;font-weight:900}.boardCenter{grid-area:2/2/5/5;background:var(--yellow);border-radius:16px;display:flex;flex-direction:column;justify-content:center;align-items:center;text-align:center;padding:20px;transform-style:preserve-3d}.boardCenter>svg{width:34px;margin-bottom:10px}.boardCenter small{font-size:9px;font-weight:900;letter-spacing:.1em;text-transform:uppercase}.boardCenter strong{font-family:Unbounded;font-size:clamp(18px,2.2vw,34px);line-height:1.05;max-width:8ch;margin:7px 0}.boardCenter span{font-size:9px;font-weight:800}.piece{position:absolute;z-index:3;right:6px;top:5px;width:25px;height:32px;filter:drop-shadow(2px 3px 0 var(--ink));transform:translateZ(30px)}.piece i{position:absolute;left:7px;top:0;width:13px;height:13px;background:var(--paper);border:3px solid var(--ink);border-radius:50%}.piece span{position:absolute;left:3px;bottom:0;width:21px;height:19px;background:var(--blue);border:3px solid var(--ink);clip-path:polygon(30% 0,70% 0,100% 100%,0 100%)}.turnPanel{background:var(--paper);border-left:3px solid var(--ink);padding:28px 22px;display:flex;flex-direction:column}.turnLabel{font-size:10px;font-weight:900;letter-spacing:.12em;color:var(--blue)}.turnPanel h2{font-family:Unbounded;font-size:24px;line-height:1.15;letter-spacing:-.04em;margin-top:12px}.dicePair{display:flex;gap:12px;margin:28px 0 20px}.dicePair div{width:66px;height:66px;border:3px solid var(--ink);border-radius:15px;background:var(--paper);box-shadow:5px 5px 0 var(--ink);display:grid;place-items:center;font-family:Unbounded;font-size:25px;font-weight:800}.dicePair.rolling{animation:diceShake .12s linear infinite alternate}@keyframes diceShake{to{transform:translate(4px,-3px) rotate(2deg)}}.rollButton{width:100%;justify-content:center}.balance{margin-top:auto;border-top:3px solid var(--ink);padding-top:20px;display:flex;justify-content:space-between;align-items:baseline}.balance span{font-size:11px;font-weight:900}.balance strong{font-family:Unbounded;font-size:22px}.buyButton{min-height:48px;margin-top:14px;border:3px solid var(--ink);border-radius:12px;background:var(--green);font-weight:900;cursor:pointer}.buyButton:disabled{opacity:.35;cursor:not-allowed;background:var(--paper)}
@media(max-width:1050px){.gameLayout{grid-template-columns:200px minmax(440px,1fr)}.turnPanel{position:fixed;right:18px;bottom:18px;width:240px;border:3px solid var(--ink);border-radius:18px;box-shadow:7px 7px 0 var(--ink);z-index:6}.turnPanel h2,.turnPanel .balance,.turnPanel .buyButton{display:none}.dicePair{margin:15px 0}.dicePair div{width:48px;height:48px}.gameBoard{width:min(65vw,68vh)}}
@media(max-width:720px){.gameHeader{grid-template-columns:1fr auto}.turnStatus{display:none}.gameTools button span{display:none}.gameLayout{height:auto;min-height:calc(100svh - 72px);display:block}.gamePlayers{display:none}.boardStage{min-height:70svh}.gameBoard{width:92vw}.turnPanel{left:12px;right:12px;bottom:12px;width:auto;display:grid;grid-template-columns:auto 1fr;gap:12px}.turnLabel,.turnPanel h2{display:none}.dicePair{margin:0}.rollButton{height:54px}.roomSettingsRow{grid-template-columns:1fr}}
EOF

(cd backend && gofmt -w cmd/api/main.go && go test ./...)
npm --prefix frontend run build

git add frontend/src/api.ts frontend/src/components/LobbyScreen.tsx frontend/src/components/GameScreen.tsx frontend/src/styles.css backend/cmd/api/main.go
git commit -m "feat: add room age modes and playable game prototype" || true
git push || echo "Push не пройшов автоматично. Виконай: git push"

echo "Готово. Перезапусти: docker compose down && docker compose up"
