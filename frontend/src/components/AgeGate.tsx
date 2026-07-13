import { motion, useReducedMotion } from 'framer-motion'
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
  const reducedMotion = useReducedMotion()
  const choose = (group: AgeGroup) => {
    playUiSound('select')
    startAmbience()
    onSelect(group)
  }

  return (
    <motion.div className="ageGate" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: .35 }}>
      <motion.div className="ageOrb ageOrbOne" animate={reducedMotion ? undefined : { x: [0, 34, -18, 0], y: [0, -22, 18, 0], rotate: [0, 18, -12, 0] }} transition={{ duration: 12, repeat: Infinity, ease: 'easeInOut' }} />
      <motion.div className="ageOrb ageOrbTwo" animate={reducedMotion ? undefined : { x: [0, -28, 22, 0], y: [0, 24, -16, 0], rotate: [0, -22, 12, 0] }} transition={{ duration: 15, repeat: Infinity, ease: 'easeInOut', delay: 1 }} />
      <motion.div className="ageGrid" animate={reducedMotion ? undefined : { opacity: [.18, .32, .18], scale: [1, 1.04, 1] }} transition={{ duration: 5, repeat: Infinity, ease: 'easeInOut' }} />
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
