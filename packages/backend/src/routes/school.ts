import type { FastifyInstance } from "fastify";
import type { AppContext } from "../context.js";
import type { CardResponse, CardTopUpResponse, FeatureFlags, FeedbackResponse, FeedbackSubmission, SchoolActionResponse, WarningsResponse, WeekendResponse } from "@honey/shared/api";
import { parsePortalTime } from "@honey/shared/access";

// The student's own records at the school (Gary 2026-09-03: campus card,
// disciplinary warnings, weekend stay-overs). These are PERSONAL and are never
// stored by HOney: each request reads them live with the student's own sealed
// portal token and hands them straight back. Nothing here mutates anything
// upstream — every call is a GET.

/** The amounts the school's own recharge form offers (its select, 2026-09-03). */
const TOP_UP_AMOUNTS = [100, 200, 300, 500, 1000];

/** A dead portal session is a state, not an error: the client reconnects. */
function isExpired(e: unknown): boolean {
  const kind = e instanceof Error && "info" in e ? (e as { info: { kind: string } }).info.kind : "";
  return kind === "sessionExpired" || kind === "credentialsRejected";
}

export function registerSchoolRoutes(app: FastifyInstance, ctx: AppContext): void {
  const tokenFor = (honeyId: string) => ctx.accounts.loadPortalToken(honeyId)?.token ?? null;

  /** One failure mapping for the actions: expiry, the school's refusal, or an outage. */
  const failure = (e: unknown, honeyId: string): SchoolActionResponse => {
    if (isExpired(e)) {
      ctx.accounts.markPortalExpired(honeyId);
      return { status: "portal_reconnect_required" };
    }
    const info = e instanceof Error && "info" in e ? (e as { info: { kind: string; reason?: string } }).info : null;
    if (info?.kind === "operationRejected") return { status: "refused", reason: info.reason ?? "The school refused it." };
    return { status: "unavailable" };
  };

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

  /**
   * Open a top-up order for the student's card. HOney does not take payment:
   * the school answers with where to pay, and the student pays there. Sending
   * this twice opens two orders and costs nothing — an unpaid order is just
   * unpaid — so it needs no confirmation gate; the amount is bounded because a
   * typo should not create an order for a fortune.
   */
  app.post<{ Body: { amount?: number } }>("/api/school/card/topup", { preHandler: ctx.requireAuth }, async (req, reply): Promise<CardTopUpResponse> => {
    void reply.header("cache-control", "no-store");
    const user = ctx.userOf(req);
    const token = tokenFor(user.honey_id);
    if (!token) return { status: "portal_reconnect_required" };
    // The school's own recharge form offers exactly these five amounts
    // (Gary's screenshots of My Cards, 2026-09-03) — HOney offers the same.
    const amount = Math.round(Number(req.body?.amount ?? 0));
    if (!TOP_UP_AMOUNTS.includes(amount)) {
      return { status: "refused", reason: "Choose one of the amounts the school offers." };
    }
    try {
      const cards = await ctx.connector.api.cardList(token);
      const card = cards[0];
      if (!card) return { status: "refused", reason: "No card is registered to you." };
      const started = await ctx.connector.api.startRecharge(token, card.cardId, amount);
      // What the school answers with was never observable without opening an
      // order, so the SHAPE is journalled on the first real attempt (Gary
      // 2026-09-03: 兼容两种，记 log，我试了你再改). Keys and value kinds only;
      // a payment URL is reduced to its origin, path and parameter NAMES.
      let where = "none";
      if (started.payUrl) {
        try {
          const u = new URL(started.payUrl);
          where = `${u.origin}${u.pathname} (params: ${[...u.searchParams.keys()].join(",") || "-"})`;
        } catch {
          where = "unparseable-url";
        }
      } else if (started.formHtml) {
        where = `form action=${/action="([^"]*)"/i.exec(started.formHtml)?.[1] ?? "?"}`;
      }
      // eslint-disable-next-line no-console
      console.log(
        `[honey-card] do-recharge answered: amount=${amount} message=${JSON.stringify(started.message.slice(0, 120))} pay=${where} shape=${started.shape}`,
      );
      return { status: "ok", payUrl: started.payUrl, formHtml: started.formHtml, message: started.message };
    } catch (e) {
      if (isExpired(e)) {
        ctx.accounts.markPortalExpired(user.honey_id);
        return { status: "portal_reconnect_required" };
      }
      const info = e instanceof Error && "info" in e ? (e as { info: { kind: string; reason?: string } }).info : null;
      if (info?.kind === "operationRejected") return { status: "refused", reason: info.reason ?? "The school refused the top-up." };
      return { status: "unavailable" };
    }
  });

  /** Apply to stay over on the chosen weekend days. */
  app.post<{ Body: { dates?: string[] } }>("/api/school/weekend/apply", { preHandler: ctx.requireAuth }, async (req, reply): Promise<SchoolActionResponse> => {
    void reply.header("cache-control", "no-store");
    const user = ctx.userOf(req);
    const token = tokenFor(user.honey_id);
    if (!token) return { status: "portal_reconnect_required" };
    const dates = (req.body?.dates ?? []).filter((d) => typeof d === "string" && /^\d{4}-\d{2}-\d{2}$/.test(d));
    if (dates.length === 0) return { status: "refused", reason: "Choose at least one day." };
    try {
      await ctx.connector.api.applyWeekendStay(token, dates);
      return { status: "ok" };
    } catch (e) {
      return failure(e, user.honey_id);
    }
  });

  /** Withdraw one stay-over the school has on record. */
  app.post<{ Body: { recordId?: number } }>("/api/school/weekend/withdraw", { preHandler: ctx.requireAuth }, async (req, reply): Promise<SchoolActionResponse> => {
    void reply.header("cache-control", "no-store");
    const user = ctx.userOf(req);
    const token = tokenFor(user.honey_id);
    if (!token) return { status: "portal_reconnect_required" };
    const recordId = Number(req.body?.recordId);
    if (!Number.isInteger(recordId)) return { status: "refused", reason: "Unknown record." };
    try {
      await ctx.connector.api.withdrawWeekendStay(token, recordId);
      return { status: "ok" };
    } catch (e) {
      return failure(e, user.honey_id);
    }
  });

  /** Lessons still waiting for this student's feedback (the portal's own list). */
  /** What the app shows (Dash owns the switches). */
  app.get("/api/features", { preHandler: ctx.requireAuth }, async (): Promise<FeatureFlags> => ({
    lessonFeedback: ctx.settings.feature("lessonFeedback"),
    schoolFeedback: ctx.settings.feature("schoolFeedback"),
  }));

  /** The school's own feedback channel — NOT anonymous: it goes under the student's name. */
  app.post<{ Body: { text?: string } }>("/api/school/complaint", { preHandler: ctx.requireAuth }, async (req, reply): Promise<SchoolActionResponse> => {
    void reply.header("cache-control", "no-store");
    const user = ctx.userOf(req);
    const token = tokenFor(user.honey_id);
    if (!token) return { status: "portal_reconnect_required" };
    const text = String(req.body?.text ?? "").trim();
    if (text.length < 4) return { status: "refused", reason: "Write what you want the school to know." };
    try {
      await ctx.connector.api.submitComplaint(token, text.slice(0, 2000));
      return { status: "ok" };
    } catch (e) {
      return failure(e, user.honey_id);
    }
  });

  app.get("/api/school/feedback", { preHandler: ctx.requireAuth }, async (req, reply): Promise<FeedbackResponse> => {
    void reply.header("cache-control", "no-store");
    const user = ctx.userOf(req);
    const token = tokenFor(user.honey_id);
    if (!token) return { status: "portal_reconnect_required", pending: [] };
    try {
      const rows = await ctx.connector.api.pendingFeedback(token);
      return {
        status: "ok",
        pending: rows
          .map((r) => ({ lessonId: r.lesson_id, teacher: r.teacher_name, topic: r.topic_name, at: r.start_time * 1000, week: r.week_num }))
          .sort((a, b) => b.at - a.at),
      };
    } catch (e) {
      if (isExpired(e)) {
        ctx.accounts.markPortalExpired(user.honey_id);
        return { status: "portal_reconnect_required", pending: [] };
      }
      return { status: "unavailable", pending: [] };
    }
  });

  /** Send one lesson's feedback, in the school's own fields. */
  app.post<{ Body: Partial<FeedbackSubmission> }>("/api/school/feedback", { preHandler: ctx.requireAuth }, async (req, reply): Promise<SchoolActionResponse> => {
    void reply.header("cache-control", "no-store");
    const user = ctx.userOf(req);
    const token = tokenFor(user.honey_id);
    if (!token) return { status: "portal_reconnect_required" };
    const b = req.body ?? {};
    const lessonId = Number(b.lessonId);
    const rating = Math.round(Number(b.rating ?? 0));
    if (!Number.isInteger(lessonId)) return { status: "refused", reason: "Unknown lesson." };
    if (!(rating >= 1 && rating <= 5)) return { status: "refused", reason: "Choose a rating." };
    try {
      await ctx.connector.api.submitFeedback(token, {
        lesson_id: lessonId,
        rating,
        feedback: String(b.comment ?? "").slice(0, 1000),
        late: b.wasLate ? 1 : 0,
        used_mobile: b.usedMobile ? 1 : 0,
        unprepared: b.unprepared ? 1 : 0,
        understandable: b.didNotUnderstand ? 1 : 0,
      });
      return { status: "ok" };
    } catch (e) {
      return failure(e, user.honey_id);
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
        ctx.connector.api.weekendDays(conn.token, 1).catch(() => [] as string[]),
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
