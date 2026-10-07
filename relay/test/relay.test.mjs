// Test de bout en bout du relais : lance `wrangler dev` en local, puis vérifie salons, relais et refus.
import { spawn } from "node:child_process";
import WebSocket from "ws";

const PORT = 8790 + Math.floor(Math.random() * 100);
const BASE = process.env.RELAY_URL ?? `ws://127.0.0.1:${PORT}`;
let failures = 0;

function check(cond, msg) {
  console.log(`${cond ? "  ok" : "  ✗"} ${msg}`);
  if (!cond) failures++;
}

function open(code, role) {
  return new Promise((resolve) => {
    const ws = new WebSocket(`${BASE}/room/${code}?role=${role}`);
    const state = { ws, inbox: [], closed: null };
    ws.on("message", (data, binary) => state.inbox.push(binary ? Buffer.from(data) : JSON.parse(data.toString())));
    ws.on("open", () => resolve(state));
    ws.on("close", (c) => {
      state.closed = c;
      resolve(state);
    });
    ws.on("error", () => {});
  });
}

const wait = (ms) => new Promise((r) => setTimeout(r, ms));

async function until(fn, ms = 3000) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (fn()) return true;
    await wait(20);
  }
  return false;
}

async function startServer() {
  if (process.env.RELAY_URL) return null;
  const proc = spawn("./node_modules/.bin/wrangler", ["dev", "--port", String(PORT), "--ip", "127.0.0.1"], {
    env: { ...process.env, WRANGLER_SEND_METRICS: "false", CI: "1" },
    stdio: ["ignore", "pipe", "pipe"],
  });
  let log = "";
  proc.stdout.on("data", (d) => (log += d));
  proc.stderr.on("data", (d) => (log += d));
  const ready = await until(() => log.includes("Ready on"), 60000);
  if (!ready) {
    console.log(log);
    throw new Error("wrangler dev n'a pas démarré");
  }
  return proc;
}

async function run() {
  const code = "T" + String.fromCharCode(65 + Math.floor(Math.random() * 26)) + "ST";
  const host = await open(code, "host");
  check(host.closed === null, "l'hôte ouvre le salon");
  await until(() => host.inbox.length > 0);
  check(host.inbox[0]?.t === "hello" && host.inbox[0]?.role === "host" && !host.inbox[0]?.peer, "hôte accueilli, seul");
  const taken = await open(code, "host");
  await until(() => taken.closed !== null);
  check(taken.closed === 4001, "un 2e hôte est refusé (code déjà pris)");
  const absent = await open("ZZZZ", "guest");
  await until(() => absent.closed !== null);
  check(absent.closed === 4004, "rejoindre un code inconnu est refusé");
  const guest = await open(code, "guest");
  await until(() => guest.inbox.length > 0 && host.inbox.length > 1);
  check(guest.inbox[0]?.peer === true, "l'invité voit l'hôte");
  check(host.inbox[1]?.t === "peer" && host.inbox[1]?.on === true, "l'hôte voit arriver l'invité");
  const full = await open(code, "guest");
  await until(() => full.closed !== null);
  check(full.closed === 4002, "un 2e invité est refusé (salon plein)");
  host.ws.send(Buffer.from([1, 2, 3]));
  guest.ws.send(Buffer.from([9, 8]));
  await until(() => guest.inbox.length > 1 && host.inbox.length > 2);
  check(Buffer.isBuffer(guest.inbox[1]) && guest.inbox[1].equals(Buffer.from([1, 2, 3])), "hôte → invité relayé");
  check(Buffer.isBuffer(host.inbox[2]) && host.inbox[2].equals(Buffer.from([9, 8])), "invité → hôte relayé");
  guest.ws.close();
  await until(() => host.inbox.length > 3);
  check(host.inbox[3]?.t === "peer" && host.inbox[3]?.on === false, "l'hôte apprend le départ de l'invité");
  host.ws.close();
}

const HTTP = BASE.replace(/^ws/, "http");

async function post(board, name, score) {
  const r = await fetch(`${HTTP}/scores`, { method: "POST", body: JSON.stringify({ board, name, score }) });
  return { status: r.status, body: await r.json() };
}

async function top(board) {
  return (await (await fetch(`${HTTP}/scores?board=${board}`)).json()).top;
}

async function runScores() {
  const b = "test" + Math.floor(Math.random() * 1e6);
  check((await post(b, "anon1", 5)).status === 200, "score enregistré");
  await post(b, "anon2", 9);
  await post(b, "anon1", 3);
  let t = await top(b);
  check(t.length === 2 && t[0].name === "anon2" && t[1].score === 5, "meilleur score gardé par pseudo, tri décroissant");
  check((await post(b, "<script>", 4)).status === 400, "pseudo invalide refusé");
  check((await post(b, "anon3", -2)).status === 400, "score invalide refusé");
  const o = "objectif_t" + Math.floor(Math.random() * 1e6);
  await post(o, "lent", 90);
  await post(o, "rapide", 40);
  t = await top(o);
  check(t[0].name === "rapide", "objectif : le plus rapide en tête");
}

const server = await startServer();
try {
  await run();
  await runScores();
} catch (err) {
  console.log("erreur", err);
  failures++;
} finally {
  server?.kill("SIGTERM");
}
console.log(failures === 0 ? "RELAY OK" : `RELAY FAILED (${failures})`);
process.exit(failures === 0 ? 0 : 1);
