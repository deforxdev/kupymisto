package main

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"

	"golang.org/x/crypto/bcrypt"
)

type User struct {
	ID           string `json:"id"`
	Name         string `json:"name"`
	Email        string `json:"email"`
	PasswordHash []byte `json:"-"`
}
type Player struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Host  bool   `json:"host"`
	Ready bool   `json:"ready"`
}
type Room struct {
	Code       string    `json:"code"`
	Name       string    `json:"name"`
	MaxPlayers int       `json:"maxPlayers"`
	AgeGroup   string    `json:"ageGroup"`
	BoardSize  string    `json:"boardSize"`
	Players    []Player  `json:"players"`
	CreatedAt  time.Time `json:"createdAt"`
}
type Store struct {
	mu       sync.RWMutex
	users    map[string]User
	sessions map[string]string
	rooms    map[string]*Room
}

type contextKey string

const userKey contextKey = "user"

var emailPattern = regexp.MustCompile(`^[^\s@]+@[^\s@]+\.[^\s@]+$`)
var codeAlphabet = []byte("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

func randomString(size int, alphabet []byte) string {
	b := make([]byte, size)
	raw := make([]byte, size)
	if _, err := rand.Read(raw); err != nil {
		panic(err)
	}
	for i := range b {
		b[i] = alphabet[int(raw[i])%len(alphabet)]
	}
	return string(b)
}
func token() string {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return base64.RawURLEncoding.EncodeToString(b)
}
func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
func readJSON(r *http.Request, value any) error {
	dec := json.NewDecoder(http.MaxBytesReader(nil, r.Body, 1<<20))
	dec.DisallowUnknownFields()
	return dec.Decode(value)
}
func fail(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}

func main() {
	store := &Store{users: map[string]User{}, sessions: map[string]string{}, rooms: map[string]*Room{}}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, _ *http.Request) { writeJSON(w, 200, map[string]string{"status": "ok"}) })

	mux.HandleFunc("POST /api/auth/register", func(w http.ResponseWriter, r *http.Request) {
		var in struct {
			Name     string `json:"name"`
			Email    string `json:"email"`
			Password string `json:"password"`
		}
		if readJSON(r, &in) != nil {
			fail(w, 400, "Перевір введені дані")
			return
		}
		in.Name = strings.TrimSpace(in.Name)
		in.Email = strings.ToLower(strings.TrimSpace(in.Email))
		if len([]rune(in.Name)) < 2 || len([]rune(in.Name)) > 30 {
			fail(w, 400, "Ім’я має містити від 2 до 30 символів")
			return
		}
		if !emailPattern.MatchString(in.Email) {
			fail(w, 400, "Вкажи правильний email")
			return
		}
		if len(in.Password) < 8 {
			fail(w, 400, "Пароль має містити щонайменше 8 символів")
			return
		}
		hash, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcrypt.DefaultCost)
		if err != nil {
			fail(w, 500, "Не вдалося створити акаунт")
			return
		}
		store.mu.Lock()
		defer store.mu.Unlock()
		if _, exists := store.users[in.Email]; exists {
			fail(w, 409, "Акаунт із таким email уже існує")
			return
		}
		user := User{ID: randomString(12, codeAlphabet), Name: in.Name, Email: in.Email, PasswordHash: hash}
		store.users[in.Email] = user
		session := token()
		store.sessions[session] = user.ID
		writeJSON(w, 201, map[string]any{"token": session, "user": user})
	})
	mux.HandleFunc("POST /api/auth/login", func(w http.ResponseWriter, r *http.Request) {
		var in struct {
			Email    string `json:"email"`
			Password string `json:"password"`
		}
		if readJSON(r, &in) != nil {
			fail(w, 400, "Перевір введені дані")
			return
		}
		email := strings.ToLower(strings.TrimSpace(in.Email))
		store.mu.RLock()
		user, ok := store.users[email]
		store.mu.RUnlock()
		if !ok || bcrypt.CompareHashAndPassword(user.PasswordHash, []byte(in.Password)) != nil {
			fail(w, 401, "Неправильний email або пароль")
			return
		}
		session := token()
		store.mu.Lock()
		store.sessions[session] = user.ID
		store.mu.Unlock()
		writeJSON(w, 200, map[string]any{"token": session, "user": user})
	})

	protected := http.NewServeMux()
	protected.HandleFunc("GET /api/auth/me", func(w http.ResponseWriter, r *http.Request) { writeJSON(w, 200, map[string]any{"user": mustUser(r)}) })
	protected.HandleFunc("POST /api/rooms", func(w http.ResponseWriter, r *http.Request) {
		var in struct {
			Name       string `json:"name"`
			MaxPlayers int    `json:"maxPlayers"`
		}
		if readJSON(r, &in) != nil {
			fail(w, 400, "Перевір налаштування кімнати")
			return
		}
		in.Name = strings.TrimSpace(in.Name)
		if len([]rune(in.Name)) < 3 || len([]rune(in.Name)) > 40 || in.MaxPlayers < 2 || in.MaxPlayers > 6 {
			fail(w, 400, "Некоректні налаштування кімнати")
			return
		}
		user := mustUser(r)
		store.mu.Lock()
		defer store.mu.Unlock()
		code := ""
		for {
			code = randomString(8, codeAlphabet)
			if _, exists := store.rooms[code]; !exists {
				break
			}
		}
		room := &Room{Code: code, Name: in.Name, MaxPlayers: in.MaxPlayers, AgeGroup: "14-15", BoardSize: "standard", Players: []Player{{ID: user.ID, Name: user.Name, Host: true}}, CreatedAt: time.Now()}
		store.rooms[code] = room
		writeJSON(w, 201, map[string]any{"room": room})
	})
	protected.HandleFunc("PATCH /api/rooms/{code}/settings", func(w http.ResponseWriter, r *http.Request) {
		var in struct {
			AgeGroup  string `json:"ageGroup"`
			BoardSize string `json:"boardSize"`
		}
		if readJSON(r, &in) != nil || !validAgeGroup(in.AgeGroup) || (in.BoardSize != "standard" && in.BoardSize != "large") {
			fail(w, 400, "Некоректні налаштування гри")
			return
		}
		code := strings.ToUpper(r.PathValue("code"))
		user := mustUser(r)
		store.mu.Lock()
		defer store.mu.Unlock()
		room, ok := store.rooms[code]
		if !ok {
			fail(w, 404, "Кімнату не знайдено")
			return
		}
		hostID := ""
		for _, player := range room.Players {
			if player.Host {
				hostID = player.ID
				break
			}
		}
		if hostID == "" || hostID != user.ID {
			fail(w, 403, "Налаштування змінює власник кімнати")
			return
		}
		room.AgeGroup = in.AgeGroup
		room.BoardSize = in.BoardSize
		writeJSON(w, 200, map[string]any{"room": room})
	})
	protected.HandleFunc("POST /api/rooms/{code}/join", func(w http.ResponseWriter, r *http.Request) {
		code := strings.ToUpper(r.PathValue("code"))
		user := mustUser(r)
		store.mu.Lock()
		defer store.mu.Unlock()
		room, ok := store.rooms[code]
		if !ok {
			fail(w, 404, "Кімнату з таким кодом не знайдено")
			return
		}
		for _, p := range room.Players {
			if p.ID == user.ID {
				writeJSON(w, 200, map[string]any{"room": room})
				return
			}
		}
		if len(room.Players) >= room.MaxPlayers {
			fail(w, 409, "У кімнаті вже немає місць")
			return
		}
		room.Players = append(room.Players, Player{ID: user.ID, Name: user.Name})
		writeJSON(w, 200, map[string]any{"room": room})
	})
	protected.HandleFunc("GET /api/rooms/{code}", func(w http.ResponseWriter, r *http.Request) {
		code := strings.ToUpper(r.PathValue("code"))
		user := mustUser(r)
		store.mu.RLock()
		defer store.mu.RUnlock()
		room, ok := store.rooms[code]
		if !ok || !containsPlayer(room, user.ID) {
			fail(w, 404, "Кімнату не знайдено")
			return
		}
		writeJSON(w, 200, map[string]any{"room": room})
	})
	protected.HandleFunc("POST /api/rooms/{code}/ready", func(w http.ResponseWriter, r *http.Request) {
		code := strings.ToUpper(r.PathValue("code"))
		user := mustUser(r)
		store.mu.Lock()
		defer store.mu.Unlock()
		room, ok := store.rooms[code]
		if !ok {
			fail(w, 404, "Кімнату не знайдено")
			return
		}
		for i := range room.Players {
			if room.Players[i].ID == user.ID {
				room.Players[i].Ready = !room.Players[i].Ready
				writeJSON(w, 200, map[string]any{"room": room})
				return
			}
		}
		fail(w, 403, "Спочатку увійди в кімнату")
	})
	protected.HandleFunc("POST /api/rooms/{code}/leave", func(w http.ResponseWriter, r *http.Request) {
		code := strings.ToUpper(r.PathValue("code"))
		user := mustUser(r)
		store.mu.Lock()
		defer store.mu.Unlock()
		room, ok := store.rooms[code]
		if !ok {
			writeJSON(w, 200, map[string]bool{"ok": true})
			return
		}
		next := room.Players[:0]
		wasHost := false
		for _, p := range room.Players {
			if p.ID == user.ID {
				wasHost = p.Host
				continue
			}
			next = append(next, p)
		}
		room.Players = next
		if len(room.Players) == 0 {
			delete(store.rooms, code)
		} else if wasHost {
			room.Players[0].Host = true
		}
		writeJSON(w, 200, map[string]bool{"ok": true})
	})

	mux.Handle("/api/auth/me", auth(store, protected))
	mux.Handle("/api/rooms", auth(store, protected))
	mux.Handle("/api/rooms/", auth(store, protected))
	server := &http.Server{Addr: ":8080", Handler: securityHeaders(mux), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 10 * time.Second, WriteTimeout: 10 * time.Second, IdleTimeout: 60 * time.Second}
	log.Println("Kupymisto API listening on :8080")
	log.Fatal(server.ListenAndServe())
}

func validAgeGroup(value string) bool {
	return value == "10-12" || value == "14-15" || value == "18-20"
}
func containsPlayer(room *Room, id string) bool {
	for _, p := range room.Players {
		if p.ID == id {
			return true
		}
	}
	return false
}
func mustUser(r *http.Request) User {
	user, ok := r.Context().Value(userKey).(User)
	if !ok {
		panic(errors.New("missing authenticated user"))
	}
	return user
}
func auth(store *Store, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			fail(w, 401, "Потрібно увійти в акаунт")
			return
		}
		session := strings.TrimPrefix(header, "Bearer ")
		store.mu.RLock()
		id, ok := store.sessions[session]
		var user User
		if ok {
			for _, candidate := range store.users {
				if candidate.ID == id {
					user = candidate
					break
				}
			}
		}
		store.mu.RUnlock()
		if !ok || user.ID == "" {
			fail(w, 401, "Сесія завершилась, увійди ще раз")
			return
		}
		next.ServeHTTP(w, contextWithUser(r, user))
	})
}
func contextWithUser(r *http.Request, user User) *http.Request {
	return r.WithContext(context.WithValue(r.Context(), userKey, user))
}
func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Referrer-Policy", "no-referrer")
		next.ServeHTTP(w, r)
	})
}
