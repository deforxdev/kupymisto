import { motion } from 'framer-motion'

interface MoneyBurstProps {
  delta: number
}

const particles = Array.from({ length: 8 }, (_, index) => ({
  x: Math.cos((index / 8) * Math.PI * 2) * (54 + (index % 3) * 12),
  y: Math.sin((index / 8) * Math.PI * 2) * (38 + (index % 2) * 14),
}))

export default function MoneyBurst({ delta }: MoneyBurstProps) {
  const positive = delta > 0
  const amount = Math.abs(delta)

  return (
    <motion.aside
      className={`moneyBurst ${positive ? 'moneyGain' : 'moneyLoss'}`}
      initial={{ opacity: 0, scale: 0.72, y: 24 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      exit={{ opacity: 0, scale: 1.16, y: -32, filter: 'blur(7px)' }}
      transition={{ type: 'spring', stiffness: 400, damping: 18 }}
      role="status"
      aria-live="polite"
    >
      <div className="moneyParticles" aria-hidden="true">
        {particles.map((particle, index) => (
          <motion.i
            key={index}
            initial={{ x: 0, y: 0, scale: 0, opacity: 0 }}
            animate={{ x: particle.x, y: particle.y, scale: [0, 1, 0.65], opacity: [0, 1, 0] }}
            transition={{ duration: 0.9, delay: index * 0.025, ease: [0.16, 1, 0.3, 1] }}
          />
        ))}
      </div>
      <small>{positive ? 'Баланс поповнено' : 'Списано з балансу'}</small>
      <strong>{positive ? '+' : '−'}{amount} ₴</strong>
      <span>{positive ? 'ГРОШІ ПРАЦЮЮТЬ' : 'ФІНАНСОВА ДРАМА'}</span>
    </motion.aside>
  )
}
