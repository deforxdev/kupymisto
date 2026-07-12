#!/usr/bin/env bash
set -euo pipefail

if [ ! -f frontend/src/App.tsx ]; then
  echo "Запусти цей файл у корені репозиторію kupymisto."
  exit 1
fi

cat > frontend/src/audio.ts <<'EOF'
let context: AudioContext | null = null
let ambience: { gain: GainNode; oscillators: OscillatorNode[] } | null = null

function getContext() {
  if (!context) context = new AudioContext()
  if (context.state === 'suspended') void context.resume()
  return context
}

export function playUiSound(kind: 'select' | 'click' | 'success' = 'click') {
  const ctx = getContext()
  const now = ctx.currentTime
  const gain = ctx.createGain()
  const filter = ctx.createBiquadFilter()
  const oscillator = ctx.createOscillator()
  const frequency = kind === 'select' ? 330 : kind === 'success' ? 523.25 : 220

  oscillator.type = kind === 'click' ? 'triangle' : 'sine'
  oscillator.frequency.setValueAtTime(frequency, now)
  if (kind === 'success') oscillator.frequency.exponentialRampToValueAtTime(784.88, now + 0.16)
  filter.type = 'lowpass'
  filter.frequency.value = 1600
  gain.gain.setValueAtTime(0.0001, now)
  gain.gain.exponentialRampToValueAtTime(0.085, now + 0.012)
  gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.2)
  oscillator.connect(filter).connect(gain).connect(ctx.destination)
  oscillator.start(now)
  oscillator.stop(now + 0.22)
}

export function startAmbience() {
  if (ambience) return
  const ctx = getContext()
  const master = ctx.createGain()
  const filter = ctx.createBiquadFilter()
  master.gain.value = 0.018
  filter.type = 'lowpass'
  filter.frequency.value = 520
  filter.Q.value = 0.7
  master.connect(filter).connect(ctx.destination)

  const oscillators = [110, 164.81, 220].map((frequency, index) => {
    const oscillator = ctx.createOscillator()
    const gain = ctx.createGain()
    oscillator.type = index === 2 ? 'triangle' : 'sine'
    oscillator.frequency.value = frequency
    oscillator.detune.value = index * 3 - 3
    gain.gain.value = index === 2 ? 0.12 : 0.34
    oscillator.connect(gain).connect(master)
    oscillator.start()
    return oscillator
  })
  ambience = { gain: master, oscillators }
}

export function stopAmbience() {
  if (!ambience || !context) return
  const current = ambience
  const now = context.currentTime
  current.gain.gain.cancelScheduledValues(now)
  current.gain.gain.setValueAtTime(Math.max(current.gain.gain.value, 0.0001), now)
  current.gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.18)
  window.setTimeout(() => {
    current.oscillators.forEach((oscillator) => oscillator.stop())
    current.gain.disconnect()
  }, 220)
  ambience = null
}
EOF

cat > frontend/src/components/AgeGate.tsx <<'EOF'
import { motion } from 'framer-motion'
import { ArrowUpRight } from 'lucide-react'
import { playUiSound, startAmbience } from '../audio'

export type AgeGroup = '10-12' | '14-15' | '18-20'

type Props = { onSelect: (group: AgeGroup) => void }

const groups: Array<{ value: AgeGroup; title: string; note: string }> = [
  { value: '10-12', title: '10–12', note: 'Легкі жарти, пригоди й дружнє суперництво' },
  { value: '14-15', title: '14–15', note: 'Шкільний вайб, тренди та більше іронії' },
  { value: '18-20', title: '18–20', note: 'Студентський хаос, оренда й дорослі рішення' },
]

export default function AgeGate({ onSelect }: Props) {
  const choose = (group: AgeGroup) => {
    playUiSound('select')
    startAmbience()
    onSelect(group)
  }

  return (
    <motion.div className="ageGate" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: .35 }}>
      <div className="ageMark" aria-hidden="true"><span>К</span><i /></div>
      <motion.section className="agePanel" initial={{ opacity: 0, y: 28, scale: .97 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0, y: -18, scale: .98 }} transition={{ duration: .65, ease: [0.16, 1, 0.3, 1] }} aria-labelledby="age-title">
        <p className="ageKicker">Налаштуємо гру під тебе</p>
        <h1 id="age-title">Скільки тобі років?</h1>
        <p className="ageIntro">Від вибору залежать жарти, тексти та мемні відсилки. Правила гри залишаються чесними. Майже.</p>
        <div className="ageOptions">
          {groups.map((group, index) => (
            <motion.button key={group.value} type="button" onClick={() => choose(group.value)} initial={{ opacity: 0, y: 18 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: .2 + index * .07, duration: .55, ease: [0.16, 1, 0.3, 1] }}>
              <strong>{group.title}</strong><span>{group.note}</span><ArrowUpRight />
            </motion.button>
          ))}
        </div>
        <small>Вибір потрібен лише для тону контенту. Ми не зберігаємо твій вік.</small>
      </motion.section>
    </motion.div>
  )
}
EOF

python3 <<'PY'
from pathlib import Path
p = Path('frontend/src/App.tsx')
s = p.read_text()

s = s.replace("import { motion, useReducedMotion } from 'framer-motion'", "import { AnimatePresence, motion, useReducedMotion } from 'framer-motion'")
s = s.replace("import BoardScene from './components/BoardScene'", "import BoardScene from './components/BoardScene'\nimport AgeGate, { type AgeGroup } from './components/AgeGate'\nimport { playUiSound, startAmbience, stopAmbience } from './audio'")

anchor = "const reveal = {"
profiles = """const profiles: Record<AgeGroup, { lead: string; ticker: string[]; quote: string; answer: string }> = {
  '10-12': {
    lead: 'Збирай друзів, будуй райони й доводь, хто тут найкмітливіший мер. Весело, швидко й без нудної економіки.',
    ticker: ['Кидай кубик, а не друзів', 'Будинок поставлено, паніку скасовано', 'Цей район тепер під наглядом'],
    quote: 'Хто тримає цей район?',
    answer: 'Той, кому сьогодні щастить із кубиком.'
  },
  '14-15': {
    lead: 'Збирай друзів, скуповуй райони й доводь, що саме ти тут головний рієлтор. Менше домашки, більше підозрілих угод.',
    ticker: ['Доброго вечора, ми з КупиМіста', 'Кидай кубик, а не друзів', 'Оренда сама себе не збере'],
    quote: 'Це база чи знову оренда?',
    answer: 'Визначить перше коло.'
  },
  '18-20': {
    lead: 'Перша пара може почекати. Скуповуй райони, збирай оренду й нарешті відчуй, що житло працює на тебе.',
    ticker: ['Кава закінчилась, оренда залишилась', 'Фінансова грамотність увійшла в чат', 'Цей район дорожчий за сесію'],
    quote: 'А можна оренду після стипендії?',
    answer: 'Банкір прочитав і не відповів.'
  }
}

"""
s = s.replace(anchor, profiles + anchor)

s = s.replace("  const [sound, setSound] = useState(false)", "  const [sound, setSound] = useState(false)\n  const [ageGroup, setAgeGroup] = useState<AgeGroup | null>(null)\n  const profile = profiles[ageGroup ?? '14-15']")

s = s.replace("  const createRoom = async () => {\n    setButtonState('Створюємо...')", "  const createRoom = async () => {\n    if (sound) playUiSound('click')\n    setButtonState('Створюємо...')")
s = s.replace("      setButtonState('Кімната готова')", "      setButtonState('Кімната готова')\n      if (sound) playUiSound('success')")

old = """  return <>
    <div className=\"grain\" />"""
new = """  const selectAge = (group: AgeGroup) => {
    setAgeGroup(group)
    setSound(true)
  }

  const toggleSound = () => {
    if (sound) stopAmbience()
    else { startAmbience(); playUiSound('click') }
    setSound(!sound)
  }

  return <>
    <AnimatePresence>{!ageGroup && <AgeGate onSelect={selectAge} />}</AnimatePresence>
    <div className=\"grain\" />"""
s = s.replace(old, new)
s = s.replace("onClick={() => setSound(!sound)}", "onClick={toggleSound}")

s = s.replace("Збирай друзів, скуповуй райони й доводь, що саме ти тут головний рієлтор. Без нудних таблиць, зате з характером.", "{profile.lead}")

old_ticker = """<div className=\"ticker\" aria-hidden=\"true\"><div><span>Доброго вечора, ми з КупиМіста</span><i /> <span>Кидай кубик, а не друзів</span><i /> <span>Оренда сама себе не збере</span><i /> <span>Доброго вечора, ми з КупиМіста</span><i /> <span>Кидай кубик, а не друзів</span><i /> <span>Оренда сама себе не збере</span><i /></div></div>"""
new_ticker = """<div className=\"ticker\" aria-hidden=\"true\"><div>{[...profile.ticker, ...profile.ticker].map((item, index) => <span className=\"tickerItem\" key={`${item}-${index}`}><b>{item}</b><i /></span>)}</div></div>"""
s = s.replace(old_ticker, new_ticker)
s = s.replace("<p>Хто тримає цей район?</p><strong>Визначить перше коло.</strong>", "<p>{profile.quote}</p><strong>{profile.answer}</strong>")

p.write_text(s)
PY

cat >> frontend/src/styles.css <<'EOF'

/* Age selection and sound onboarding */
.ageGate{position:fixed;inset:0;z-index:90;display:grid;place-items:center;padding:24px;background:var(--yellow);overflow:auto}.ageGate::before,.ageGate::after{content:"";position:absolute;border:3px solid var(--ink);border-radius:50%;pointer-events:none}.ageGate::before{width:min(58vw,780px);height:min(58vw,780px);left:-18vw;bottom:-36vw}.ageGate::after{width:280px;height:280px;right:-90px;top:-100px}.agePanel{width:min(980px,100%);position:relative;z-index:2}.ageKicker{font-size:13px;font-weight:900;letter-spacing:.11em;text-transform:uppercase;margin-bottom:20px}.agePanel h1{max-width:none;font-size:clamp(46px,7vw,94px);line-height:.95;margin:0 0 24px}.ageIntro{font-size:clamp(17px,1.7vw,22px);line-height:1.5;font-weight:650;max-width:62ch}.ageOptions{display:grid;grid-template-columns:repeat(3,1fr);border-top:3px solid var(--ink);margin-top:48px}.ageOptions button{min-height:190px;border:0;border-bottom:3px solid var(--ink);border-right:3px solid var(--ink);background:transparent;padding:24px;text-align:left;display:grid;grid-template-columns:1fr auto;align-content:space-between;gap:14px;cursor:pointer;transition:background .2s,color .2s,transform .22s var(--ease)}.ageOptions button:first-child{border-left:3px solid var(--ink)}.ageOptions button:hover,.ageOptions button:focus-visible{background:var(--blue);color:var(--paper);transform:translateY(-8px)}.ageOptions strong{grid-column:1/-1;font-family:Unbounded;font-size:clamp(28px,3vw,44px);letter-spacing:-.055em}.ageOptions span{font-size:13px;font-weight:800;line-height:1.45;max-width:24ch}.ageOptions svg{width:24px;align-self:end}.agePanel>small{display:block;margin-top:20px;font-size:12px;font-weight:800}.ageMark{position:absolute;right:5vw;top:5vh;width:74px;height:74px;border:3px solid var(--ink);border-radius:18px;background:var(--red);display:grid;place-items:center;transform:rotate(8deg);box-shadow:5px 5px 0 var(--ink);z-index:3}.ageMark span{font-family:Unbounded;font-size:34px;font-weight:800;color:var(--paper)}.ageMark i{position:absolute;width:12px;height:12px;border-radius:50%;background:var(--yellow);border:2px solid var(--ink);right:-7px;top:-7px}.tickerItem{display:flex;align-items:center}.tickerItem b{padding:0 26px}.tickerItem i{flex:none}
@media(max-width:720px){.ageGate{place-items:start center;padding-top:76px}.ageMark{width:55px;height:55px;right:20px;top:18px}.ageMark span{font-size:25px}.ageOptions{grid-template-columns:1fr;margin-top:34px}.ageOptions button{min-height:116px;border-left:3px solid var(--ink);padding:18px;grid-template-columns:1fr auto}.ageOptions strong{grid-column:auto;font-size:28px}.ageOptions span{grid-column:1/2}.ageOptions svg{grid-column:2;grid-row:1/3}.agePanel>small{padding-bottom:30px}}
EOF

npm --prefix frontend run build

git add frontend/src/App.tsx frontend/src/styles.css frontend/src/audio.ts frontend/src/components/AgeGate.tsx
git commit -m "feat: add age-tailored content and menu audio" || true
git push || echo "Автоматичний push не пройшов. Виконай: git push"

echo "Оновлення готове. Запусти: docker compose up"
