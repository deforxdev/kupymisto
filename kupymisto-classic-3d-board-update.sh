#!/usr/bin/env bash
set -euo pipefail

if [ ! -f frontend/src/components/GameScreen.tsx ] || [ ! -f frontend/src/components/LobbyScreen.tsx ]; then
  echo "Запусти файл у корені kupymisto після всіх попередніх оновлень."
  exit 1
fi

cat > frontend/src/components/ClassicBoard3D.tsx <<'EOF'
import { Canvas, useFrame } from '@react-three/fiber'
import { ContactShadows, Environment, Float, RoundedBox, Text } from '@react-three/drei'
import { useMemo, useRef } from 'react'
import type { Group, Mesh } from 'three'
import type { BoardSize, Player } from '../api'

export type BoardCell = { name: string; kind: 'corner'|'city'|'chance'|'tax'|'station'; price?: number; color: string }

const cityNames = ['Київ','Львів','Одеса','Харків','Дніпро','Чернівці','Ужгород','Луцьк','Рівне','Житомир','Вінниця','Полтава','Черкаси','Суми','Чернігів','Тернопіль','Івано-Франківськ','Миколаїв','Херсон','Запоріжжя','Кропивницький','Біла Церква','Кременчук','Кам’янець']
const bands = ['#6e4a2c','#6e4a2c','#69b8d8','#69b8d8','#d55c8b','#d55c8b','#e87942','#e87942','#d94d45','#d94d45','#efc63e','#efc63e','#55a96a','#55a96a','#4574cf','#4574cf']

export function makeCells(size: BoardSize): BoardCell[] {
  const side = size === 'large' ? 15 : 11
  const total = side * 4 - 4
  let city = 0
  return Array.from({ length: total }, (_, index) => {
    if (index % (side - 1) === 0) {
      const corners = ['СТАРТ','ВІЛЬНА ЗУПИНКА','МІСЬКА РАДА','ПАРКІНГ']
      return { name: corners[index / (side - 1)], kind: 'corner', color: index === 0 ? '#efc63e' : '#e9e5d7' }
    }
    if (index % 7 === 0) return { name: 'ШАНС', kind: 'chance', color: '#e9e5d7' }
    if (index % 9 === 0) return { name: 'ЗБІР', kind: 'tax', color: '#e9e5d7' }
    if (index % 5 === 0) return { name: 'ВОКЗАЛ', kind: 'station', price: 200, color: '#e9e5d7' }
    const name = cityNames[city % cityNames.length]
    const color = bands[Math.floor(city / 2) % bands.length]
    city++
    return { name, kind: 'city', price: 100 + (city % 9) * 30, color }
  })
}

function boardPosition(index: number, side: number): [number, number, number] {
  const edge = side - 1
  const half = edge / 2
  if (index <= edge) return [half - index, 0, half]
  if (index <= edge * 2) return [-half, 0, half - (index - edge)]
  if (index <= edge * 3) return [-half + (index - edge * 2), 0, -half]
  return [half, 0, -half + (index - edge * 3)]
}

function Token({ index, side, color, offset }: { index:number; side:number; color:string; offset:number }) {
  const ref = useRef<Group>(null)
  const [x,,z] = boardPosition(index, side)
  useFrame(() => {
    if (!ref.current) return
    ref.current.position.x += (x + offset - ref.current.position.x) * .08
    ref.current.position.z += (z + offset - ref.current.position.z) * .08
  })
  return <group ref={ref} position={[x + offset,.45,z + offset]}>
    <mesh position={[0,.28,0]} castShadow><sphereGeometry args={[.16,24,24]}/><meshStandardMaterial color={color}/></mesh>
    <mesh castShadow><coneGeometry args={[.28,.55,24]}/><meshStandardMaterial color={color}/></mesh>
    <mesh position={[0,-.29,0]} castShadow><cylinderGeometry args={[.31,.31,.09,24]}/><meshStandardMaterial color="#20202a"/></mesh>
  </group>
}

function Die({ position, value, rolling }: { position:[number,number,number]; value:number; rolling:boolean }) {
  const ref = useRef<Mesh>(null)
  useFrame((_,delta) => { if (rolling && ref.current) { ref.current.rotation.x += delta*8; ref.current.rotation.z += delta*6 } })
  return <Float speed={1.2} floatIntensity={.12} rotationIntensity={.08}>
    <RoundedBox ref={ref} args={[.72,.72,.72]} radius={.12} smoothness={4} position={position} castShadow>
      <meshStandardMaterial color="#f3efe3" roughness={.38}/>
      <Text position={[0,.371,0]} rotation={[-Math.PI/2,0,0]} fontSize={.28} color="#20202a" anchorX="center" anchorY="middle">{String(value)}</Text>
    </RoundedBox>
  </Float>
}

function BoardModel({ size, positions, players, dice, rolling }: { size:BoardSize; positions:number[]; players:Player[]; dice:[number,number]; rolling:boolean }) {
  const group = useRef<Group>(null)
  const cells = useMemo(() => makeCells(size), [size])
  const side = size === 'large' ? 15 : 11
  const edge = side - 1
  const boardWidth = edge + 1.7
  const playerColors = ['#3167dc','#de5549','#54b87a','#efc63e','#955fc7','#e98a44']

  useFrame((state) => {
    if (!group.current) return
    group.current.rotation.y += (state.pointer.x * .09 - group.current.rotation.y) * .025
    group.current.rotation.x += ((-.05 + state.pointer.y * .035) - group.current.rotation.x) * .025
  })

  return <group ref={group}>
    <RoundedBox args={[boardWidth,.34,boardWidth]} radius={.18} smoothness={4} receiveShadow>
      <meshStandardMaterial color="#20202a" roughness={.68}/>
    </RoundedBox>
    <RoundedBox args={[boardWidth-.3,.18,boardWidth-.3]} radius={.12} smoothness={4} position={[0,.25,0]} receiveShadow>
      <meshStandardMaterial color="#dce7da" roughness={.78}/>
    </RoundedBox>
    {cells.map((cell,index) => {
      const [x,,z] = boardPosition(index,side)
      const corner = cell.kind === 'corner'
      const rotation = index <= edge ? 0 : index <= edge*2 ? Math.PI/2 : index <= edge*3 ? Math.PI : -Math.PI/2
      return <group key={index} position={[x,.38,z]} rotation={[0,rotation,0]}>
        <RoundedBox args={[corner?1.05:.78,.10,1.05]} radius={.035} smoothness={2} receiveShadow>
          <meshStandardMaterial color={corner?cell.color:'#f3efe3'} roughness={.7}/>
        </RoundedBox>
        {!corner && <mesh position={[0,.075,-.38]}><boxGeometry args={[.76,.035,.26]}/><meshStandardMaterial color={cell.color}/></mesh>}
        <Text position={[0,.095,.05]} rotation={[-Math.PI/2,0,0]} fontSize={corner?.12:.09} maxWidth={.68} color="#20202a" textAlign="center" anchorX="center" anchorY="middle">{cell.name}</Text>
        {cell.price && <Text position={[0,.096,.28]} rotation={[-Math.PI/2,0,0]} fontSize={.07} color="#20202a" anchorX="center" anchorY="middle">{cell.price} ₴</Text>}
      </group>
    })}
    <group position={[0,.38,0]} rotation={[0,-Math.PI/4,0]}>
      <Text fontSize={size==='large'?.76:.92} color="#20202a" anchorX="center" anchorY="middle">КУПИМІСТО</Text>
      <Text position={[0,-.58,0]} fontSize={.18} color="#496b58" anchorX="center" anchorY="middle">УКРАЇНСЬКА ОНЛАЙН-ГРА</Text>
    </group>
    {players.map((player,index) => <Token key={player.id} index={positions[index]||0} side={side} color={playerColors[index%playerColors.length]} offset={(index%3-.8)*.16}/>)}
    <Die position={[-.5,.78,.45]} value={dice[0]} rolling={rolling}/><Die position={[.5,.78,.45]} value={dice[1]} rolling={rolling}/>
  </group>
}

export default function ClassicBoard3D(props: { size:BoardSize; positions:number[]; players:Player[]; dice:[number,number]; rolling:boolean }) {
  const camera = props.size === 'large' ? [0,12.5,13.8] as [number,number,number] : [0,10.8,12.5] as [number,number,number]
  return <Canvas dpr={[1,1.6]} shadows camera={{ position:camera, fov:38 }} gl={{ antialias:true }}>
    <color attach="background" args={['#dce7da']}/><ambientLight intensity={1.6}/><directionalLight position={[7,12,5]} intensity={3.1} castShadow shadow-mapSize={[1024,1024]}/>
    <BoardModel {...props}/><ContactShadows position={[0,-.2,0]} opacity={.22} scale={19} blur={2.5} far={8}/><Environment preset="city"/>
  </Canvas>
}
EOF

cat > frontend/src/components/GameScreen.tsx <<'EOF'
import { useEffect, useMemo, useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { LogOut, Settings, Volume2 } from 'lucide-react'
import type { Room, User } from '../api'
import { playUiSound } from '../audio'
import ClassicBoard3D, { makeCells } from './ClassicBoard3D'

type Props = { room: Room; user: User; onExit: () => void }
const colors = ['blue','red','green','yellow','purple','orange']

export default function GameScreen({ room, user, onExit }: Props) {
  const players = useMemo(() => room.players.length ? room.players : [{ id:user.id,name:user.name,host:true,ready:true }], [room.players,user])
  const [positions,setPositions] = useState(players.map(() => 0))
  const [dice,setDice] = useState<[number,number]>([1,1])
  const [rolling,setRolling] = useState(false)
  const [turn,setTurn] = useState(0)
  const [showTurn,setShowTurn] = useState(true)
  const cells = useMemo(() => makeCells(room.boardSize),[room.boardSize])

  useEffect(() => { const timer=window.setTimeout(()=>setShowTurn(false),1700); return()=>window.clearTimeout(timer) },[turn])
  const roll = () => {
    if (rolling || players[turn]?.id !== user.id) return
    setRolling(true); playUiSound('click')
    window.setTimeout(() => {
      const a=1+Math.floor(Math.random()*6), b=1+Math.floor(Math.random()*6)
      setDice([a,b]); setPositions(old=>old.map((p,i)=>i===turn?(p+a+b)%cells.length:p)); setRolling(false); playUiSound('success')
      window.setTimeout(()=>{ setTurn(value=>(value+1)%players.length); setShowTurn(true) },750)
    },700)
  }

  return <main className="classicGame">
    <header className="classicHeader"><div className="gameBrand"><span>КупиМісто</span><small>{room.code}</small></div><div className="topTurn">Хід {players[turn]?.name}</div><div className="gameTools"><button><Volume2/></button><button><Settings/></button><button onClick={onExit}><LogOut/><span>Вийти</span></button></div></header>
    <section className="boardOnly">
      <ClassicBoard3D size={room.boardSize} positions={positions} players={players} dice={dice} rolling={rolling}/>
      {players.slice(0,6).map((player,index)=><div key={player.id} className={`cornerPlayer corner${index+1} ${turn===index?'current':''}`}>
        <div className={`cornerAvatar ${colors[index]}`}>{player.name.slice(0,1).toUpperCase()}<i/></div><span><strong>{player.name}</strong><small>{turn===index?'Зараз ходить':'1500 ₴'}</small></span>
      </div>)}
      <AnimatePresence>{showTurn&&<motion.div className="turnAnnouncement" initial={{opacity:0,scale:.88,y:20}} animate={{opacity:1,scale:1,y:0}} exit={{opacity:0,y:-230,scale:.7}} transition={{duration:.5,ease:[.16,1,.3,1]}}><small>НАСТУПНИЙ ХІД</small><strong>{players[turn]?.id===user.id?'Твій хід':`Хід: ${players[turn]?.name}`}</strong></motion.div>}</AnimatePresence>
      <div className="diceAction"><span>{dice[0]} + {dice[1]}</span><button onClick={roll} disabled={rolling||players[turn]?.id!==user.id}>{rolling?'Кубики летять':'Кинути кубики'}</button></div>
    </section>
  </main>
}
EOF

python3 <<'PY'
from pathlib import Path
p=Path('frontend/src/api.ts');s=p.read_text(encoding='utf-8')
s=s.replace("export type AgeGroup = '10-12' | '14-15' | '18-20'", "export type AgeGroup = '10-12' | '14-15' | '18-20'\nexport type BoardSize = 'standard' | 'large'")
s=s.replace("ageGroup: AgeGroup; players", "ageGroup: AgeGroup; boardSize: BoardSize; players")
s=s.replace("createRoom: (body: { name: string; maxPlayers: number; ageGroup: AgeGroup })", "createRoom: (body: { name: string; maxPlayers: number })")
s=s.replace("  joinRoom:", "  updateRoom: (code: string, body: { ageGroup: AgeGroup; boardSize: BoardSize }) => request<{ room: Room }>(`/api/rooms/${code}/settings`, { method: 'PATCH', body: JSON.stringify(body) }),\n  joinRoom:")
p.write_text(s, encoding='utf-8')

p=Path('frontend/src/components/LobbyScreen.tsx');s=p.read_text(encoding='utf-8')
s=s.replace("type AgeGroup, type Room", "type AgeGroup, type BoardSize, type Room")
s=s.replace("  const [ageGroup, setAgeGroup] = useState<AgeGroup>('14-15')", "  const [ageGroup, setAgeGroup] = useState<AgeGroup>('14-15')\n  const [boardSize, setBoardSize] = useState<BoardSize>('standard')")
s=s.replace("api.createRoom({ name: roomName.trim(), maxPlayers, ageGroup })", "api.createRoom({ name: roomName.trim(), maxPlayers })")
# Remove age controls from create form
start='<div className="roomSettingsRow"><label>Гравців'
if start in s:
    a=s.index(start); b=s.index('<button className="primary"',a)
    replacement='<label>Гравців<select value={maxPlayers} onChange={e => setMaxPlayers(Number(e.target.value))}><option value={2}>2 гравці</option><option value={3}>3 гравці</option><option value={4}>4 гравці</option><option value={5}>5 гравців</option><option value={6}>6 гравців</option></select></label>'
    s=s[:a]+replacement+s[b:]
# Add room settings before actions
needle='<aside className="roomActions"><p>Власник:'
settings='''<aside className="roomActions"><div className="insideRoomSettings"><span>НАЛАШТУВАННЯ ГРИ</span><label>Віковий режим<select value={room.ageGroup} disabled={host?.id !== user.id} onChange={async e => { const ageGroup=e.target.value as AgeGroup; setAgeGroup(ageGroup); setRoom((await api.updateRoom(room.code,{ageGroup,boardSize:room.boardSize})).room) }}><option value="10-12">10–12 років</option><option value="14-15">14–15 років</option><option value="18-20">18–20 років</option></select></label><label>Розмір карти<select value={room.boardSize} disabled={host?.id !== user.id} onChange={async e => { const boardSize=e.target.value as BoardSize; setBoardSize(boardSize); setRoom((await api.updateRoom(room.code,{ageGroup:room.ageGroup,boardSize})).room) }}><option value="standard">Стандартна, 40 клітинок</option><option value="large">Велика, 56 клітинок</option></select></label></div><p>Власник:'''
s=s.replace(needle,settings)
p.write_text(s, encoding='utf-8')

p=Path('backend/cmd/api/main.go');s=p.read_text(encoding='utf-8')
s=s.replace('AgeGroup string `json:"ageGroup"`; Players', 'AgeGroup string `json:"ageGroup"`; BoardSize string `json:"boardSize"`; Players')
s=s.replace(';AgeGroup string `json:"ageGroup"`','')
s=s.replace('||!validAgeGroup(in.AgeGroup)','')
s=s.replace('AgeGroup:in.AgeGroup,Players:', 'AgeGroup:"14-15",BoardSize:"standard",Players:')
route='''    protected.HandleFunc("PATCH /api/rooms/{code}/settings",func(w http.ResponseWriter,r *http.Request){var in struct{AgeGroup string `json:"ageGroup"`;BoardSize string `json:"boardSize"`};if readJSON(r,&in)!=nil||!validAgeGroup(in.AgeGroup)||(in.BoardSize!="standard"&&in.BoardSize!="large"){fail(w,400,"Некоректні налаштування гри");return};code:=strings.ToUpper(r.PathValue("code"));user:=mustUser(r);store.mu.Lock();defer store.mu.Unlock();room,ok:=store.rooms[code];if !ok{fail(w,404,"Кімнату не знайдено");return};if len(room.Players)==0||room.Players[0].ID!=user.ID{fail(w,403,"Налаштування змінює власник кімнати");return};room.AgeGroup=in.AgeGroup;room.BoardSize=in.BoardSize;writeJSON(w,200,map[string]any{"room":room})})
'''
s=s.replace('    protected.HandleFunc("POST /api/rooms/{code}/join"',route+'    protected.HandleFunc("POST /api/rooms/{code}/join"')
p.write_text(s, encoding='utf-8')
PY

cat >> frontend/src/styles.css <<'EOF'
.insideRoomSettings{display:grid;gap:12px;margin-bottom:24px;padding-bottom:22px;border-bottom:2px solid var(--paper)}.insideRoomSettings>span{font-size:10px;font-weight:900;letter-spacing:.11em}.insideRoomSettings label{display:grid;gap:6px;font-size:10px;font-weight:900}.insideRoomSettings select{height:42px;border:2px solid var(--ink);border-radius:9px;background:var(--paper);padding:0 9px;font-weight:800}.classicGame{height:100svh;background:oklch(88% .035 151);overflow:hidden}.classicHeader{height:64px;background:var(--paper);border-bottom:3px solid var(--ink);display:grid;grid-template-columns:1fr auto 1fr;align-items:center;padding:0 22px;position:relative;z-index:20}.topTurn{font-size:12px;font-weight:900}.boardOnly{height:calc(100svh - 64px);position:relative}.boardOnly canvas{touch-action:none}.cornerPlayer{position:absolute;z-index:8;display:flex;align-items:center;gap:10px;background:var(--paper);border:3px solid var(--ink);border-radius:14px;padding:8px 14px 8px 8px;box-shadow:5px 5px 0 var(--ink);min-width:170px;transition:transform .3s var(--ease)}.cornerPlayer.current{transform:translateY(-5px);background:var(--yellow)}.corner1{left:22px;top:22px}.corner2{right:22px;top:22px}.corner3{right:22px;bottom:22px}.corner4{left:22px;bottom:22px}.corner5{left:50%;top:22px;transform:translateX(-50%)}.corner6{left:50%;bottom:22px;transform:translateX(-50%)}.cornerAvatar{width:42px;height:42px;border:2px solid var(--ink);border-radius:50%;display:grid;place-items:center;font-family:Unbounded;font-weight:800;position:relative}.cornerAvatar.blue{background:var(--blue);color:var(--paper)}.cornerAvatar.red{background:var(--red);color:var(--paper)}.cornerAvatar.green{background:var(--green)}.cornerAvatar.yellow{background:var(--yellow)}.cornerAvatar.purple{background:oklch(60% .16 305);color:var(--paper)}.cornerAvatar.orange{background:oklch(70% .16 55)}.cornerAvatar i{position:absolute;width:10px;height:10px;border-radius:50%;border:2px solid var(--ink);background:var(--green);right:-1px;bottom:0}.cornerPlayer>span{display:grid}.cornerPlayer strong{font-size:12px}.cornerPlayer small{font-size:9px;font-weight:800;color:var(--muted)}.turnAnnouncement{position:absolute;z-index:12;left:50%;top:50%;transform:translate(-50%,-50%);background:var(--yellow);border:4px solid var(--ink);border-radius:20px;padding:25px 42px;box-shadow:9px 9px 0 var(--ink);text-align:center;display:grid;gap:7px;pointer-events:none}.turnAnnouncement small{font-size:10px;font-weight:900;letter-spacing:.12em}.turnAnnouncement strong{font-family:Unbounded;font-size:clamp(25px,4vw,48px);white-space:nowrap}.diceAction{position:absolute;z-index:9;left:50%;bottom:20px;transform:translateX(-50%);display:flex;align-items:center;gap:9px;background:var(--paper);border:3px solid var(--ink);border-radius:13px;padding:7px;box-shadow:5px 5px 0 var(--ink)}.diceAction span{font-family:Unbounded;font-size:13px;padding:0 9px}.diceAction button{height:43px;border:2px solid var(--ink);border-radius:9px;background:var(--blue);color:var(--paper);font-weight:900;padding:0 16px;cursor:pointer}.diceAction button:disabled{opacity:.45;cursor:not-allowed}
@media(max-width:700px){.classicHeader{grid-template-columns:1fr auto}.topTurn{display:none}.cornerPlayer{min-width:0;padding:5px}.cornerPlayer>span{display:none}.cornerAvatar{width:36px;height:36px}.corner1{left:8px;top:8px}.corner2{right:8px;top:8px}.corner3{right:8px;bottom:70px}.corner4{left:8px;bottom:70px}.corner5,.corner6{display:none}.turnAnnouncement{padding:18px 24px}.turnAnnouncement strong{font-size:24px}.diceAction{bottom:10px}.gameTools button span{display:none}}
EOF

(cd backend && gofmt -w cmd/api/main.go && go test ./...)
npm --prefix frontend run build

git add frontend/src/api.ts frontend/src/components/LobbyScreen.tsx frontend/src/components/GameScreen.tsx frontend/src/components/ClassicBoard3D.tsx frontend/src/styles.css backend/cmd/api/main.go
git commit -m "feat: rebuild game around classic 3D board" || true
git push || echo "Виконай git push вручну"

echo "Готово. Перезапусти: docker compose down && docker compose up"
