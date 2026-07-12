#!/usr/bin/env bash
set -euo pipefail

if [ ! -f frontend/src/components/ClassicBoard3D.tsx ] || [ ! -f frontend/src/audio.ts ]; then
  echo "Запусти файл у корені kupymisto після всіх попередніх оновлень."
  exit 1
fi

python3 <<'PY'
from pathlib import Path

# Make audio context resume deterministic and align pawn sounds with cell-by-cell movement.
p=Path('frontend/src/audio.ts')
s=p.read_text(encoding='utf-8')
insert='''
export async function unlockAudio() {
  const ctx = getContext()
  if (ctx.state !== 'running') await ctx.resume()
  const buffer = ctx.createBuffer(1, 1, ctx.sampleRate)
  const source = ctx.createBufferSource()
  source.buffer = buffer
  source.connect(ctx.destination)
  source.start()
}
'''
if 'export async function unlockAudio()' not in s:
    marker='export function playUiSound'
    s=s.replace(marker,insert+'\n'+marker)
start=s.index('export function playPawnMove(steps: number) {')
end=s.find('\n}', start)+2
new='''export function playPawnMove(steps: number) {
  const ctx = getContext()
  const start = ctx.currentTime + 0.02
  const count = Math.min(steps, 16)
  for (let index = 0; index < count; index++) {
    const oscillator = ctx.createOscillator()
    const gain = ctx.createGain()
    const filter = ctx.createBiquadFilter()
    const time = start + index * 0.19
    oscillator.type = 'triangle'
    oscillator.frequency.value = 165 + (index % 4) * 28
    filter.type = 'lowpass'
    filter.frequency.value = 920
    gain.gain.setValueAtTime(0.0001, time)
    gain.gain.exponentialRampToValueAtTime(0.075, time + 0.008)
    gain.gain.exponentialRampToValueAtTime(0.0001, time + 0.085)
    oscillator.connect(filter).connect(gain).connect(ctx.destination)
    oscillator.start(time)
    oscillator.stop(time + 0.1)
  }
}'''
s=s[:start]+new+s[end:]
p.write_text(s, encoding='utf-8')

# Rework token animation into an actual perimeter walk and remove HDR overexposure.
p=Path('frontend/src/components/ClassicBoard3D.tsx')
s=p.read_text(encoding='utf-8')
s=s.replace("import { ContactShadows, Environment, RoundedBox, Text } from '@react-three/drei'", "import { ContactShadows, RoundedBox, Text } from '@react-three/drei'")
s=s.replace("import type { Group, PerspectiveCamera } from 'three'", "import { ACESFilmicToneMapping, SRGBColorSpace, type Group, type PerspectiveCamera } from 'three'")
old_start=s.index('function Token(')
old_end=s.index('\nconst pipMap',old_start)
new_token='''function Token({index,side,color,offset}:{index:number;side:number;color:string;offset:number}){
  const ref=useRef<Group>(null)
  const total=side*4-4
  const current=useRef(index)
  const target=useRef(index)
  const stepProgress=useRef(1)
  const from=useRef(boardPosition(index,side))
  const to=useRef(boardPosition(index,side))

  useEffect(()=>{target.current=index},[index])
  useFrame((_,delta)=>{
    if(!ref.current)return
    if(stepProgress.current>=1&&current.current!==target.current){
      from.current=boardPosition(current.current,side)
      current.current=(current.current+1)%total
      to.current=boardPosition(current.current,side)
      stepProgress.current=0
    }
    if(stepProgress.current<1){
      stepProgress.current=Math.min(1,stepProgress.current+delta*5.25)
      const raw=stepProgress.current
      const t=raw*raw*(3-2*raw)
      const a=from.current,b=to.current
      ref.current.position.x=a[0]+(b[0]-a[0])*t+offset
      ref.current.position.z=a[2]+(b[2]-a[2])*t+offset
      ref.current.position.y=.5+Math.sin(raw*Math.PI)*.34
      ref.current.rotation.y+=delta*4.8
    }else{
      const point=boardPosition(current.current,side)
      ref.current.position.x=point[0]+offset
      ref.current.position.z=point[2]+offset
      ref.current.position.y=.5
    }
  })
  const initial=boardPosition(index,side)
  return <group ref={ref} position={[initial[0]+offset,.5,initial[2]+offset]}>
    <mesh position={[0,.28,0]} castShadow><sphereGeometry args={[.16,24,24]}/><meshStandardMaterial color={color} roughness={.48} metalness={.04}/></mesh>
    <mesh castShadow><coneGeometry args={[.28,.55,24]}/><meshStandardMaterial color={color} roughness={.52}/></mesh>
    <mesh position={[0,-.29,0]} castShadow><cylinderGeometry args={[.31,.31,.09,24]}/><meshStandardMaterial color="#24212b" roughness={.58}/></mesh>
  </group>
}
'''
s=s[:old_start]+new_token+s[old_end:]
# Strong, explicit colors and no environment reflections.
s=s.replace('color="#a9c9ae" roughness={.66}', 'color="#78a881" roughness={.82} metalness={0}')
s=s.replace("color={corner?cell.color:'#ded8c7'} roughness={.62}", "color={corner?cell.color:'#cfc6af'} roughness={.86} metalness={0}")
s=s.replace("<color attach=\"background\" args={['#8fb59a']}/><ambientLight intensity={.82}/><hemisphereLight args={['#dae8d7','#324d3a',1.2]}/><directionalLight position={[7,12,5]} intensity={2.35}", "<color attach=\"background\" args={['#557b61']}/><ambientLight intensity={.42}/><hemisphereLight args={['#c3d9c5','#263b2d',.72]}/><directionalLight position={[7,12,5]} intensity={1.55}")
s=s.replace('/><Environment preset="city"/></Canvas>', '/></Canvas>')
s=s.replace("<Canvas dpr={[1,1.6]} shadows camera={{position:camera,fov:38}} gl={{antialias:true}}>", "<Canvas dpr={[1,1.6]} shadows camera={{position:camera,fov:38}} gl={{antialias:true,toneMapping:ACESFilmicToneMapping,toneMappingExposure:.72,outputColorSpace:SRGBColorSpace}}>")
p.write_text(s, encoding='utf-8')

# Guarantee audio unlock happens inside the actual click gesture.
p=Path('frontend/src/components/GameScreen.tsx')
s=p.read_text(encoding='utf-8')
s=s.replace("import { playDiceRoll, playPawnMove } from '../audio'", "import { playDiceRoll, playPawnMove, unlockAudio } from '../audio'")
s=s.replace("  const roll = () => {", "  const roll = async () => {")
s=s.replace("    setRolling(true); playDiceRoll()", "    await unlockAudio()\n    setRolling(true); playDiceRoll()")
s=s.replace("      setDice([a,b]); playPawnMove(a+b); setPositions", "      setDice([a,b]); setPositions")
s=s.replace("setRolling(false)\n      window.setTimeout", "setRolling(false); playPawnMove(a+b)\n      window.setTimeout")
# Wait for cell-by-cell movement before changing turns.
s=s.replace("},750)\n    },700)", "},Math.max(900,(a+b)*190+260))\n    },700)")
p.write_text(s, encoding='utf-8')
PY

cat >> frontend/src/styles.css <<'EOF'
/* Final exposure correction: intentionally darker stage, no washed-out overlay */
.boardOnly{background:oklch(48% .085 151)}
.boardOnly::before{background:radial-gradient(circle at 50% 35%,oklch(67% .075 151),oklch(39% .09 151));opacity:.38}
EOF

npm --prefix frontend run build

git add frontend/src/audio.ts frontend/src/components/ClassicBoard3D.tsx frontend/src/components/GameScreen.tsx frontend/src/styles.css
git commit -m "fix: correct board exposure, step pawn through cells and unlock audio" || true
git push || echo "Виконай git push вручну"

echo "Готово. Обов'язково перезапусти: docker compose down && docker compose up --build"
