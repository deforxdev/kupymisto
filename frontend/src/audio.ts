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
