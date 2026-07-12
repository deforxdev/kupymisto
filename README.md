# КупиМісто

Анімована головна сторінка української онлайн-гри.

## Стек

- React + Vite + TypeScript
- React Three Fiber + Drei
- Framer Motion
- Go API

## Запуск

Frontend:

```bash
cd frontend
npm install
npm run dev
```

Backend:

```bash
cd backend
go run ./cmd/api
```

Supabase:

1. Copy `.env.example` to `.env` and set `DATABASE_URL` to the Supabase Postgres connection string.
2. Run the migration in `supabase/migrations/20260713000000_create_app_state.sql` in the Supabase SQL Editor.
3. Start the backend. It loads and persists users, sessions, and rooms through the private `app_state` table.

The real `.env` is ignored by Git. Never commit database passwords or service-role keys.

Frontend: http://localhost:5173
API healthcheck: http://localhost:8080/api/health
