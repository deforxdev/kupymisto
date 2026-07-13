let context: AudioContext | null = null
let ambience: { gain: GainNode; oscillators: OscillatorNode[] } | null = null
let masterGain: GainNode | null = null
let muted = typeof localStorage !== 'undefined' ? localStorage.getItem('kupymisto_audio_muted') !== '0' : true
const activeAssets = new Map<HTMLAudioElement, number>()

function getContext() {
  if (!context) context = new AudioContext()
  if (context.state === 'suspended') void context.resume()
  return context
}

function getMasterGain() {
 const ctx = getContext()
 if (!masterGain) {
  masterGain = ctx.createGain()
  masterGain.gain.value = muted ? 0 : 1
  masterGain.connect(ctx.destination)
 }
 return masterGain
}

export function setAudioMuted(value: boolean) {
 muted = value
 if (typeof localStorage !== 'undefined') localStorage.setItem('kupymisto_audio_muted', value ? '1' : '0')
 if (masterGain && context) {
  masterGain.gain.cancelScheduledValues(context.currentTime)
  masterGain.gain.setTargetAtTime(value ? 0 : 1, context.currentTime, .025)
 }
 activeAssets.forEach((volume, audio) => { audio.volume = value ? 0 : volume })
}

export function isAudioMuted() {
 return muted
}


export async function unlockAudio() {
  const ctx = getContext()
  if (ctx.state !== 'running') await ctx.resume()
  const buffer = ctx.createBuffer(1, 1, ctx.sampleRate)
  const source = ctx.createBufferSource()
  source.buffer = buffer
 source.connect(getMasterGain())
  source.start()
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
 oscillator.connect(filter).connect(gain).connect(getMasterGain())
  oscillator.start(now)
  oscillator.stop(now + 0.22)
}

export function playMoneySound(positive: boolean) {
  const ctx = getContext()
  const start = ctx.currentTime
  const frequencies = positive ? [392, 523.25, 659.25, 783.99] : [330, 261.63, 196]
  frequencies.forEach((frequency, index) => {
    const oscillator = ctx.createOscillator()
    const gain = ctx.createGain()
    const filter = ctx.createBiquadFilter()
    const time = start + index * 0.075
    oscillator.type = index % 2 === 0 ? 'triangle' : 'sine'
    oscillator.frequency.setValueAtTime(frequency, time)
    filter.type = 'lowpass'
    filter.frequency.value = positive ? 2200 : 1100
    gain.gain.setValueAtTime(0.0001, time)
    gain.gain.exponentialRampToValueAtTime(positive ? 0.11 : 0.085, time + 0.012)
    gain.gain.exponentialRampToValueAtTime(0.0001, time + 0.16)
    oscillator.connect(filter).connect(gain).connect(getMasterGain())
    oscillator.start(time)
    oscillator.stop(time + 0.18)
  })
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
 master.connect(filter).connect(getMasterGain())

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

export function playDiceRoll() {
  const ctx = getContext()
  const start = ctx.currentTime
  ;[0, .07, .13, .21, .30, .40, .51, .63].forEach((delay, index) => {
    const oscillator = ctx.createOscillator()
    const gain = ctx.createGain()
    const filter = ctx.createBiquadFilter()
    oscillator.type = index % 2 ? 'triangle' : 'square'
    oscillator.frequency.value = 105 + Math.random() * 85
    filter.type = 'lowpass'
    filter.frequency.value = 720 + Math.random() * 500
    const time = start + delay
    gain.gain.setValueAtTime(.0001, time)
    gain.gain.exponentialRampToValueAtTime(.045 * (1 - index / 12), time + .006)
    gain.gain.exponentialRampToValueAtTime(.0001, time + .055)
    oscillator.connect(filter).connect(gain).connect(getMasterGain())
    oscillator.start(time); oscillator.stop(time + .065)
  })
}

export function playPawnMove(steps: number) {
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
    oscillator.connect(filter).connect(gain).connect(getMasterGain())
    oscillator.start(time)
    oscillator.stop(time + 0.1)
  }
}

export async function playAssetSound(name: string, fallback?: () => void) {
  try {
    const audio = new Audio(`/sounds/${name}`)
    const volume = 0.55
    audio.volume = muted ? 0 : volume
    activeAssets.set(audio, volume)
    audio.addEventListener('ended', () => activeAssets.delete(audio), { once: true })
    await audio.play()
  } catch {
    fallback?.()
  }
}
