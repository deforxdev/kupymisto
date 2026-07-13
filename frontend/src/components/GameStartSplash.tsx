import { motion, useReducedMotion } from 'framer-motion'

interface GameStartSplashProps {
  roomName: string
  onComplete: () => void
}

const cityBlocks = [
  { x: '8%', y: '58%', color: 'var(--blue)', delay: 0.08 },
  { x: '18%', y: '38%', color: 'var(--yellow)', delay: 0.14 },
  { x: '31%', y: '67%', color: 'var(--red)', delay: 0.2 },
  { x: '67%', y: '61%', color: 'var(--yellow)', delay: 0.11 },
  { x: '78%', y: '35%', color: 'var(--blue)', delay: 0.18 },
  { x: '88%', y: '66%', color: 'var(--red)', delay: 0.24 },
]

export default function GameStartSplash({ roomName, onComplete }: GameStartSplashProps) {
  const reducedMotion = useReducedMotion()

  return (
    <motion.section
      className="gameStartSplash"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0, filter: reducedMotion ? 'none' : 'blur(10px)' }}
      transition={{ duration: reducedMotion ? 0.15 : 0.45 }}
      aria-label="Гра починається"
    >
      <div className="startCityMap" aria-hidden="true">
        <motion.div
          className="startRoute"
          initial={reducedMotion ? false : { opacity: 0 }}
          animate={{ opacity: 1 }}
        >
          <svg viewBox="0 0 1000 560" preserveAspectRatio="none">
            <motion.path
              d="M-30 440 C130 330 190 480 350 335 S610 175 760 295 S930 360 1040 160"
              fill="none"
              stroke="currentColor"
              strokeWidth="5"
              strokeDasharray="12 14"
              initial={reducedMotion ? false : { pathLength: 0 }}
              animate={{ pathLength: 1 }}
              transition={{ duration: 1.5, ease: [0.16, 1, 0.3, 1] }}
            />
          </svg>
        </motion.div>
        {cityBlocks.map((block, index) => (
          <motion.i
            key={index}
            className="startCityBlock"
            style={{ left: block.x, top: block.y, background: block.color }}
            initial={reducedMotion ? false : { opacity: 0, y: 70, rotate: -12, scale: 0.65 }}
            animate={{ opacity: 1, y: 0, rotate: index % 2 ? 5 : -5, scale: 1 }}
            transition={{ duration: 0.75, delay: block.delay, ease: [0.16, 1, 0.3, 1] }}
          />
        ))}
        <motion.div
          className="startPawn"
          initial={reducedMotion ? false : { x: '-42vw', y: '14vh', opacity: 0, rotate: -18 }}
          animate={{ x: 0, y: 0, opacity: 1, rotate: 0 }}
          transition={{ duration: 1.25, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
        >
          <b />
          <i />
        </motion.div>
      </div>

      <motion.div
        className="startCopy"
        initial={reducedMotion ? false : { opacity: 0, y: 30, clipPath: 'inset(0 0 100% 0)' }}
        animate={{ opacity: 1, y: 0, clipPath: 'inset(0 0 0% 0)' }}
        transition={{ duration: 0.85, delay: 0.35, ease: [0.16, 1, 0.3, 1] }}
      >
        <span>КупиМісто · 30 кіл</span>
        <h1>МІСТО<br />В ГРІ</h1>
        <p><strong>{roomName}</strong>Перший хід починається</p>
      </motion.div>

      <motion.div
        className="startCountdown"
        initial={reducedMotion ? false : { opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.55, delay: 0.95 }}
        aria-hidden="true"
      >
        <i /><span>КУПУЙ</span><i /><span>БУДУЙ</span><i /><span>ПЕРЕМАГАЙ</span><i />
      </motion.div>

      <motion.button
        type="button"
        className="startSkip"
        onClick={onComplete}
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ type: 'spring', stiffness: 400, damping: 10, delay: reducedMotion ? 0 : 0.9 }}
        whileTap={{ scale: 0.96, y: 2 }}
      >
        Пропустити
      </motion.button>
    </motion.section>
  )
}
