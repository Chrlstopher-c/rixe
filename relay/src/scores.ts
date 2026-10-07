// Classement mondial : un seul Durable Object (SQLite) garde, par tableau, le meilleur score de chaque pseudo.
import { DurableObject } from "cloudflare:workers";

const BOARD = /^[a-z0-9_]{1,32}$/;
const NAME = /^[A-Za-z0-9_-]{1,14}$/;
const TOP = 20;
const MAX_SCORE = 100000;
// Envois par adresse et par minute (anti-déluge, pas un anti-triche).
const RATE = 20;

export interface ScoreRow {
  name: string;
  score: number;
  at: string;
}

// Tableaux où le plus petit score gagne (temps pour atteindre l'objectif).
function lowerIsBetter(board: string): boolean {
  return board.startsWith("objectif");
}

export class Scores extends DurableObject<Record<string, never>> {
  private hits = new Map<string, { n: number; since: number }>();

  constructor(ctx: DurableObjectState, env: Record<string, never>) {
    super(ctx, env);
    ctx.storage.sql.exec(
      "CREATE TABLE IF NOT EXISTS scores (board TEXT, name TEXT, score REAL, at TEXT, PRIMARY KEY (board, name))",
    );
  }

  top(board: string): ScoreRow[] {
    if (!BOARD.test(board)) return [];
    const order = lowerIsBetter(board) ? "ASC" : "DESC";
    return this.ctx.storage.sql
      .exec<{ name: string; score: number; at: string }>(
        `SELECT name, score, at FROM scores WHERE board = ? ORDER BY score ${order}, at ASC LIMIT ${TOP}`,
        board,
      )
      .toArray();
  }

  submit(ip: string, board: string, name: string, score: number): { ok: boolean; error?: string; rank?: number } {
    if (!BOARD.test(board) || !NAME.test(name)) return { ok: false, error: "tableau ou pseudo invalide" };
    if (!Number.isFinite(score) || score <= 0 || score > MAX_SCORE) return { ok: false, error: "score invalide" };
    if (!this.allow(ip)) return { ok: false, error: "trop d'envois, réessaie dans une minute" };
    const lower = lowerIsBetter(board);
    const prev = this.ctx.storage.sql
      .exec<{ score: number }>("SELECT score FROM scores WHERE board = ? AND name = ?", board, name)
      .toArray()[0];
    const better = !prev || (lower ? score < prev.score : score > prev.score);
    if (better) {
      this.ctx.storage.sql.exec(
        "INSERT OR REPLACE INTO scores (board, name, score, at) VALUES (?, ?, ?, ?)",
        board,
        name,
        score,
        new Date().toISOString().slice(0, 10),
      );
    }
    const rank = this.top(board).findIndex((r) => r.name === name);
    return { ok: true, rank };
  }

  private allow(ip: string): boolean {
    const now = Date.now();
    const h = this.hits.get(ip);
    if (!h || now - h.since > 60000) {
      this.hits.set(ip, { n: 1, since: now });
      return true;
    }
    h.n += 1;
    return h.n <= RATE;
  }
}
