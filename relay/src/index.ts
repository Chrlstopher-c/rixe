// Worker Rixe : salons de jeu en ligne (/room/CODE, voir room.ts) et classement mondial (/scores, voir scores.ts).
// Le relais ne lit jamais le jeu : il fait passer les messages entre les joueurs d'un même salon.
import { Room } from "./room";
import { Scores } from "./scores";

export { Room, Scores };

interface Env {
  ROOMS: DurableObjectNamespace<Room>;
  SCORES: DurableObjectNamespace<Scores>;
}

const CODE = /^[A-Z]{4}$/;

const CORS = { "Access-Control-Allow-Origin": "*", "Content-Type": "application/json" };

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), { status, headers: CORS });
}

// Classement mondial : GET /scores?board=… (top 20), POST /scores {board, name, score}.
async function scores(request: Request, env: Env, url: URL): Promise<Response> {
  const board = env.SCORES.get(env.SCORES.idFromName("global"));
  if (request.method === "GET") {
    const name = url.searchParams.get("board") ?? "";
    return json({ board: name, top: await board.top(name) });
  }
  if (request.method !== "POST") return json({ error: "méthode" }, 405);
  let body: { board?: unknown; name?: unknown; score?: unknown };
  try {
    body = await request.json();
  } catch (err) {
    console.log("score illisible", err);
    return json({ error: "json attendu" }, 400);
  }
  const ip = request.headers.get("CF-Connecting-IP") ?? "local";
  const res = await board.submit(ip, String(body.board ?? ""), String(body.name ?? ""), Number(body.score));
  return json(res, res.ok ? 200 : 400);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/scores") return scores(request, env, url);
    const match = url.pathname.match(/^\/room\/([A-Za-z]{4})$/);
    if (!match) return new Response("rixe relay", { status: url.pathname === "/" ? 200 : 404 });
    const code = match[1].toUpperCase();
    if (!CODE.test(code) || request.headers.get("Upgrade") !== "websocket") {
      return new Response("websocket attendu", { status: 426 });
    }
    return env.ROOMS.get(env.ROOMS.idFromName(code)).fetch(request);
  },
} satisfies ExportedHandler<Env>;
