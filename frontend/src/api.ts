export type User = { id: string; name: string; email: string }
export type Player = { id: string; name: string; host: boolean; ready: boolean }
export type AgeGroup = '10-12' | '14-15' | '18-20'
export type BoardSize = 'standard' | 'large'
export type SharedChance = { id:string; title:string; text:string; amount:number; art:'owl'|'bus'|'rich'|'fire'; deck?:'chance'|'bad'; nonce:number; drawnBy:string }
export type Trade={id:string;from:string;to:string;giveCell:number;wantCell:number;giveMoney:number;wantMoney:number;status:'pending'|'accepted'|'rejected';expiresAt:string}
export type Room = { code: string; name: string; maxPlayers: number; ageGroup: AgeGroup; boardSize: BoardSize; ownership: Record<string,string>; balances:Record<string,number>; trades:Trade[]; turnSeconds:number; decisionSeconds:number; houses: Record<string,number>; currentChance?: SharedChance; chanceAcknowledged?: string[]; players: Player[]; started: boolean; positions: number[]; dice: [number, number]; turn: number; createdAt: string }

type ApiError = { error?: string }

const TOKEN_KEY = 'kupymisto_token'
const ACTIVE_ROOM_KEY = 'kupymisto_active_room'
const API_BASE_URL = (import.meta.env.VITE_API_URL ?? '').replace(/\/$/, '')
export const getToken = () => localStorage.getItem(TOKEN_KEY)
export const setToken = (token: string) => localStorage.setItem(TOKEN_KEY, token)
export const clearToken = () => localStorage.removeItem(TOKEN_KEY)
export const getActiveRoomCode = () => localStorage.getItem(ACTIVE_ROOM_KEY)
export const setActiveRoomCode = (code: string) => localStorage.setItem(ACTIVE_ROOM_KEY, code)
export const clearActiveRoomCode = () => localStorage.removeItem(ACTIVE_ROOM_KEY)

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = getToken()
  const response = await fetch(`${API_BASE_URL}${path}`, {
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
  createRoom: (body: { name: string; maxPlayers: number }) => request<{ room: Room }>('/api/rooms', { method: 'POST', body: JSON.stringify(body) }),
  updateRoom: (code: string, body: { boardSize: BoardSize; turnSeconds:number; decisionSeconds:number }) => request<{ room: Room }>(`/api/rooms/${code}/settings`, { method: 'PATCH', body: JSON.stringify(body) }),
  joinRoom: (code: string) => request<{ room: Room }>(`/api/rooms/${code}/join`, { method: 'POST' }),
  getRoom: (code: string) => request<{ room: Room }>(`/api/rooms/${code}`),
  createTrade:(code:string,body:{to:string;giveCell:number;wantCell:number;giveMoney:number;wantMoney:number})=>request<{room:Room}>(`/api/rooms/${code}/trades`,{method:'POST',body:JSON.stringify(body)}),
  answerTrade:(code:string,id:string,accept:boolean)=>request<{room:Room}>(`/api/rooms/${code}/trades/${id}`,{method:'PATCH',body:JSON.stringify({accept})}),
  drawBadLuck: (code:string) => request<{ room:Room }>(`/api/rooms/${code}/bad-luck`, { method:'POST' }),
  drawChance: (code:string) => request<{ room:Room }>(`/api/rooms/${code}/chance`, { method:'POST' }),
  clearChance: (code:string) => request<{ room:Room }>(`/api/rooms/${code}/chance`, { method:'DELETE' }),
  buildHouse: (code:string, body:{ cellIndex:number }) => request<{ room:Room }>(`/api/rooms/${code}/houses`, { method:'POST', body:JSON.stringify(body) }),
  purchaseProperty: (code: string, body: { cellIndex:number; price:number }) => request<{ room: Room }>(`/api/rooms/${code}/properties`, { method: 'POST', body: JSON.stringify(body) }),
  toggleReady: (code: string) => request<{ room: Room }>(`/api/rooms/${code}/ready`, { method: 'POST' }),
  startRoom: (code: string) => request<{ room: Room }>(`/api/rooms/${code}/start`, { method: 'POST' }),
  roll: (code: string) => request<{ room: Room }>(`/api/rooms/${code}/roll`, { method: 'POST' }),
  finishTurn: (code: string) => request<{ room: Room }>(`/api/rooms/${code}/finish-turn`, { method: 'POST' }),
  leaveRoom: (code: string) => request<{ ok: boolean }>(`/api/rooms/${code}/leave`, { method: 'POST' }),
}
