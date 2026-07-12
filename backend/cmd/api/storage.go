package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
)

const stateKey = "kupymisto"

type persistedState struct {
	Users    map[string]User   `json:"users"`
	Sessions map[string]string `json:"sessions"`
	Rooms    map[string]*Room  `json:"rooms"`
}

func newStore(ctx context.Context) (*Store, error) {
	_ = godotenv.Load(".env")
	_ = godotenv.Load("../.env")
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	store := &Store{
		users:    map[string]User{},
		sessions: map[string]string{},
		rooms:    map[string]*Room{},
	}
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Println("DATABASE_URL is not set; using in-memory storage")
		return store, nil
	}

	poolConfig, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse DATABASE_URL: %w", err)
	}
	poolConfig.MaxConns = 5
	poolConfig.MinConns = 1
	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		return nil, fmt.Errorf("connect Supabase Postgres: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping Supabase Postgres: %w", err)
	}
	store.db = pool
	if _, err := pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS app_state (
			key text PRIMARY KEY,
			value jsonb NOT NULL,
			updated_at timestamptz NOT NULL DEFAULT now()
		)
	`); err != nil {
		pool.Close()
		return nil, fmt.Errorf("create app_state table: %w", err)
	}
	var raw []byte
	err = pool.QueryRow(ctx, `SELECT value FROM app_state WHERE key = $1`, stateKey).Scan(&raw)
	if err == nil {
		var state persistedState
		if unmarshalErr := json.Unmarshal(raw, &state); unmarshalErr != nil {
			pool.Close()
			return nil, fmt.Errorf("decode persisted game state: %w", unmarshalErr)
		}
		store.users = state.Users
		store.sessions = state.Sessions
		store.rooms = state.Rooms
		if store.users == nil {
			store.users = map[string]User{}
		}
		if store.sessions == nil {
			store.sessions = map[string]string{}
		}
		if store.rooms == nil {
			store.rooms = map[string]*Room{}
		}
		for _, room := range store.rooms {
			if room != nil && room.TurnDeadline.IsZero() {
				room.TurnDeadline = time.Now().Add(time.Duration(max(room.TurnSeconds, 60)) * time.Second)
			}
		}
		log.Println("Loaded Kupymisto state from Supabase")
	} else if !errors.Is(err, pgx.ErrNoRows) {
		pool.Close()
		return nil, fmt.Errorf("load persisted game state: %w", err)
	}
	return store, nil
}

func (s *Store) close() {
	if s.db != nil {
		s.db.Close()
	}
}

func (s *Store) persist(ctx context.Context) error {
	if s.db == nil {
		return nil
	}
	s.mu.RLock()
	state := persistedState{Users: s.users, Sessions: s.sessions, Rooms: s.rooms}
	raw, err := json.Marshal(state)
	s.mu.RUnlock()
	if err != nil {
		return fmt.Errorf("encode game state: %w", err)
	}
	_, err = s.db.Exec(ctx, `
		INSERT INTO app_state (key, value, updated_at)
		VALUES ($1, $2::jsonb, now())
		ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()
	`, stateKey, raw)
	if err != nil {
		return fmt.Errorf("persist game state: %w", err)
	}
	return nil
}

func persisting(store *Store, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		next.ServeHTTP(w, r)
		if err := store.persist(r.Context()); err != nil {
			log.Printf("Supabase persistence failed: %v", err)
		}
	})
}
