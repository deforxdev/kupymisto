import { Canvas, useFrame, useThree } from "@react-three/fiber";
import { RoundedBox, Sparkles, Text } from "@react-three/drei";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  ACESFilmicToneMapping,
  Color,
  SRGBColorSpace,
  type CanvasTexture,
  type Group,
  type MeshStandardMaterial,
  type PerspectiveCamera,
} from "three";
import type { BoardSize, Player } from "../api";
import {
  makeFeltTexture,
  makeNoiseMap,
  makePaperTexture,
  makeWoodTexture,
} from "../boardTextures";

export type BoardCell = {
  name: string;
  kind: "corner" | "city" | "chance" | "tax" | "station" | "casino";
  price?: number;
  color: string;
  description?: string;
};
export type BoardTheme = "meadow" | "midnight" | "sunset" | "custom";
interface BoardPalette {
  background: string;
  ground: string;
  board: string;
  center: string;
  sky: string;
  groundLight: string;
  key: string;
  ring: string;
}
const themePalettes: Record<Exclude<BoardTheme, "custom">, BoardPalette> = {
  meadow: {
    background: "#176657",
    ground: "#123f38",
    board: "#24212b",
    center: "#75aa82",
    sky: "#d8f4df",
    groundLight: "#14362f",
    key: "#fff2c2",
    ring: "#7ce0b6",
  },
  midnight: {
    background: "#172852",
    ground: "#101a36",
    board: "#171a2a",
    center: "#46628b",
    sky: "#b9c8ff",
    groundLight: "#10162c",
    key: "#b7d3ff",
    ring: "#6d8ff0",
  },
  sunset: {
    background: "#7b3f4a",
    ground: "#452434",
    board: "#2d202c",
    center: "#ba735f",
    sky: "#ffd5ba",
    groundLight: "#3a1d2c",
    key: "#ffd0a3",
    ring: "#ffb36b",
  },
};

function colorHex(color: Color) {
  return `#${color.getHexString()}`;
}

function useBoardTextures(palette: BoardPalette) {
  const textures = useMemo(
    () => ({
      wood: makeWoodTexture(palette.board),
      felt: makeFeltTexture(palette.center),
      paper: makePaperTexture("#d8cfb9"),
      noise: makeNoiseMap(),
    }),
    [palette.board, palette.center],
  );
  useEffect(
    () => () => {
      Object.values(textures).forEach((texture: CanvasTexture) =>
        texture.dispose(),
      );
    },
    [textures],
  );
  return textures;
}

function getThemePalette(
  theme: BoardTheme,
  customColor = "#7c3aed",
): BoardPalette {
  if (theme !== "custom") return themePalettes[theme];
  const base = new Color(customColor);
  return {
    background: colorHex(base.clone().multiplyScalar(0.72)),
    ground: colorHex(base.clone().multiplyScalar(0.42)),
    board: colorHex(base.clone().multiplyScalar(0.22)),
    center: colorHex(base.clone().lerp(new Color("#ffffff"), 0.28)),
    sky: colorHex(base.clone().lerp(new Color("#ffffff"), 0.7)),
    groundLight: colorHex(base.clone().multiplyScalar(0.3)),
    key: colorHex(base.clone().lerp(new Color("#fff4ce"), 0.76)),
    ring: colorHex(base.clone().lerp(new Color("#ffffff"), 0.42)),
  };
}
const cityNames = [
  "Київ",
  "Львів",
  "Одеса",
  "Харків",
  "Дніпро",
  "Чернівці",
  "Ужгород",
  "Луцьк",
  "Рівне",
  "Житомир",
  "Вінниця",
  "Полтава",
  "Черкаси",
  "Суми",
  "Чернігів",
  "Тернопіль",
  "Івано-Франківськ",
  "Миколаїв",
  "Херсон",
  "Запоріжжя",
  "Кропивницький",
  "Біла Церква",
  "Кременчук",
  "Кам’янець",
];
const bands = [
  "#71472f",
  "#71472f",
  "#55aeca",
  "#55aeca",
  "#cf4d83",
  "#cf4d83",
  "#e17132",
  "#e17132",
  "#c93f39",
  "#c93f39",
  "#e5b92f",
  "#e5b92f",
  "#47985c",
  "#47985c",
  "#3565c2",
  "#3565c2",
];
export function makeCells(size: BoardSize): BoardCell[] {
  const side = size === "large" ? 15 : 11;
  const total = side * 4 - 4;
  const casinoIndex = (side - 1) * 3;
  let city = 0;
  return Array.from({ length: total }, (_, index) => {
    const lane = index % (side - 1);
    if (index === casinoIndex)
      return {
        name: "КАЗИНО",
        description: "Рівні шанси: −150, −100, −50, +50, +100 або +150 ₴.",
        kind: "casino",
        color: "#9b59b6",
      };
    if (lane === 0) {
      const corners = [
        ["СТАРТ", "Проходиш старт — отримуєш +100 ₴."],
        ["Я У ПОЛЬЩІ", "Доставка через кордон: отримуєш +100 ₴."],
        ["БУСИФІКАЦІЯ", "Міський маршрут приніс +75 ₴."],
        ["КАЗИНО", "Рівні шанси: −150, −100, −50, +50, +100 або +150 ₴."],
      ];
      const [name, description] = corners[index / (side - 1)];
      return {
        name,
        description,
        kind: "corner",
        color: index === 0 ? "#e8bd32" : "#d9e2d1",
      };
    }
    if (lane === 3)
      return {
        name: "ШАНС",
        description: "Позитивна картка з бонусом для твого балансу.",
        kind: "chance",
        color: "#ded8c7",
      };
    if (lane === 7)
      return {
        name: "ХАЛЕПА",
        description: "Негативна картка зі штрафом для твого балансу.",
        kind: "tax",
        color: "#d8d1bf",
      };
    if (lane === 5)
      return {
        name: "ВОКЗАЛ",
        description: "Купівля за 200 ₴. Базова оренда — 66 ₴.",
        kind: "city",
        price: 200,
        color: "#d8d1bf",
      };
    const name = cityNames[city % cityNames.length];
    const color = bands[Math.floor(city / 2) % bands.length];
    city++;
    return {
      name,
      description: "Міська власність. Купуй і отримуй оренду.",
      kind: "city",
      price: 100 + (city % 9) * 30,
      color,
    };
  });
}
function boardPosition(index: number, side: number): [number, number, number] {
  const edge = side - 1,
    half = edge / 2;
  if (index <= edge) return [half - index, 0, half];
  if (index <= edge * 2) return [-half, 0, half - (index - edge)];
  if (index <= edge * 3) return [-half + (index - edge * 2), 0, -half];
  return [half, 0, -half + (index - edge * 3)];
}

function Token({
  index,
  side,
  color,
  offset,
}: {
  index: number;
  side: number;
  color: string;
  offset: number;
}) {
  const ref = useRef<Group>(null);
  const total = side * 4 - 4;
  const current = useRef(index);
  const target = useRef(index);
  const stepProgress = useRef(1);
  const from = useRef(boardPosition(index, side));
  const to = useRef(boardPosition(index, side));

  useEffect(() => {
    target.current = index;
  }, [index]);
  const glow = useRef<MeshStandardMaterial>(null);
  useFrame((state, delta) => {
    if (!ref.current) return;
    if (stepProgress.current >= 1 && current.current !== target.current) {
      from.current = boardPosition(current.current, side);
      current.current = (current.current + 1) % total;
      to.current = boardPosition(current.current, side);
      stepProgress.current = 0;
    }
    if (stepProgress.current < 1) {
      stepProgress.current = Math.min(1, stepProgress.current + delta * 5.25);
      const raw = stepProgress.current;
      const t = raw * raw * (3 - 2 * raw);
      const a = from.current,
        b = to.current;
      ref.current.position.x = a[0] + (b[0] - a[0]) * t + offset;
      ref.current.position.z = a[2] + (b[2] - a[2]) * t + offset;
      ref.current.position.y = 0.86 + Math.sin(raw * Math.PI) * 0.34;
      ref.current.rotation.y += delta * 4.8;
    } else {
      const point = boardPosition(current.current, side);
      ref.current.position.x = point[0] + offset;
      ref.current.position.z = point[2] + offset;
      ref.current.position.y = 0.86;
    }
    if (glow.current) {
      glow.current.emissiveIntensity =
        0.18 + Math.sin(state.clock.elapsedTime * 3.2 + offset * 8) * 0.08;
    }
  });
  const initial = boardPosition(index, side);
  return (
    <group
      ref={ref}
      position={[initial[0] + offset, 0.86, initial[2] + offset]}
    >
      <mesh position={[0, 0.21, 0]}>
        <sphereGeometry args={[0.12, 24, 24]} />
        <meshStandardMaterial
          ref={glow}
          color={color}
          emissive={color}
          emissiveIntensity={0.2}
          roughness={0.32}
          metalness={0.28}
        />
      </mesh>
      <mesh>
        <coneGeometry args={[0.21, 0.42, 24]} />
        <meshStandardMaterial color={color} roughness={0.38} metalness={0.22} />
      </mesh>
      <mesh position={[0, -0.225, 0]}>
        <cylinderGeometry args={[0.235, 0.235, 0.075, 24]} />
        <meshStandardMaterial
          color="#1a1820"
          roughness={0.48}
          metalness={0.4}
        />
      </mesh>
      <mesh position={[0, 0.02, 0]} rotation={[-Math.PI / 2, 0, 0]}>
        <ringGeometry args={[0.22, 0.32, 24]} />
        <meshBasicMaterial color={color} transparent opacity={0.22} />
      </mesh>
    </group>
  );
}

const pipMap: Record<number, [number, number][]> = {
  1: [[0, 0]],
  2: [
    [-1, 1],
    [1, -1],
  ],
  3: [
    [-1, 1],
    [0, 0],
    [1, -1],
  ],
  4: [
    [-1, 1],
    [1, 1],
    [-1, -1],
    [1, -1],
  ],
  5: [
    [-1, 1],
    [1, 1],
    [0, 0],
    [-1, -1],
    [1, -1],
  ],
  6: [
    [-1, 1],
    [-1, 0],
    [-1, -1],
    [1, 1],
    [1, 0],
    [1, -1],
  ],
};
function FacePips({
  value,
  face,
}: {
  value: number;
  face: "top" | "front" | "back" | "left" | "right" | "bottom";
}) {
  const rotation: [number, number, number] =
    face === "top"
      ? [-Math.PI / 2, 0, 0]
      : face === "bottom"
        ? [Math.PI / 2, 0, 0]
        : face === "front"
          ? [0, 0, 0]
          : face === "back"
            ? [0, Math.PI, 0]
            : face === "left"
              ? [0, -Math.PI / 2, 0]
              : [0, Math.PI / 2, 0];
  const position: [number, number, number] =
    face === "top"
      ? [0, 0.366, 0]
      : face === "bottom"
        ? [0, -0.366, 0]
        : face === "front"
          ? [0, 0, 0.366]
          : face === "back"
            ? [0, 0, -0.366]
            : face === "left"
              ? [-0.366, 0, 0]
              : [0.366, 0, 0];
  const pips = pipMap[value] || pipMap[1];
  return (
    <group position={position} rotation={rotation}>
      {pips.map(([x, y], i) => (
        <mesh key={i} position={[x * 0.19, y * 0.19, 0.008]}>
          <circleGeometry args={[0.055, 18]} />
          <meshStandardMaterial color="#24232b" roughness={0.5} />
        </mesh>
      ))}
    </group>
  );
}
function Die({
  home,
  value,
  rolling,
  seed,
}: {
  home: [number, number, number];
  value: number;
  rolling: boolean;
  seed: number;
}) {
  const ref = useRef<Group>(null),
    phase = useRef(0),
    wasRolling = useRef(false);
  useEffect(() => {
    if (rolling && !wasRolling.current) phase.current = 0;
    wasRolling.current = rolling;
  }, [rolling]);
  useFrame((_, delta) => {
    if (!ref.current) return;
    if (rolling) {
      phase.current = Math.min(1, phase.current + delta * 1.35);
      const t = phase.current;
      ref.current.position.x =
        home[0] + Math.sin(t * Math.PI * 3 + seed) * 0.7 * (1 - t);
      ref.current.position.z =
        home[2] + Math.cos(t * Math.PI * 2.4 + seed) * 0.55 * (1 - t);
      ref.current.position.y =
        home[1] +
        Math.sin(t * Math.PI) * 1.65 +
        Math.abs(Math.sin(t * Math.PI * 5)) * 0.16 * (1 - t);
      ref.current.rotation.x += delta * (15 + seed * 2);
      ref.current.rotation.y += delta * (12 + seed);
      ref.current.rotation.z += delta * 9;
    } else {
      ref.current.position.x += (home[0] - ref.current.position.x) * 0.12;
      ref.current.position.y += (home[1] - ref.current.position.y) * 0.18;
      ref.current.position.z += (home[2] - ref.current.position.z) * 0.12;
      ref.current.rotation.x += -ref.current.rotation.x * 0.08;
      ref.current.rotation.z += -ref.current.rotation.z * 0.08;
    }
  });
  const faces = [
    value,
    7 - value,
    ((value + 1) % 6) + 1,
    7 - (((value + 1) % 6) + 1),
    ((value + 3) % 6) + 1,
    7 - (((value + 3) % 6) + 1),
  ];
  return (
    <group ref={ref} position={home}>
      <RoundedBox args={[0.72, 0.72, 0.72]} radius={0.115} smoothness={5}>
        <meshStandardMaterial
          color="#efe6d4"
          roughness={0.22}
          metalness={0.08}
          envMapIntensity={0.6}
        />
      </RoundedBox>
      <FacePips value={faces[0]} face="top" />
      <FacePips value={faces[1]} face="bottom" />
      <FacePips value={faces[2]} face="front" />
      <FacePips value={faces[3]} face="back" />
      <FacePips value={faces[4]} face="left" />
      <FacePips value={faces[5]} face="right" />
    </group>
  );
}

function ChanceDeck({
  drawNonce,
  onClick,
  kind,
  position,
}: {
  drawNonce: number;
  onClick: () => void;
  kind: "chance" | "bad";
  position: [number, number, number];
}) {
  const card = useRef<Group>(null);
  const activeNonce =
    kind === "bad" && drawNonce < 0
      ? -drawNonce
      : kind === "chance" && drawNonce > 0
        ? drawNonce
        : 0;
  const previous = useRef(activeNonce);
  const progress = useRef(1);
  const accent = kind === "chance" ? "#e8bd32" : "#e46b5f";
  const cover = kind === "chance" ? "#244f95" : "#a9323b";
  useEffect(() => {
    if (activeNonce !== 0 && activeNonce !== previous.current) {
      previous.current = activeNonce;
      progress.current = 0;
    }
  }, [activeNonce]);
  useFrame((_, delta) => {
    if (!card.current) return;
    progress.current = Math.min(1, progress.current + delta * 0.82);
    const t = 1 - Math.pow(1 - progress.current, 4);
    card.current.position.x = t * 0.5;
    card.current.position.y = 0.76 + Math.sin(t * Math.PI) * 0.55;
    card.current.position.z = -t * 0.3;
    card.current.rotation.x = -Math.PI / 2 + t * 0.45;
    card.current.rotation.z = t * Math.PI * 0.18;
    card.current.visible = progress.current < 0.985;
  });
  return (
    <group
      position={position}
      onClick={(e) => {
        e.stopPropagation();
        onClick();
      }}
    >
      <RoundedBox
        args={[1.16, 0.24, 1.52]}
        radius={0.065}
        smoothness={4}
        position={[0, 0.58, 0]}
      >
        <meshStandardMaterial
          color="#e9dfc9"
          roughness={0.55}
          metalness={0.04}
        />
      </RoundedBox>
      <RoundedBox
        args={[1.12, 0.055, 1.48]}
        radius={0.06}
        smoothness={4}
        position={[0, 0.72, 0]}
      >
        <meshStandardMaterial
          color={cover}
          roughness={0.4}
          metalness={0.12}
          emissive={cover}
          emissiveIntensity={0.12}
        />
      </RoundedBox>
      <mesh position={[0, 0.755, 0]} rotation={[-Math.PI / 2, 0, 0]}>
        <ringGeometry args={[0.25, 0.38, 32]} />
        <meshStandardMaterial
          color={accent}
          roughness={0.32}
          metalness={0.25}
          emissive={accent}
          emissiveIntensity={0.35}
        />
      </mesh>
      <Text
        position={[0, 0.762, 0.38]}
        rotation={[-Math.PI / 2, 0, 0]}
        fontSize={0.13}
        maxWidth={0.9}
        color="#f8f1df"
        textAlign="center"
      >
        {kind === "chance" ? "ШАНС" : "ХАЛЕПА"}
      </Text>
      <group
        ref={card}
        position={[0, 0.76, 0]}
        rotation={[-Math.PI / 2, 0, 0]}
        visible={false}
      >
        <RoundedBox args={[1.12, 0.045, 1.48]} radius={0.055} smoothness={3}>
          <meshStandardMaterial
            color={accent}
            roughness={0.36}
            metalness={0.18}
            emissive={accent}
            emissiveIntensity={0.4}
          />
        </RoundedBox>
        <Text
          position={[0, 0.04, 0]}
          rotation={[-Math.PI / 2, 0, 0]}
          fontSize={0.18}
          maxWidth={0.82}
          color="#20202a"
          textAlign="center"
        >
          {kind === "chance" ? "ШАНС" : "ХАЛЕПА"}
        </Text>
      </group>
    </group>
  );
}

function BoardModel({
  size,
  positions,
  players,
  dice,
  rolling,
  onSelectCell,
  ownership,
  drawNonce,
  houses,
  onChanceDeckClick,
  onBadDeckClick,
  palette,
}: {
  size: BoardSize;
  positions: number[];
  players: Player[];
  dice: [number, number];
  rolling: boolean;
  onSelectCell: (index: number) => void;
  ownership: Record<string, string>;
  drawNonce: number;
  houses: Record<string, number>;
  onChanceDeckClick: () => void;
  onBadDeckClick: () => void;
  palette: BoardPalette;
}) {
  const ownerColors = [
      "#3167dc",
      "#de5549",
      "#54b87a",
      "#efc63e",
      "#955fc7",
      "#e98a44",
    ],
    ownerColor = (index: number) => {
      const id = ownership[String(index)];
      const playerIndex = players.findIndex((player) => player.id === id);
      return playerIndex >= 0
        ? ownerColors[playerIndex % ownerColors.length]
        : null;
    },
    group = useRef<Group>(null),
    drag = useRef({ active: false, x: 0, y: 0, targetX: -0.04, targetY: 0 }),
    zoom = useRef(size === "large" ? 18.5 : 16.2),
    { gl, camera } = useThree(),
    cells = useMemo(() => makeCells(size), [size]),
    side = size === "large" ? 15 : 11,
    edge = side - 1,
    boardWidth = edge + 1.7,
    playerColors = [
      "#3167dc",
      "#de5549",
      "#54b87a",
      "#efc63e",
      "#955fc7",
      "#e98a44",
    ],
    textures = useBoardTextures(palette),
    [hovered, setHovered] = useState<number | null>(null);
  useEffect(() => {
    const canvas = gl.domElement,
      context = (e: MouseEvent) => e.preventDefault(),
      down = (e: PointerEvent) => {
        if (e.button !== 2) return;
        e.preventDefault();
        drag.current.active = true;
        drag.current.x = e.clientX;
        drag.current.y = e.clientY;
        canvas.setPointerCapture?.(e.pointerId);
        canvas.classList.add("isRotating");
      },
      move = (e: PointerEvent) => {
        if (!drag.current.active || (e.buttons & 2) !== 2) return;
        const dx = e.clientX - drag.current.x,
          dy = e.clientY - drag.current.y;
        drag.current.x = e.clientX;
        drag.current.y = e.clientY;
        drag.current.targetY += dx * 0.008;
        drag.current.targetX = Math.max(
          -0.38,
          Math.min(0.32, drag.current.targetX + dy * 0.005),
        );
      },
      up = (e: PointerEvent) => {
        if (e.button !== 2) return;
        drag.current.active = false;
        canvas.releasePointerCapture?.(e.pointerId);
        canvas.classList.remove("isRotating");
      },
      wheel = (e: WheelEvent) => {
        e.preventDefault();
        zoom.current = Math.max(
          size === "large" ? 13.5 : 11.5,
          Math.min(size === "large" ? 25 : 22, zoom.current + e.deltaY * 0.012),
        );
      };
    canvas.addEventListener("contextmenu", context);
    canvas.addEventListener("pointerdown", down);
    canvas.addEventListener("pointermove", move);
    canvas.addEventListener("pointerup", up);
    canvas.addEventListener("pointercancel", up);
    canvas.addEventListener("wheel", wheel, { passive: false });
    return () => {
      canvas.removeEventListener("contextmenu", context);
      canvas.removeEventListener("pointerdown", down);
      canvas.removeEventListener("pointermove", move);
      canvas.removeEventListener("pointerup", up);
      canvas.removeEventListener("pointercancel", up);
      canvas.removeEventListener("wheel", wheel);
    };
  }, [gl, size]);
  useFrame(() => {
    if (group.current) {
      group.current.rotation.y +=
        (drag.current.targetY - group.current.rotation.y) * 0.12;
      group.current.rotation.x +=
        (drag.current.targetX - group.current.rotation.x) * 0.12;
    }
    const cam = camera as PerspectiveCamera;
    const length = Math.hypot(cam.position.x, cam.position.y, cam.position.z);
    const target = zoom.current;
    if (Math.abs(length - target) > 0.01)
      cam.position.multiplyScalar((length + (target - length) * 0.12) / length);
  });
  return (
    <group ref={group}>
      <RoundedBox
        args={[boardWidth, 0.42, boardWidth]}
        radius={0.18}
        smoothness={4}
      >
        <meshStandardMaterial
          map={textures.wood}
          color="#ffffff"
          roughness={0.42}
          metalness={0.08}
          roughnessMap={textures.noise}
        />
      </RoundedBox>
      <RoundedBox
        args={[boardWidth - 0.28, 0.2, boardWidth - 0.28]}
        radius={0.12}
        smoothness={4}
        position={[0, 0.28, 0]}
      >
        <meshStandardMaterial
          map={textures.felt}
          color="#ffffff"
          roughness={0.88}
          metalness={0.02}
        />
      </RoundedBox>
      <mesh position={[0, 0.39, 0]} rotation={[-Math.PI / 2, 0, 0]}>
        <ringGeometry
          args={[boardWidth * 0.5 - 0.55, boardWidth * 0.5 - 0.38, 64]}
        />
        <meshStandardMaterial
          color="#d4b35a"
          roughness={0.28}
          metalness={0.65}
          emissive="#a8842a"
          emissiveIntensity={0.15}
        />
      </mesh>
      <group position={[0, 0.42, 0.55]}>
        <RoundedBox args={[2.4, 0.06, 1.05]} radius={0.08} smoothness={3}>
          <meshStandardMaterial
            map={textures.wood}
            color="#c9a45c"
            roughness={0.4}
            metalness={0.2}
          />
        </RoundedBox>
        <Text
          position={[0, 0.05, -0.12]}
          rotation={[-Math.PI / 2, 0, 0]}
          fontSize={0.22}
          color="#1d1830"
          anchorX="center"
          anchorY="middle"
        >
          КУПИ МІСТО
        </Text>
        <Text
          position={[0, 0.05, 0.22]}
          rotation={[-Math.PI / 2, 0, 0]}
          fontSize={0.09}
          color="#3a3348"
          anchorX="center"
          anchorY="middle"
        >
          УКРАЇНСЬКА МОНОПОЛІЯ
        </Text>
      </group>
      <Sparkles
        count={rolling ? 48 : 22}
        scale={[boardWidth * 0.55, 1.2, boardWidth * 0.55]}
        size={rolling ? 4.5 : 2.4}
        speed={rolling ? 1.1 : 0.35}
        opacity={0.55}
        color={palette.key}
        position={[0, 0.95, 0]}
      />
      {cells.map((cell, index) => {
        const [x, , z] = boardPosition(index, side),
          corner = cell.kind === "corner",
          isHovered = hovered === index,
          owned = ownerColor(index),
          houseCount = houses[String(index)] || 0,
          rotation =
            index <= edge
              ? 0
              : index <= edge * 2
                ? -Math.PI / 2
                : index <= edge * 3
                  ? Math.PI
                  : Math.PI / 2;
        return (
          <group
            key={index}
            position={[x, 0.43, z]}
            rotation={[0, rotation, 0]}
            onClick={(event) => {
              event.stopPropagation();
              onSelectCell(index);
            }}
            onPointerOver={(event) => {
              event.stopPropagation();
              setHovered(index);
              gl.domElement.style.cursor = "pointer";
            }}
            onPointerOut={() => {
              setHovered((current) => (current === index ? null : current));
              gl.domElement.style.cursor = drag.current.active
                ? "grabbing"
                : "default";
            }}
          >
            <RoundedBox
              args={[corner ? 1.05 : 0.78, 0.12, 1.05]}
              radius={0.035}
              smoothness={2}
              scale={isHovered ? 1.035 : 1}
            >
              <meshStandardMaterial
                map={corner ? undefined : textures.paper}
                color={corner ? cell.color : "#ffffff"}
                roughness={0.62}
                metalness={0.04}
                emissive={isHovered ? palette.key : "#000000"}
                emissiveIntensity={isHovered ? 0.22 : 0}
              />
            </RoundedBox>
            {!corner && (
              <mesh position={[0, 0.085, -0.38]}>
                <boxGeometry args={[0.76, 0.045, 0.26]} />
                <meshStandardMaterial
                  color={cell.color}
                  roughness={0.45}
                  metalness={0.12}
                  emissive={cell.color}
                  emissiveIntensity={0.18}
                />
              </mesh>
            )}
            <Text
              position={[0, 0.112, 0.02]}
              rotation={[-Math.PI / 2, 0, 0]}
              fontSize={corner ? 0.12 : 0.09}
              maxWidth={0.68}
              color="#20202a"
              textAlign="center"
              anchorX="center"
              anchorY="middle"
            >
              {cell.name}
            </Text>
            {owned && (
              <group position={[0, 0.19, 0]}>
                <mesh position={[0, 0, -0.54]}>
                  <boxGeometry args={[corner ? 1.1 : 0.84, 0.055, 0.035]} />
                  <meshStandardMaterial
                    color={owned}
                    emissive={owned}
                    emissiveIntensity={0.35}
                    roughness={0.35}
                    metalness={0.25}
                  />
                </mesh>
                <mesh position={[0, 0, 0.54]}>
                  <boxGeometry args={[corner ? 1.1 : 0.84, 0.055, 0.035]} />
                  <meshStandardMaterial
                    color={owned}
                    emissive={owned}
                    emissiveIntensity={0.35}
                    roughness={0.35}
                    metalness={0.25}
                  />
                </mesh>
                <mesh position={[-(corner ? 0.55 : 0.42), 0, 0]}>
                  <boxGeometry args={[0.035, 0.055, 1.08]} />
                  <meshStandardMaterial
                    color={owned}
                    emissive={owned}
                    emissiveIntensity={0.35}
                    roughness={0.35}
                    metalness={0.25}
                  />
                </mesh>
                <mesh position={[corner ? 0.55 : 0.42, 0, 0]}>
                  <boxGeometry args={[0.035, 0.055, 1.08]} />
                  <meshStandardMaterial
                    color={owned}
                    emissive={owned}
                    emissiveIntensity={0.35}
                    roughness={0.35}
                    metalness={0.25}
                  />
                </mesh>
                {houseCount > 0 &&
                  Array.from({ length: Math.min(houseCount, 5) }).map(
                    (_, houseIndex) => {
                      const hotel = houseCount >= 5 && houseIndex === 0;
                      const span = Math.min(houseCount, 4);
                      const xPos = hotel
                        ? 0
                        : (houseIndex - (span - 1) / 2) * 0.17;
                      if (hotel && houseIndex > 0) return null;
                      return (
                        <group
                          key={houseIndex}
                          position={[
                            xPos,
                            hotel ? 0.14 : 0.1,
                            hotel ? 0 : -0.08,
                          ]}
                        >
                          <mesh>
                            <boxGeometry
                              args={
                                hotel ? [0.28, 0.22, 0.22] : [0.12, 0.12, 0.1]
                              }
                            />
                            <meshStandardMaterial
                              color={hotel ? "#c93f39" : "#54b87a"}
                              roughness={0.45}
                              metalness={0.15}
                            />
                          </mesh>
                          <mesh position={[0, hotel ? 0.14 : 0.09, 0]}>
                            <coneGeometry
                              args={hotel ? [0.18, 0.1, 4] : [0.09, 0.08, 4]}
                            />
                            <meshStandardMaterial
                              color={hotel ? "#8a241f" : "#2f7a4a"}
                              roughness={0.5}
                            />
                          </mesh>
                        </group>
                      );
                    },
                  )}
              </group>
            )}
            {cell.price && (
              <Text
                position={[0, 0.113, 0.29]}
                rotation={[-Math.PI / 2, 0, 0]}
                fontSize={0.07}
                color="#20202a"
                anchorX="center"
                anchorY="middle"
              >
                {cell.price} ₴
              </Text>
            )}
          </group>
        );
      })}
      {players.map((player, index) => (
        <Token
          key={player.id}
          index={positions[index] || 0}
          side={side}
          color={playerColors[index % playerColors.length]}
          offset={((index % 3) - 0.8) * 0.16}
        />
      ))}
      <ChanceDeck
        position={[1.55, 0.02, -0.45]}
        drawNonce={drawNonce}
        onClick={onChanceDeckClick}
        kind="chance"
      />
      <ChanceDeck
        position={[-1.55, 0.02, -0.45]}
        drawNonce={drawNonce}
        onClick={onBadDeckClick}
        kind="bad"
      />
      <Die
        home={[-0.5, 0.86, 0.45]}
        value={dice[0]}
        rolling={rolling}
        seed={1}
      />
      <Die
        home={[0.5, 0.86, 0.45]}
        value={dice[1]}
        rolling={rolling}
        seed={2}
      />
    </group>
  );
}
export default function ClassicBoard3D(props: {
  size: BoardSize;
  positions: number[];
  players: Player[];
  dice: [number, number];
  rolling: boolean;
  onSelectCell: (index: number) => void;
  ownership: Record<string, string>;
  drawNonce: number;
  houses: Record<string, number>;
  onChanceDeckClick: () => void;
  onBadDeckClick: () => void;
  theme?: BoardTheme;
  customColor?: string;
}) {
  const camera =
      props.size === "large"
        ? ([0, 15.2, 11.8] as [number, number, number])
        : ([0, 13.6, 10.4] as [number, number, number]),
    theme = props.theme ?? "meadow",
    palette = getThemePalette(theme, props.customColor);
  return (
    <Canvas
      dpr={[1, 1.75]}
      camera={{ position: camera, fov: 38 }}
      gl={{
        antialias: true,
        alpha: true,
        toneMapping: ACESFilmicToneMapping,
        toneMappingExposure: 1.05,
        outputColorSpace: SRGBColorSpace,
      }}
      onCreated={({ gl }) => gl.setClearColor(0x000000, 0)}
    >
      <ambientLight intensity={0.62} />
      <hemisphereLight args={[palette.sky, palette.groundLight, 0.55]} />
      <directionalLight
        color={palette.key}
        position={[7, 12, 5]}
        intensity={1.45}
      />
      <pointLight
        color={palette.ring}
        position={[-6, 4.5, -5]}
        intensity={5.5}
        distance={20}
      />
      <pointLight
        color="#fff4d2"
        position={[0, 6, 2]}
        intensity={3.2}
        distance={16}
      />
      <BoardModel {...props} palette={palette} />
    </Canvas>
  );
}
