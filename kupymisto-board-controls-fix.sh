#!/usr/bin/env bash
set -euo pipefail

if [ ! -f frontend/src/components/ClassicBoard3D.tsx ] || [ ! -f frontend/src/components/GameScreen.tsx ]; then
  echo "Запусти файл у корені kupymisto після оновлення класичної 3D-дошки."
  exit 1
fi

python3 <<'PY'
from pathlib import Path

p=Path('frontend/src/components/ClassicBoard3D.tsx')
s=p.read_text(encoding='utf-8')
s=s.replace("import { Canvas, useFrame } from '@react-three/fiber'", "import { Canvas, useFrame, useThree } from '@react-three/fiber'")
s=s.replace("import { ContactShadows, Environment, Float, RoundedBox, Text } from '@react-three/drei'", "import { ContactShadows, Environment, Float, RoundedBox, Text } from '@react-three/drei'")
s=s.replace("import { useMemo, useRef } from 'react'", "import { useEffect, useMemo, useRef } from 'react'")

old_start="""function BoardModel({ size, positions, players, dice, rolling }: { size:BoardSize; positions:number[]; players:Player[]; dice:[number,number]; rolling:boolean }) {
  const group = useRef<Group>(null)
  const cells = useMemo(() => makeCells(size), [size])"""
new_start="""function BoardModel({ size, positions, players, dice, rolling }: { size:BoardSize; positions:number[]; players:Player[]; dice:[number,number]; rolling:boolean }) {
  const group = useRef<Group>(null)
  const drag = useRef({ active:false, x:0, y:0, targetX:-0.04, targetY:0 })
  const { gl } = useThree()
  const cells = useMemo(() => makeCells(size), [size])

  useEffect(() => {
    const canvas = gl.domElement
    const context = (event: MouseEvent) => event.preventDefault()
    const down = (event: PointerEvent) => {
      if (event.button !== 2) return
      event.preventDefault()
      drag.current.active = true
      drag.current.x = event.clientX
      drag.current.y = event.clientY
      canvas.setPointerCapture?.(event.pointerId)
      canvas.classList.add('isRotating')
    }
    const move = (event: PointerEvent) => {
      if (!drag.current.active || (event.buttons & 2) !== 2) return
      const dx = event.clientX - drag.current.x
      const dy = event.clientY - drag.current.y
      drag.current.x = event.clientX
      drag.current.y = event.clientY
      drag.current.targetY += dx * 0.008
      drag.current.targetX = Math.max(-0.34, Math.min(0.28, drag.current.targetX + dy * 0.005))
    }
    const up = (event: PointerEvent) => {
      if (event.button !== 2) return
      drag.current.active = false
      canvas.releasePointerCapture?.(event.pointerId)
      canvas.classList.remove('isRotating')
    }
    canvas.addEventListener('contextmenu', context)
    canvas.addEventListener('pointerdown', down)
    canvas.addEventListener('pointermove', move)
    canvas.addEventListener('pointerup', up)
    canvas.addEventListener('pointercancel', up)
    return () => {
      canvas.removeEventListener('contextmenu', context)
      canvas.removeEventListener('pointerdown', down)
      canvas.removeEventListener('pointermove', move)
      canvas.removeEventListener('pointerup', up)
      canvas.removeEventListener('pointercancel', up)
    }
  }, [gl])"""
if old_start not in s: raise SystemExit('BoardModel signature not found')
s=s.replace(old_start,new_start)

old_frame="""  useFrame((state) => {
    if (!group.current) return
    group.current.rotation.y += (state.pointer.x * .09 - group.current.rotation.y) * .025
    group.current.rotation.x += ((-.05 + state.pointer.y * .035) - group.current.rotation.x) * .025
  })"""
new_frame="""  useFrame(() => {
    if (!group.current) return
    group.current.rotation.y += (drag.current.targetY - group.current.rotation.y) * .12
    group.current.rotation.x += (drag.current.targetX - group.current.rotation.x) * .12
  })"""
if old_frame not in s: raise SystemExit('Old pointer rotation not found')
s=s.replace(old_frame,new_frame)

s=s.replace('<meshStandardMaterial color="#dce7da" roughness={.78}/>', '<meshStandardMaterial color="#c9ddca" roughness={.72} metalness={.015}/>')
s=s.replace("color={corner?cell.color:'#f3efe3'}", "color={corner?cell.color:'#eee9d9'}")
s=s.replace("<color attach=\"background\" args={['#dce7da']}/><ambientLight intensity={1.6}/><directionalLight position={[7,12,5]} intensity={3.1}", "<color attach=\"background\" args={['#b8d1bd']}/><ambientLight intensity={1.05}/><hemisphereLight args={['#e8f0df','#49604f',1.25]}/><directionalLight position={[7,12,5]} intensity={2.5}")
p.write_text(s, encoding='utf-8')

p=Path('frontend/src/components/GameScreen.tsx')
s=p.read_text(encoding='utf-8')
s=s.replace("  const [showTurn,setShowTurn] = useState(true)", "  const [turnNoticeId,setTurnNoticeId] = useState(1)")
s=s.replace("  useEffect(() => { const timer=window.setTimeout(()=>setShowTurn(false),1700); return()=>window.clearTimeout(timer) },[turn])", "")
s=s.replace("setTurn(value=>(value+1)%players.length); setShowTurn(true)", "setTurn(value=>(value+1)%players.length); setTurnNoticeId(value=>value+1)")
old="""      <AnimatePresence>{showTurn&&<motion.div className=\"turnAnnouncement\" initial={{opacity:0,scale:.88,y:20}} animate={{opacity:1,scale:1,y:0}} exit={{opacity:0,y:-230,scale:.7}} transition={{duration:.5,ease:[.16,1,.3,1]}}><small>НАСТУПНИЙ ХІД</small><strong>{players[turn]?.id===user.id?'Твій хід':`Хід: ${players[turn]?.name}`}</strong></motion.div>}</AnimatePresence>"""
new="""      <AnimatePresence>{<motion.div key={turnNoticeId} className=\"turnAnnouncement\" initial={{opacity:0,scale:.9,y:26}} animate={{opacity:[0,1,1,0],scale:[.9,1,1,.82],y:[26,0,0,-260]}} transition={{duration:1.75,times:[0,.16,.62,1],ease:[.16,1,.3,1]}}><small>НАСТУПНИЙ ХІД</small><strong>{players[turn]?.id===user.id?'Твій хід':`Хід: ${players[turn]?.name}`}</strong></motion.div>}</AnimatePresence>"""
if old not in s: raise SystemExit('Turn announcement block not found')
s=s.replace(old,new)
s=s.replace("      <ClassicBoard3D size={room.boardSize}", "      <div className=\"rotateHint\">Затисни праву кнопку миші та рухай, щоб обертати дошку</div>\n      <ClassicBoard3D size={room.boardSize}")
p.write_text(s, encoding='utf-8')
PY

cat >> frontend/src/styles.css <<'EOF'
/* Board control and contrast fix */
.boardOnly{background:oklch(79% .065 151)}.boardOnly::before{content:"";position:absolute;inset:0;pointer-events:none;background:radial-gradient(circle at 50% 40%,oklch(90% .04 151),oklch(71% .08 151));opacity:.58}.boardOnly canvas{position:relative;z-index:1;cursor:default}.boardOnly canvas.isRotating{cursor:grabbing}.rotateHint{position:absolute;z-index:7;left:50%;top:18px;transform:translateX(-50%);background:var(--ink);color:var(--paper);border:2px solid var(--paper);border-radius:999px;padding:8px 14px;font-size:10px;font-weight:850;letter-spacing:.02em;pointer-events:none;box-shadow:0 5px 0 oklch(20% .03 151/.22)}.turnAnnouncement{will-change:transform,opacity}.classicGame .cornerPlayer,.classicGame .diceAction{z-index:10}
@media(max-width:700px){.rotateHint{display:none}}
EOF

npm --prefix frontend run build

git add frontend/src/components/ClassicBoard3D.tsx frontend/src/components/GameScreen.tsx frontend/src/styles.css
git commit -m "fix: use right-drag board controls and timed turn notice" || true
git push || echo "Виконай git push вручну"

echo "Готово. Перезапусти: docker compose down && docker compose up"
