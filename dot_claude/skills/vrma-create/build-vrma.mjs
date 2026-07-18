/* build-vrma.mjs — spec JSON -> .vrma (VRMC_vrm_animation GLB).
 * Bundled from theo packages/core/src/motion/ (github.com/yuzukq/Theo).
 * Motion pipeline adapted from Text-To-VRMA (c) 2026 Kiratchi, MIT License.
 * Zero dependencies: runs with plain Node 20+. */

// ../../../../private/tmp/claude-501/-Users-yuzu-develop-theo/ad2d3073-efe5-4247-8897-522c74e3a7a4/scratchpad/vrma-cli-entry.ts
import { readFileSync, writeFileSync } from "node:fs";

// packages/core/src/motion/vrma.ts
var SKELETON = {
  hips: [null, [0, 0.9, 0]],
  spine: ["hips", [0, 0.08, 0]],
  chest: ["spine", [0, 0.12, 0]],
  upperChest: ["chest", [0, 0.12, 0]],
  neck: ["upperChest", [0, 0.13, 0]],
  head: ["neck", [0, 0.08, 0]],
  leftShoulder: ["upperChest", [0.03, 0.1, 0]],
  leftUpperArm: ["leftShoulder", [0.06, 0, 0]],
  leftLowerArm: ["leftUpperArm", [0.24, 0, 0]],
  leftHand: ["leftLowerArm", [0.22, 0, 0]],
  rightShoulder: ["upperChest", [-0.03, 0.1, 0]],
  rightUpperArm: ["rightShoulder", [-0.06, 0, 0]],
  rightLowerArm: ["rightUpperArm", [-0.24, 0, 0]],
  rightHand: ["rightLowerArm", [-0.22, 0, 0]],
  leftUpperLeg: ["hips", [0.09, -0.02, 0]],
  leftLowerLeg: ["leftUpperLeg", [0, -0.38, 0]],
  leftFoot: ["leftLowerLeg", [0, -0.42, 0]],
  rightUpperLeg: ["hips", [-0.09, -0.02, 0]],
  rightLowerLeg: ["rightUpperLeg", [0, -0.38, 0]],
  rightFoot: ["rightLowerLeg", [0, -0.42, 0]]
};
var FINGER_SEGMENTS = {
  Proximal: [0.09, 0.035],
  Intermediate: [0.035, 0.028],
  Distal: [0.025, 0.02]
};
for (const side of ["left", "right"]) {
  const sx = side === "left" ? 1 : -1;
  const fingers = {
    Index: 0.025,
    Middle: 8e-3,
    Ring: -8e-3,
    Little: -0.024
  };
  for (const [finger, z] of Object.entries(fingers)) {
    let parent = `${side}Hand`;
    for (const [seg, [len]] of Object.entries(FINGER_SEGMENTS)) {
      const name = `${side}${finger}${seg}`;
      SKELETON[name] = [parent, [sx * len, 0, seg === "Proximal" ? z : 0]];
      parent = name;
    }
  }
}
var HIPS_HEIGHT = 0.9;
var BONE_NAMES = Object.keys(SKELETON).filter(
  (n) => !/Proximal|Intermediate|Distal/.test(n)
);
var ALL_BONES = Object.keys(SKELETON);
var FINGER_CURL = { Proximal: 14, Intermediate: 17, Distal: 10 };
var EXPRESSION_PRESETS = [
  "happy",
  "angry",
  "sad",
  "relaxed",
  "surprised",
  "neutral",
  "aa",
  "ih",
  "ou",
  "ee",
  "oh",
  "blink",
  "blinkLeft",
  "blinkRight",
  "lookUp",
  "lookDown",
  "lookLeft",
  "lookRight"
];
function eulerToQuat(deg) {
  const [x, y, z] = deg.map((d) => d * Math.PI / 360);
  const cx = Math.cos(x ?? 0);
  const sx = Math.sin(x ?? 0);
  const cy = Math.cos(y ?? 0);
  const sy = Math.sin(y ?? 0);
  const cz = Math.cos(z ?? 0);
  const sz = Math.sin(z ?? 0);
  return [
    sx * cy * cz + cx * sy * sz,
    cx * sy * cz - sx * cy * sz,
    cx * cy * sz + sx * sy * cz,
    cx * cy * cz - sx * sy * sz
  ];
}
function buildVrma(spec) {
  const nodes = [];
  const nodeIndex = {};
  for (const name of ALL_BONES) {
    nodeIndex[name] = nodes.length;
    const bone = SKELETON[name];
    if (!bone) continue;
    nodes.push({ name: `J_${name}`, translation: [...bone[1]] });
  }
  for (const name of ALL_BONES) {
    const parent = SKELETON[name]?.[0];
    if (parent != null) {
      const parentNode = nodes[nodeIndex[parent] ?? -1];
      if (parentNode) {
        parentNode.children ??= [];
        parentNode.children.push(nodeIndex[name] ?? 0);
      }
    }
  }
  const tracks = { ...spec.tracks ?? {} };
  const dur = spec.duration ?? 1;
  for (const side of ["left", "right"]) {
    const shoulderBone = `${side}Shoulder`;
    const ua = tracks[`${side}UpperArm`];
    if (!ua?.length || tracks[shoulderBone]) continue;
    const raiseSign = side === "left" ? 1 : -1;
    const keys = ua.map((k) => {
      const raise = Math.max(0, raiseSign * (k.r[2] ?? 0) - 55);
      const lift = Math.min(14, raise * 0.4);
      return { t: k.t, r: [0, 0, raiseSign * lift] };
    });
    if (keys.some((k) => k.r[2] !== 0)) tracks[shoulderBone] = keys;
  }
  for (const side of ["left", "right"]) {
    const sign = side === "left" ? -1 : 1;
    for (const finger of ["Index", "Middle", "Ring", "Little"]) {
      for (const [seg, deg] of Object.entries(FINGER_CURL)) {
        const bone = `${side}${finger}${seg}`;
        if (!(bone in tracks)) {
          const r = [0, 0, sign * deg];
          tracks[bone] = [
            { t: 0, r },
            { t: dur, r }
          ];
        }
      }
    }
  }
  const binParts = [];
  const bufferViews = [];
  const accessors = [];
  let binOffset = 0;
  function addAccessor(floatArray, type, isInput) {
    const byteLength = floatArray.byteLength;
    bufferViews.push({ buffer: 0, byteOffset: binOffset, byteLength });
    binParts.push(floatArray);
    binOffset += byteLength;
    const acc = {
      bufferView: bufferViews.length - 1,
      componentType: 5126,
      // FLOAT
      count: type === "SCALAR" ? floatArray.length : floatArray.length / (type === "VEC3" ? 3 : 4),
      type
    };
    if (isInput) {
      acc.min = [Math.min(...floatArray)];
      acc.max = [Math.max(...floatArray)];
    }
    accessors.push(acc);
    return accessors.length - 1;
  }
  const samplers = [];
  const channels = [];
  for (const [bone, keys] of Object.entries(tracks)) {
    if (!(bone in SKELETON) || !keys?.length) continue;
    const sorted = [...keys].sort((a, b) => a.t - b.t);
    const times = new Float32Array(sorted.map((k) => k.t));
    const values = new Float32Array(sorted.length * 4);
    sorted.forEach((k, i) => values.set(eulerToQuat(k.r), i * 4));
    const input = addAccessor(times, "SCALAR", true);
    const output = addAccessor(values, "VEC4", false);
    samplers.push({ input, output, interpolation: "LINEAR" });
    channels.push({
      sampler: samplers.length - 1,
      target: { node: nodeIndex[bone] ?? 0, path: "rotation" }
    });
  }
  if (spec.hips?.length) {
    const sorted = [...spec.hips].sort((a, b) => a.t - b.t);
    const times = new Float32Array(sorted.map((k) => k.t));
    const values = new Float32Array(sorted.length * 3);
    sorted.forEach((k, i) => values.set([k.p[0], HIPS_HEIGHT + k.p[1], k.p[2]], i * 3));
    const input = addAccessor(times, "SCALAR", true);
    const output = addAccessor(values, "VEC3", false);
    samplers.push({ input, output, interpolation: "LINEAR" });
    channels.push({
      sampler: samplers.length - 1,
      target: { node: nodeIndex.hips ?? 0, path: "translation" }
    });
  }
  const expressionsUsed = {};
  for (const [name, keys] of Object.entries(spec.expressions ?? {})) {
    if (!EXPRESSION_PRESETS.includes(name) || !keys?.length) continue;
    const nodeIdx = nodes.length;
    nodes.push({ name: `E_${name}`, translation: [0, 0, 0] });
    expressionsUsed[name] = { node: nodeIdx };
    const sorted = [...keys].sort((a, b) => a.t - b.t);
    const times = new Float32Array(sorted.map((k) => k.t));
    const values = new Float32Array(sorted.length * 3);
    sorted.forEach((k, i) => values.set([Math.max(0, Math.min(1, Number(k.w) || 0)), 0, 0], i * 3));
    const input = addAccessor(times, "SCALAR", true);
    const output = addAccessor(values, "VEC3", false);
    samplers.push({ input, output, interpolation: "LINEAR" });
    channels.push({
      sampler: samplers.length - 1,
      target: { node: nodeIdx, path: "translation" }
    });
  }
  if (channels.length === 0) {
    throw new Error("motion has no tracks");
  }
  const humanBones = {};
  for (const name of ALL_BONES) humanBones[name] = { node: nodeIndex[name] ?? 0 };
  const json = {
    asset: { version: "2.0", generator: "theo (adapted from text-to-vrma)" },
    extensionsUsed: ["VRMC_vrm_animation"],
    extensions: {
      VRMC_vrm_animation: {
        specVersion: "1.0",
        humanoid: { humanBones },
        ...Object.keys(expressionsUsed).length ? { expressions: { preset: expressionsUsed } } : {}
      }
    },
    scene: 0,
    scenes: [{ nodes: [nodeIndex.hips] }],
    nodes,
    animations: [{ name: spec.name ?? "motion", channels, samplers }],
    accessors,
    bufferViews,
    buffers: [{ byteLength: binOffset }]
  };
  return packGlb(json, binParts, binOffset);
}
function packGlb(json, binParts, binLength) {
  const encoder = new TextEncoder();
  const jsonBytes = encoder.encode(JSON.stringify(json));
  const jsonPad = (4 - jsonBytes.length % 4) % 4;
  const binPad = (4 - binLength % 4) % 4;
  const jsonChunkLen = jsonBytes.length + jsonPad;
  const binChunkLen = binLength + binPad;
  const total = 12 + 8 + jsonChunkLen + 8 + binChunkLen;
  const buffer = new ArrayBuffer(total);
  const dv = new DataView(buffer);
  const u8 = new Uint8Array(buffer);
  let o = 0;
  dv.setUint32(o, 1179937895, true);
  o += 4;
  dv.setUint32(o, 2, true);
  o += 4;
  dv.setUint32(o, total, true);
  o += 4;
  dv.setUint32(o, jsonChunkLen, true);
  o += 4;
  dv.setUint32(o, 1313821514, true);
  o += 4;
  u8.set(jsonBytes, o);
  o += jsonBytes.length;
  for (let i = 0; i < jsonPad; i++) u8[o++] = 32;
  dv.setUint32(o, binChunkLen, true);
  o += 4;
  dv.setUint32(o, 5130562, true);
  o += 4;
  for (const part of binParts) {
    u8.set(new Uint8Array(part.buffer, part.byteOffset, part.byteLength), o);
    o += part.byteLength;
  }
  return buffer;
}

// packages/core/src/motion/spec.ts
var MAX_DURATION = 20;
var ANGLE_LIMITS = {
  leftHand: 25,
  rightHand: 25,
  leftUpperArm: 75,
  rightUpperArm: 75,
  neck: 45,
  head: 70,
  spine: 45,
  chest: 45,
  upperChest: 45,
  leftFoot: 60,
  rightFoot: 60
};
var DEFAULT_ANGLE_LIMIT = 175;
function clamp(v, lo, hi) {
  return Math.max(lo, Math.min(hi, v));
}
function sampleZ(keys, t) {
  if (keys.length === 0) return 0;
  const sorted = [...keys].sort((a, b) => a.t - b.t);
  const first = sorted[0];
  const last = sorted[sorted.length - 1];
  if (!first || !last) return 0;
  if (t <= first.t) return first.r[2];
  if (t >= last.t) return last.r[2];
  for (let i = 0; i < sorted.length - 1; i++) {
    const a = sorted[i];
    const b = sorted[i + 1];
    if (!a || !b) continue;
    if (t >= a.t && t <= b.t) {
      const f = b.t === a.t ? 0 : (t - a.t) / (b.t - a.t);
      return a.r[2] + (b.r[2] - a.r[2]) * f;
    }
  }
  return last.r[2];
}
function validateMotionSpec(input) {
  const warnings = [];
  if (typeof input !== "object" || input === null) {
    throw new Error("spec must be a JSON object");
  }
  const raw2 = input;
  const duration = Number(raw2.duration);
  if (!Number.isFinite(duration) || duration <= 0) {
    throw new Error("spec.duration must be a positive number of seconds");
  }
  const spec = {
    name: typeof raw2.name === "string" ? raw2.name : void 0,
    duration: Math.min(duration, MAX_DURATION),
    loop: raw2.loop === true,
    tracks: {}
  };
  if (duration > MAX_DURATION) {
    warnings.push(`duration ${duration}s clamped to ${MAX_DURATION}s (keys beyond it dropped)`);
  }
  const tracks = raw2.tracks;
  if (typeof tracks !== "object" || tracks === null) {
    throw new Error("spec.tracks is required (bone name \u2192 keyframe array)");
  }
  for (const [bone, keysRaw] of Object.entries(tracks)) {
    if (!BONE_NAMES.includes(bone)) {
      warnings.push(`unknown bone "${bone}" dropped (valid bones: see theo_motion_guide)`);
      continue;
    }
    if (bone === "leftShoulder" || bone === "rightShoulder") {
      warnings.push(`${bone} dropped \u2014 shoulders are auto-driven; build arm motion with upperArm`);
      continue;
    }
    if (!Array.isArray(keysRaw)) {
      warnings.push(`track "${bone}" is not an array \u2014 dropped`);
      continue;
    }
    const limit = ANGLE_LIMITS[bone] ?? DEFAULT_ANGLE_LIMIT;
    const keys = [];
    for (const k of keysRaw) {
      if (typeof k?.t !== "number" || !Array.isArray(k.r) || k.r.length !== 3) {
        warnings.push(`malformed keyframe in "${bone}" dropped (need {t, r:[x,y,z]})`);
        continue;
      }
      if (k.t > spec.duration) continue;
      const r = k.r.map((v) => {
        const n = Number(v) || 0;
        if (Math.abs(n) > limit) {
          warnings.push(`${bone} angle ${n}\xB0 clamped to \xB1${limit}\xB0`);
        }
        return clamp(n, -limit, limit);
      });
      keys.push({ t: k.t, r });
    }
    if (bone === "leftLowerLeg" || bone === "rightLowerLeg") {
      for (const k of keys) {
        const before = [...k.r];
        k.r[0] = clamp(k.r[0], -3, 140);
        k.r[1] = clamp(k.r[1], -15, 15);
        k.r[2] = clamp(k.r[2], -15, 15);
        if (String(before) !== String(k.r)) {
          warnings.push(`${bone} clamped to hinge range (X -3..140, Y/Z \xB115)`);
        }
      }
    }
    if (bone === "leftLowerArm" || bone === "rightLowerArm") {
      const fwdSign = bone === "rightLowerArm" ? 1 : -1;
      for (const k of keys) {
        const before = [...k.r];
        k.r[0] = clamp(k.r[0], -10, 10);
        const y = fwdSign * k.r[1];
        k.r[1] = fwdSign * clamp(y, -15, 135);
        if (String(before) !== String(k.r)) {
          warnings.push(`${bone} clamped (X \xB110, forward bend -15..135) \u2014 keep elbow X at 0`);
        }
      }
    }
    if (keys.length > 0) spec.tracks[bone] = keys;
  }
  for (const side of ["left", "right"]) {
    const ua = spec.tracks[`${side}UpperArm`];
    const la = spec.tracks[`${side}LowerArm`];
    if (!ua?.length || !la?.length) continue;
    for (const k of la) {
      const uaZ = sampleZ(ua, k.t);
      if (Math.abs(uaZ) < 40) continue;
      const sign = Math.sign(uaZ);
      if (Math.sign(k.r[2]) === -sign && Math.abs(k.r[2]) > 15) {
        k.r[2] = -sign * 15;
        warnings.push(`${side}LowerArm Z folded against the raised arm \u2014 limited to 15\xB0`);
      }
    }
  }
  for (const side of ["left", "right"]) {
    const ua = spec.tracks[`${side}UpperArm`];
    const la = spec.tracks[`${side}LowerArm`];
    if (!ua?.length || !la?.length) continue;
    const raiseSign = side === "left" ? 1 : -1;
    const maxBend = Math.max(...la.map((k) => Math.max(Math.abs(k.r[1]), Math.abs(k.r[2]))));
    if (maxBend > 55) {
      for (const k of ua) {
        if (raiseSign * k.r[2] > 58) {
          k.r[2] = raiseSign * 58;
          warnings.push(
            `${side}UpperArm raise limited to 58\xB0 while the elbow bends >55\xB0 (forearm would cover the head)`
          );
        }
      }
    }
  }
  if (Array.isArray(raw2.hips)) {
    const hips = [];
    for (const k of raw2.hips) {
      if (typeof k?.t !== "number" || !Array.isArray(k.p) || k.p.length !== 3) {
        warnings.push("malformed hips keyframe dropped (need {t, p:[x,y,z]})");
        continue;
      }
      if (k.t > spec.duration) continue;
      hips.push({ t: k.t, p: k.p.map((v) => Number(v) || 0) });
    }
    if (hips.length > 0) spec.hips = hips;
  }
  if (typeof raw2.expressions === "object" && raw2.expressions !== null) {
    const expressions = {};
    for (const [name, keysRaw] of Object.entries(raw2.expressions)) {
      if (!EXPRESSION_PRESETS.includes(name)) {
        warnings.push(
          `unknown expression "${name}" dropped (valid: ${EXPRESSION_PRESETS.join(", ")})`
        );
        continue;
      }
      if (!Array.isArray(keysRaw)) continue;
      const keys = [];
      for (const k of keysRaw) {
        if (typeof k?.t !== "number" || typeof k?.w !== "number" || k.t > spec.duration) continue;
        keys.push({ t: k.t, w: clamp(k.w, 0, 1) });
      }
      if (keys.length > 0) expressions[name] = keys;
    }
    if (Object.keys(expressions).length > 0) spec.expressions = expressions;
  }
  if (Object.keys(spec.tracks).length === 0 && !spec.hips?.length) {
    throw new Error("motion has no valid tracks \u2014 check bone names against theo_motion_guide");
  }
  return { spec, warnings };
}

// ../../../../private/tmp/claude-501/-Users-yuzu-develop-theo/ad2d3073-efe5-4247-8897-522c74e3a7a4/scratchpad/vrma-cli-entry.ts
function fail(message) {
  console.log(JSON.stringify({ ok: false, error: message }));
  process.exit(1);
}
var [specPath, outPath] = process.argv.slice(2);
if (!specPath || !outPath) {
  fail("usage: node build-vrma.mjs <spec.json> <out.vrma>");
}
var raw;
try {
  raw = JSON.parse(readFileSync(specPath, "utf-8"));
} catch (err) {
  fail(`cannot read/parse spec: ${err instanceof Error ? err.message : String(err)}`);
}
try {
  const { spec, warnings } = validateMotionSpec(raw);
  const glb = buildVrma(spec);
  writeFileSync(outPath, Buffer.from(glb));
  const buf = readFileSync(outPath);
  if (buf.readUInt32LE(0) !== 1179937895 || buf.readUInt32LE(8) !== buf.length) {
    fail("self-check failed: written file is not a valid GLB");
  }
  const jsonLen = buf.readUInt32LE(12);
  const json = buf.subarray(20, 20 + jsonLen).toString("utf-8");
  if (!json.includes("VRMC_vrm_animation")) {
    fail("self-check failed: VRMC_vrm_animation extension missing");
  }
  console.log(
    JSON.stringify({ ok: true, out: outPath, bytes: glb.byteLength, durationS: spec.duration, warnings })
  );
} catch (err) {
  fail(err instanceof Error ? err.message : String(err));
}
