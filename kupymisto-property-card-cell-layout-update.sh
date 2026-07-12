#!/usr/bin/env bash
set -euo pipefail

if [ ! -f frontend/src/components/ClassicBoard3D.tsx ] || [ ! -f frontend/src/components/GameScreen.tsx ]; then
  echo "Запусти файл у корені kupymisto після попередніх оновлень."
  exit 1
fi

python3 <<'PY'
from pathlib import Path

# Fix edge layout and expose cell click selection to the game UI.
p=Path('frontend/src/components/ClassicBoard3D.tsx')
s=p.read_text(encoding='utf-8')
s=s.replace("function BoardModel({size,positions,players,dice,rolling}:{size:BoardSize;positions:number[];players:Player[];dice:[number,number];rolling:boolean})", "function BoardModel({size,positions,players,dice,rolling,onSelectCell}:{size:BoardSize;positions:number[];players:Player[];dice:[number,number];rolling:boolean;onSelectCell:(index:number)=>void})")
# The color strip must sit on the outer edge of every tile. Group rotation handles all four sides.
s=s.replace("position={[0,.085,-.38]}", "position={[0,.085,.38]}")
# Previous global 180 degree text rotation made the near edge backwards. Local zero plus edge group rotation faces every label outward.
s=s.replace("rotation={[-Math.PI/2,0,Math.PI]}", "rotation={[-Math.PI/2,0,0]}")
# Move price toward the inner half and name toward the outer half, matching a classic property card.
s=s.replace("position={[0,.112,.05]}", "position={[0,.112,.10]}")
s=s.replace("position={[0,.113,.28]}", "position={[0,.113,-.27]}")
# Make each 3D tile clickable and keyboard-independent through pointer input.
old="<group key={index} position={[x,.43,z]} rotation={[0,rotation,0]}>"
new="<group key={index} position={[x,.43,z]} rotation={[0,rotation,0]} onClick={(event)=>{event.stopPropagation();onSelectCell(index)}} onPointerOver={(event)=>{event.stopPropagation();gl.domElement.style.cursor='pointer'}} onPointerOut={()=>{gl.domElement.style.cursor=drag.current.active?'grabbing':'default'}}>"
if old not in s: raise SystemExit('Не знайдено 3D-групу клітинки')
s=s.replace(old,new)
# Public component accepts selection callback.
s=s.replace("export default function ClassicBoard3D(props:{size:BoardSize;positions:number[];players:Player[];dice:[number,number];rolling:boolean})", "export default function ClassicBoard3D(props:{size:BoardSize;positions:number[];players:Player[];dice:[number,number];rolling:boolean;onSelectCell:(index:number)=>void})")
p.write_text(s, encoding='utf-8')

# Add landing card, manual cell inspection and local purchase prototype.
p=Path('frontend/src/components/GameScreen.tsx')
s=p.read_text(encoding='utf-8')
s=s.replace("import { LogOut, Settings, Volume2 } from 'lucide-react'", "import { Building2, Check, Home, LogOut, Settings, Volume2, X } from 'lucide-react'")
s=s.replace("  const [turnNoticeId,setTurnNoticeId] = useState(1)", "  const [turnNoticeId,setTurnNoticeId] = useState(1)\n  const [selectedCell,setSelectedCell] = useState(0)\n  const [owned,setOwned] = useState<number[]>([])\n  const [balance,setBalance] = useState(1500)\n  const [cardOpen,setCardOpen] = useState(false)")
# Select destination only after the one-second pause, exactly when movement starts.
old="""        playPawnMove(a+b)
        setPositions(old=>old.map((p,i)=>i===turn?(p+a+b)%cells.length:p))"""
new="""        const destination=(positions[turn]+a+b)%cells.length
        setSelectedCell(destination)
        setCardOpen(true)
        playPawnMove(a+b)
        setPositions(old=>old.map((p,i)=>i===turn?destination:p))"""
if old not in s: raise SystemExit('Не знайдено початок руху фішки')
s=s.replace(old,new)
# Pass click handler to 3D board.
s=s.replace("<ClassicBoard3D size={room.boardSize} positions={positions} players={players} dice={dice} rolling={rolling}/>", "<ClassicBoard3D size={room.boardSize} positions={positions} players={players} dice={dice} rolling={rolling} onSelectCell={(index)=>{setSelectedCell(index);setCardOpen(true)}}/>")
# Insert derived values before return.
marker="  return <main className=\"classicGame\">"
derived="""  const selected=cells[selectedCell]
  const baseRent=selected.price ? Math.max(10,Math.round(selected.price*.12/5)*5) : 0
  const oneHouse=baseRent*3
  const twoHouses=baseRent*7
  const threeHouses=baseRent*12
  const canBuy=selected.kind==='city'&&!owned.includes(selectedCell)&&balance>=(selected.price||0)
  const buy=()=>{if(!canBuy)return;setBalance(value=>value-(selected.price||0));setOwned(value=>[...value,selectedCell]);playUiSound('success')}

"""
s=s.replace(marker,derived+marker)
# Restore playUiSound import for purchase feedback.
s=s.replace("import { playDiceRoll, playPawnMove, unlockAudio } from '../audio'", "import { playDiceRoll, playPawnMove, playUiSound, unlockAudio } from '../audio'")
# Insert property panel before section close.
needle="""      <div className="diceAction"><span>{dice[0]} + {dice[1]}</span><button onClick={roll} disabled={rolling||players[turn]?.id!==user.id}>{rolling?'Кубики летять':'Кинути кубики'}</button></div>
    </section>"""
panel="""      <div className="diceAction"><span>{dice[0]} + {dice[1]}</span><button onClick={roll} disabled={rolling||players[turn]?.id!==user.id}>{rolling?'Кубики летять':'Кинути кубики'}</button></div>
      <AnimatePresence>{cardOpen&&<motion.aside className="propertyPanel" initial={{opacity:0,x:60}} animate={{opacity:1,x:0}} exit={{opacity:0,x:70}} transition={{duration:.36,ease:[.16,1,.3,1]}}>
        <button className="propertyClose" onClick={()=>setCardOpen(false)} aria-label="Закрити картку"><X/></button>
        <div className="propertyBand" style={{background:selected.color}}/>
        <span className="propertyType">{selected.kind==='city'?'МІСЬКА ВЛАСНІСТЬ':selected.kind==='station'?'ТРАНСПОРТ':selected.kind==='chance'?'ПОДІЯ':selected.kind==='tax'?'МІСЬКИЙ ЗБІР':'КУТОВА КЛІТИНКА'}</span>
        <h2>{selected.name}</h2>
        {selected.kind==='city'&&<>
          <div className="propertyPrice"><span>Ціна ділянки</span><strong>{selected.price} ₴</strong></div>
          <div className="rentTable"><div><span>Без будинку</span><b>{baseRent} ₴</b></div><div><span><Home/> 1 будинок</span><b>{oneHouse} ₴</b></div><div><span><Home/> 2 будинки</span><b>{twoHouses} ₴</b></div><div><span><Building2/> 3 будинки</span><b>{threeHouses} ₴</b></div></div>
          <p className="propertyNote">Повний комплект одного кольору збільшує оренду. Вартість будинків додамо на етапі економіки.</p>
          {owned.includes(selectedCell)?<div className="ownedLabel"><Check/> Це твоя власність</div>:<div className="propertyActions"><button className="buyProperty" disabled={!canBuy} onClick={buy}>Купити за {selected.price} ₴</button><button className="skipProperty" onClick={()=>setCardOpen(false)}>Не купувати</button></div>}
        </>}
        {selected.kind!=='city'&&<p className="specialCellText">Ця клітинка не продається. Її дія спрацює після завершення ходу.</p>}
        <div className="panelBalance">Баланс: <strong>{balance} ₴</strong></div>
      </motion.aside>}</AnimatePresence>
    </section>"""
if needle not in s: raise SystemExit('Не знайдено місце для картки клітинки')
s=s.replace(needle,panel)
p.write_text(s, encoding='utf-8')
PY

cat >> frontend/src/styles.css <<'EOF'
/* Interactive property information */
.propertyPanel{position:absolute;z-index:15;right:20px;top:76px;width:min(330px,calc(100vw - 40px));max-height:calc(100% - 96px);overflow:auto;background:var(--paper);border:3px solid var(--ink);border-radius:18px;box-shadow:8px 8px 0 var(--ink);padding:0 22px 22px}.propertyBand{height:34px;margin:0 -22px 20px;border-bottom:3px solid var(--ink)}.propertyClose{position:absolute;right:9px;top:7px;width:34px;height:34px;border:2px solid var(--ink);border-radius:50%;background:var(--paper);display:grid;place-items:center;cursor:pointer}.propertyClose svg{width:16px}.propertyType{font-size:9px;font-weight:900;letter-spacing:.12em;color:var(--muted)}.propertyPanel h2{font-family:Unbounded;font-size:28px;line-height:1.05;letter-spacing:-.05em;margin:8px 0 20px}.propertyPrice{display:flex;justify-content:space-between;align-items:baseline;border-block:2px solid var(--ink);padding:13px 0}.propertyPrice span,.panelBalance{font-size:11px;font-weight:850}.propertyPrice strong{font-family:Unbounded;font-size:18px}.rentTable{padding:8px 0;border-bottom:2px solid var(--ink)}.rentTable div{display:flex;justify-content:space-between;align-items:center;padding:8px 0;font-size:12px}.rentTable span{display:flex;align-items:center;gap:6px;font-weight:750}.rentTable svg{width:14px;height:14px}.propertyNote,.specialCellText{font-size:11px;line-height:1.5;font-weight:700;color:var(--muted);margin:14px 0}.propertyActions{display:grid;gap:8px}.buyProperty,.skipProperty{min-height:44px;border:2px solid var(--ink);border-radius:10px;font-weight:900;cursor:pointer}.buyProperty{background:var(--green)}.buyProperty:disabled{opacity:.4;cursor:not-allowed}.skipProperty{background:transparent}.ownedLabel{min-height:45px;background:var(--green);border:2px solid var(--ink);border-radius:10px;display:flex;align-items:center;justify-content:center;gap:8px;font-weight:900;font-size:12px}.ownedLabel svg{width:17px}.panelBalance{margin-top:14px;text-align:center}.panelBalance strong{font-variant-numeric:tabular-nums}.boardOnly canvas{cursor:default}
@media(max-width:700px){.propertyPanel{right:10px;top:62px;max-height:calc(100% - 138px);width:calc(100vw - 20px)}.propertyPanel h2{font-size:23px}}
EOF

npm --prefix frontend run build

git add frontend/src/components/ClassicBoard3D.tsx frontend/src/components/GameScreen.tsx frontend/src/styles.css
git commit -m "feat: orient property cells outward and add interactive property card" || true
git push || echo "Виконай git push вручну"

echo "Готово. Перезапусти: docker compose down && docker compose up --build"
