// Salon de jeu : un Durable Object par code de 4 lettres. Place 0 = hôte, places 1 à 3 = invités (jusqu'au maximum
// choisi par l'hôte). Chaque message binaire part chez tous les autres, précédé d'un octet : la place de l'expéditeur.
import { DurableObject } from "cloudflare:workers";

type Role = "host" | "guest";

const MAX_MESSAGE = 64 * 1024;
const MAX_PLAYERS = 4;

export class Room extends DurableObject<Record<string, never>> {
  constructor(ctx: DurableObjectState, env: Record<string, never>) {
    super(ctx, env);
    ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair("ping", "pong"));
  }

  async fetch(request: Request): Promise<Response> {
    const params = new URL(request.url).searchParams;
    const role = params.get("role");
    if (role !== "host" && role !== "guest") {
      return new Response("rôle attendu : host ou guest", { status: 400 });
    }
    const max = Math.min(Math.max(Number(params.get("max") ?? 2) || 2, 2), MAX_PLAYERS);
    const pair = new WebSocketPair();
    const [client, server] = [pair[0], pair[1]];
    const refusal = this.refusal(role);
    const slot = role === "host" ? 0 : this.freeSlot();
    if (refusal || slot < 0) {
      const r = refusal ?? { code: 4002, reason: "salon plein" };
      server.accept();
      server.close(r.code, r.reason);
      return new Response(null, { status: 101, webSocket: client });
    }
    const tags = [role, `s${slot}`];
    if (role === "host") tags.push(`max${max}`);
    this.ctx.acceptWebSocket(server, tags);
    const others = this.ctx.getWebSockets().filter((w) => w !== server);
    send(server, { t: "hello", role, slot, peers: others.map((w) => this.slotOf(w)) });
    for (const w of others) send(w, { t: "peer", slot, on: true });
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    if (typeof message === "string") return;
    if (message.byteLength > MAX_MESSAGE) {
      ws.close(1009, "message trop gros");
      return;
    }
    const framed = new Uint8Array(message.byteLength + 1);
    framed[0] = this.slotOf(ws);
    framed.set(new Uint8Array(message), 1);
    for (const w of this.ctx.getWebSockets()) {
      if (w !== ws) {
        try {
          w.send(framed);
        } catch (err) {
          console.log("relais impossible", err);
        }
      }
    }
  }

  async webSocketClose(ws: WebSocket, code: number): Promise<void> {
    const slot = this.slotOf(ws);
    for (const w of this.ctx.getWebSockets()) {
      if (w !== ws) send(w, { t: "peer", slot, on: false });
    }
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
    const host = this.ctx.getWebSockets("host")[0];
    if (role === "host" && host) return { code: 4001, reason: "code déjà pris" };
    if (role === "guest" && !host) return { code: 4004, reason: "aucune partie avec ce code" };
    return null;
  }

  // Plus petite place d'invité libre, ou -1 si le salon a atteint le maximum de l'hôte.
  private freeSlot(): number {
    const host = this.ctx.getWebSockets("host")[0];
    if (!host) return 1;
    const maxTag = this.ctx.getTags(host).find((t) => t.startsWith("max"));
    const max = Number(maxTag?.slice(3) ?? 2);
    const taken = new Set(this.ctx.getWebSockets().map((w) => this.slotOf(w)));
    for (let s = 1; s < max; s++) if (!taken.has(s)) return s;
    return -1;
  }

  private slotOf(ws: WebSocket): number {
    const tag = this.ctx.getTags(ws).find((t) => /^s\d$/.test(t));
    return Number(tag?.slice(1) ?? 0);
  }
}

function send(ws: WebSocket, msg: Record<string, unknown>): void {
  try {
    ws.send(JSON.stringify(msg));
  } catch (err) {
    console.log("envoi impossible", err);
  }
}
