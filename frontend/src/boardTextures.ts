import {
  CanvasTexture,
  NearestFilter,
  RepeatWrapping,
  SRGBColorSpace,
} from "three";

function hash(n: number) {
  const x = Math.sin(n * 127.1) * 43758.5453;
  return x - Math.floor(x);
}

function mixChannel(a: number, b: number, t: number) {
  return Math.round(a + (b - a) * t);
}

function parseHex(hex: string): [number, number, number] {
  const clean = hex.replace("#", "");
  const full =
    clean.length === 3
      ? clean
          .split("")
          .map((c) => c + c)
          .join("")
      : clean;
  return [
    parseInt(full.slice(0, 2), 16),
    parseInt(full.slice(2, 4), 16),
    parseInt(full.slice(4, 6), 16),
  ];
}

function finishTexture(
  canvas: HTMLCanvasElement,
  repeat = 1,
  filter: "linear" | "nearest" = "linear",
) {
  const texture = new CanvasTexture(canvas);
  texture.colorSpace = SRGBColorSpace;
  texture.wrapS = RepeatWrapping;
  texture.wrapT = RepeatWrapping;
  texture.repeat.set(repeat, repeat);
  texture.anisotropy = 8;
  if (filter === "nearest") {
    texture.minFilter = NearestFilter;
    texture.magFilter = NearestFilter;
  }
  texture.needsUpdate = true;
  return texture;
}

/** Dark lacquered wood for the board frame. */
export function makeWoodTexture(baseHex: string, size = 512) {
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d")!;
  const [br, bg, bb] = parseHex(baseHex);
  const dark: [number, number, number] = [
    mixChannel(br, 20, 0.55),
    mixChannel(bg, 14, 0.55),
    mixChannel(bb, 10, 0.55),
  ];
  const light: [number, number, number] = [
    mixChannel(br, 210, 0.28),
    mixChannel(bg, 170, 0.28),
    mixChannel(bb, 120, 0.28),
  ];
  ctx.fillStyle = `rgb(${dark.join(",")})`;
  ctx.fillRect(0, 0, size, size);
  for (let i = 0; i < size; i++) {
    const wave =
      Math.sin(i * 0.045) * 18 +
      Math.sin(i * 0.11 + 1.7) * 8 +
      hash(i * 0.37) * 6;
    const t = 0.35 + hash(i * 1.7) * 0.45;
    const r = mixChannel(dark[0], light[0], t);
    const g = mixChannel(dark[1], light[1], t);
    const b = mixChannel(dark[2], light[2], t);
    ctx.strokeStyle = `rgba(${r},${g},${b},${0.18 + hash(i) * 0.35})`;
    ctx.lineWidth = 1 + hash(i + 9) * 2.2;
    ctx.beginPath();
    ctx.moveTo(0, i + wave * 0.04);
    for (let x = 0; x <= size; x += 8) {
      const y =
        i +
        Math.sin(x * 0.02 + i * 0.03) * wave * 0.08 +
        Math.sin(x * 0.07) * 2.5;
      ctx.lineTo(x, y);
    }
    ctx.stroke();
  }
  // Subtle pores / knots
  for (let k = 0; k < 28; k++) {
    const x = hash(k * 3.1) * size;
    const y = hash(k * 7.7) * size;
    const radius = 4 + hash(k * 2.2) * 14;
    const grad = ctx.createRadialGradient(x, y, 0, x, y, radius);
    grad.addColorStop(0, `rgba(${dark.join(",")},0.55)`);
    grad.addColorStop(1, "rgba(0,0,0,0)");
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.ellipse(
      x,
      y,
      radius * 1.4,
      radius * 0.55,
      hash(k) * Math.PI,
      0,
      Math.PI * 2,
    );
    ctx.fill();
  }
  return finishTexture(canvas, 2);
}

/** Soft felt / cloth for the board center. */
export function makeFeltTexture(baseHex: string, size = 512) {
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d")!;
  const [br, bg, bb] = parseHex(baseHex);
  ctx.fillStyle = `rgb(${br},${bg},${bb})`;
  ctx.fillRect(0, 0, size, size);
  const image = ctx.getImageData(0, 0, size, size);
  const data = image.data;
  for (let i = 0; i < data.length; i += 4) {
    const n = (hash(i * 0.13) - 0.5) * 28;
    data[i] = Math.max(0, Math.min(255, data[i] + n));
    data[i + 1] = Math.max(0, Math.min(255, data[i + 1] + n * 0.9));
    data[i + 2] = Math.max(0, Math.min(255, data[i + 2] + n * 0.75));
  }
  ctx.putImageData(image, 0, 0);
  // Cross-hatch fiber
  ctx.globalAlpha = 0.08;
  for (let y = 0; y < size; y += 3) {
    ctx.strokeStyle = y % 6 === 0 ? "#fff" : "#000";
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(size, y);
    ctx.stroke();
  }
  for (let x = 0; x < size; x += 4) {
    ctx.strokeStyle = x % 8 === 0 ? "#fff" : "#000";
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, size);
    ctx.stroke();
  }
  ctx.globalAlpha = 1;
  return finishTexture(canvas, 1.4);
}

/** Paper / cardboard grain for property tiles. */
export function makePaperTexture(baseHex = "#d8cfb9", size = 256) {
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d")!;
  const [br, bg, bb] = parseHex(baseHex);
  ctx.fillStyle = `rgb(${br},${bg},${bb})`;
  ctx.fillRect(0, 0, size, size);
  const image = ctx.getImageData(0, 0, size, size);
  const data = image.data;
  for (let i = 0; i < data.length; i += 4) {
    const n = (hash(i * 0.41) - 0.5) * 22;
    data[i] = Math.max(0, Math.min(255, data[i] + n));
    data[i + 1] = Math.max(0, Math.min(255, data[i + 1] + n));
    data[i + 2] = Math.max(0, Math.min(255, data[i + 2] + n * 0.85));
  }
  ctx.putImageData(image, 0, 0);
  ctx.strokeStyle = "rgba(80,60,40,0.08)";
  ctx.lineWidth = 1;
  for (let i = 0; i < 40; i++) {
    const y = hash(i * 5.5) * size;
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(size, y + (hash(i) - 0.5) * 8);
    ctx.stroke();
  }
  return finishTexture(canvas, 1);
}

/** Soft normal-ish roughness variation for clearer material read. */
export function makeNoiseMap(size = 128) {
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d")!;
  const image = ctx.createImageData(size, size);
  for (let i = 0; i < image.data.length; i += 4) {
    const v = Math.floor(hash(i * 0.17) * 255);
    image.data[i] = v;
    image.data[i + 1] = v;
    image.data[i + 2] = v;
    image.data[i + 3] = 255;
  }
  ctx.putImageData(image, 0, 0);
  return finishTexture(canvas, 2, "nearest");
}
