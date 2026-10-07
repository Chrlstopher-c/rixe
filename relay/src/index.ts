// Relais Rixe : un salon (Durable Object) par code de 4 lettres, deux places (hôte, invité).
// Les messages binaires d'un joueur partent tels quels chez l'autre ; le relais ne lit jamais le jeu.
import { DurableObject } from "cloudflare:workers";

type Role = "host" | "guest";

interface Env {
  ROOMS: DurableObjectNamespace<Room>;
}

const CODE = /^[A-Z]{4}$/;
const MAX_MESSAGE = 64 * 1024;

export class Room extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair("ping", "pong"));
  }

  async fetch(request: Request): Promise<Response> {
    const role = new URL(request.url).searchParams.get("role");
    if (role !== "host" && role !== "guest") {
      return new Response("rôle attendu : host ou guest", { status: 400 });
    }
    const refusal = this.refusal(role);
    const pair = new WebSocketPair();
    const [client, server] = [pair[0], pair[1]];
    if (refusal) {
      server.accept();
      server.close(refusal.code, refusal.reason);
      return new Response(null, { status: 101, webSocket: client });
    }
    this.ctx.acceptWebSocket(server, [role]);
    const other = this.peer(role);
    send(server, { t: "hello", role, peer: other !== null });
    if (other) send(other, { t: "peer", on: true });
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    if (typeof message === "string") return;
    if (message.byteLength > MAX_MESSAGE) {
      ws.close(1009, "message trop gros");
      return;
    }
    this.peer(this.roleOf(ws))?.send(message);
  }

  async webSocketClose(ws: WebSocket, code: number): Promise<void> {
    const role = this.roleOf(ws);
    const other = this.peer(role);
    if (other) send(other, { t: "peer", on: false });
    try {
      ws.close(code === 1000 || (code >= 3000 && code < 5000) ? code : 1000, "fin");
    } catch (err) {
      console.log("fermeture déjà faite", err);
    }
  }

  async webSocketError(ws: WebSocket, error: unknown): Promise<void> {
    console.log("erreur de socket", error);
    await this.webSocketClose(ws, 1011);
  }

  private refusal(role: Role): { code: number; reason: string } | null {
    if (this.ctx.getWebSockets(role).length > 0) {
      return role === "host" ? { code: 4001, reason: "code déjà pris" } : { code: 4002, reason: "salon plein" };
    }
    if (role === "guest" && this.ctx.getWebSockets("host").length === 0) {
      return { code: 4004, reason: "aucune partie avec ce code" };
    }
    return null;
  }

  private roleOf(ws: WebSocket): Role {
    return this.ctx.getTags(ws).includes("host") ? "host" : "guest";
  }

  private peer(role: Role): WebSocket | null {
    return this.ctx.getWebSockets(role === "host" ? "guest" : "host")[0] ?? null;
  }
}

function send(ws: WebSocket, msg: Record<string, unknown>): void {
  try {
    ws.send(JSON.stringify(msg));
  } catch (err) {
    console.log("envoi impossible", err);
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const match = url.pathname.match(/^\/room\/([A-Za-z]{4})$/);
    if (!match) return new Response("rixe relay", { status: url.pathname === "/" ? 200 : 404 });
    const code = match[1].toUpperCase();
    if (!CODE.test(code) || request.headers.get("Upgrade") !== "websocket") {
      return new Response("websocket attendu", { status: 426 });
    }
    return env.ROOMS.get(env.ROOMS.idFromName(code)).fetch(request);
  },
} satisfies ExportedHandler<Env>;
