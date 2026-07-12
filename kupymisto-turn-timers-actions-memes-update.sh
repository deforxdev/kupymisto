#!/usr/bin/env bash
set -euo pipefail

FILE="frontend/src/components/GameScreen.tsx"
if [ ! -f "$FILE" ]; then
  echo "Запусти файл у корені kupymisto після попередніх оновлень."
  exit 1
fi

python3 <<'PY'
from pathlib import Path
p=Path('frontend/src/components/GameScreen.tsx')
s=p.read_text(encoding='utf-8')

# Timer icon and remove obsolete center turn animation dependency.
s=s.replace("import { Building2, Check, Home, LogOut, Settings, Volume2, X } from 'lucide-react'", "import { Building2, Check, Clock3, Home, LogOut, Settings, Volume2, X } from 'lucide-react'")

# Add explicit turn phases and countdown.
s=s.replace("  const [cardOpen,setCardOpen] = useState(false)", """  const [cardOpen,setCardOpen] = useState(false)
  const [phase,setPhase] = useState<'roll'|'moving'|'decision'>('roll')
  const [timeLeft,setTimeLeft] = useState(30)
  const [meme,setMeme] = useState('')""")

# Replace old notice timer effect with phase countdown behavior.
insert_after="  const cells = useMemo(() => makeCells(room.boardSize),[room.boardSize])\n"
effect="""
  useEffect(() => {
    setTimeLeft(phase === 'decision' ? 15 : phase === 'roll' ? 30 : 0)
  }, [phase, turn])

  useEffect(() => {
    if (phase === 'moving' || timeLeft <= 0) return
    const timer = window.setTimeout(() => setTimeLeft(value => Math.max(0, value - 1)), 1000)
    return () => window.clearTimeout(timer)
  }, [phase, timeLeft])
"""
if insert_after not in s: raise SystemExit('Не знайдено список клітинок')
s=s.replace(insert_after,insert_after+effect)

# Add helper to complete turn and timeout reactions before roll function.
roll_marker="  const roll = async () => {"
helpers="""  const finishTurn = () => {
    setCardOpen(false)
    setPhase('roll')
    setTurn(value => (value + 1) % players.length)
  }

  useEffect(() => {
    if (timeLeft > 0) return
    if (phase === 'roll') {
      if (players[turn]?.id === user.id) void roll()
      else finishTurn()
    }
    if (phase === 'decision') finishTurn()
  }, [timeLeft])

"""
if roll_marker not in s: raise SystemExit('Не знайдено roll')
s=s.replace(roll_marker,helpers+roll_marker)

# Prevent rolling outside roll phase and mark movement phase.
s=s.replace("    if (rolling || players[turn]?.id !== user.id) return", "    if (rolling || phase !== 'roll' || players[turn]?.id !== user.id) return")
s=s.replace("    setRolling(true); playDiceRoll()", "    setPhase('moving')\n    setRolling(true); playDiceRoll()")

# Replace movement completion: property gets decision phase, non-property ends turn. Chance gets a grounded meme event.
old="""        const destination=(positions[turn]+a+b)%cells.length
        setSelectedCell(destination)
        setCardOpen(true)
        playPawnMove(a+b)
        setPositions(old=>old.map((p,i)=>i===turn?destination:p))
        window.setTimeout(()=>{ setTurn(value=>(value+1)%players.length); setTurnNoticeId(value=>value+1) },Math.max(900,(a+b)*190+260))"""
new="""        const destination=(positions[turn]+a+b)%cells.length
        const landed=cells[destination]
        setSelectedCell(destination)
        playPawnMove(a+b)
        setPositions(old=>old.map((p,i)=>i===turn?destination:p))
        window.setTimeout(()=>{
          if (landed.kind==='city') {
            setCardOpen(true)
            setPhase('decision')
          } else {
            if (landed.kind==='chance') {
              const lines=['Доброго вечора, ми з КупиМіста. Банк дарує 100 ₴.','Пес Патрон тримає район. Отримай 80 ₴ за безпечний маршрут.','Бавовна цін на оренду: отримай компенсацію 120 ₴.']
              setMeme(lines[Math.floor(Math.random()*lines.length)])
              window.setTimeout(()=>setMeme(''),2800)
            }
            finishTurn()
          }
        },Math.max(900,(a+b)*190+260))"""
if old not in s: raise SystemExit('Не знайдено завершення руху')
s=s.replace(old,new)

# Buy immediately ends decision and passes turn.
s=s.replace("const buy=()=>{if(!canBuy)return;setBalance(value=>value-(selected.price||0));setOwned(value=>[...value,selectedCell]);playUiSound('success')}", "const buy=()=>{if(!canBuy)return;setBalance(value=>value-(selected.price||0));setOwned(value=>[...value,selectedCell]);playUiSound('success');finishTurn()}")

# Top status: no center announcement, clear current turn plus countdown.
s=s.replace("<div className=\"topTurn\">Хід {players[turn]?.name}</div>", "<div className=\"topTurn\"><strong>{players[turn]?.id===user.id?'ВАШ ХІД':`ХІД: ${players[turn]?.name}`}</strong><span><Clock3/>{phase==='moving'?'Фішка рухається':`${timeLeft} с`}</span></div>")

# Remove centered announcement completely.
start=s.find('      <AnimatePresence>{<motion.div key={turnNoticeId}')
if start!=-1:
    end=s.find('</AnimatePresence>',start)
    if end==-1: raise SystemExit('Не знайдено кінець центрального повідомлення')
    s=s[:start]+s[end+19:]

# Roll button follows phase.
s=s.replace("disabled={rolling||players[turn]?.id!==user.id}", "disabled={rolling||phase!=='roll'||players[turn]?.id!==user.id}")

# Property buttons: only when standing on the cell. Cross remains always available.
old_actions="""          {owned.includes(selectedCell)?<div className="ownedLabel"><Check/> Це твоя власність</div>:<div className="propertyActions"><button className="buyProperty" disabled={!canBuy} onClick={buy}>{!standingOnSelected?'Спочатку стань на цю клітинку':balance<(selected.price||0)?'Недостатньо коштів':`Купити за ${selected.price} ₴`}</button><button className="skipProperty" onClick={()=>setCardOpen(false)}>Не купувати</button></div>}"""
new_actions="""          {owned.includes(selectedCell)?<div className="ownedLabel"><Check/> Це твоя власність</div>:standingOnSelected&&phase==='decision'?<div className="propertyActions"><button className="buyProperty" disabled={!canBuy} onClick={buy}>{balance<(selected.price||0)?'Недостатньо коштів':`Купити за ${selected.price} ₴`}</button><button className="skipProperty" onClick={finishTurn}>Не купувати</button><small className="decisionTimer"><Clock3/> На рішення: {timeLeft} с</small></div>:null}"""
if old_actions not in s: raise SystemExit('Не знайдено кнопки власності')
s=s.replace(old_actions,new_actions)

# Click-to-inspect should never start a purchase phase. Existing handler opens informational card only.
# Add meme toast before property panel.
needle="      <AnimatePresence>{cardOpen&&<motion.aside className=\"propertyPanel\""
s=s.replace(needle,"      <AnimatePresence>{meme&&<motion.div className=\"memeToast\" initial={{opacity:0,y:18}} animate={{opacity:1,y:0}} exit={{opacity:0,y:-18}}>{meme}</motion.div>}</AnimatePresence>\n"+needle)

# Remove stale state if present.
s=s.replace("  const [turnNoticeId,setTurnNoticeId] = useState(1)\n","")
p.write_text(s, encoding='utf-8')
PY

cat >> frontend/src/styles.css <<'EOF'
/* Turn phases, countdowns and contextual actions */
.topTurn{display:flex;align-items:center;gap:14px;background:var(--yellow);border:2px solid var(--ink);border-radius:10px;padding:6px 12px;box-shadow:3px 3px 0 var(--ink)}.topTurn strong{font-family:Unbounded;font-size:11px;letter-spacing:.04em}.topTurn span{display:flex;align-items:center;gap:5px;font-size:10px;font-weight:900;font-variant-numeric:tabular-nums}.topTurn svg{width:14px;height:14px}.decisionTimer{display:flex;align-items:center;justify-content:center;gap:6px;font-size:10px;font-weight:900;color:var(--muted)}.decisionTimer svg{width:14px}.memeToast{position:absolute;z-index:17;left:50%;top:82px;transform:translateX(-50%);max-width:min(520px,calc(100vw - 40px));background:var(--yellow);border:3px solid var(--ink);border-radius:14px;padding:14px 18px;box-shadow:6px 6px 0 var(--ink);font-family:Unbounded;font-size:12px;line-height:1.45;text-align:center}.propertyClose{z-index:2}.propertyActions:empty{display:none}
@media(max-width:700px){.topTurn{justify-self:center}.topTurn strong{font-size:9px}.topTurn span{font-size:9px}.memeToast{top:66px;font-size:10px}}
EOF

npm --prefix frontend run build

git add frontend/src/components/GameScreen.tsx frontend/src/styles.css
git commit -m "feat: add timed turn phases and contextual property actions" || true
git push || echo "Виконай git push вручну"

echo "Готово. Перезапусти: docker compose down && docker compose up --build"
