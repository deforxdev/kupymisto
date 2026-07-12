#!/usr/bin/env bash
set -euo pipefail

printf '\nKupymisto: creating React, TypeScript and Go project...\n\n'

mkdir -p frontend/src/components backend/cmd/api

cat > .gitignore <<'EOF'
node_modules/
dist/
.env
.DS_Store
*.log
backend/kupymisto-api
EOF

cat > README.md <<'EOF'
# КупиМісто

Анімована головна сторінка української онлайн-гри.

## Стек

- React + Vite + TypeScript
- React Three Fiber + Drei
- Framer Motion
- Go API

## Запуск

Frontend:

```bash
cd frontend
npm install
npm run dev
```

Backend:

```bash
cd backend
go run ./cmd/api
```

Frontend: http://localhost:5173
API healthcheck: http://localhost:8080/api/health
EOF

cat > frontend/package.json <<'EOF'
{
  "name": "kupymisto-frontend",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "lint": "eslint .",
    "preview": "vite preview"
  },
  "dependencies": {
    "@react-three/drei": "^10.4.2",
    "@react-three/fiber": "^9.3.0",
    "framer-motion": "^12.23.3",
    "lenis": "^1.3.8",
    "lucide-react": "^0.525.0",
    "react": "^19.1.0",
    "react-dom": "^19.1.0",
    "three": "^0.178.0"
  },
  "devDependencies": {
    "@eslint/js": "^9.30.1",
    "@types/node": "^24.0.10",
    "@types/react": "^19.1.8",
    "@types/react-dom": "^19.1.6",
    "@types/three": "^0.178.1",
    "@vitejs/plugin-react": "^4.6.0",
    "eslint": "^9.30.1",
    "eslint-plugin-react-hooks": "^5.2.0",
    "eslint-plugin-react-refresh": "^0.4.20",
    "globals": "^16.3.0",
    "typescript": "~5.8.3",
    "typescript-eslint": "^8.35.1",
    "vite": "^7.0.4"
  }
}
EOF

cat > frontend/index.html <<'EOF'
<!doctype html>
<html lang="uk">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="theme-color" content="#f2eee2" />
    <meta name="description" content="КупиМісто: українська онлайн-гра про міста, друзів і фінансові драми." />
    <title>КупиМісто</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

cat > frontend/tsconfig.json <<'EOF'
{
  "files": [],
  "references": [
    { "path": "./tsconfig.app.json" },
    { "path": "./tsconfig.node.json" }
  ]
}
EOF

cat > frontend/tsconfig.app.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "useDefineForClassFields": true,
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "allowJs": false,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx"
  },
  "include": ["src"]
}
EOF

cat > frontend/tsconfig.node.json <<'EOF'
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "allowImportingTsExtensions": true
  },
  "include": ["vite.config.ts"]
}
EOF

cat > frontend/vite.config.ts <<'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: { '/api': 'http://localhost:8080' }
  }
})
EOF

cat > frontend/src/main.tsx <<'EOF'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App'
import './styles.css'

createRoot(document.getElementById('root')!).render(
  <StrictMode><App /></StrictMode>,
)
EOF

cat > frontend/src/components/BoardScene.tsx <<'EOF'
import { Canvas, useFrame } from '@react-three/fiber'
import { ContactShadows, Environment, Float, RoundedBox } from '@react-three/drei'
import { useRef } from 'react'
import type { Group, Mesh } from 'three'

const colors = {
  ink: '#20202a', paper: '#f2eee2', blue: '#3167dc', yellow: '#f2c84b',
  red: '#de5549', green: '#54b87a', orange: '#e98a44'
}

function House({ position, color, scale = 1 }: { position: [number, number, number], color: string, scale?: number }) {
  return (
    <group position={position} scale={scale}>
      <RoundedBox args={[0.7, 0.58, 0.7]} radius={0.06} smoothness={3} position={[0, 0.29, 0]}>
        <meshStandardMaterial color={color} roughness={0.62} />
      </RoundedBox>
      <mesh position={[0, 0.8, 0]} rotation={[0, Math.PI / 4, 0]}>
        <coneGeometry args={[0.62, 0.52, 4]} />
        <meshStandardMaterial color={colors.red} roughness={0.55} />
      </mesh>
      <mesh position={[0, 0.27, 0.356]}>
        <boxGeometry args={[0.2, 0.36, 0.02]} />
        <meshStandardMaterial color={colors.ink} />
      </mesh>
    </group>
  )
}

function Coin({ position, color = colors.yellow, speed = 1 }: { position: [number, number, number], color?: string, speed?: number }) {
  const ref = useRef<Mesh>(null)
  useFrame((state, delta) => {
    if (!ref.current) return
    ref.current.rotation.y += delta * speed
    ref.current.position.y = position[1] + Math.sin(state.clock.elapsedTime * speed) * 0.16
  })
  return (
    <mesh ref={ref} position={position} rotation={[Math.PI / 2, 0, 0]}>
      <cylinderGeometry args={[0.43, 0.43, 0.12, 48]} />
      <meshStandardMaterial color={color} metalness={0.18} roughness={0.32} />
      <mesh position={[0, 0.071, 0]} rotation={[-Math.PI / 2, 0, 0]}>
        <torusGeometry args={[0.29, 0.035, 12, 48]} />
        <meshStandardMaterial color={colors.paper} />
      </mesh>
    </mesh>
  )
}

function Die() {
  const ref = useRef<Group>(null)
  useFrame((state) => {
    if (!ref.current) return
    ref.current.rotation.x = state.clock.elapsedTime * 0.3
    ref.current.rotation.y = state.clock.elapsedTime * 0.42
  })
  return (
    <Float speed={1.4} rotationIntensity={0.25} floatIntensity={0.35}>
      <group ref={ref} position={[-3.3, 1.2, 1.5]}>
        <RoundedBox args={[0.9, 0.9, 0.9]} radius={0.17} smoothness={4}>
          <meshStandardMaterial color={colors.paper} roughness={0.35} />
        </RoundedBox>
        {[[0, 0.46, 0], [0.22, 0.46, 0.22], [-0.22, 0.46, -0.22]].map((p, i) => (
          <mesh key={i} position={p as [number, number, number]} rotation={[Math.PI / 2, 0, 0]}>
            <cylinderGeometry args={[0.065, 0.065, 0.025, 24]} />
            <meshStandardMaterial color={colors.red} />
          </mesh>
        ))}
      </group>
    </Float>
  )
}

function Pawn() {
  return (
    <Float speed={1.1} floatIntensity={0.18} rotationIntensity={0.08}>
      <group position={[2.65, 0.78, 1.65]}>
        <mesh position={[0, 0.52, 0]}>
          <sphereGeometry args={[0.3, 32, 32]} />
          <meshStandardMaterial color={colors.blue} roughness={0.38} />
        </mesh>
        <mesh position={[0, 0.03, 0]}>
          <coneGeometry args={[0.52, 0.82, 32]} />
          <meshStandardMaterial color={colors.blue} roughness={0.4} />
        </mesh>
        <mesh position={[0, -0.39, 0]}>
          <cylinderGeometry args={[0.58, 0.58, 0.12, 32]} />
          <meshStandardMaterial color={colors.ink} />
        </mesh>
      </group>
    </Float>
  )
}

function Board() {
  const ref = useRef<Group>(null)
  useFrame((state) => {
    if (!ref.current) return
    const targetX = state.pointer.y * 0.12 - 0.52
    const targetY = state.pointer.x * 0.18 - 0.48
    ref.current.rotation.x += (targetX - ref.current.rotation.x) * 0.035
    ref.current.rotation.y += (targetY - ref.current.rotation.y) * 0.035
  })

  const tiles = [
    [-2.55, 0.23, -2.55, colors.blue], [-1.25, 0.23, -2.55, colors.paper], [0, 0.23, -2.55, colors.green], [1.25, 0.23, -2.55, colors.paper], [2.55, 0.23, -2.55, colors.red],
    [2.55, 0.23, -1.25, colors.paper], [2.55, 0.23, 0, colors.orange], [2.55, 0.23, 1.25, colors.paper], [2.55, 0.23, 2.55, colors.yellow],
    [1.25, 0.23, 2.55, colors.paper], [0, 0.23, 2.55, colors.blue], [-1.25, 0.23, 2.55, colors.paper], [-2.55, 0.23, 2.55, colors.green],
    [-2.55, 0.23, 1.25, colors.paper], [-2.55, 0.23, 0, colors.red], [-2.55, 0.23, -1.25, colors.paper]
  ] as const

  return (
    <group ref={ref} rotation={[-0.52, -0.48, 0]}>
      <RoundedBox args={[6.7, 0.38, 6.7]} radius={0.22} smoothness={4} position={[0, 0, 0]}>
        <meshStandardMaterial color={colors.ink} roughness={0.6} />
      </RoundedBox>
      <RoundedBox args={[6.35, 0.14, 6.35]} radius={0.16} smoothness={4} position={[0, 0.24, 0]}>
        <meshStandardMaterial color={colors.yellow} roughness={0.72} />
      </RoundedBox>
      {tiles.map(([x, y, z, color], i) => (
        <RoundedBox key={i} args={[1.08, 0.12, 1.08]} radius={0.08} smoothness={3} position={[x, y + 0.1, z]}>
          <meshStandardMaterial color={color} roughness={0.65} />
        </RoundedBox>
      ))}
      <mesh position={[0, 0.35, 0]} rotation={[-Math.PI / 2, 0, Math.PI / 4]}>
        <ringGeometry args={[1.25, 1.32, 64]} />
        <meshStandardMaterial color={colors.ink} />
      </mesh>
      <House position={[-1.55, 0.36, -0.5]} color={colors.blue} />
      <House position={[1.15, 0.36, 0.72]} color={colors.green} scale={0.78} />
      <Coin position={[3.45, 1.2, -1.6]} speed={1.15} />
      <Coin position={[-3.45, 0.65, -0.8]} color={colors.green} speed={0.8} />
      <Die />
      <Pawn />
    </group>
  )
}

export default function BoardScene() {
  return (
    <Canvas dpr={[1, 1.7]} camera={{ position: [0, 5.3, 9.2], fov: 38 }} gl={{ antialias: true }}>
      <color attach="background" args={['#f2eee2']} />
      <ambientLight intensity={1.7} />
      <directionalLight position={[5, 8, 4]} intensity={3.2} castShadow />
      <Board />
      <ContactShadows position={[0, -1.45, 0]} opacity={0.22} scale={13} blur={2.5} far={5} />
      <Environment preset="city" />
    </Canvas>
  )
}
EOF

cat > frontend/src/App.tsx <<'EOF'
import { useEffect, useState } from 'react'
import { motion, useReducedMotion } from 'framer-motion'
import Lenis from 'lenis'
import { ArrowDownRight, ArrowUpRight, Users, Volume2, VolumeX } from 'lucide-react'
import BoardScene from './components/BoardScene'

const reveal = {
  hidden: { opacity: 0, y: 30 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.72, ease: [0.16, 1, 0.3, 1] as const } }
}

function Mark() {
  return <svg className="mark" viewBox="0 0 48 48" aria-hidden="true"><path d="M7 18 24 7l17 11v23H7V18Z"/><path d="M18 41V27h12v14"/><circle cx="24" cy="18" r="3"/></svg>
}

function App() {
  const [sound, setSound] = useState(false)
  const [buttonState, setButtonState] = useState('Створити кімнату')
  const reduceMotion = useReducedMotion()

  useEffect(() => {
    if (reduceMotion) return
    const lenis = new Lenis({ duration: 1.05, smoothWheel: true })
    let frame = 0
    const raf = (time: number) => { lenis.raf(time); frame = requestAnimationFrame(raf) }
    frame = requestAnimationFrame(raf)
    return () => { cancelAnimationFrame(frame); lenis.destroy() }
  }, [reduceMotion])

  const createRoom = async () => {
    setButtonState('Створюємо...')
    try {
      const response = await fetch('/api/rooms', { method: 'POST' })
      if (!response.ok) throw new Error('request failed')
      setButtonState('Кімната готова')
    } catch {
      setButtonState('Демо готове')
    }
    window.setTimeout(() => setButtonState('Створити кімнату'), 2200)
  }

  return <>
    <div className="grain" />
    <header>
      <a className="brand" href="#top" aria-label="КупиМісто, на головну"><Mark /><span>Купи<span>Місто</span></span></a>
      <nav aria-label="Головна навігація"><a href="#rules">Як грати</a><a href="#mood">Настрій</a><a href="#about">Про гру</a></nav>
      <button className="sound" onClick={() => setSound(!sound)} aria-label={sound ? 'Вимкнути звук' : 'Увімкнути звук'}>{sound ? <Volume2 /> : <VolumeX />}<span>{sound ? 'Звук є' : 'Без звуку'}</span></button>
    </header>

    <main id="top">
      <section className="hero">
        <motion.div className="heroCopy" initial="hidden" animate="visible" variants={reveal}>
          <p className="eyebrow"><span /> Українська онлайн-гра</p>
          <h1>Купуй.<br/>Будуй.<br/><em>Керуй.</em></h1>
          <p className="lead">Збирай друзів, скуповуй райони й доводь, що саме ти тут головний рієлтор. Без нудних таблиць, зате з характером.</p>
          <div className="heroActions">
            <button className="primary" onClick={createRoom}>{buttonState}<ArrowUpRight /></button>
            <a className="textLink" href="#rules">Правила за 42 секунди <ArrowDownRight /></a>
          </div>
          <div className="players"><Users /><span><strong>2–6 гравців</strong><small>і один підозріло хитрий банкір</small></span></div>
        </motion.div>
        <motion.div className="scene" initial={{ opacity: 0, scale: .9 }} animate={{ opacity: 1, scale: 1 }} transition={{ duration: 1, ease: [0.16, 1, 0.3, 1], delay: .12 }}>
          <BoardScene />
          <div className="sceneLabel labelOne"><b>КИЇВ</b><span>вартість знову зросла</span></div>
          <div className="sceneLabel labelTwo"><b>КУБИК</b><span>винен у всьому</span></div>
        </motion.div>
      </section>

      <div className="ticker" aria-hidden="true"><div><span>Доброго вечора, ми з КупиМіста</span><i /> <span>Кидай кубик, а не друзів</span><i /> <span>Оренда сама себе не збере</span><i /> <span>Доброго вечора, ми з КупиМіста</span><i /> <span>Кидай кубик, а не друзів</span><i /> <span>Оренда сама себе не збере</span><i /></div></div>

      <section className="mood" id="mood">
        <motion.div className="moodIntro" initial="hidden" whileInView="visible" viewport={{ once: true, amount: .3 }} variants={reveal}>
          <span className="sectionNo">01</span><h2>Меми тут не декор. Це валюта настрою.</h2>
        </motion.div>
        <motion.div className="poster" initial={{ opacity: 0, rotate: 0, y: 40 }} whileInView={{ opacity: 1, rotate: 2.3, y: 0 }} viewport={{ once: true }} transition={{ duration: .8, ease: [0.16, 1, 0.3, 1] }}>
          <div className="dogIllustration" aria-hidden="true"><svg viewBox="0 0 360 260"><path className="dogBody" d="M81 147c18-45 58-68 108-64 42 3 77 27 94 63l32 4-8 26-33 5c-10 36-42 57-88 57-58 0-98-30-105-91Z"/><path className="dogHead" d="M74 51c36 0 65 29 65 65s-29 65-65 65-57-30-57-66c0-25 10-46 31-57l-9-36 35 29Z"/><path className="dogEar" d="m82 49 53-27-13 63Z"/><circle cx="86" cy="97" r="8"/><path className="dogNose" d="m34 117 22-9 3 18Z"/><path className="dogLeg" d="M133 213v38M237 210v41"/><path className="collar" d="M35 146c25 12 57 12 83-4"/></svg></div>
          <p>Хто тримає цей район?</p><strong>Визначить перше коло.</strong>
          <span className="stamp">МЕМНИЙ ФОНД</span>
        </motion.div>
      </section>

      <section className="rules" id="rules">
        <motion.div className="rulesHead" initial="hidden" whileInView="visible" viewport={{ once: true }} variants={reveal}><span className="sectionNo">02</span><h2>Три кроки до фінансової драми</h2></motion.div>
        <div className="steps">
          {[
            ['01', 'Створи кімнату', 'Один клік. Жодних реєстраційних квестів.'],
            ['02', 'Поклич своїх', 'Надішли посилання тим, кому ще довіряєш.'],
            ['03', 'Забери місто', 'Купуй райони, збирай оренду, не виправдовуйся.']
          ].map(([n, title, text], index) => <motion.article key={n} initial={{ opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: index * .08, duration: .65, ease: [0.16, 1, 0.3, 1] }}><span>{n}</span><h3>{title}</h3><p>{text}</p><ArrowUpRight /></motion.article>)}
        </div>
      </section>

      <section className="finalCta" id="about"><p>Дружба пройшла багато.</p><h2>Час перевірити її орендою.</h2><button className="primary inverse" onClick={createRoom}>{buttonState}<ArrowUpRight /></button></section>
    </main>

    <footer><a className="brand footBrand" href="#top"><Mark /><span>Купи<span>Місто</span></span></a><p>Зроблено в Україні. Без емодзі та нудних квадратів.</p><span>2026</span></footer>
  </>
}

export default App
EOF

cat > frontend/src/styles.css <<'EOF'
@import url('https://fonts.googleapis.com/css2?family=Manrope:wght@500;600;700;800&family=Unbounded:wght@600;700;800&display=swap');
:root{font-family:Manrope,system-ui,sans-serif;color:oklch(21% .035 278);background:oklch(95.5% .018 96);font-synthesis:none;text-rendering:optimizeLegibility;--ink:oklch(21% .035 278);--paper:oklch(95.5% .018 96);--blue:oklch(58% .19 257);--yellow:oklch(84% .16 91);--red:oklch(62% .2 28);--green:oklch(70% .15 151);--muted:oklch(48% .035 278);--ease:cubic-bezier(.16,1,.3,1)}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;min-width:320px;overflow-x:hidden}button,a{font:inherit}button{color:inherit}a{color:inherit;text-decoration:none}h1,h2,h3,p{margin:0}h1,h2,h3{text-wrap:balance}.grain{position:fixed;inset:0;pointer-events:none;z-index:100;opacity:.055;background-image:url("data:image/svg+xml,%3Csvg viewBox='0 0 180 180' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='.5'/%3E%3C/svg%3E")}
header{height:80px;display:flex;align-items:center;justify-content:space-between;padding:0 clamp(20px,4vw,68px);border-bottom:1px solid oklch(21% .035 278/.16);position:relative;z-index:10}.brand{display:flex;align-items:center;gap:10px;font-family:Unbounded,sans-serif;font-size:20px;font-weight:800;letter-spacing:-.065em}.brand span span{color:var(--blue)}.mark{width:32px;height:32px;fill:var(--yellow);stroke:var(--ink);stroke-width:3;stroke-linejoin:round}.mark path:nth-child(2),.mark circle{fill:var(--paper)}nav{display:flex;gap:32px;font-weight:800;font-size:14px}nav a{transition:color .2s,transform .2s var(--ease)}nav a:hover{color:var(--blue);transform:translateY(-2px)}.sound{border:0;background:transparent;display:flex;align-items:center;gap:9px;font-weight:800;cursor:pointer}.sound svg{width:19px}.sound:focus-visible,a:focus-visible,button:focus-visible{outline:3px solid var(--blue);outline-offset:5px}
.hero{min-height:calc(100svh - 80px);display:grid;grid-template-columns:minmax(440px,.92fr) 1.08fr;align-items:center;padding:60px clamp(20px,4vw,68px) 88px;gap:10px}.heroCopy{position:relative;z-index:2}.eyebrow{font-size:13px;font-weight:900;letter-spacing:.11em;text-transform:uppercase;display:flex;align-items:center;gap:10px}.eyebrow span{width:12px;height:12px;border-radius:50%;border:2px solid var(--ink);background:var(--red)}h1{font-family:Unbounded,sans-serif;font-size:clamp(58px,7.4vw,112px);line-height:.87;letter-spacing:-.078em;margin:24px 0 32px;margin-left:-.06em}h1 em{font-style:normal;color:var(--blue)}.lead{font-size:clamp(17px,1.4vw,22px);line-height:1.55;max-width:56ch;font-weight:650}.heroActions{display:flex;align-items:center;gap:24px;margin-top:32px}.primary{min-height:54px;padding:0 20px;border:3px solid var(--ink);border-radius:15px;background:var(--yellow);font-weight:900;display:inline-flex;align-items:center;gap:14px;box-shadow:5px 5px 0 var(--ink);cursor:pointer;transition:transform .15s var(--ease),box-shadow .15s var(--ease)}.primary:hover{transform:translate(2px,2px);box-shadow:3px 3px 0 var(--ink)}.primary:active{transform:translate(5px,5px);box-shadow:0 0 0}.primary svg{width:20px}.textLink{font-weight:900;display:flex;align-items:center;gap:7px}.textLink svg{width:18px;transition:transform .25s var(--ease)}.textLink:hover svg{transform:translate(3px,3px)}.players{display:flex;align-items:center;gap:12px;margin-top:34px;color:var(--muted)}.players svg{width:24px}.players span{display:grid}.players strong{font-size:13px;color:var(--ink)}.players small{font-size:12px;font-weight:700}.scene{height:min(720px,76vw);min-height:530px;position:relative}.scene canvas{touch-action:pan-y}.sceneLabel{position:absolute;z-index:2;border:2px solid var(--ink);background:var(--paper);padding:10px 13px;border-radius:10px;box-shadow:4px 4px 0 var(--ink);display:grid;line-height:1.2;pointer-events:none}.sceneLabel b{font-family:Unbounded;font-size:11px}.sceneLabel span{font-size:10px;font-weight:800;color:var(--muted)}.labelOne{right:7%;top:20%;transform:rotate(4deg)}.labelTwo{left:5%;bottom:20%;transform:rotate(-5deg)}
.ticker{width:102%;margin-left:-1%;overflow:hidden;background:var(--blue);color:var(--paper);border-block:3px solid var(--ink);transform:rotate(-1deg)}.ticker>div{display:flex;align-items:center;width:max-content;padding:15px 0;font-family:Unbounded,sans-serif;font-size:14px;font-weight:700;animation:marquee 25s linear infinite}.ticker span{padding:0 26px}.ticker i{display:block;width:9px;height:9px;border-radius:50%;background:var(--yellow);border:1px solid var(--ink)}@keyframes marquee{to{transform:translateX(-50%)}}
.mood{padding:130px clamp(20px,6vw,96px);display:grid;grid-template-columns:.82fr 1.18fr;gap:8vw;align-items:center}.sectionNo{font-family:Unbounded;font-size:13px;font-weight:800;color:var(--blue)}.moodIntro h2,.rules h2,.finalCta h2{font-family:Unbounded,sans-serif;font-size:clamp(40px,5.2vw,76px);line-height:1.02;letter-spacing:-.06em;margin-top:18px}.poster{min-height:500px;background:var(--red);color:var(--paper);border:4px solid var(--ink);border-radius:28px;padding:48px;box-shadow:13px 13px 0 var(--ink);position:relative;display:flex;flex-direction:column;justify-content:flex-end;overflow:hidden}.poster p{font-family:Unbounded;font-size:clamp(27px,3.8vw,53px);line-height:1.04;letter-spacing:-.05em;max-width:10ch;position:relative;z-index:2}.poster strong{font-size:14px;margin-top:14px;letter-spacing:.07em;text-transform:uppercase;position:relative;z-index:2}.stamp{position:absolute;right:24px;top:24px;border:2px solid var(--paper);border-radius:50%;width:102px;height:102px;display:grid;place-items:center;text-align:center;font-family:Unbounded;font-size:10px;line-height:1.3;transform:rotate(12deg)}.dogIllustration{position:absolute;right:-10px;top:65px;width:62%;color:var(--ink)}.dogIllustration svg{width:100%;overflow:visible}.dogBody,.dogHead{fill:var(--paper);stroke:currentColor;stroke-width:8;stroke-linejoin:round}.dogEar{fill:var(--yellow);stroke:currentColor;stroke-width:8;stroke-linejoin:round}.dogIllustration circle,.dogNose{fill:var(--ink)}.dogLeg,.collar{fill:none;stroke:currentColor;stroke-width:10;stroke-linecap:round}
.rules{padding:90px clamp(20px,6vw,96px) 140px}.rulesHead{max-width:950px}.steps{margin-top:72px;border-top:3px solid var(--ink)}.steps article{display:grid;grid-template-columns:80px 1.1fr 1fr 44px;align-items:center;gap:28px;padding:31px 0;border-bottom:3px solid var(--ink);transition:color .25s,transform .25s var(--ease)}.steps article:hover{color:var(--blue);transform:translateX(9px)}.steps article>span{font-family:Unbounded;font-size:15px}.steps h3{font-family:Unbounded;font-size:clamp(21px,2.5vw,36px);letter-spacing:-.05em}.steps p{font-weight:700;line-height:1.55;color:var(--muted);max-width:42ch}.steps svg{justify-self:end}
.finalCta{background:var(--yellow);border-block:4px solid var(--ink);padding:110px clamp(20px,6vw,96px);text-align:center;display:flex;flex-direction:column;align-items:center}.finalCta>p{font-weight:900;text-transform:uppercase;letter-spacing:.11em;font-size:13px}.finalCta h2{max-width:13ch}.inverse{margin-top:38px;background:var(--paper)}footer{min-height:160px;background:var(--ink);color:var(--paper);padding:42px clamp(20px,4vw,68px);display:flex;align-items:center;justify-content:space-between;gap:28px}.footBrand .mark{stroke:var(--paper)}footer p{color:oklch(78% .025 278);font-size:13px;font-weight:700}.footBrand span span{color:oklch(75% .15 257)}
@media(max-width:900px){header nav{display:none}.hero{grid-template-columns:1fr;padding-top:46px}.scene{height:520px;min-height:0}.mood{grid-template-columns:1fr}.poster{margin-top:20px}.steps article{grid-template-columns:55px 1fr 36px}.steps article p{display:none}}
@media(max-width:560px){header{height:68px}.brand{font-size:17px}.mark{width:28px}.sound span{display:none}.hero{min-height:auto;padding-bottom:64px}.heroActions{align-items:flex-start;flex-direction:column}.scene{height:400px;margin-inline:-20px}.sceneLabel{display:none}.mood{padding-block:90px}.poster{min-height:440px;padding:28px}.dogIllustration{width:88%;top:70px;right:-42px}.stamp{width:80px;height:80px}.rules{padding-block:70px 100px}.steps article{gap:12px}.finalCta{padding-block:90px}footer{align-items:flex-start;flex-direction:column}.ticker>div{animation-duration:18s}}
@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}.ticker>div{animation:none}*{transition:none!important}}
EOF

cat > backend/go.mod <<'EOF'
module github.com/deforxdev/kupymisto/backend

go 1.24
EOF

cat > backend/cmd/api/main.go <<'EOF'
package main

import (
    "encoding/json"
    "log"
    "math/rand/v2"
    "net/http"
    "os"
    "time"
)

type response struct {
    Status string `json:"status"`
    RoomID string `json:"roomId,omitempty"`
}

func writeJSON(w http.ResponseWriter, status int, value response) {
    w.Header().Set("Content-Type", "application/json; charset=utf-8")
    w.WriteHeader(status)
    _ = json.NewEncoder(w).Encode(value)
}

func main() {
    mux := http.NewServeMux()
    mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, _ *http.Request) {
        writeJSON(w, http.StatusOK, response{Status: "ok"})
    })
    mux.HandleFunc("POST /api/rooms", func(w http.ResponseWriter, _ *http.Request) {
        id := time.Now().Format("150405") + "-" + string(rune('A'+rand.IntN(26)))
        writeJSON(w, http.StatusCreated, response{Status: "created", RoomID: id})
    })

    port := os.Getenv("PORT")
    if port == "" { port = "8080" }
    server := &http.Server{Addr: ":" + port, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
    log.Printf("Kupymisto API listening on :%s", port)
    log.Fatal(server.ListenAndServe())
}
EOF

cat > docker-compose.yml <<'EOF'
services:
  api:
    image: golang:1.24-alpine
    working_dir: /app
    volumes:
      - ./backend:/app
    command: go run ./cmd/api
    ports:
      - "8080:8080"
  web:
    image: node:22-alpine
    working_dir: /app
    volumes:
      - ./frontend:/app
      - web_node_modules:/app/node_modules
    command: sh -c "npm install && npm run dev -- --host 0.0.0.0"
    ports:
      - "5173:5173"
    depends_on:
      - api
volumes:
  web_node_modules:
EOF

printf 'Installing frontend dependencies...\n'
(cd frontend && npm install)

printf 'Checking production build...\n'
(cd frontend && npm run build)

printf 'Formatting and checking Go backend...\n'
(cd backend && gofmt -w cmd/api/main.go && go test ./...)

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add .
  git commit -m "feat: add animated Kupymisto landing page" || true
  current_branch="$(git branch --show-current)"
  if git remote get-url origin >/dev/null 2>&1; then
    git push -u origin "${current_branch:-main}" || printf '\nPush skipped. Run git push after signing in to GitHub.\n'
  fi
fi

printf '\nDone. Run: docker compose up\nOpen: http://localhost:5173\n'
