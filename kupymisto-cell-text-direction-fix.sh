#!/usr/bin/env bash
set -euo pipefail

FILE="frontend/src/components/ClassicBoard3D.tsx"
if [ ! -f "$FILE" ]; then
  echo "Запусти файл у корені kupymisto."
  exit 1
fi

python3 <<'PY'
from pathlib import Path
p=Path('frontend/src/components/ClassicBoard3D.tsx')
s=p.read_text()
old='rotation={[-Math.PI/2,0,0]}'
new='rotation={[-Math.PI/2,0,Math.PI]}'
count=s.count(old)
if count < 2:
    raise SystemExit('Не знайдено назву та ціну клітинки. Перевір попередні оновлення.')
s=s.replace(old,new)
p.write_text(s)
print(f'Розвернуто текстових елементів: {count}')
PY

npm --prefix frontend run build

git add "$FILE"
git commit -m "fix: orient board cell labels toward outer edge" || true
git push || echo "Виконай git push вручну"

echo "Готово. Перезапусти: docker compose down && docker compose up --build"
