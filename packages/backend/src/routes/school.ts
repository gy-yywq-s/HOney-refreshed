import type { FastifyInstance } from "fastify";
import type { AppContext } from "../context.js";
import type { CardResponse, WarningsResponse, WeekendResponse } from "@honey/shared/api";
import { parsePortalTime } from "@honey/shared/access";

// The student's own records at the school (Gary 2026-09-03: campus card,
// disciplinary warnings, weekend stay-overs). These are PERSONAL and are never
// stored by HOney: each request reads them live with the student's own sealed
// portal token and hands them straight back. Nothing here mutates anything
// upstream — every call is a GET.

/** A dead portal session is a state, not an error: the client reconnects. */
function isExpired(e: unknown): boolean {
  const kind = e instanceof Error && "info" in e ? (e as { info: { kind: string } }).info.kind : "";
  return kind === "sessionExpired" || kind === "credentialsRejected";
}

export function registerSchoolRoutes(app: FastifyInstance, ctx: AppContext): void {
  const tokenFor = (honeyId: string) => ctx.accounts.loadPortalToken(honeyId)?.token ?? null;

  app.get("/api/school/card", { preHandler: ctx.requireAuth }, async (req, reply): Promise<CardResponse> => {
    void reply.header("cache-control", "no-store");
    const token = tokenFor(ctx.userOf(req).honey_id);
    if (!token) return { status: "portal_reconnect_required", card: null, purchases: [], topUps: [] };
    try {
      const cards = await ctx.connector.api.cardList(token);
      const first = cards[0];
      if (!first) return { status: "ok", card: null, purchases: [], topUps: [] };
      // The card is addressed by NUMBER upstream: cardId answers 500.
      // Spending is addressed by card NUMBER, top-ups by card ID — the two
      // endpoints disagree upstream, and each 500s on the other's key.
      const [purchases, topUps] = await Promise.all([
        ctx.connector.api.cardConsume(token, first.cardNo).catch(() => []),
        ctx.connector.api.cardRecharges(token, first.cardId).catch(() => []),
      ]);
      return {
        status: "ok",
        card: {
          cardNo: first.cardNo,
          balance: first.totalAccount,
          general: first.genAccount,
          subsidy: first.subAccount,
          usable: first.useStatus === 1,
          validFrom: first.startDate,
          validTo: first.endDate,
        },
        // The portal's own order is not chronological (two purchases in the
        // same minute came back oldest-first): sort by the time it stamped.
        purchases: purchases
          .map((p) => ({
            id: p.chargeNo,
            where: p.merchantName,
            amount: p.deduction,
            balanceAfter: p.balance,
            at: parsePortalTime(p.debitTime.slice(0, 19)) ?? 0,
          }))
          .sort((a, b) => b.at - a.at),
        topUps: topUps
          .map((r) => ({
            id: r.trade_number,
            amount: Number(r.amount) || 0,
            state: r.status_str,
            at: parsePortalTime(r.create_time) ?? 0,
          }))
          .sort((a, b) => b.at - a.at),
      };
    } catch (e) {
      if (isExpired(e)) {
        ctx.accounts.markPortalExpired(ctx.userOf(req).honey_id);
        return { status: "portal_reconnect_required", card: null, purchases: [], topUps: [] };
      }
      return { status: "unavailable", card: null, purchases: [], topUps: [] };
    }
  });

  app.get("/api/school/warnings", { preHandler: ctx.requireAuth }, async (req, reply): Promise<WarningsResponse> => {
    void reply.header("cache-control", "no-store");
    const user = ctx.userOf(req);
    const token = tokenFor(user.honey_id);
    if (!token) return { status: "portal_reconnect_required", warnings: [] };
    try {
      const rows = await ctx.connector.api.warnings(token);
      return {
        status: "ok",
        warnings: rows.map((w) => ({
          id: w.record_id,
          kind: w.warn_type_str,
          rule: w.warn_select_str,
          reason: w.warn_reason,
          on: w.warn_time,
          by: w.operator_name,
          recordedAt: w.create_time,
        })),
      };
    } catch (e) {
      if (isExpired(e)) {
        ctx.accounts.markPortalExpired(user.honey_id);
        return { status: "portal_reconnect_required", warnings: [] };
      }
      return { status: "unavailable", warnings: [] };
    }
  });

  app.get("/api/school/weekend", { preHandler: ctx.requireAuth }, async (req, reply): Promise<WeekendResponse> => {
    void reply.header("cache-control", "no-store");
    const user = ctx.userOf(req);
    const conn = ctx.accounts.loadPortalToken(user.honey_id);
    if (!conn) return { status: "portal_reconnect_required", stays: [], selectableDays: [] };
    try {
      const [rows, days] = await Promise.all([
        ctx.connector.api.weekendStays(conn.token),
        ctx.connector.api.weekendDays(conn.token, conn.studentId).catch(() => [] as string[]),
      ]);
      return {
        status: "ok",
        stays: rows.map((s) => ({
          id: s.record_id,
          date: s.live_date,
          label: s.live_date_str,
          mentor: s.mentor_name,
          campus: s.campus_name,
        })),
        selectableDays: days,
      };
    } catch (e) {
      if (isExpired(e)) {
        ctx.accounts.markPortalExpired(user.honey_id);
        return { status: "portal_reconnect_required", stays: [], selectableDays: [] };
      }
      return { status: "unavailable", stays: [], selectableDays: [] };
    }
  });
}
