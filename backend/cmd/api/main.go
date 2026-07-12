package main

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"log"
	mathrand "math/rand"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
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
type ChanceCard struct {
	ID      string `json:"id"`
	Title   string `json:"title"`
	Text    string `json:"text"`
	Amount  int    `json:"amount"`
	Art     string `json:"art"`
	Nonce   int64  `json:"nonce"`
	DrawnBy string `json:"drawnBy"`
}
type Trade struct {
	ID        string    `json:"id"`
	From      string    `json:"from"`
	To        string    `json:"to"`
	GiveCell  int       `json:"giveCell"`
	WantCell  int       `json:"wantCell"`
	GiveMoney int       `json:"giveMoney"`
	WantMoney int       `json:"wantMoney"`
	Status    string    `json:"status"`
	ExpiresAt time.Time `json:"expiresAt"`
}
type Room struct {
	Code            string            `json:"code"`
	Name            string            `json:"name"`
	MaxPlayers      int               `json:"maxPlayers"`
	AgeGroup        string            `json:"ageGroup"`
	BoardSize       string            `json:"boardSize"`
	Ownership       map[string]string `json:"ownership"`
	Balances        map[string]int    `json:"balances"`
	Trades          []Trade           `json:"trades"`
	TurnSeconds     int               `json:"turnSeconds"`
	DecisionSeconds int               `json:"decisionSeconds"`
	Houses          map[string]int    `json:"houses"`
	CurrentChance   *ChanceCard       `json:"currentChance,omitempty"`
	Players         []Player          `json:"players"`
	Started         bool              `json:"started"`
	Positions       []int             `json:"positions"`
	Dice            [2]int            `json:"dice"`
	Turn            int               `json:"turn"`
	CreatedAt       time.Time         `json:"createdAt"`
}
type Store struct {
	mu       sync.RWMutex
	users    map[string]User
	sessions map[string]string
	rooms    map[string]*Room
	db       *pgxpool.Pool
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
	store, err := newStore(context.Background())
	if err != nil {
		log.Fatal(err)
	}
	defer store.close()
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
		room := &Room{Code: code, Name: in.Name, MaxPlayers: in.MaxPlayers, AgeGroup: "14-15", BoardSize: "standard", Ownership: map[string]string{}, Balances: map[string]int{user.ID: 1500}, Trades: []Trade{}, TurnSeconds: 60, DecisionSeconds: 45, Houses: map[string]int{}, Players: []Player{{ID: user.ID, Name: user.Name, Host: true}}, Positions: []int{0}, Dice: [2]int{1, 1}, CreatedAt: time.Now()}
		store.rooms[code] = room
		writeJSON(w, 201, map[string]any{"room": room})
	})
	protected.HandleFunc("PATCH /api/rooms/{code}/settings", func(w http.ResponseWriter, r *http.Request) {
		var in struct {
			BoardSize       string `json:"boardSize"`
			TurnSeconds     int    `json:"turnSeconds"`
			DecisionSeconds int    `json:"decisionSeconds"`
		}
		if readJSON(r, &in) != nil || (in.BoardSize != "standard" && in.BoardSize != "large") || in.TurnSeconds < 30 || in.TurnSeconds > 90 || in.DecisionSeconds < 20 || in.DecisionSeconds > 60 {
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
		room.BoardSize = in.BoardSize
		room.TurnSeconds = in.TurnSeconds
		room.DecisionSeconds = in.DecisionSeconds
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
		if room.Balances == nil {
			room.Balances = map[string]int{}
		}
		if _, ok := room.Balances[user.ID]; !ok {
			room.Balances[user.ID] = 1500
		}
		room.Positions = append(room.Positions, 0)
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
	protected.HandleFunc("POST /api/rooms/{code}/trades", func(w http.ResponseWriter, r *http.Request) {
		var in struct {
			To        string `json:"to"`
			GiveCell  int    `json:"giveCell"`
			WantCell  int    `json:"wantCell"`
			GiveMoney int    `json:"giveMoney"`
			WantMoney int    `json:"wantMoney"`
		}
		if readJSON(r, &in) != nil || in.GiveMoney < 0 || in.WantMoney < 0 {
			fail(w, 400, "Некоректна угода")
			return
		}
		code := strings.ToUpper(r.PathValue("code"))
		u := mustUser(r)
		store.mu.Lock()
		defer store.mu.Unlock()
		room, ok := store.rooms[code]
		if !ok || !containsPlayer(room, u.ID) {
			fail(w, 404, "Кімнату не знайдено")
			return
		}
		if room.Balances == nil {
			room.Balances = map[string]int{}
		}
		if in.GiveCell >= 0 && room.Ownership[strconv.Itoa(in.GiveCell)] != u.ID {
			fail(w, 403, "Ця клітинка не твоя")
			return
		}
		if in.WantCell >= 0 && room.Ownership[strconv.Itoa(in.WantCell)] != in.To {
			fail(w, 409, "Клітинка вже не належить гравцю")
			return
		}
		if room.Balances[u.ID] < in.GiveMoney {
			fail(w, 409, "Недостатньо коштів для пропозиції")
			return
		}
		trade := Trade{ID: randomString(10, codeAlphabet), From: u.ID, To: in.To, GiveCell: in.GiveCell, WantCell: in.WantCell, GiveMoney: in.GiveMoney, WantMoney: in.WantMoney, Status: "pending", ExpiresAt: time.Now().Add(time.Duration(max(room.DecisionSeconds, 20)) * time.Second)}
		room.Trades = append(room.Trades, trade)
		writeJSON(w, 201, map[string]any{"room": room})
	})
	protected.HandleFunc("PATCH /api/rooms/{code}/trades/{id}", func(w http.ResponseWriter, r *http.Request) {
		var in struct {
			Accept bool `json:"accept"`
		}
		if readJSON(r, &in) != nil {
			fail(w, 400, "Некоректна відповідь")
			return
		}
		code := strings.ToUpper(r.PathValue("code"))
		u := mustUser(r)
		store.mu.Lock()
		defer store.mu.Unlock()
		room, ok := store.rooms[code]
		if !ok {
			fail(w, 404, "Кімнату не знайдено")
			return
		}
		if room.Balances == nil {
			room.Balances = map[string]int{}
		}
		for i := range room.Trades {
			t := &room.Trades[i]
			if t.ID != r.PathValue("id") {
				continue
			}
			if t.To != u.ID || t.Status != "pending" {
				fail(w, 403, "Угода недоступна")
				return
			}
			if !in.Accept {
				t.Status = "rejected"
				writeJSON(w, 200, map[string]any{"room": room})
				return
			}
			if time.Now().After(t.ExpiresAt) || room.Balances[t.From] < t.GiveMoney || room.Balances[t.To] < t.WantMoney {
				t.Status = "rejected"
				fail(w, 409, "Угода прострочена або баланс змінився")
				return
			}
			if t.GiveCell >= 0 && room.Ownership[strconv.Itoa(t.GiveCell)] != t.From {
				fail(w, 409, "Власність змінилась")
				return
			}
			if t.WantCell >= 0 && room.Ownership[strconv.Itoa(t.WantCell)] != t.To {
				fail(w, 409, "Власність змінилась")
				return
			}
			room.Balances[t.From] += t.WantMoney - t.GiveMoney
			room.Balances[t.To] += t.GiveMoney - t.WantMoney
			if t.GiveCell >= 0 {
				room.Ownership[strconv.Itoa(t.GiveCell)] = t.To
			}
			if t.WantCell >= 0 {
				room.Ownership[strconv.Itoa(t.WantCell)] = t.From
			}
			t.Status = "accepted"
			writeJSON(w, 200, map[string]any{"room": room})
			return
		}
		fail(w, 404, "Угоду не знайдено")
	})
	protected.HandleFunc("POST /api/rooms/{code}/bad-luck", func(w http.ResponseWriter, r *http.Request) {
		code := strings.ToUpper(r.PathValue("code"))
		user := mustUser(r)
		store.mu.Lock()
		defer store.mu.Unlock()
		room, ok := store.rooms[code]
		if !ok || !containsPlayer(room, user.ID) {
			fail(w, 404, "Кімнату не знайдено")
			return
		}
		deck := loadDeck("bad")
		card := deck[time.Now().UnixNano()%int64(len(deck))]
		card.Nonce = time.Now().UnixNano()
		card.DrawnBy = user.ID
		if room.Balances == nil {
			room.Balances = map[string]int{}
		}
		room.CurrentChance = &card
		room.Balances[user.ID] += card.Amount
		writeJSON(w, 200, map[string]any{"room": room})
	})
	protected.HandleFunc("POST /api/rooms/{code}/chance", func(w http.ResponseWriter, r *http.Request) {
		code := strings.ToUpper(r.PathValue("code"))
		user := mustUser(r)
		store.mu.Lock()
		defer store.mu.Unlock()
		room, ok := store.rooms[code]
		if !ok || !containsPlayer(room, user.ID) {
			fail(w, 404, "Кімнату не знайдено")
			return
		}
		deck := loadDeck("chance")
		card := deck[time.Now().UnixNano()%int64(len(deck))]
		card.Nonce = time.Now().UnixNano()
		card.DrawnBy = user.ID
		if room.Balances == nil {
			room.Balances = map[string]int{}
		}
		room.CurrentChance = &card
		room.Balances[user.ID] += card.Amount
		writeJSON(w, 200, map[string]any{"room": room})
	})
	protected.HandleFunc("DELETE /api/rooms/{code}/chance", func(w http.ResponseWriter, r *http.Request) {
		code := strings.ToUpper(r.PathValue("code"))
		user := mustUser(r)
		store.mu.Lock()
		defer store.mu.Unlock()
		room, ok := store.rooms[code]
		if !ok || !containsPlayer(room, user.ID) {
			fail(w, 404, "Кімнату не знайдено")
			return
		}
		room.CurrentChance = nil
		writeJSON(w, 200, map[string]any{"room": room})
	})
	protected.HandleFunc("POST /api/rooms/{code}/houses", func(w http.ResponseWriter, r *http.Request) {
		var in struct {
			CellIndex int `json:"cellIndex"`
		}
		if readJSON(r, &in) != nil || in.CellIndex < 0 {
			fail(w, 400, "Некоректна клітинка")
			return
		}
		code := strings.ToUpper(r.PathValue("code"))
		user := mustUser(r)
		store.mu.Lock()
		defer store.mu.Unlock()
		room, ok := store.rooms[code]
		if !ok || !containsPlayer(room, user.ID) {
			fail(w, 404, "Кімнату не знайдено")
			return
		}
		if room.Ownership == nil {
			room.Ownership = map[string]string{}
		}
		if room.Houses == nil {
			room.Houses = map[string]int{}
		}
		key := strconv.Itoa(in.CellIndex)
		if room.Ownership[key] != user.ID {
			fail(w, 403, "Будувати може лише власник")
			return
		}
		if room.Houses[key] >= 3 {
			fail(w, 409, "На клітинці вже максимум будинків")
			return
		}
		if room.Balances == nil {
			room.Balances = map[string]int{}
		}
		if room.Balances[user.ID] < 100 {
			fail(w, 409, "Недостатньо коштів")
			return
		}
		room.Balances[user.ID] -= 100
		room.Houses[key]++
		writeJSON(w, 200, map[string]any{"room": room})
	})
	protected.HandleFunc("POST /api/rooms/{code}/properties", func(w http.ResponseWriter, r *http.Request) {
		var in struct {
			CellIndex int `json:"cellIndex"`
			Price     int `json:"price"`
		}
		if readJSON(r, &in) != nil || in.CellIndex < 0 || in.Price < 0 {
			fail(w, 400, "Некоректна власність")
			return
		}
		code := strings.ToUpper(r.PathValue("code"))
		user := mustUser(r)
		store.mu.Lock()
		defer store.mu.Unlock()
		room, ok := store.rooms[code]
		if !ok || !containsPlayer(room, user.ID) {
			fail(w, 404, "Кімнату не знайдено")
			return
		}
		if room.Ownership == nil {
			room.Ownership = map[string]string{}
		}
		key := strconv.Itoa(in.CellIndex)
		if _, exists := room.Ownership[key]; exists {
			fail(w, 409, "Ця клітинка вже має власника")
			return
		}
		if room.Balances == nil {
			room.Balances = map[string]int{}
		}
		if room.Balances[user.ID] < in.Price {
			fail(w, 409, "Недостатньо коштів")
			return
		}
		room.Balances[user.ID] -= in.Price
		room.Ownership[key] = user.ID
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
	protected.HandleFunc("POST /api/rooms/{code}/start", func(w http.ResponseWriter, r *http.Request) {
		code := strings.ToUpper(r.PathValue("code"))
		user := mustUser(r)
		store.mu.Lock()
		defer store.mu.Unlock()
		room, ok := store.rooms[code]
		if !ok {
			fail(w, 404, "Кімнату не знайдено")
			return
		}
		host := false
		allReady := len(room.Players) >= 2
		for _, player := range room.Players {
			if player.ID == user.ID && player.Host {
				host = true
			}
			if !player.Ready {
				allReady = false
			}
		}
		if !host {
			fail(w, 403, "Почати гру може лише власник кімнати")
			return
		}
		if !allReady {
			fail(w, 409, "Усі гравці мають бути готові")
			return
		}
		room.Started = true
		writeJSON(w, 200, map[string]any{"room": room})
	})
	protected.HandleFunc("POST /api/rooms/{code}/roll", func(w http.ResponseWriter, r *http.Request) {
		code := strings.ToUpper(r.PathValue("code"))
		user := mustUser(r)
		store.mu.Lock()
		defer store.mu.Unlock()
		room, ok := store.rooms[code]
		if !ok || !containsPlayer(room, user.ID) {
			fail(w, 404, "Кімнату не знайдено")
			return
		}
		if !room.Started || len(room.Players) == 0 || room.Players[room.Turn].ID != user.ID {
			fail(w, 409, "Зараз не твій хід")
			return
		}
		if len(room.Positions) != len(room.Players) {
			room.Positions = make([]int, len(room.Players))
		}
		boardCells := 40
		if room.BoardSize == "large" {
			boardCells = 56
		}
		a, b := mathrand.Intn(6)+1, mathrand.Intn(6)+1
		room.Dice = [2]int{a, b}
		previousPosition := room.Positions[room.Turn]
		if previousPosition+a+b >= boardCells {
			room.Balances[user.ID] += 200
		}
		room.Positions[room.Turn] = (previousPosition + a + b) % boardCells
		writeJSON(w, 200, map[string]any{"room": room})
	})
	protected.HandleFunc("POST /api/rooms/{code}/finish-turn", func(w http.ResponseWriter, r *http.Request) {
		code := strings.ToUpper(r.PathValue("code"))
		user := mustUser(r)
		store.mu.Lock()
		defer store.mu.Unlock()
		room, ok := store.rooms[code]
		if !ok || !containsPlayer(room, user.ID) {
			fail(w, 404, "Кімнату не знайдено")
			return
		}
		if len(room.Players) == 0 || room.Players[room.Turn].ID != user.ID {
			fail(w, 409, "Зараз не твій хід")
			return
		}
		room.Turn = (room.Turn + 1) % len(room.Players)
		writeJSON(w, 200, map[string]any{"room": room})
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
	server := &http.Server{Addr: ":8080", Handler: securityHeaders(cors(persisting(store, mux))), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 10 * time.Second, WriteTimeout: 10 * time.Second, IdleTimeout: 60 * time.Second}
	log.Println("Kupymisto API listening on :8080")
	log.Fatal(server.ListenAndServe())
}

func validAgeGroup(value string) bool {
	return value == "10-12" || value == "14-15" || value == "18-20"
}

type DeckConfig struct {
	Chance []ChanceCard `json:"chance"`
	Bad    []ChanceCard `json:"bad"`
}

func loadDeck(kind string) []ChanceCard {
	raw, err := os.ReadFile("data/decks.json")
	if err == nil {
		var cfg DeckConfig
		if json.Unmarshal(raw, &cfg) == nil {
			if kind == "bad" && len(cfg.Bad) > 0 {
				return cfg.Bad
			}
			if kind == "chance" && len(cfg.Chance) > 0 {
				return cfg.Chance
			}
		}
	}
	if kind == "bad" {
		return []ChanceCard{{ID: "fallback-bad", Title: "Халепа", Text: "Несподіваний штраф.", Amount: -100, Art: "fire"}}
	}
	return []ChanceCard{{ID: "fallback-good", Title: "Шанс", Text: "Міський бонус.", Amount: 100, Art: "rich"}, {ID: "fallback-bad", Title: "Невдалий шанс", Text: "Комісія банку.", Amount: -70, Art: "fire"}}
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

func cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		allowedOrigin := strings.TrimRight(os.Getenv("FRONTEND_URL"), "/")
		if allowedOrigin == "" {
			allowedOrigin = origin
		}
		if origin != "" && origin == allowedOrigin {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}
