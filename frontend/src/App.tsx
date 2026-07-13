import { useEffect, useState } from 'react'
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion'
import Lenis from 'lenis'
import { ArrowDownRight, ArrowUpRight, Users, Volume2, VolumeX } from 'lucide-react'
import BoardScene from './components/BoardScene'
import AgeGate, { type AgeGroup } from './components/AgeGate'
import { playUiSound, setAudioMuted, startAmbience, stopAmbience } from './audio'
import AuthScreen from './components/AuthScreen'
import LobbyScreen from './components/LobbyScreen'
import { api, clearToken, getToken, type User } from './api'

const profiles: Record<AgeGroup, { lead: string; ticker: string[]; quote: string; answer: string }> = {
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

const reveal = {
  hidden: { opacity: 0, y: 30 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.72, ease: [0.16, 1, 0.3, 1] as const } }
}

function Mark() {
  return <svg className="mark" viewBox="0 0 48 48" aria-hidden="true"><path d="M7 18 24 7l17 11v23H7V18Z"/><path d="M18 41V27h12v14"/><circle cx="24" cy="18" r="3"/></svg>
}

function App() {
  const [sound, setSound] = useState(false)
  const [ageGroup, setAgeGroup] = useState<AgeGroup | null>(null)
  const profile = profiles[ageGroup ?? '14-15']
  const buttonState = 'Створити кімнату'
  const [screen, setScreen] = useState<'home' | 'auth' | 'lobby'>('home')
  const [user, setUser] = useState<User | null>(null)
  const reduceMotion = useReducedMotion()
  const navigate = (path: '/' | '/lobby') => { window.history.pushState({}, '', path); setScreen(path === '/lobby' ? 'lobby' : 'home') }
  useEffect(() => {
    const onPopState = () => setScreen(window.location.pathname === '/lobby' ? 'lobby' : 'home')
    window.addEventListener('popstate', onPopState)
    return () => window.removeEventListener('popstate', onPopState)
  }, [])

  useEffect(() => {
    if (!getToken()) return
    api.me().then(({ user }) => { setUser(user); navigate('/lobby') }).catch(() => clearToken())
  }, [])

  useEffect(() => {
    if (reduceMotion) return
    const lenis = new Lenis({ duration: 1.05, smoothWheel: true })
    let frame = 0
    const raf = (time: number) => { lenis.raf(time); frame = requestAnimationFrame(raf) }
    frame = requestAnimationFrame(raf)
    return () => { cancelAnimationFrame(frame); lenis.destroy() }
  }, [reduceMotion])

  const openGame = () => {
    if (sound) playUiSound('click')
    if (user) navigate('/lobby')
    else setScreen('auth')
  }

  const selectAge = (group: AgeGroup) => {
    setAgeGroup(group)
    setAudioMuted(false)
    startAmbience()
    setSound(true)
  }

  const toggleSound = () => {
    if (sound) { stopAmbience(); setAudioMuted(true) }
    else { setAudioMuted(false); startAmbience(); playUiSound('click') }
    setSound(!sound)
  }

  if (screen === 'auth') return <AuthScreen onBack={() => navigate('/')} onSuccess={(nextUser) => { setUser(nextUser); navigate('/lobby') }} />
  if (screen === 'lobby' && user) return <LobbyScreen user={user} onHome={() => navigate('/')} onLogout={() => { setUser(null); navigate('/') }} />

  return <>
    <AnimatePresence>{!ageGroup && <AgeGate onSelect={selectAge} />}</AnimatePresence>
    <div className="grain" />
    <header>
      <a className="brand" href="/" onClick={(event) => { event.preventDefault(); navigate('/') }} aria-label="КупиМісто, на головну"><Mark /><span>Купи<span>Місто</span></span></a>
      <nav aria-label="Головна навігація"><a href="#rules">Як грати</a><a href="#mood">Настрій</a><a href="#about">Про гру</a></nav>
      <button className="sound" onClick={toggleSound} aria-label={sound ? 'Вимкнути звук' : 'Увімкнути звук'}>{sound ? <Volume2 /> : <VolumeX />}<span>{sound ? 'Звук є' : 'Без звуку'}</span></button>
    </header>

    <main id="top">
      <section className="hero">
        <motion.div className="heroCopy" initial="hidden" animate="visible" variants={reveal}>
          <p className="eyebrow"><span /> Українська онлайн-гра</p>
          <h1>Купуй.<br/>Будуй.<br/><em>Керуй.</em></h1>
          <p className="lead">{profile.lead}</p>
          <div className="heroActions">
            <button className="primary" onClick={openGame}>{buttonState}<ArrowUpRight /></button>
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

      <div className="ticker" aria-hidden="true"><div>{[...profile.ticker, ...profile.ticker].map((item, index) => <span className="tickerItem" key={`${item}-${index}`}><b>{item}</b><i /></span>)}</div></div>

      <section className="mood" id="mood">
        <motion.div className="moodIntro" initial="hidden" whileInView="visible" viewport={{ once: true, amount: .3 }} variants={reveal}>
          <span className="sectionNo">01</span><h2>Меми тут не декор. Це валюта настрою.</h2>
        </motion.div>
        <motion.div className="poster" initial={{ opacity: 0, rotate: 0, y: 40 }} whileInView={{ opacity: 1, rotate: 2.3, y: 0 }} viewport={{ once: true }} transition={{ duration: .8, ease: [0.16, 1, 0.3, 1] }}>
          <div className="dogIllustration" aria-hidden="true"><svg viewBox="0 0 360 260"><path className="dogBody" d="M81 147c18-45 58-68 108-64 42 3 77 27 94 63l32 4-8 26-33 5c-10 36-42 57-88 57-58 0-98-30-105-91Z"/><path className="dogHead" d="M74 51c36 0 65 29 65 65s-29 65-65 65-57-30-57-66c0-25 10-46 31-57l-9-36 35 29Z"/><path className="dogEar" d="m82 49 53-27-13 63Z"/><circle cx="86" cy="97" r="8"/><path className="dogNose" d="m34 117 22-9 3 18Z"/><path className="dogLeg" d="M133 213v38M237 210v41"/><path className="collar" d="M35 146c25 12 57 12 83-4"/></svg></div>
          <p>{profile.quote}</p><strong>{profile.answer}</strong>
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

      <section className="finalCta" id="about"><p>Дружба пройшла багато.</p><h2>Час перевірити її орендою.</h2><button className="primary inverse" onClick={openGame}>{buttonState}<ArrowUpRight /></button></section>
    </main>

    <footer><a className="brand footBrand" href="#top"><Mark /><span>Купи<span>Місто</span></span></a><p>Зроблено в Україні. Без емодзі та нудних квадратів.</p><span>2026</span></footer>
  </>
}

export default App
