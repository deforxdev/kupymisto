import {
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
} from "react";
import { AnimatePresence, motion } from "framer-motion";
import {
  ArrowLeftRight,
  Clock3,
  LogOut,
  Palette,
  Settings,
  Volume2,
  VolumeX,
} from "lucide-react";
import { api, isAdminEmail, type Room, type User } from "../api";
import {
  isAudioMuted,
  playAssetSound,
  playDiceRoll,
  playMoneySound,
  playPawnMove,
  playUiSound,
  setAudioMuted,
  unlockAudio,
} from "../audio";
import { houseCost, propertyRent as calculatePropertyRent } from "../economy";
import ClassicBoard3D, { makeCells, type BoardTheme } from "./ClassicBoard3D";
import ChanceCard, { type ChanceEvent } from "./ChanceCard";
import TradePanel, { IncomingTrades } from "./TradePanel";
import AdminPanel from "./AdminPanel";
import GameStartSplash from "./GameStartSplash";
import MoneyBurst from "./MoneyBurst";

type Props = { room: Room; user: User; onExit: () => void };
const safeDice = (dice?: [number, number]): [number, number] =>
  dice && dice.every((value) => value >= 1 && value <= 6) ? dice : [1, 1];
export default function GameScreen({ room, user, onExit }: Props) {
  const [liveRoom, setLiveRoom] = useState(room),
    players = liveRoom.players;
  const cells = useMemo(
    () => makeCells(liveRoom.boardSize),
    [liveRoom.boardSize],
  );
  const [positions, setPositions] = useState(
      room.positions?.length === players.length
        ? room.positions
        : players.map(() => 0),
    ),
    [dice, setDice] = useState<[number, number]>(safeDice(room.dice)),
    [rolling, setRolling] = useState(false),
    [gameError, setGameError] = useState(""),
    [moneyEffect, setMoneyEffect] = useState<{
      id: number;
      delta: number;
    } | null>(null);
  const turn = liveRoom.turn || 0;
  const [phase, setPhase] = useState<"roll" | "moving" | "decision" | "card">(
      "roll",
    ),
    [timeLeft, setTimeLeft] = useState(liveRoom.turnSeconds || 60);
  const [selected, setSelected] = useState(0),
    [propertyOpen, setPropertyOpen] = useState(false),
    [pendingDeck, setPendingDeck] = useState<"chance" | "bad" | null>(null),
    [chance, setChance] = useState<ChanceEvent | null>(null),
    [casinoOpen, setCasinoOpen] = useState(false),
    [drawNonce, setDrawNonce] = useState(0),
    [tradeOpen, setTradeOpen] = useState(false),
    [adminOpen, setAdminOpen] = useState(false),
    [soundEnabled, setSoundEnabled] = useState(!isAudioMuted()),
    [showStart, setShowStart] = useState(true),
    [boardTheme, setBoardTheme] = useState<BoardTheme>(() => {
      const saved = localStorage.getItem("kupymisto_board_theme");
      return saved === "midnight" || saved === "sunset" || saved === "custom"
        ? saved
        : "meadow";
    }),
    [customThemeColor, setCustomThemeColor] = useState(() => {
      return localStorage.getItem("kupymisto_custom_theme") || "#7c3aed";
    });
  const shownNonce = useRef(0),
    finishing = useRef(false),
    previousBalance = useRef(liveRoom.balances?.[user.id] ?? 1500),
    meIndex = Math.max(
      0,
      players.findIndex((p) => p.id === user.id),
    ),
    balance = liveRoom.balances?.[user.id] ?? 1500,
    current = cells[selected],
    ownerId = liveRoom.ownership?.[String(selected)],
    standing = (positions[meIndex] ?? 0) === selected;
  const sameColorCells =
      current?.kind === "city"
        ? cells.filter(
            (cell) => cell.kind === "city" && cell.color === current.color,
          )
        : [],
    ownsColorGroup =
      sameColorCells.length > 0 &&
      sameColorCells.every((cell) => {
        const index = cells.indexOf(cell);
        return liveRoom.ownership?.[String(index)] === user.id;
      }),
    maxHouses = ownsColorGroup ? 5 : 3,
    currentHouses = liveRoom.houses?.[String(selected)] || 0,
    nextHouseCost = houseCost(currentHouses);
  const capitalRows = players
    .map((player) => ({
      id: player.id,
      name: player.name,
      value: liveRoom.capital?.[player.id] ?? 0,
    }))
    .sort((a, b) => b.value - a.value);
  useEffect(() => {
    const timer = window.setTimeout(() => setShowStart(false), 4800);
    void playAssetSound("game-start.ogg", () => playUiSound("success"));
    return () => window.clearTimeout(timer);
  }, []);
  useEffect(() => {
    if (liveRoom.winnerId)
      void playAssetSound("game-win.ogg", () => playUiSound("success"));
  }, [liveRoom.winnerId]);
  useEffect(() => {
    if (balance === previousBalance.current) return;
    const delta = balance - previousBalance.current;
    previousBalance.current = balance;
    setMoneyEffect({ id: Date.now(), delta });
    void unlockAudio();
    void playAssetSound(delta > 0 ? "money-in.ogg" : "money-out.ogg", () =>
      playMoneySound(delta > 0),
    );
    const timeout = window.setTimeout(() => setMoneyEffect(null), 1800);
    return () => window.clearTimeout(timeout);
  }, [balance]);
  const finishTurn = () => {
    if (finishing.current) return;
    finishing.current = true;
    setPropertyOpen(false);
    setPendingDeck(null);
    setChance(null);
    setPhase("roll");
    setTimeLeft(liveRoom.turnSeconds || 60);
    void api
      .finishTurn(room.code)
      .then(({ room: r }) => {
        setLiveRoom(r);
      })
      .catch((cause) => {
        if (cause instanceof Error) setGameError(cause.message);
      })
      .finally(() => {
        finishing.current = false;
      });
  };
  useEffect(() => {
    const t = setInterval(
      () =>
        api
          .getRoom(room.code)
          .then(({ room: r }) => {
            setLiveRoom(r);
            if (r.positions?.length === players.length)
              setPositions(r.positions);
            setDice(safeDice(r.dice));
            if (
              r.currentChance &&
              r.currentChance.nonce !== shownNonce.current
            ) {
              shownNonce.current = r.currentChance.nonce;
              setDrawNonce(
                r.currentChance.deck === "bad"
                  ? -r.currentChance.nonce
                  : r.currentChance.nonce,
              );
              setChance(r.currentChance);
            }
          })
          .catch((cause) => {
            if (
              cause instanceof Error &&
              "status" in cause &&
              cause.status === 404
            )
              onExit();
          }),
      900,
    );
    return () => clearInterval(t);
  }, [room.code, players.length]);
  useEffect(() => {
    const deadline =
      phase === "decision" ? liveRoom.decisionDeadline : liveRoom.turnDeadline;
    if (!deadline) return;
    const syncTime = () =>
      setTimeLeft(
        Math.max(0, Math.ceil((Date.parse(deadline) - Date.now()) / 1000)),
      );
    syncTime();
    const timer = window.setInterval(syncTime, 250);
    return () => window.clearInterval(timer);
  }, [phase, liveRoom.turnDeadline, liveRoom.decisionDeadline]);
  useEffect(() => {
    if (phase !== "roll" && phase !== "decision") return;
    if (players[turn]?.id !== user.id) return;
    if (
      phase === "decision" ? liveRoom.decisionDeadline : liveRoom.turnDeadline
    )
      return;
    if (timeLeft <= 0) {
      finishTurn();
      return;
    }
    const t = setTimeout(() => setTimeLeft((v) => v - 1), 1000);
    return () => clearTimeout(t);
  }, [timeLeft, phase]);
  const roll = async () => {
    if (
      liveRoom.winnerId ||
      rolling ||
      phase !== "roll" ||
      players[turn]?.id !== user.id
    )
      return;
    await unlockAudio();
    setPhase("moving");
    setRolling(true);
    setGameError("");
    playDiceRoll();
    try {
      const result = await api.roll(room.code);
      const nextRoom = result.room;
      const nextDice = safeDice(nextRoom.dice);
      const nextPosition = nextRoom.positions?.[turn] ?? positions[turn] ?? 0;
      const autoFinished = result.autoFinished;
      setLiveRoom(nextRoom);
      setDice(nextDice);
      setPositions(nextRoom.positions);
      setRolling(false);
      setTimeout(() => {
        playPawnMove(nextDice[0] + nextDice[1]);
        setSelected(nextPosition);
        setTimeout(
          () => {
            const landed = cells[nextPosition];
            if (autoFinished) {
              setPhase("roll");
              setTimeLeft(nextRoom.turnSeconds || 60);
            } else if (landed.kind === "city") {
              const decision = nextRoom.decisionSeconds || 45;
              setPropertyOpen(true);
              setTimeLeft(decision);
              setPhase("decision");
            } else if (landed.kind === "chance") {
              setPendingDeck("chance");
              setPhase("card");
            } else if (landed.kind === "tax") {
              setPendingDeck("bad");
              setPhase("card");
            } else if (landed.kind === "casino") {
              setCasinoOpen(true);
              setPhase("card");
            } else finishTurn();
          },
          (nextDice[0] + nextDice[1]) * 190 + 250,
        );
      }, 1000);
    } catch (cause) {
      setRolling(false);
      setPhase("roll");
      setGameError(
        cause instanceof Error ? cause.message : "Не вдалося кинути кубики",
      );
    }
  };
  const draw = async (kind: "chance" | "bad") => {
    if (pendingDeck !== kind || players[turn]?.id !== user.id) return;
    await unlockAudio();
    void playAssetSound("card-draw.ogg", () => playUiSound("select"));
    const result =
      kind === "chance"
        ? await api.drawChance(room.code)
        : await api.drawBadLuck(room.code);
    setLiveRoom(result.room);
    setPendingDeck(null);
    setPhase("card");
    if (result.room.currentChance) {
      shownNonce.current = result.room.currentChance.nonce;
      setDrawNonce(
        result.room.currentChance.deck === "bad"
          ? -result.room.currentChance.nonce
          : result.room.currentChance.nonce,
      );
      setChance(result.room.currentChance);
    }
  };
  const closeCard = async () => {
    setChance(null);
    if (players[turn]?.id === user.id) {
      await api.clearChance(room.code).catch(() => null);
      finishTurn();
    }
  };
  const spinCasino = async () => {
    void playAssetSound("casino-spin.ogg", () => playUiSound("click"));
    const result = await api.casino(room.code);
    setLiveRoom(result.room);
    setCasinoOpen(false);
    setPhase("roll");
  };
  const skipCasino = () => {
    setCasinoOpen(false);
    finishTurn();
  };
  const buy = async () => {
    if (!standing || ownerId || balance < (current.price || 0)) return;
    setGameError("");
    try {
      void playAssetSound("purchase.ogg", () => playUiSound("success"));
      setLiveRoom(
        (
          await api.purchaseProperty(room.code, {
            cellIndex: selected,
            price: current.price || 0,
          })
        ).room,
      );
      finishTurn();
    } catch (cause) {
      setGameError(
        cause instanceof Error ? cause.message : "Не вдалося купити клітинку",
      );
    }
  };
  const buildHouse = async () => {
    if (
      ownerId !== user.id ||
      !current.price ||
      balance < nextHouseCost ||
      currentHouses >= maxHouses
    )
      return;
    void playAssetSound("house-place.ogg", () => playUiSound("success"));
    setLiveRoom(
      (await api.buildHouse(room.code, { cellIndex: selected })).room,
    );
  };
  const toggleGameSound = () => {
    const next = !soundEnabled;
    setSoundEnabled(next);
    setAudioMuted(!next);
  };
  const cycleTheme = () => {
    const next: BoardTheme =
      boardTheme === "meadow"
        ? "midnight"
        : boardTheme === "midnight"
          ? "sunset"
          : "meadow";
    setBoardTheme(next);
    localStorage.setItem("kupymisto_board_theme", next);
  };
  const chooseCustomTheme = (color: string) => {
    setCustomThemeColor(color);
    setBoardTheme("custom");
    localStorage.setItem("kupymisto_custom_theme", color);
    localStorage.setItem("kupymisto_board_theme", "custom");
  };
  const propertyRent = current.price
    ? calculatePropertyRent(
        current.price,
        liveRoom.houses?.[String(selected)] || 0,
      )
    : 0;
  const canBuy =
    standing &&
    current.kind === "city" &&
    !ownerId &&
    balance >= (current.price || 0);
  return (
    <main
      className={`classicGame theme-${boardTheme}`}
      style={{ "--custom-theme-color": customThemeColor } as CSSProperties}
    >
      <header className="classicHeader">
        <div className="gameBrand">
          <span>КупиМісто</span>
          <small>{room.code}</small>
        </div>
        <div className="topTurn">
          <strong>
            {players[turn]?.id === user.id
              ? "ВАШ ХІД"
              : `ХІД: ${players[turn]?.name}`}
          </strong>
          <span>
            <Clock3 />
            {phase === "moving"
              ? "рух"
              : phase === "card"
                ? "картка"
                : `${timeLeft} с`}
          </span>
          <small className="roundCounter">
            Коло{" "}
            {Math.min((liveRoom.round ?? 0) + 1, liveRoom.roundLimit ?? 30)} /{" "}
            {liveRoom.roundLimit ?? 30}
          </small>
        </div>
        <div className="gameTools">
          <button
            onClick={toggleGameSound}
            aria-label={soundEnabled ? "Вимкнути звук" : "Увімкнути звук"}
            title={soundEnabled ? "Вимкнути звук" : "Увімкнути звук"}
          >
            {soundEnabled ? <Volume2 /> : <VolumeX />}
          </button>
          <button
            onClick={cycleTheme}
            aria-label="Змінити тему поля"
            title="Змінити тему поля"
          >
            <Palette />
            <span>Тема</span>
          </button>
          <label
            className="themeColorPicker"
            title="Власний колір поля"
            aria-label="Власний колір поля"
          >
            <input
              type="color"
              value={customThemeColor}
              onChange={(event) => chooseCustomTheme(event.target.value)}
            />
            <span style={{ backgroundColor: customThemeColor }} />
          </label>
          <button onClick={() => setTradeOpen(true)}>
            <ArrowLeftRight />
            <span>Обмін</span>
          </button>
          {isAdminEmail(user.email, user.name) && (
            <button onClick={() => setAdminOpen(true)}>
              <Settings />
              <span>Адмін</span>
            </button>
          )}
          <button onClick={onExit}>
            <LogOut />
            <span>Вийти</span>
          </button>
        </div>
      </header>
      <section className="boardOnly">
        <AnimatePresence>
          {moneyEffect && (
            <MoneyBurst key={moneyEffect.id} delta={moneyEffect.delta} />
          )}
        </AnimatePresence>
        <AnimatePresence>
          {showStart && (
            <GameStartSplash
              roomName={room.name}
              onComplete={() => setShowStart(false)}
            />
          )}
        </AnimatePresence>
        <div className="rotateHint">
          Права кнопка: обертання. Колесо: масштаб
        </div>
        <div className="gameBalanceHud">
          <small>МІЙ БАЛАНС</small>
          <strong className={balance < 0 ? "negativeBalance" : ""}>
            {balance} ₴
          </strong>
        </div>
        <ClassicBoard3D
          size={liveRoom.boardSize}
          positions={positions}
          players={players}
          dice={dice}
          rolling={rolling}
          onSelectCell={(i) => {
            setSelected(i);
            setPropertyOpen(true);
          }}
          ownership={liveRoom.ownership || {}}
          houses={liveRoom.houses || {}}
          theme={boardTheme}
          customColor={customThemeColor}
          drawNonce={drawNonce}
          onChanceDeckClick={() => void draw("chance")}
          onBadDeckClick={() => void draw("bad")}
        />
        {pendingDeck && (
          <div className={`deckInstruction ${pendingDeck}`}>
            <small>{pendingDeck === "chance" ? "ШАНС" : "ХАЛЕПА"}</small>
            <strong>
              Натисни на {pendingDeck === "chance" ? "синю" : "червону"} колоду
              на полі
            </strong>
          </div>
        )}
        <div className="diceAction">
          <span>
            {dice[0]} + {dice[1]}
          </span>
          <button
            onClick={roll}
            disabled={
              Boolean(liveRoom.winnerId) ||
              rolling ||
              phase !== "roll" ||
              players[turn]?.id !== user.id
            }
          >
            {rolling ? "Кубики летять" : "Кинути кубики"}
          </button>
        </div>
        {gameError && (
          <p className="formError" role="alert">
            {gameError}
          </p>
        )}
        {liveRoom.winnerId && (
          <div className="winnerOverlay">
            <strong>ГРА ЗАВЕРШЕНО</strong>
            <span>
              Переміг{" "}
              {players.find((player) => player.id === liveRoom.winnerId)
                ?.name || "гравець"}
              !
            </span>
            <div className="winnerScores">
              {capitalRows.map((row) => (
                <small key={row.id}>
                  {row.name}: {row.value} ₴
                </small>
              ))}
            </div>
          </div>
        )}
        <IncomingTrades room={liveRoom} user={user} onRoom={setLiveRoom} />
        <AnimatePresence>
          {tradeOpen && (
            <TradePanel
              room={liveRoom}
              user={user}
              onRoom={setLiveRoom}
              onClose={() => setTradeOpen(false)}
            />
          )}
        </AnimatePresence>
        <AnimatePresence>
          {adminOpen && isAdminEmail(user.email, user.name) && (
            <AdminPanel
              room={liveRoom}
              adminId={user.id}
              onRoom={setLiveRoom}
              onClose={() => setAdminOpen(false)}
            />
          )}
        </AnimatePresence>
        <AnimatePresence>
          {chance && <ChanceCard event={chance} onContinue={closeCard} />}
        </AnimatePresence>
        <AnimatePresence>
          {casinoOpen && (
            <motion.aside
              className="propertyPanel"
              initial={{ opacity: 0, x: 60 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: 60 }}
            >
              <button className="propertyClose" onClick={skipCasino}>
                ×
              </button>
              <span className="propertyType">КАЗИНО</span>
              <h2>Крутимо?</h2>
              <p className="propertyNote">
                Рівні шанси: −150, −100, −50, +50, +100 або +150 ₴.
              </p>
              <div className="propertyActions">
                <button
                  className="buyProperty"
                  onClick={() => void spinCasino()}
                >
                  Крутити
                </button>
                <button className="skipProperty" onClick={skipCasino}>
                  Не крутити
                </button>
              </div>
            </motion.aside>
          )}
        </AnimatePresence>
        <AnimatePresence>
          {propertyOpen && (
            <motion.aside
              className="propertyPanel"
              initial={{ opacity: 0, x: 60 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: 60 }}
            >
              <button
                className="propertyClose"
                onClick={() => setPropertyOpen(false)}
              >
                ×
              </button>
              <div
                className="propertyBand"
                style={{ background: current.color }}
              />
              <span className="propertyType">
                {current.kind === "city" ? "МІСЬКА ВЛАСНІСТЬ" : "ІНФОРМАЦІЯ"}
              </span>
              <h2>{current.name}</h2>
              {current.kind !== "city" && (
                <p className="propertyNote">{current.description}</p>
              )}
              {current.kind === "city" && (
                <>
                  <div className="propertyPrice">
                    <span>Ціна</span>
                    <strong>{current.price} ₴</strong>
                  </div>
                  <div className="propertyRent">
                    <span>Оренда зараз</span>
                    <strong>{propertyRent} ₴</strong>
                  </div>
                  <p className="propertyNote">
                    {ownerId
                      ? `Власник: ${players.find((p) => p.id === ownerId)?.name || "гравець"}`
                      : standing
                        ? "Ти стоїш на цій клітинці."
                        : "Перегляд клітинки."}
                  </p>
                  {ownerId === user.id && (
                    <button
                      className="buildHouseButton"
                      disabled={
                        balance < nextHouseCost || currentHouses >= maxHouses
                      }
                      onClick={() => void buildHouse()}
                    >
                      Поставити будинок — {nextHouseCost} ₴
                    </button>
                  )}
                  {standing && !ownerId && phase === "decision" && (
                    <div className="propertyActions">
                      <button
                        className="buyProperty"
                        disabled={!canBuy}
                        onClick={buy}
                      >
                        {balance < (current.price || 0)
                          ? "Недостатньо коштів"
                          : `Купити за ${current.price} ₴`}
                      </button>
                      <button className="skipProperty" onClick={finishTurn}>
                        Не купувати
                      </button>
                    </div>
                  )}
                </>
              )}
            </motion.aside>
          )}
        </AnimatePresence>
      </section>
    </main>
  );
}
