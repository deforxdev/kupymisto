#!/usr/bin/env bash
set -euo pipefail

if [ ! -f frontend/src/components/ClassicBoard3D.tsx ] || [ ! -f frontend/src/components/GameScreen.tsx ] || [ ! -f backend/cmd/api/main.go ]; then
  echo "Запусти файл у корені kupymisto після всіх попередніх оновлень."
  exit 1
fi

python3 <<'PY'
from pathlib import Path

# ---------- Shared API ----------
p=Path('frontend/src/api.ts');s=p.read_text(encoding='utf-8')
s=s.replace("art:'owl'|'bus'|'rich'|'fire'; nonce:number", "art:'owl'|'bus'|'rich'|'fire'; nonce:number; drawnBy:string")
s=s.replace("ownership: Record<string,string>; currentChance?", "ownership: Record<string,string>; houses: Record<string,number>; currentChance?")
s=s.replace("  purchaseProperty:", "  buildHouse: (code:string, body:{ cellIndex:number }) => request<{ room:Room }>(`/api/rooms/${code}/houses`, { method:'POST', body:JSON.stringify(body) }),\n  purchaseProperty:")
p.write_text(s, encoding='utf-8')

# ---------- 3D board: ownership platforms and houses ----------
p=Path('frontend/src/components/ClassicBoard3D.tsx');s=p.read_text(encoding='utf-8')
s=s.replace("onSelectCell,drawNonce}:{size:BoardSize;positions:number[];players:Player[];dice:[number,number];rolling:boolean;onSelectCell:(index:number)=>void;ownership:Record<string,string>;drawNonce:number}", "onSelectCell,drawNonce,houses}:{size:BoardSize;positions:number[];players:Player[];dice:[number,number];rolling:boolean;onSelectCell:(index:number)=>void;ownership:Record<string,string>;drawNonce:number;houses:Record<string,number>}")
old="{ownerColor(index)&&<group position={[0,.175,0]}><mesh><boxGeometry args={[corner?1.11:.84,.035,1.11]}/><meshStandardMaterial color={ownerColor(index)!}/></mesh><mesh position={[0,.025,0]}><boxGeometry args={[corner?1.02:.75,.04,1.02]}/><meshStandardMaterial color={corner?cell.color:'#cfc6af'}/></mesh></group>}"
new="""{ownerColor(index)&&<group position={[0,.34,0]}>
          <RoundedBox args={[corner?1.14:.88,.16,1.14]} radius={.045} smoothness={3} castShadow><meshStandardMaterial color={ownerColor(index)!} roughness={.58}/></RoundedBox>
          {Array.from({length:houses[String(index)]||0}).map((_,houseIndex)=><group key={houseIndex} position={[-.24+houseIndex*.24,.25,-.08]}>
            <mesh castShadow><boxGeometry args={[.17,.18,.17]}/><meshStandardMaterial color={ownerColor(index)!}/></mesh>
            <mesh position={[0,.14,0]} rotation={[0,Math.PI/4,0]} castShadow><coneGeometry args={[.15,.16,4]}/><meshStandardMaterial color="#e8bd32"/></mesh>
          </group>)}
        </group>}"""
if old not in s: raise SystemExit('Не знайдено стару обводку власності')
s=s.replace(old,new)
s=s.replace("onSelectCell:(index:number)=>void;ownership:Record<string,string>;drawNonce:number})", "onSelectCell:(index:number)=>void;ownership:Record<string,string>;drawNonce:number;houses:Record<string,number>})")
p.write_text(s, encoding='utf-8')

# ---------- Game phases, manual draw, tax, negative balances, houses ----------
p=Path('frontend/src/components/GameScreen.tsx');s=p.read_text(encoding='utf-8')
s=s.replace("  const [chanceEvent,setChanceEvent] = useState<ChanceEvent|null>(room.currentChance||null)", "  const [chanceEvent,setChanceEvent] = useState<ChanceEvent|null>(room.currentChance||null)\n  const [chancePending,setChancePending] = useState(false)")
# Pass houses to board.
s=s.replace("ownership={liveRoom.ownership||{}} drawNonce={drawNonce}/>", "ownership={liveRoom.ownership||{}} houses={liveRoom.houses||{}} drawNonce={drawNonce}/>")
# Poll: all clients see card, but only drawer applies money, once.
old_poll="if(room.currentChance&&room.currentChance.nonce!==drawNonce){setDrawNonce(room.currentChance.nonce);setChanceEvent(room.currentChance)}"
new_poll="""if(room.currentChance&&room.currentChance.nonce!==drawNonce){
      setDrawNonce(room.currentChance.nonce)
      window.setTimeout(()=>{
        setChanceEvent(room.currentChance||null)
        if(room.currentChance?.drawnBy===user.id)setBalance(value=>value+room.currentChance!.amount)
      },1100)
    }"""
if old_poll not in s: raise SystemExit('Не знайдено синхронізацію картки')
s=s.replace(old_poll,new_poll)
# Landing chance no longer auto draws. Repair roads always charges 100 and can go negative.
old_chance="""            if (landed.kind==='chance') {
              api.drawChance(room.code).then(({room:nextRoom})=>{
                setLiveRoom(nextRoom)
                if(nextRoom.currentChance){
                  setDrawNonce(nextRoom.currentChance.nonce)
                  window.setTimeout(()=>{
                    setChanceEvent(nextRoom.currentChance||null)
                    setBalance(value=>Math.max(0,value+(nextRoom.currentChance?.amount||0)))
                  },1100)
                }
              })
            }"""
new_chance="""            if (landed.kind==='chance') {
              setChancePending(true)
              setPhase('decision')
            }
            if (landed.name==='РЕМОНТ ДОРІГ') {
              setBalance(value=>value-100)
              setMeme('Ремонт доріг: міський бюджет просить 100 ₴. Баланс може піти в мінус.')
              window.setTimeout(()=>setMeme(''),2800)
            }"""
if old_chance not in s: raise SystemExit('Не знайдено автоматичне витягування шансу')
s=s.replace(old_chance,new_chance)
# Do not finish turn while chance waits.
s=s.replace("if(landed.kind!=='chance')finishTurn()", "if(landed.kind!=='chance')finishTurn()")
# Manual draw function before derived values.
marker="  const selected=cells[selectedCell]\n"
manual="""  const drawChance=async()=>{
    if(!chancePending)return
    await unlockAudio()
    setChancePending(false)
    const {room:nextRoom}=await api.drawChance(room.code)
    setLiveRoom(nextRoom)
    if(nextRoom.currentChance){
      setDrawNonce(nextRoom.currentChance.nonce)
      window.setTimeout(()=>{
        setChanceEvent(nextRoom.currentChance||null)
        setBalance(value=>value+(nextRoom.currentChance?.amount||0))
      },1100)
    }
  }

"""
if marker not in s: raise SystemExit('Не знайдено selected')
s=s.replace(marker,manual+marker)
# House state and action.
s=s.replace("  const owner=players.find(player=>player.id===ownerId)", "  const owner=players.find(player=>player.id===ownerId)\n  const houseCount=liveRoom.houses?.[String(selectedCell)]||0")
s=s.replace("  const buy=async()=>", "  const canBuild=ownerId===user.id&&houseCount<3&&balance>=100\n  const buildHouse=async()=>{if(!canBuild)return;const result=await api.buildHouse(room.code,{cellIndex:selectedCell});setLiveRoom(result.room);setBalance(value=>value-100);playUiSound('success')}\n  const buy=async()=>")
# Add balance warning and houses control in owned label.
old_owned="<div className=\"ownedLabel\"><Check/> {ownerId===user.id?'Це твоя власність':`Власник: ${owner?.name||'інший гравець'}`}</div>"
new_owned="""<div className="ownedPropertyBlock"><div className="ownedLabel"><Check/> {ownerId===user.id?'Це твоя власність':`Власник: ${owner?.name||'інший гравець'}`}</div>{ownerId===user.id&&<button className="buildHouseButton" disabled={!canBuild} onClick={buildHouse}>{balance<100?'У мінусі будувати не можна':houseCount>=3?'Максимум будинків':`Побудувати будинок, 100 ₴ (${houseCount}/3)`}</button>}</div>"""
s=s.replace(old_owned,new_owned)
# Chance prompt above deck.
needle="      <div className=\"diceAction\">"
prompt="""      <AnimatePresence>{chancePending&&<motion.div className="chanceDrawPrompt" initial={{opacity:0,y:18,scale:.92}} animate={{opacity:1,y:0,scale:1}} exit={{opacity:0,y:-14}}><small>ТИ СТАВ НА «ШАНС»</small><strong>Витягни верхню картку</strong><button onClick={drawChance}>Витягнути картку</button></motion.div>}</AnimatePresence>
"""
s=s.replace(needle,prompt+needle)
# Synced card close: drawer clears and passes turn, others only close locally.
old_close="onContinue={()=>{api.clearChance(room.code).then(({room})=>setLiveRoom(room)).catch(()=>null);setChanceEvent(null);finishTurn()}}"
new_close="onContinue={()=>{const mine=chanceEvent?.drawnBy===user.id;setChanceEvent(null);if(mine){api.clearChance(room.code).then(({room})=>setLiveRoom(room)).catch(()=>null);finishTurn()}}}"
s=s.replace(old_close,new_close)
# Negative balance class.
s=s.replace("<strong>{balance} ₴</strong></div>\n      <ClassicBoard3D", "<strong className={balance<0?'negativeBalance':''}>{balance} ₴</strong></div>\n      <ClassicBoard3D")
p.write_text(s, encoding='utf-8')

# ---------- Backend shared houses + chance drawer ----------
p=Path('backend/cmd/api/main.go');s=p.read_text(encoding='utf-8')
s=s.replace('Art string `json:"art"`; Nonce int64 `json:"nonce"`', 'Art string `json:"art"`; Nonce int64 `json:"nonce"`; DrawnBy string `json:"drawnBy"`')
s=s.replace('Ownership map[string]string `json:"ownership"`; CurrentChance', 'Ownership map[string]string `json:"ownership"`; Houses map[string]int `json:"houses"`; CurrentChance')
s=s.replace('Ownership:map[string]string{},Players:', 'Ownership:map[string]string{},Houses:map[string]int{},Players:')
s=s.replace('card.Nonce=time.Now().UnixNano();room.CurrentChance=&card', 'card.Nonce=time.Now().UnixNano();card.DrawnBy=user.ID;room.CurrentChance=&card')
# Houses endpoint validates ownership and max 3.
route='''    protected.HandleFunc("POST /api/rooms/{code}/houses",func(w http.ResponseWriter,r *http.Request){var in struct{CellIndex int `json:"cellIndex"`};if readJSON(r,&in)!=nil||in.CellIndex<0{fail(w,400,"Некоректна клітинка");return};code:=strings.ToUpper(r.PathValue("code"));user:=mustUser(r);store.mu.Lock();defer store.mu.Unlock();room,ok:=store.rooms[code];if !ok||!containsPlayer(room,user.ID){fail(w,404,"Кімнату не знайдено");return};key:=strconv.Itoa(in.CellIndex);if room.Ownership[key]!=user.ID{fail(w,403,"Будувати може лише власник");return};if room.Houses[key]>=3{fail(w,409,"На клітинці вже максимум будинків");return};room.Houses[key]++;writeJSON(w,200,map[string]any{"room":room})})
'''
s=s.replace('    protected.HandleFunc("POST /api/rooms/{code}/properties"',route+'    protected.HandleFunc("POST /api/rooms/{code}/properties"')
p.write_text(s, encoding='utf-8')
PY

cat >> frontend/src/styles.css <<'EOF'
/* Manual synchronized chance draw, debt and houses */
.chanceDrawPrompt{position:absolute;z-index:18;left:50%;top:50%;transform:translate(-50%,-50%);width:min(340px,calc(100vw - 40px));background:var(--yellow);border:4px solid var(--ink);border-radius:18px;padding:22px;text-align:center;box-shadow:9px 9px 0 var(--ink);display:grid;gap:9px}.chanceDrawPrompt small{font-size:9px;font-weight:900;letter-spacing:.12em}.chanceDrawPrompt strong{font-family:Unbounded;font-size:21px}.chanceDrawPrompt button{min-height:46px;border:3px solid var(--ink);border-radius:10px;background:var(--blue);color:var(--paper);font-weight:900;cursor:pointer}.negativeBalance{color:oklch(72% .19 28)!important}.ownedPropertyBlock{display:grid;gap:8px}.buildHouseButton{min-height:43px;border:2px solid var(--ink);border-radius:10px;background:var(--yellow);font-weight:900;font-size:11px;cursor:pointer}.buildHouseButton:disabled{background:oklch(85% .015 96);color:var(--muted);cursor:not-allowed}.propertyPanel .panelBalance strong.negativeBalance{color:var(--red)}
EOF

(cd backend && gofmt -w cmd/api/main.go && go test ./...)
npm --prefix frontend run build

git add frontend/src/api.ts frontend/src/components/ClassicBoard3D.tsx frontend/src/components/GameScreen.tsx frontend/src/styles.css backend/cmd/api/main.go
git commit -m "feat: add debt, manual synced chance draw, platforms and houses" || true
git push || echo "Виконай git push вручну"

echo "Готово. Перезапусти: docker compose down && docker compose up --build"
