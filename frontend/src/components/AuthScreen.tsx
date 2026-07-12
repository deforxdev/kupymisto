import { useState, type FormEvent } from 'react'
import { motion } from 'framer-motion'
import { ArrowUpRight, Eye, EyeOff, LockKeyhole } from 'lucide-react'
import { api, setToken, type User } from '../api'
import { playUiSound } from '../audio'

type Props = { onSuccess: (user: User) => void; onBack: () => void }

export default function AuthScreen({ onSuccess, onBack }: Props) {
  const [mode, setMode] = useState<'login' | 'register'>('register')
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  async function submit(event: FormEvent) {
    event.preventDefault()
    setError('')
    setLoading(true)
    try {
      const result = mode === 'register'
        ? await api.register({ name: name.trim(), email: email.trim(), password })
        : await api.login({ email: email.trim(), password })
      setToken(result.token)
      playUiSound('success')
      onSuccess(result.user)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Не вдалося продовжити')
    } finally { setLoading(false) }
  }

  const changeMode = (next: 'login' | 'register') => {
    setMode(next); setError(''); playUiSound('select')
  }

  return <main className="authScreen">
    <button className="backLink" onClick={onBack}>Назад на головну</button>
    <motion.section className="authPanel" initial={{ opacity: 0, y: 28 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: .65, ease: [0.16, 1, 0.3, 1] }}>
      <div className="authArt" aria-hidden="true">
        <LockKeyhole />
        <p>Свої люди.<br/>Свої правила.<br/><span>Своє місто.</span></p>
        <div className="authBlock blockOne"/><div className="authBlock blockTwo"/><div className="authBlock blockThree"/>
      </div>
      <div className="authFormWrap">
        <div className="authTabs" role="tablist">
          <button className={mode === 'register' ? 'active' : ''} onClick={() => changeMode('register')}>Реєстрація</button>
          <button className={mode === 'login' ? 'active' : ''} onClick={() => changeMode('login')}>Вхід</button>
        </div>
        <h1>{mode === 'register' ? 'Створи акаунт' : 'З поверненням'}</h1>
        <p>{mode === 'register' ? 'Один акаунт для кімнат, друзів і майбутніх перемог.' : 'Твоє місто нікуди не поділося.'}</p>
        <form onSubmit={submit}>
          {mode === 'register' && <label>Ім’я<input value={name} onChange={e => setName(e.target.value)} autoComplete="name" minLength={2} maxLength={30} required placeholder="Як тебе називати у грі" /></label>}
          <label>Email<input type="email" value={email} onChange={e => setEmail(e.target.value)} autoComplete="email" required placeholder="you@example.com" /></label>
          <label>Пароль<span className="passwordField"><input type={showPassword ? 'text' : 'password'} value={password} onChange={e => setPassword(e.target.value)} autoComplete={mode === 'register' ? 'new-password' : 'current-password'} minLength={8} required placeholder="Мінімум 8 символів"/><button type="button" onClick={() => setShowPassword(!showPassword)} aria-label={showPassword ? 'Сховати пароль' : 'Показати пароль'}>{showPassword ? <EyeOff/> : <Eye/>}</button></span></label>
          {error && <p className="formError" role="alert">{error}</p>}
          <button className="primary authSubmit" disabled={loading}>{loading ? 'Зачекай...' : mode === 'register' ? 'Створити акаунт' : 'Увійти'}<ArrowUpRight /></button>
        </form>
      </div>
    </motion.section>
  </main>
}
