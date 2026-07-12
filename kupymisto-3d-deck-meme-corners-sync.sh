#!/usr/bin/env bash
set -euo pipefail

if [ ! -f frontend/src/components/ClassicBoard3D.tsx ] || [ ! -f frontend/src/components/GameScreen.tsx ] || [ ! -f backend/cmd/api/main.go ]; then
  echo "Запусти файл у корені kupymisto після попередніх оновлень."
  exit 1
fi

mkdir -p frontend/public/cards frontend/public/sounds
cat > frontend/public/cards/README.md <<'EOF'
# Зображення карток

Клади сюди WebP, PNG або JPG. Рекомендований розмір: 900x1200, співвідношення 3:4.
Назви для поточної колоди: owl.webp, bus.webp, rich.webp, cotton.webp.
Якщо файла немає, гра показує вбудовану SVG-ілюстрацію.
EOF
cat > frontend/public/sounds/README.md <<'EOF'
# Звуки гри

Клади сюди OGG або MP3. Рекомендовані назви: card-draw.ogg, card-flip.ogg,
dice-roll.ogg, pawn-step.ogg, purchase.ogg, turn-start.ogg.
Поточний синтезований звук лишається резервним варіантом.
EOF

python3 <<'PY'
from pathlib import Path

# Shared chance state in client types and endpoints.
p=Path('frontend/src/api.ts');s=p.read_text(encoding='utf-8')
s=s.replace("export type Room = {", "export type SharedChance = { id:string; title:string; text:string; amount:number; art:'owl'|'bus'|'rich'|'fire'; nonce:number }\nexport type Room = {")
s=s.replace("ownership: Record<string,string>; players", "ownership: Record<string,string>; currentChance?: SharedChance; chanceAcknowledged?: string[]; players")
s=s.replace("  purchaseProperty:", "  drawChance: (code:string) => request<{ room:Room }>(`/api/rooms/${code}/chance`, { method:'POST' }),\n  clearChance: (code:string) => request<{ room:Room }>(`/api/rooms/${code}/chance`, { method:'DELETE' }),\n  purchaseProperty:")
p.write_text(s, encoding='utf-8')

# Change corner names and tax name in board data.
p=Path('frontend/src/components/ClassicBoard3D.tsx');s=p.read_text(encoding='utf-8')
s=s.replace("const corners=['СТАРТ','ВІЛЬНА ЗУПИНКА','МІСЬКА РАДА','ПАРКІНГ']", "const corners=['СТАРТ','Я У ПОЛЬЩІ','БУСИФІКАЦІЯ','DON’T PUSH THE HORSES']")
s=s.replace("return{name:'ЗБІР',kind:'tax'", "return{name:'РЕМОНТ ДОРІГ',kind:'tax'")
# Smaller pawns.
s=s.replace("<sphereGeometry args={[.16,24,24]}", "<sphereGeometry args={[.12,24,24]}")
s=s.replace("<coneGeometry args={[.28,.55,24]}", "<coneGeometry args={[.21,.42,24]}")
s=s.replace("<cylinderGeometry args={[.31,.31,.09,24]}", "<cylinderGeometry args={[.235,.235,.075,24]}")
s=s.replace("position={[0,.28,0]}", "position={[0,.21,0]}",1)
s=s.replace("position={[0,-.29,0]}", "position={[0,-.225,0]}",1)

# Replace circular ownership puck with a full tile outline frame.
old="{ownerColor(index)&&<mesh position={[0,.16,.17]}><cylinderGeometry args={[.105,.105,.045,24]}/><meshStandardMaterial color={ownerColor(index)!}/></mesh>}"
new="{ownerColor(index)&&<group position={[0,.175,0]}><mesh><boxGeometry args={[corner?1.11:.84,.035,1.11]}/><meshStandardMaterial color={ownerColor(index)!}/></mesh><mesh position={[0,.025,0]}><boxGeometry args={[corner?1.02:.75,.04,1.02]}/><meshStandardMaterial color={corner?cell.color:'#cfc6af'}/></mesh></group>}"
if old not in s: raise SystemExit('Не знайдено круглу мітку власності')
s=s.replace(old,new)

# Add a physical deck and animated top card.
deck_component='''
function ChanceDeck({drawNonce}:{drawNonce:number}){
  const card=useRef<Group>(null)
  const previous=useRef(drawNonce)
  const progress=useRef(1)
  useEffect(()=>{if(drawNonce!==previous.current){previous.current=drawNonce;progress.current=0}},[drawNonce])
  useFrame((_,delta)=>{
    if(!card.current)return
    progress.current=Math.min(1,progress.current+delta*.82)
    const t=1-Math.pow(1-progress.current,4)
    card.current.position.x=1.55+(3.15-1.55)*t
    card.current.position.y=.69+Math.sin(t*Math.PI)*1.65
    card.current.position.z=-.45+(-2.45+.45)*t
    card.current.rotation.x=-Math.PI/2+t*Math.PI*2
    card.current.rotation.z=t*Math.PI*.18
    card.current.visible=progress.current<.985
  })
  return <group>
    {Array.from({length:7}).map((_,index)=><RoundedBox key={index} args={[1.12,.055,1.48]} radius={.055} smoothness={3} position={[1.55,.50+index*.045,-.45]} castShadow><meshStandardMaterial color={index%2?'#e8bd32':'#244f95'} roughness={.58}/></RoundedBox>)}
    <group ref={card} position={[1.55,.69,-.45]} rotation={[-Math.PI/2,0,0]} visible={false}>
      <RoundedBox args={[1.12,.045,1.48]} radius={.055} smoothness={3} castShadow><meshStandardMaterial color="#e8bd32" roughness={.46}/></RoundedBox>
      <Text position={[0,.04,0]} rotation={[-Math.PI/2,0,0]} fontSize={.18} maxWidth={.82} color="#20202a" textAlign="center">ШАНС</Text>
    </group>
  </group>
}
'''
pos=s.index('function BoardModel(')
s=s[:pos]+deck_component+'\n'+s[pos:]
s=s.replace("onSelectCell}:{size:BoardSize;positions:number[];players:Player[];dice:[number,number];rolling:boolean;onSelectCell:(index:number)=>void;ownership:Record<string,string>}", "onSelectCell,drawNonce}:{size:BoardSize;positions:number[];players:Player[];dice:[number,number];rolling:boolean;onSelectCell:(index:number)=>void;ownership:Record<string,string>;drawNonce:number}")
# Add deck inside BoardModel before closing group, immediately before dice.
s=s.replace("<Die home={[-.5,.86,.45]}", "<ChanceDeck drawNonce={drawNonce}/><Die home={[-.5,.86,.45]}")
s=s.replace("onSelectCell:(index:number)=>void;ownership:Record<string,string>})", "onSelectCell:(index:number)=>void;ownership:Record<string,string>;drawNonce:number})")
p.write_text(s, encoding='utf-8')

# Use backend chance, show synchronized card and card-draw timing.
p=Path('frontend/src/components/GameScreen.tsx');s=p.read_text(encoding='utf-8')
s=s.replace("  const [chanceEvent,setChanceEvent] = useState<ChanceEvent|null>(null)", "  const [chanceEvent,setChanceEvent] = useState<ChanceEvent|null>(room.currentChance||null)\n  const [drawNonce,setDrawNonce] = useState(room.currentChance?.nonce||0)\n  const [skippedTurns,setSkippedTurns] = useState<Record<string,number>>({})")
# Poll sync chance event.
s=s.replace("api.getRoom(room.code).then(({room})=>setLiveRoom(room)", "api.getRoom(room.code).then(({room})=>{setLiveRoom(room);if(room.currentChance&&room.currentChance.nonce!==drawNonce){setDrawNonce(room.currentChance.nonce);setChanceEvent(room.currentChance)}}")
# Pass draw nonce.
s=s.replace("ownership={liveRoom.ownership||{}}/>", "ownership={liveRoom.ownership||{}} drawNonce={drawNonce}/>")
# Replace local random draw with API draw, delay popup until 3D card leaves deck.
old="""              const event=chanceDeck[Math.floor(Math.random()*chanceDeck.length)]
              setChanceEvent(event)
              setBalance(value=>Math.max(0,value+event.amount))"""
new="""              api.drawChance(room.code).then(({room:nextRoom})=>{
                setLiveRoom(nextRoom)
                if(nextRoom.currentChance){
                  setDrawNonce(nextRoom.currentChance.nonce)
                  window.setTimeout(()=>{
                    setChanceEvent(nextRoom.currentChance||null)
                    setBalance(value=>Math.max(0,value+(nextRoom.currentChance?.amount||0)))
                  },1100)
                }
              })"""
if old not in s: raise SystemExit('Не знайдено локальну колоду шансу')
s=s.replace(old,new)
# Synced clear.
s=s.replace("onContinue={()=>{setChanceEvent(null);finishTurn()}}", "onContinue={()=>{api.clearChance(room.code).then(({room})=>setLiveRoom(room)).catch(()=>null);setChanceEvent(null);finishTurn()}}")
# Remove obsolete local deck declaration.
start=s.find('  const chanceDeck:ChanceEvent[]=[')
if start!=-1:
    end=s.find('\n\n  const finishTurn',start)
    s=s[:start]+s[end+2:]
# Corner mechanics after landing.
needle="""          if (landed.kind==='city') {
            setCardOpen(true)
            setPhase('decision')
          } else {"""
replacement="""          if (landed.kind==='city') {
            setCardOpen(true)
            setPhase('decision')
          } else {
            if(landed.name==='БУСИФІКАЦІЯ'){
              setSkippedTurns(value=>({...value,[players[turn].id]:(value[players[turn].id]||0)+1}))
              setMeme('Бусифікація: наступний хід пропускається.')
              window.setTimeout(()=>setMeme(''),2600)
            }
            if(landed.name==='DON’T PUSH THE HORSES'){
              setMeme('Don’t push the horses: стоїмо спокійно до наступного кола.')
              window.setTimeout(()=>setMeme(''),2600)
            }
            if(landed.name==='Я У ПОЛЬЩІ'){
              setMeme('Я у Польщі: експрес до найближчого вокзалу.')
              window.setTimeout(()=>setMeme(''),2600)
            }"""
if needle not in s: raise SystemExit('Не знайдено логіку приземлення')
s=s.replace(needle,replacement)
p.write_text(s, encoding='utf-8')

# Backend chance card sync.
p=Path('backend/cmd/api/main.go');s=p.read_text(encoding='utf-8')
s=s.replace('type Room struct {', 'type ChanceCard struct { ID string `json:"id"`; Title string `json:"title"`; Text string `json:"text"`; Amount int `json:"amount"`; Art string `json:"art"`; Nonce int64 `json:"nonce"` }\ntype Room struct {')
s=s.replace('Ownership map[string]string `json:"ownership"`; Players', 'Ownership map[string]string `json:"ownership"`; CurrentChance *ChanceCard `json:"currentChance,omitempty"`; Players')
route='''    protected.HandleFunc("POST /api/rooms/{code}/chance",func(w http.ResponseWriter,r *http.Request){code:=strings.ToUpper(r.PathValue("code"));user:=mustUser(r);store.mu.Lock();defer store.mu.Unlock();room,ok:=store.rooms[code];if !ok||!containsPlayer(room,user.ID){fail(w,404,"Кімнату не знайдено");return};deck:=[]ChanceCard{{ID:"owl",Title:"Сова на скакалці",Text:"Ранкова руханка оживила район. Місто платить за спортивну ініціативу.",Amount:120,Art:"owl"},{ID:"bus",Title:"Бусифікація маршруту",Text:"Новий міський бус підняв пасажиропотік і касу району.",Amount:150,Art:"bus"},{ID:"rich",Title:"Я не з такої сім’ї",Text:"Фінансовий план виявився із багатої сім’ї. Отримай дивіденди.",Amount:100,Art:"rich"},{ID:"cotton",Title:"Економічна бавовна",Text:"Ціни ефектно згоріли. Ремонт коштує грошей.",Amount:-90,Art:"fire"}};card:=deck[time.Now().UnixNano()%int64(len(deck))];card.Nonce=time.Now().UnixNano();room.CurrentChance=&card;writeJSON(w,200,map[string]any{"room":room})})
    protected.HandleFunc("DELETE /api/rooms/{code}/chance",func(w http.ResponseWriter,r *http.Request){code:=strings.ToUpper(r.PathValue("code"));user:=mustUser(r);store.mu.Lock();defer store.mu.Unlock();room,ok:=store.rooms[code];if !ok||!containsPlayer(room,user.ID){fail(w,404,"Кімнату не знайдено");return};room.CurrentChance=nil;writeJSON(w,200,map[string]any{"room":room})})
'''
s=s.replace('    protected.HandleFunc("POST /api/rooms/{code}/properties"',route+'    protected.HandleFunc("POST /api/rooms/{code}/properties"')
p.write_text(s, encoding='utf-8')
PY

# Optional real asset audio helper for later uploaded files.
cat >> frontend/src/audio.ts <<'EOF'

export async function playAssetSound(name: string, fallback?: () => void) {
  try {
    const audio = new Audio(`/sounds/${name}`)
    audio.volume = 0.55
    await audio.play()
  } catch {
    fallback?.()
  }
}
EOF

cat >> frontend/src/styles.css <<'EOF'
/* 3D deck card reveal polish */
.chanceBackdrop{perspective:1100px}.chanceCard{transform-style:preserve-3d}.chanceCard::before{content:"";position:absolute;inset:7px;border:1px solid oklch(24% .035 278/.25);border-radius:16px;pointer-events:none}
EOF

(cd backend && gofmt -w cmd/api/main.go && go test ./...)
npm --prefix frontend run build

git add frontend/public/cards frontend/public/sounds frontend/src/api.ts frontend/src/audio.ts frontend/src/components/ClassicBoard3D.tsx frontend/src/components/GameScreen.tsx frontend/src/styles.css backend/cmd/api/main.go
git commit -m "feat: add synchronized 3D chance deck and meme corner mechanics" || true
git push || echo "Виконай git push вручну"

echo "Готово. Перезапусти: docker compose down && docker compose up --build"
