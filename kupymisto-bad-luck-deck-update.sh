#!/usr/bin/env bash
set -euo pipefail

if [ ! -f frontend/src/components/ClassicBoard3D.tsx ] || [ ! -f frontend/src/components/GameScreen.tsx ] || [ ! -f backend/cmd/api/main.go ]; then
  echo "Запусти файл у корені kupymisto після попередніх оновлень."
  exit 1
fi

python3 <<'PY'
from pathlib import Path

# Rename tax cells to a separate bad-luck deck.
p=Path('frontend/src/components/ClassicBoard3D.tsx')
s=p.read_text(encoding='utf-8').replace("return{name:'РЕМОНТ ДОРІГ',kind:'tax'", "return{name:'ХАЛЕПА',kind:'tax'")
p.write_text(s, encoding='utf-8')

# Add a dedicated synchronized bad-card endpoint.
p=Path('frontend/src/api.ts')
s=p.read_text(encoding='utf-8')
s=s.replace("  drawChance:", "  drawBadLuck: (code:string) => request<{ room:Room }>(`/api/rooms/${code}/bad-luck`, { method:'POST' }),\n  drawChance:")
p.write_text(s, encoding='utf-8')

# Frontend: landing on HALЕПА requires manually drawing an always-negative card.
p=Path('frontend/src/components/GameScreen.tsx')
s=p.read_text(encoding='utf-8')
s=s.replace("  const [chancePending,setChancePending] = useState(false)", "  const [chancePending,setChancePending] = useState(false)\n  const [badLuckPending,setBadLuckPending] = useState(false)")

# Add manual bad-card draw next to normal chance draw.
marker="  const selected=cells[selectedCell]\n"
function='''  const drawBadLuck=async()=>{
    if(!badLuckPending)return
    await unlockAudio()
    setBadLuckPending(false)
    const {room:nextRoom}=await api.drawBadLuck(room.code)
    setLiveRoom(nextRoom)
    if(nextRoom.currentChance){
      setDrawNonce(nextRoom.currentChance.nonce)
      window.setTimeout(()=>{
        setChanceEvent(nextRoom.currentChance||null)
        setBalance(value=>value+(nextRoom.currentChance?.amount||0))
      },1100)
    }
  }

'''
if marker not in s: raise SystemExit('Не знайдено selected')
s=s.replace(marker,function+marker)

# Replace fixed road charge with manual bad card.
old="""            if (landed.name==='РЕМОНТ ДОРІГ') {
              setBalance(value=>value-100)
              setMeme('Ремонт доріг: міський бюджет просить 100 ₴. Баланс може піти в мінус.')
              window.setTimeout(()=>setMeme(''),2800)
            }"""
new="""            if (landed.name==='ХАЛЕПА') {
              setBadLuckPending(true)
              setPhase('decision')
            }"""
if old not in s: raise SystemExit('Не знайдено старий штраф ремонту доріг')
s=s.replace(old,new)

# Keep turn open on both card cells.
s=s.replace("if(landed.kind!=='chance')finishTurn()", "if(landed.kind!=='chance'&&landed.kind!=='tax')finishTurn()")

# Add bad deck prompt with distinct visual treatment.
needle="""      <AnimatePresence>{chancePending&&<motion.div className="chanceDrawPrompt""" 
insert="""      <AnimatePresence>{badLuckPending&&<motion.div className="chanceDrawPrompt badLuckPrompt" initial={{opacity:0,y:18,scale:.92}} animate={{opacity:1,y:0,scale:1}} exit={{opacity:0,y:-14}}><small>ТИ СТАВ НА «ХАЛЕПУ»</small><strong>Витягни погану картку</strong><p>У цій колоді бонусів немає.</p><button onClick={drawBadLuck}>Дізнатися, що сталося</button></motion.div>}</AnimatePresence>
"""
if needle not in s: raise SystemExit('Не знайдено prompt шансу')
s=s.replace(needle,insert+needle)

# Panel label for tax cells.
s=s.replace("selected.kind==='tax'?'МІСЬКИЙ ЗБІР'", "selected.kind==='tax'?'КОЛОДА ХАЛЕПИ'")
p.write_text(s, encoding='utf-8')

# Backend: all cards in this endpoint are negative and synced through CurrentChance.
p=Path('backend/cmd/api/main.go')
s=p.read_text(encoding='utf-8')
route='''    protected.HandleFunc("POST /api/rooms/{code}/bad-luck",func(w http.ResponseWriter,r *http.Request){
        code:=strings.ToUpper(r.PathValue("code"));user:=mustUser(r)
        store.mu.Lock();defer store.mu.Unlock()
        room,ok:=store.rooms[code]
        if !ok||!containsPlayer(room,user.ID){fail(w,404,"Кімнату не знайдено");return}
        deck:=[]ChanceCard{
            {ID:"coffee-flood",Title:"Кава пішла не туди",Text:"Лате вирішило стати частиною ноутбука. Ремонт техніки коштує грошей.",Amount:-140,Art:"fire"},
            {ID:"bus-fine",Title:"Бус приїхав без тебе",Text:"Довелося брати таксі через усе місто. Списуємо дорожні витрати.",Amount:-90,Art:"bus"},
            {ID:"rich-audit",Title:"Із багатої, але є нюанс",Text:"Банк попросив пояснити походження мемних доходів. Комісія вже списана.",Amount:-120,Art:"rich"},
            {ID:"owl-night",Title:"Сова не спала",Text:"Нічна руханка сусідів закінчилася штрафом за шум.",Amount:-70,Art:"owl"},
            {ID:"roads",Title:"Асфальт зійшов разом зі снігом",Text:"Район скидається на терміновий ремонт дороги.",Amount:-110,Art:"fire"},
        }
        card:=deck[time.Now().UnixNano()%int64(len(deck))]
        card.Nonce=time.Now().UnixNano();card.DrawnBy=user.ID
        room.CurrentChance=&card
        writeJSON(w,200,map[string]any{"room":room})
    })
'''
anchor='    protected.HandleFunc("POST /api/rooms/{code}/chance"'
if anchor not in s: raise SystemExit('Не знайдено endpoint шансу')
s=s.replace(anchor,route+anchor)
p.write_text(s, encoding='utf-8')
PY

cat >> frontend/src/styles.css <<'EOF'
/* Separate bad-luck deck */
.badLuckPrompt{background:oklch(63% .2 28);color:var(--paper)}.badLuckPrompt p{font-size:11px;font-weight:800}.badLuckPrompt button{background:var(--ink);color:var(--paper)}.chanceCard.fire{background:oklch(82% .075 28)}
EOF

(cd backend && gofmt -w cmd/api/main.go && go test ./...)
npm --prefix frontend run build

git add frontend/src/api.ts frontend/src/components/ClassicBoard3D.tsx frontend/src/components/GameScreen.tsx frontend/src/styles.css backend/cmd/api/main.go
git commit -m "feat: replace road tax with synchronized bad-luck deck" || true
git push || echo "Виконай git push вручну"

echo "Готово. Перезапусти: docker compose down && docker compose up --build"
