export type User = { id: string; name: string; email: string }
export type Player = { id: string; name: string; host: boolean; ready: boolean }
export type AgeGroup = '10-12' | '14-15' | '18-20'
export type Room = { code: string; name: string; maxPlayers: number; ageGroup: AgeGroup; players: Player[]; createdAt: string }

type ApiError = { error?: string }

const TOKEN_KEY = 'kupymisto_token'
export const getToken = () => localStorage.getItem(TOKEN_KEY)
export const setToken = (token: string) => localStorage.setItem(TOKEN_KEY, token)
export const clearToken = () => localStorage.removeItem(TOKEN_KEY)

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = getToken()
  const response = await fetch(path, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...init.headers,
    },
  })
  const data = await response.json().catch(() => ({})) as T & ApiError
  if (!response.ok) throw new Error(data.error || 'Щось пішло не так')
  return data
}

export const api = {
  register: (body: { name: string; email: string; password: string }) => request<{ token: string; user: User }>('/api/auth/register', { method: 'POST', body: JSON.stringify(body) }),
  login: (body: { email: string; password: string }) => request<{ token: string; user: User }>('/api/auth/login', { method: 'POST', body: JSON.stringify(body) }),
  me: () => request<{ user: User }>('/api/auth/me'),
  createRoom: (body: { name: string; maxPlayers: number; ageGroup: AgeGroup }) => request<{ room: Room }>('/api/rooms', { method: 'POST', body: JSON.stringify(body) }),
  joinRoom: (code: string) => request<{ room: Room }>(`/api/rooms/${code}/join`, { method: 'POST' }),
  getRoom: (code: string) => request<{ room: Room }>(`/api/rooms/${code}`),
  toggleReady: (code: string) => request<{ room: Room }>(`/api/rooms/${code}/ready`, { method: 'POST' }),
  leaveRoom: (code: string) => request<{ ok: boolean }>(`/api/rooms/${code}/leave`, { method: 'POST' }),
}
