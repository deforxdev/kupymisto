#!/usr/bin/env bash
set -euo pipefail

if [ ! -f frontend/src/components/ClassicBoard3D.tsx ] || [ ! -f frontend/src/components/GameScreen.tsx ] || [ ! -f backend/cmd/api/main.go ]; then
  echo "Запусти файл у корені kupymisto після попередніх оновлень."
  exit 1
fi

mkdir -p backend/data frontend/public/cards frontend/public/sounds

cat > backend/data/decks.json <<'EOF'
{
  "chance": [
    {"id":"owl-workout","title":"Сова на скакалці","text":"Ранкова руханка оживила район. Отримай міський грант.","amount":120,"art":"owl"},
    {"id":"bus-route","title":"Новий маршрут","text":"Бус привіз пасажирів просто до твоїх магазинів.","amount":150,"art":"bus"},
    {"id":"rich-family","title":"Я із багатої","text":"Фінансовий план нарешті спрацював. Отримай дивіденди.","amount":180,"art":"rich"},
    {"id":"patron-route","title":"Район під наглядом","text":"Безпечний маршрут збільшив потік відвідувачів.","amount":100,"art":"owl"},
    {"id":"good-evening","title":"Доброго вечора","text":"Місто зустріло туристів. Бізнес отримує прибуток.","amount":90,"art":"rich"},
    {"id":"poland-delivery","title":"Я у Польщі","text":"Експрес-доставка приїхала раніше. Отримай бонус.","amount":80,"art":"bus"},
    {"id":"horse-patience","title":"Don’t push the horses","text":"Ти не поспішав і дочекався вигідної ціни.","amount":110,"art":"rich"},
    {"id":"city-festival","title":"Фестиваль району","text":"Орендарі заробили більше й діляться прибутком.","amount":140,"art":"owl"},
    {"id":"cashback","title":"Міський кешбек","text":"Повернення за комунальні витрати.","amount":70,"art":"rich"},
    {"id":"startup","title":"Стартап злетів","text":"Твоя дивна ідея раптом стала прибутковою.","amount":200,"art":"bus"},
    {"id":"market-day","title":"Ярмарок вихідного дня","text":"Торгівля була вдалою.","amount":60,"art":"owl"},
    {"id":"rent-bonus","title":"Орендар не забув","text":"Неочікувано вчасна оплата.","amount":130,"art":"rich"},
    {"id":"coffee-laptop","title":"Кава пішла не туди","text":"Ноутбук програв зустріч із лате.","amount":-120,"art":"fire"},
    {"id":"missed-bus","title":"Бус поїхав без тебе","text":"Таксі через усе місто вдарило по бюджету.","amount":-80,"art":"bus"},
    {"id":"noise-fine","title":"Сова не спала","text":"Нічна активність закінчилась штрафом за шум.","amount":-60,"art":"owl"},
    {"id":"audit","title":"Банк має питання","text":"Комісія за надто мемні доходи.","amount":-100,"art":"rich"},
    {"id":"broken-pipe","title":"Трубу прорвало","text":"Терміновий ремонт у твоєму районі.","amount":-150,"art":"fire"},
    {"id":"wrong-parking","title":"Паркування майже вдалося","text":"Майже не рахується. Сплати штраф.","amount":-70,"art":"bus"},
    {"id":"rent-delay","title":"Орендар зник із радарів","text":"Цього місяця грошей менше.","amount":-90,"art":"rich"},
    {"id":"roof-repair","title":"Дах вирішив піти","text":"Ремонт не дочекається наступного кола.","amount":-180,"art":"fire"}
  ],
  "bad": [
    {"id":"bad-coffee","title":"Кава проти ноутбука","text":"Ремонт техніки.","amount":-140,"art":"fire"},
    {"id":"bad-taxi","title":"Останній бус уже поїхав","text":"Додому лише на таксі.","amount":-90,"art":"bus"},
    {"id":"bad-audit","title":"Фінансова перевірка","text":"Банк списав комісію.","amount":-120,"art":"rich"},
    {"id":"bad-owl","title":"Сова шуміла всю ніч","text":"Штраф від сусідів.","amount":-70,"art":"owl"},
    {"id":"bad-road","title":"Асфальт зійшов зі снігом","text":"Район скидається на ремонт.","amount":-110,"art":"fire"},
    {"id":"bad-roof","title":"Дах дав задню","text":"Термінове відновлення будинку.","amount":-180,"art":"fire"},
    {"id":"bad-water","title":"Води нема, рахунок є","text":"Комунальний сюрприз.","amount":-80,"art":"owl"},
    {"id":"bad-window","title":"М’яч знайшов вікно","text":"Нове скло за твій рахунок.","amount":-60,"art":"owl"},
    {"id":"bad-delivery","title":"Посилка поїхала гуляти","text":"Компенсуй клієнту замовлення.","amount":-100,"art":"bus"},
    {"id":"bad-rent","title":"Оренда буде завтра","text":"Завтра теж не буде.","amount":-130,"art":"rich"},
    {"id":"bad-sign","title":"Вивіска втомилась","text":"Ремонт фасаду.","amount":-75,"art":"fire"},
    {"id":"bad-tax","title":"Знайшовся старий рахунок","text":"Він чомусь досі твій.","amount":-160,"art":"rich"}
  ]
}
EOF

cat > frontend/public/cards/HOW_TO_ADD.md <<'EOF'
# Як додати свою картку

1. Додай опис до `backend/data/decks.json` у масив `chance` або `bad`.
2. `amount` більше нуля додає гроші, менше нуля списує. Нуль поки нічого не змінює.
3. Поклади картинку сюди у форматі WebP. Ім'я файла має збігатися з `id`, наприклад `owl-workout.webp`.
4. Рекомендований розмір картинки: 900x1200 px.
5. Перезапусти API: `docker compose down && docker compose up --build`.

Баланс:
- `chance`: 20 карток, 12 хороших і 8 поганих.
- `bad`: 12 карток, усі погані.
- Хороші ефекти: +60...+200 ₴.
- Звичайні штрафи: -60...-130 ₴.
- Рідкі сильні штрафи: до -180 ₴.
EOF

cat > frontend/public/sounds/HOW_TO_ADD.md <<'EOF'
# Як додати свої звуки

Поклади файли у цю папку:
- `card-draw.ogg` або `card-draw.mp3`: клік по колоді.
- `card-open.ogg`: поява картки.
- `dice-roll.ogg`: кубики.
- `pawn-step.ogg`: рух фішки.
- `purchase.ogg`: купівля.

OGG бажаний, гучність нормалізуй приблизно до -14 LUFS. Якщо файла немає, гра використовує синтезований резервний звук.
EOF

python3 <<'PY'
from pathlib import Path
import re

# Distinct 3D decks: blue Chance and red Bad Luck.
p=Path('frontend/src/components/ClassicBoard3D.tsx')
s=p.read_text(encoding='utf-8')
s=s.replace("function ChanceDeck({drawNonce,onClick}:{drawNonce:number;onClick:()=>void})", "function ChanceDeck({drawNonce,onClick,kind}:{drawNonce:number;onClick:()=>void;kind:'chance'|'bad'})")
s=s.replace("color={index%2?'#e8bd32':'#244f95'}", "color={kind==='chance'?(index%2?'#e8bd32':'#244f95'):(index%2?'#f0d4c6':'#b63832')}")
s=s.replace("color=\"#e8bd32\" roughness={.46}", "color={kind==='chance'?'#e8bd32':'#b63832'} roughness={.46}")
s=s.replace(">ШАНС</Text>", ">{kind==='chance'?'ШАНС':'ХАЛЕПА'}</Text>")
s=s.replace("<ChanceDeck drawNonce={drawNonce} onClick={onChanceDeckClick}/><group position={[-1.55,.02,-.45]}><ChanceDeck drawNonce={drawNonce} onClick={onBadDeckClick}/>", "<ChanceDeck drawNonce={drawNonce} onClick={onChanceDeckClick} kind=\"chance\"/><group position={[-1.55,.02,-.45]}><ChanceDeck drawNonce={drawNonce} onClick={onBadDeckClick} kind=\"bad\"/>")
p.write_text(s, encoding='utf-8')

# Immediate single card display after a deck click, no wait for polling to rediscover it.
p=Path('frontend/src/components/GameScreen.tsx')
s=p.read_text(encoding='utf-8')
s=s.replace("import { playDiceRoll,playPawnMove,unlockAudio } from '../audio'", "import { playAssetSound,playDiceRoll,playPawnMove,playUiSound,unlockAudio } from '../audio'")
old=""" const draw=async(kind:'chance'|'bad')=>{if(pendingDeck!==kind||players[turn]?.id!==user.id)return;const result=kind==='chance'?await api.drawChance(room.code):await api.drawBadLuck(room.code);setLiveRoom(result.room);setPendingDeck(null);setPhase('card')}"""
new=""" const draw=async(kind:'chance'|'bad')=>{
  if(pendingDeck!==kind||players[turn]?.id!==user.id)return
  await unlockAudio()
  void playAssetSound('card-draw.ogg',()=>playUiSound('select'))
  const result=kind==='chance'?await api.drawChance(room.code):await api.drawBadLuck(room.code)
  setLiveRoom(result.room);setPendingDeck(null);setPhase('card')
  if(result.room.currentChance){
   shownNonce.current=result.room.currentChance.nonce
   setDrawNonce(result.room.currentChance.nonce)
   setChance(result.room.currentChance)
  }
 }"""
if old not in s: raise SystemExit('Не знайдено функцію draw')
s=s.replace(old,new)
p.write_text(s, encoding='utf-8')

# Chance card loads custom image by matching event id, with SVG as fallback.
p=Path('frontend/src/components/ChanceCard.tsx')
s=p.read_text(encoding='utf-8')
s=s.replace("<div className=\"chanceArt\">", "<div className=\"chanceArt\"><img className=\"customCardImage\" src={`/cards/${event.id}.webp`} alt=\"\" onError={e=>{e.currentTarget.style.display='none'}}/>")
p.write_text(s, encoding='utf-8')

# Backend reads editable JSON deck file. Replace literal deck declarations route-by-route.
p=Path('backend/cmd/api/main.go')
s=p.read_text(encoding='utf-8')
helper='''
type DeckConfig struct { Chance []ChanceCard `json:"chance"`; Bad []ChanceCard `json:"bad"` }
func loadDeck(kind string) []ChanceCard {
    raw,err:=os.ReadFile("data/decks.json")
    if err==nil { var cfg DeckConfig; if json.Unmarshal(raw,&cfg)==nil { if kind=="bad"&&len(cfg.Bad)>0{return cfg.Bad};if kind=="chance"&&len(cfg.Chance)>0{return cfg.Chance} } }
    if kind=="bad" { return []ChanceCard{{ID:"fallback-bad",Title:"Халепа",Text:"Несподіваний штраф.",Amount:-100,Art:"fire"}} }
    return []ChanceCard{{ID:"fallback-good",Title:"Шанс",Text:"Міський бонус.",Amount:100,Art:"rich"},{ID:"fallback-bad",Title:"Невдалий шанс",Text:"Комісія банку.",Amount:-70,Art:"fire"}}
}
'''
anchor='func containsPlayer('
if 'func loadDeck(' not in s:
    s=s.replace(anchor,helper+'\n'+anchor)
if '"os"' not in s:
    s=s.replace('\"encoding/json\"','\"encoding/json\"\n\t\"os\"')

def replace_deck(source, route, kind):
    start=source.find(route)
    if start<0: raise SystemExit(f'Не знайдено route {route}')
    next_route=source.find('protected.HandleFunc(',start+30)
    end=next_route if next_route>0 else len(source)
    chunk=source[start:end]
    pattern=r'deck\s*:=\s*\[\]ChanceCard\{[\s\S]*?\}\s*card\s*:=\s*deck'
    updated,n=re.subn(pattern,f'deck := loadDeck("{kind}")\n\t\tcard := deck',chunk,count=1)
    if n==0: raise SystemExit(f'Не знайдено literal deck для {kind}')
    return source[:start]+updated+source[end:]

s=replace_deck(s,'protected.HandleFunc("POST /api/rooms/{code}/bad-luck"','bad')
s=replace_deck(s,'protected.HandleFunc("POST /api/rooms/{code}/chance"','chance')
p.write_text(s, encoding='utf-8')
PY

cat >> frontend/src/styles.css <<'EOF'
/* Distinct decks and custom card image support */
.customCardImage{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;border-radius:14px;z-index:2}.chanceArt{position:relative;overflow:hidden;border-radius:14px}.chanceArt>svg{position:relative;z-index:1}.deckInstruction.chance{border-color:oklch(48% .18 257)}.deckInstruction.bad{border-color:oklch(48% .19 28)}
EOF

(cd backend && gofmt -w cmd/api/main.go && go test ./...)
npm --prefix frontend run build

git add backend/data/decks.json backend/cmd/api/main.go frontend/public/cards frontend/public/sounds frontend/src/components/ClassicBoard3D.tsx frontend/src/components/GameScreen.tsx frontend/src/components/ChanceCard.tsx frontend/src/styles.css
git commit -m "fix: separate decks, show cards once and add editable card balance" || true
git push || echo "Виконай git push вручну"

echo "Готово. Перезапусти: docker compose down && docker compose up --build"
