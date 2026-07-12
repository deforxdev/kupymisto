#!/usr/bin/env bash
set -euo pipefail

if [ ! -f frontend/src/components/ClassicBoard3D.tsx ] || [ ! -f frontend/src/components/GameScreen.tsx ] || [ ! -f backend/cmd/api/main.go ]; then
  echo "Запусти файл у корені kupymisto після попередніх оновлень."
  exit 1
fi

cat > frontend/src/components/ChanceCard.tsx <<'EOF'
import { motion } from 'framer-motion'
import { ArrowRight, X } from 'lucide-react'

export type ChanceEvent = { id:string; title:string; text:string; amount:number; art:'owl'|'bus'|'rich'|'fire' }

type Props = { event:ChanceEvent; onContinue:()=>void }

function OwlArt(){return <svg viewBox="0 0 260 190" aria-hidden="true"><path className="rope" d="M38 22c23 35 22 101 4 145M222 22c-23 35-22 101-4 145"/><path className="owlWing" d="M86 91 44 74l29 55M174 91l42-17-29 55"/><ellipse className="owlBody" cx="130" cy="105" rx="58" ry="67"/><path className="owlHead" d="m81 67 14-46 34 28 36-28 14 47c-12 24-32 36-49 36-20 0-39-12-49-37Z"/><circle className="owlEye" cx="108" cy="66" r="17"/><circle className="owlEye" cx="152" cy="66" r="17"/><circle className="owlPupil" cx="108" cy="66" r="6"/><circle className="owlPupil" cx="152" cy="66" r="6"/><path className="owlBeak" d="m122 82 16 0-8 15Z"/><path className="bar" d="M42 153h176"/></svg>}
function BusArt(){return <svg viewBox="0 0 280 180" aria-hidden="true"><path className="road" d="M18 149h244"/><rect className="busBody" x="42" y="50" width="196" height="91" rx="18"/><path className="busTop" d="M66 31h122c20 0 34 10 42 30H48c3-18 8-30 18-30Z"/><rect className="busWindow" x="64" y="62" width="44" height="35" rx="6"/><rect className="busWindow" x="119" y="62" width="44" height="35" rx="6"/><rect className="busWindow" x="174" y="62" width="42" height="35" rx="6"/><circle className="wheel" cx="87" cy="142" r="18"/><circle className="wheel" cx="200" cy="142" r="18"/><path className="speed" d="M15 83h32M7 105h40"/></svg>}
function RichArt(){return <svg viewBox="0 0 260 180" aria-hidden="true"><path className="coat" d="M70 165c5-57 24-82 60-82s56 25 60 82Z"/><circle className="face" cx="130" cy="63" r="38"/><path className="hat" d="M78 51h104M102 48l8-38h41l9 38Z"/><path className="mustache" d="M127 69c-17-13-33 8-17 17 9 5 17-2 20-9 3 7 11 14 20 9 16-9 0-30-17-17"/><circle className="coinShape" cx="205" cy="44" r="25"/><path className="coinMark" d="M205 29v30M195 37h15c10 0 10 11 0 11h-10c-10 0-10 11 0 11h15"/></svg>}
function FireArt(){return <svg viewBox="0 0 260 180" aria-hidden="true"><path className="cotton" d="M83 144c-30 2-48-25-34-48-18-25 5-52 32-45 7-31 48-35 62-8 28-18 59 4 52 34 30 4 39 43 15 59-21 14-102 8-127 8Z"/><path className="flame" d="M132 131c-26-21-7-39 3-54 5 17 20 21 17 39 13-10 18-19 15-31 25 25 18 56-13 66-31 10-51-8-50-29 9 10 17 13 28 9Z"/></svg>}

export default function ChanceCard({event,onContinue}:Props){return <motion.div className="chanceBackdrop" initial={{opacity:0}} animate={{opacity:1}} exit={{opacity:0}}><motion.section className={`chanceCard ${event.art}`} initial={{opacity:0,scale:.86,rotate:-3,y:32}} animate={{opacity:1,scale:1,rotate:0,y:0}} exit={{opacity:0,scale:.9,y:-30}} transition={{duration:.46,ease:[.16,1,.3,1]}}><button className="chanceClose" onClick={onContinue} aria-label="Закрити"><X/></button><span className="chanceLabel">КАРТКА ШАНСУ</span><div className="chanceArt">{event.art==='owl'?<OwlArt/>:event.art==='bus'?<BusArt/>:event.art==='rich'?<RichArt/>:<FireArt/>}</div><h2>{event.title}</h2><p>{event.text}</p><strong className={event.amount>=0?'positive':'negative'}>{event.amount>=0?'+':''}{event.amount} ₴</strong><button className="chanceContinue" onClick={onContinue}>Продовжити<ArrowRight/></button></motion.section></motion.div>}
EOF

python3 <<'PY'
from pathlib import Path

# API room ownership shared through Go backend.
p=Path('frontend/src/api.ts');s=p.read_text(encoding='utf-8')
s=s.replace("boardSize: BoardSize; players", "boardSize: BoardSize; ownership: Record<string,string>; players")
s=s.replace("  toggleReady:", "  purchaseProperty: (code: string, body: { cellIndex:number; price:number }) => request<{ room: Room }>(`/api/rooms/${code}/properties`, { method: 'POST', body: JSON.stringify(body) }),\n  toggleReady:")
p.write_text(s, encoding='utf-8')

# Board gets owner markers visible to everyone.
p=Path('frontend/src/components/ClassicBoard3D.tsx');s=p.read_text(encoding='utf-8')
s=s.replace("function BoardModel({size,positions,players,dice,rolling,onSelectCell}:{size:BoardSize;positions:number[];players:Player[];dice:[number,number];rolling:boolean;onSelectCell:(index:number)=>void})", "function BoardModel({size,positions,players,dice,rolling,onSelectCell,ownership}:{size:BoardSize;positions:number[];players:Player[];dice:[number,number];rolling:boolean;onSelectCell:(index:number)=>void;ownership:Record<string,string>})")
s=s.replace("const group=useRef<Group>(null),drag=", "const ownerColors=['#3167dc','#de5549','#54b87a','#efc63e','#955fc7','#e98a44'],ownerColor=(index:number)=>{const id=ownership[String(index)];const playerIndex=players.findIndex(player=>player.id===id);return playerIndex>=0?ownerColors[playerIndex%ownerColors.length]:null},group=useRef<Group>(null),drag=")
needle="{cell.price&&<Text position={[0,.113,.29]}"
s=s.replace(needle,"{ownerColor(index)&&<mesh position={[0,.16,.17]}><cylinderGeometry args={[.105,.105,.045,24]}/><meshStandardMaterial color={ownerColor(index)!}/></mesh>}{cell.price&&<Text position={[0,.113,.29]}")
s=s.replace("export default function ClassicBoard3D(props:{size:BoardSize;positions:number[];players:Player[];dice:[number,number];rolling:boolean;onSelectCell:(index:number)=>void})", "export default function ClassicBoard3D(props:{size:BoardSize;positions:number[];players:Player[];dice:[number,number];rolling:boolean;onSelectCell:(index:number)=>void;ownership:Record<string,string>})")
p.write_text(s, encoding='utf-8')

# Gameplay: server-backed ownership plus chance card deck.
p=Path('frontend/src/components/GameScreen.tsx');s=p.read_text(encoding='utf-8')
s=s.replace("import type { Room, User } from '../api'", "import { api, type Room, type User } from '../api'")
s=s.replace("import ClassicBoard3D, { makeCells } from './ClassicBoard3D'", "import ClassicBoard3D, { makeCells } from './ClassicBoard3D'\nimport ChanceCard, { type ChanceEvent } from './ChanceCard'")
s=s.replace("  const [owned,setOwned] = useState<number[]>([])", "  const [liveRoom,setLiveRoom] = useState(room)\n  const [chanceEvent,setChanceEvent] = useState<ChanceEvent|null>(null)")
s=s.replace("  const cells = useMemo(() => makeCells(room.boardSize),[room.boardSize])", "  const cells = useMemo(() => makeCells(liveRoom.boardSize),[liveRoom.boardSize])")
# Poll ownership so all clients see purchases.
effect_marker="  useEffect(() => {\n    setTimeLeft"
poll="""  useEffect(() => {
    const timer=window.setInterval(()=>api.getRoom(room.code).then(({room})=>setLiveRoom(room)).catch(()=>null),1200)
    return()=>window.clearInterval(timer)
  },[room.code])

"""
s=s.replace(effect_marker,poll+effect_marker)
# Chance deck.
marker="  const finishTurn = () => {"
deck="""  const chanceDeck:ChanceEvent[]=[
    {id:'owl',title:'Сова на скакалці',text:'Сова провела ранкову руханку для всього району. Місто платить за спортивну ініціативу.',amount:120,art:'owl'},
    {id:'bus',title:'Бусифікація маршруту',text:'Твій район отримав новий міський бус. Пасажири задоволені, каса теж.',amount:150,art:'bus'},
    {id:'rich',title:'Я не з такої сім’ї',text:'Твій фінансовий план виявився із багатої сім’ї. Банк повертає дивіденди.',amount:100,art:'rich'},
    {id:'cotton',title:'Економічна бавовна',text:'Ціни на сусідній вулиці ефектно згоріли. Ремонт коштує грошей.',amount:-90,art:'fire'},
  ]

"""
s=s.replace(marker,deck+marker)
# Replace chance meme logic.
old="""              const lines=['Доброго вечора, ми з КупиМіста. Банк дарує 100 ₴.','Пес Патрон тримає район. Отримай 80 ₴ за безпечний маршрут.','Бавовна цін на оренду: отримай компенсацію 120 ₴.']
              setMeme(lines[Math.floor(Math.random()*lines.length)])
              window.setTimeout(()=>setMeme(''),2800)"""
new="""              const event=chanceDeck[Math.floor(Math.random()*chanceDeck.length)]
              setChanceEvent(event)
              setBalance(value=>Math.max(0,value+event.amount))"""
s=s.replace(old,new)
# Don't finish turn immediately if chance card must be acknowledged.
s=s.replace("            finishTurn()\n          }\n        },Math.max", "            if(landed.kind!=='chance')finishTurn()\n          }\n        },Math.max")
# Ownership derive and server purchase.
s=s.replace("  const canBuy=standingOnSelected&&selected.kind==='city'&&!owned.includes(selectedCell)&&balance>=", "  const ownerId=liveRoom.ownership?.[String(selectedCell)]\n  const owner=players.find(player=>player.id===ownerId)\n  const canBuy=standingOnSelected&&selected.kind==='city'&&!ownerId&&balance>=")
s=s.replace("const buy=()=>{if(!canBuy)return;setBalance(value=>value-(selected.price||0));setOwned(value=>[...value,selectedCell]);playUiSound('success');finishTurn()}", "const buy=async()=>{if(!canBuy)return;try{const result=await api.purchaseProperty(room.code,{cellIndex:selectedCell,price:selected.price||0});setLiveRoom(result.room);setBalance(value=>value-(selected.price||0));playUiSound('success');finishTurn()}catch{playUiSound('click')}}")
# Pass ownership.
s=s.replace("onSelectCell={(index)=>{setSelectedCell(index);setCardOpen(true)}}/>", "onSelectCell={(index)=>{setSelectedCell(index);setCardOpen(true)}} ownership={liveRoom.ownership||{}}/>")
# Owner UI replaces local owned state.
s=s.replace("{owned.includes(selectedCell)?<div className=\"ownedLabel\"><Check/> Це твоя власність</div>:standingOnSelected", "{ownerId?<div className=\"ownedLabel\"><Check/> {ownerId===user.id?'Це твоя власність':`Власник: ${owner?.name||'інший гравець'}`}</div>:standingOnSelected")
# Add chance card rendering.
needle="      <AnimatePresence>{meme&&"
s=s.replace(needle,"      <AnimatePresence>{chanceEvent&&<ChanceCard event={chanceEvent} onContinue={()=>{setChanceEvent(null);finishTurn()}}/>}</AnimatePresence>\n"+needle)
p.write_text(s, encoding='utf-8')

# Backend shared ownership endpoint.
p=Path('backend/cmd/api/main.go');s=p.read_text(encoding='utf-8')
s=s.replace('BoardSize string `json:"boardSize"`; Players', 'BoardSize string `json:"boardSize"`; Ownership map[string]string `json:"ownership"`; Players')
s=s.replace('BoardSize:"standard",Players:', 'BoardSize:"standard",Ownership:map[string]string{},Players:')
route='''    protected.HandleFunc("POST /api/rooms/{code}/properties",func(w http.ResponseWriter,r *http.Request){var in struct{CellIndex int `json:"cellIndex"`;Price int `json:"price"`};if readJSON(r,&in)!=nil||in.CellIndex<0||in.Price<0{fail(w,400,"Некоректна власність");return};code:=strings.ToUpper(r.PathValue("code"));user:=mustUser(r);store.mu.Lock();defer store.mu.Unlock();room,ok:=store.rooms[code];if !ok||!containsPlayer(room,user.ID){fail(w,404,"Кімнату не знайдено");return};key:=strconv.Itoa(in.CellIndex);if _,exists:=room.Ownership[key];exists{fail(w,409,"Ця клітинка вже має власника");return};room.Ownership[key]=user.ID;writeJSON(w,200,map[string]any{"room":room})})
'''
s=s.replace('    protected.HandleFunc("POST /api/rooms/{code}/ready"',route+'    protected.HandleFunc("POST /api/rooms/{code}/ready"')
s=s.replace('"strings"', '"strings"\n    "strconv"')
p.write_text(s, encoding='utf-8')
PY

cat >> frontend/src/styles.css <<'EOF'
/* Shared ownership markers and illustrated chance cards */
.chanceBackdrop{position:absolute;inset:0;z-index:30;background:oklch(18% .03 278/.58);display:grid;place-items:center;padding:20px}.chanceCard{width:min(430px,100%);background:var(--yellow);border:4px solid var(--ink);border-radius:24px;box-shadow:12px 12px 0 var(--ink);padding:24px;position:relative;text-align:center}.chanceClose{position:absolute;right:12px;top:12px;width:38px;height:38px;border:2px solid var(--ink);border-radius:50%;background:var(--paper);display:grid;place-items:center;cursor:pointer}.chanceClose svg{width:17px}.chanceLabel{font-size:9px;font-weight:900;letter-spacing:.14em}.chanceArt{height:180px;margin:8px 0}.chanceArt svg{height:100%;max-width:100%}.chanceCard h2{font-family:Unbounded;font-size:29px;line-height:1.05;letter-spacing:-.05em}.chanceCard p{font-size:13px;line-height:1.5;font-weight:750;margin:12px auto;max-width:36ch}.chanceCard>strong{display:block;font-family:Unbounded;font-size:27px;margin:12px}.chanceCard .positive{color:oklch(45% .15 151)}.chanceCard .negative{color:var(--red)}.chanceContinue{min-height:47px;width:100%;border:3px solid var(--ink);border-radius:11px;background:var(--paper);font-weight:900;display:flex;align-items:center;justify-content:center;gap:8px;cursor:pointer}.chanceContinue svg{width:18px}.rope,.bar,.road,.speed,.mustache,.coinMark{fill:none;stroke:var(--ink);stroke-width:7;stroke-linecap:round;stroke-linejoin:round}.owlBody,.owlHead,.busBody,.coat,.face,.cotton{fill:var(--paper);stroke:var(--ink);stroke-width:7}.owlWing,.owlBeak,.busTop,.flame{fill:var(--red);stroke:var(--ink);stroke-width:7}.owlEye,.busWindow{fill:var(--yellow);stroke:var(--ink);stroke-width:6}.owlPupil,.wheel{fill:var(--ink)}.road{stroke-width:5}.busBody{fill:var(--blue)}.busTop{fill:var(--paper)}.coat{fill:var(--blue)}.face{fill:var(--paper)}.hat{fill:var(--ink)}.coinShape{fill:var(--yellow);stroke:var(--ink);stroke-width:7}.cotton{fill:var(--paper)}.flame{fill:var(--red)}
EOF

(cd backend && gofmt -w cmd/api/main.go && go test ./...)
npm --prefix frontend run build

git add frontend/src/api.ts frontend/src/components/ClassicBoard3D.tsx frontend/src/components/GameScreen.tsx frontend/src/components/ChanceCard.tsx frontend/src/styles.css backend/cmd/api/main.go
git commit -m "feat: sync property ownership and add illustrated chance cards" || true
git push || echo "Виконай git push вручну"

echo "Готово. Перезапусти: docker compose down && docker compose up --build"
