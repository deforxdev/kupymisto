#!/usr/bin/env bash
set -euo pipefail

if [ ! -f frontend/src/components/ClassicBoard3D.tsx ] || [ ! -f frontend/src/components/GameScreen.tsx ]; then
  echo "Запусти файл у корені kupymisto після попередніх оновлень."
  exit 1
fi

python3 <<'PY'
from pathlib import Path

p=Path('frontend/src/components/ClassicBoard3D.tsx')
s=p.read_text(encoding='utf-8')
# Remove center title/subtitle group entirely.
start=s.find('<group position={[0,.44,0]} rotation={[0,-Math.PI/4,0]}>')
if start != -1:
    end=s.find('</group>', start)
    if end == -1: raise SystemExit('Не знайдено закриття центрального тексту')
    s=s[:start]+s[end+8:]
# Lift token base safely above tile top. Tile center .43 + half .06 = .49, token bottom was around .21.
s=s.replace("ref.current.position.y=.5+Math.sin(raw*Math.PI)*.34", "ref.current.position.y=.86+Math.sin(raw*Math.PI)*.34")
s=s.replace("ref.current.position.y=.5\n", "ref.current.position.y=.86\n")
s=s.replace("position={[initial[0]+offset,.5,initial[2]+offset]}", "position={[initial[0]+offset,.86,initial[2]+offset]}")
p.write_text(s, encoding='utf-8')

p=Path('frontend/src/components/GameScreen.tsx')
s=p.read_text(encoding='utf-8')
old="""      setDice([a,b]); setPositions(old=>old.map((p,i)=>i===turn?(p+a+b)%cells.length:p)); setRolling(false); playPawnMove(a+b)
      window.setTimeout(()=>{ setTurn(value=>(value+1)%players.length); setTurnNoticeId(value=>value+1) },Math.max(900,(a+b)*190+260))
    },700)"""
new="""      setDice([a,b]); setRolling(false)
      window.setTimeout(() => {
        playPawnMove(a+b)
        setPositions(old=>old.map((p,i)=>i===turn?(p+a+b)%cells.length:p))
        window.setTimeout(()=>{ setTurn(value=>(value+1)%players.length); setTurnNoticeId(value=>value+1) },Math.max(900,(a+b)*190+260))
      }, 1000)
    },700)"""
if old not in s: raise SystemExit('Не знайдено таймінг кидка. Переконайся, що попередній фікс застосовано.')
s=s.replace(old,new)
p.write_text(s, encoding='utf-8')
PY

npm --prefix frontend run build

git add frontend/src/components/ClassicBoard3D.tsx frontend/src/components/GameScreen.tsx
git commit -m "fix: clear board center and delay raised pawn movement" || true
git push || echo "Виконай git push вручну"

echo "Готово. Перезапусти: docker compose down && docker compose up --build"
