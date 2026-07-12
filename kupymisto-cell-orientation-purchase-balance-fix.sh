#!/usr/bin/env bash
set -euo pipefail

if [ ! -f frontend/src/components/ClassicBoard3D.tsx ] || [ ! -f frontend/src/components/GameScreen.tsx ]; then
  echo "Запусти файл у корені kupymisto після попередніх оновлень."
  exit 1
fi

python3 <<'PY'
from pathlib import Path

# Every edge gets one consistent local coordinate system:
# local +Z points outside, local -Z points toward the board center.
p=Path('frontend/src/components/ClassicBoard3D.tsx')
s=p.read_text(encoding='utf-8')
old="rotation=index<=edge?0:index<=edge*2?Math.PI/2:index<=edge*3?Math.PI:-Math.PI/2"
new="rotation=index<=edge?0:index<=edge*2?-Math.PI/2:index<=edge*3?Math.PI:Math.PI/2"
if old not in s:
    raise SystemExit('Не знайдено формулу повороту сторін дошки.')
s=s.replace(old,new)

# Classic property layout as seen from outside: color band on top, text below it.
s=s.replace("position={[0,.085,.38]}", "position={[0,.085,-.38]}")
s=s.replace("position={[0,.112,.10]}", "position={[0,.112,.02]}")
s=s.replace("position={[0,.113,-.27]}", "position={[0,.113,.29]}")
p.write_text(s, encoding='utf-8')

p=Path('frontend/src/components/GameScreen.tsx')
s=p.read_text(encoding='utf-8')

# Add the current user's real board position to purchase validation.
marker="  const selected=cells[selectedCell]\n"
insert="""  const userPlayerIndex=Math.max(0,players.findIndex(player=>player.id===user.id))
  const userPosition=positions[userPlayerIndex]??0
  const standingOnSelected=userPosition===selectedCell
"""
if marker not in s:
    raise SystemExit('Не знайдено дані вибраної клітинки.')
s=s.replace(marker,marker+insert)

old="  const canBuy=selected.kind==='city'&&!owned.includes(selectedCell)&&balance>=(selected.price||0)"
new="  const canBuy=standingOnSelected&&selected.kind==='city'&&!owned.includes(selectedCell)&&balance>=(selected.price||0)"
if old not in s:
    raise SystemExit('Не знайдено перевірку купівлі.')
s=s.replace(old,new)

# Permanent balance HUD, visible even when the property panel is closed.
board_needle="""      <div className="rotateHint">Права кнопка: обертання. Колесо: масштаб</div>
      <ClassicBoard3D"""
board_replacement="""      <div className="rotateHint">Права кнопка: обертання. Колесо: масштаб</div>
      <div className="gameBalanceHud"><small>МІЙ БАЛАНС</small><strong>{balance} ₴</strong></div>
      <ClassicBoard3D"""
if board_needle not in s:
    raise SystemExit('Не знайдено сцену дошки для балансу.')
s=s.replace(board_needle,board_replacement)

# Make the reason explicit instead of showing a misleading buy action.
old_button="<button className=\"buyProperty\" disabled={!canBuy} onClick={buy}>Купити за {selected.price} ₴</button>"
new_button="<button className=\"buyProperty\" disabled={!canBuy} onClick={buy}>{!standingOnSelected?'Спочатку стань на цю клітинку':balance<(selected.price||0)?'Недостатньо коштів':`Купити за ${selected.price} ₴`}</button>"
if old_button not in s:
    raise SystemExit('Не знайдено кнопку купівлі.')
s=s.replace(old_button,new_button)

# Explain click-to-inspect vs landing-to-buy.
note="<p className=\"propertyNote\">Повний комплект одного кольору збільшує оренду. Вартість будинків додамо на етапі економіки.</p>"
replacement="<p className=\"propertyNote\">{standingOnSelected?'Твоя фішка стоїть тут. Ділянку можна придбати.':'Це режим перегляду. Купівля доступна лише тоді, коли твоя фішка зупинилась на цій клітинці.'}</p>"
if note not in s:
    raise SystemExit('Не знайдено пояснення картки.')
s=s.replace(note,replacement)
p.write_text(s, encoding='utf-8')
PY

cat >> frontend/src/styles.css <<'EOF'
/* Permanent balance and corrected purchase affordance */
.gameBalanceHud{position:absolute;z-index:11;left:22px;top:94px;min-width:150px;background:var(--ink);color:var(--paper);border:3px solid var(--paper);border-radius:13px;padding:10px 14px;box-shadow:5px 5px 0 oklch(18% .03 151/.28);display:grid;gap:2px;pointer-events:none}.gameBalanceHud small{font-size:8px;font-weight:900;letter-spacing:.12em;color:oklch(82% .04 151)}.gameBalanceHud strong{font-family:Unbounded;font-size:18px;font-variant-numeric:tabular-nums}.buyProperty:disabled{background:oklch(84% .015 96);color:oklch(42% .025 278);opacity:1}.propertyNote{border:1px solid oklch(45% .035 278/.28);border-radius:8px;padding:9px 10px;background:oklch(92% .018 96)}
@media(max-width:700px){.gameBalanceHud{left:8px;top:58px;min-width:120px;padding:7px 10px}.gameBalanceHud strong{font-size:14px}}
EOF

npm --prefix frontend run build

git add frontend/src/components/ClassicBoard3D.tsx frontend/src/components/GameScreen.tsx frontend/src/styles.css
git commit -m "fix: normalize board edges and restrict purchase to occupied cell" || true
git push || echo "Виконай git push вручну"

echo "Готово. Перезапусти: docker compose down && docker compose up --build"
