import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";
import { MARZ_COUNTRIES, MarzRequestError, getUserFromRequest, json, marzPost, toE164 } from "@/lib/marz.server";

// Admin approves a withdrawal: money is sent through Marz right away.
export const Route = createFileRoute("/api/public/payments/payout")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const user = await getUserFromRequest(request);
        if (!user) return json({ error: "Unauthorized" }, 401);
        const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
        const { data: role } = await supabaseAdmin.from("admin_roles").select("role").eq("user_id", user.id).maybeSingle();
        if (!role) return json({ error: "Administrator access required." }, 403);
        const parsed = z.object({ request_id: z.string().uuid() }).safeParse(await request.json().catch(() => null));
        if (!parsed.success) return json({ error: "Bad request" }, 400);

        const { data: w } = await supabaseAdmin.from("withdrawal_requests").update({
          status: "processing", reviewed_by: user.id, reviewed_at: new Date().toISOString(),
        }).eq("id", parsed.data.request_id).in("status", ["pending", "approved"]).select("*").maybeSingle();
        if (!w) return json({ error: "This request is no longer waiting for approval." }, 409);

        const [country = "", rawPhone = ""] = w.destination.split(":");
        const phone = toE164(rawPhone, country);
        const c = MARZ_COUNTRIES[country];
        const fail = async (msg: string) => {
          await supabaseAdmin.from("withdrawal_requests").update({ status: "failed", note: msg }).eq("id", w.id);
          await supabaseAdmin.from("notifications").insert({ user_id: w.user_id, title: "Withdrawal failed", body: "We could not send your withdrawal. The amount is back in your available balance.", type: "info" });
          return json({ error: msg }, 502);
        };
        if (!c) return fail("Unsupported country");
        const { data: fx } = await supabaseAdmin.from("fx_rates").select("units_per_usd").eq("currency", c.currency).maybeSingle();
        if (!fx) return fail("Exchange rate unavailable");
        const usd = Number(w.amount_cents) / 100;
        const local = c.currency === "USD" ? usd : Math.floor(usd * Number(fx.units_per_usd));

        const id = crypto.randomUUID();
        const { error: insertError } = await supabaseAdmin.from("payment_transactions").insert({
          id, user_id: w.user_id, kind: "withdrawal", method: "mobile_money", country, currency: c.currency,
          local_amount: local, usd_cents: w.amount_cents, phone, status: "processing", withdrawal_request_id: w.id,
        });
        if (insertError) return fail("Could not record payout. No transfer was started.");
        await supabaseAdmin.from("audit_log").insert({ actor_id: user.id, action: "withdrawal_approved_payout", target_user_id: w.user_id, target_reference: w.id });
        try {
          const body: Record<string, unknown> = {
            amount: local, phone_number: phone, country, reference: id, description: "CRYPTONVA withdrawal",
            callback_url: `${new URL(request.url).origin}/api/public/marz/callback`,
          };
          if (c.currency === "USD") body["currency"] = "USD";
          const res = await marzPost("/send-money", body);
          const { error: saveError } = await supabaseAdmin.from("payment_transactions").update({ marz_uuid: res?.data?.transaction?.uuid ?? res?.transaction?.uuid }).eq("id", id);
          if (saveError) throw new MarzRequestError("Payout confirmation is pending. Do not approve it again.", true);
          return json({ ok: true, payment_id: id, local_amount: local, currency: c.currency });
        } catch (e) {
          if (e instanceof MarzRequestError && e.uncertain) {
            // Keep funds reserved until the provider independently confirms the outcome.
            return json({ error: "Payout confirmation is pending. Do not approve it again.", payment_id: id, status: "processing" }, 503);
          }
          await supabaseAdmin.from("payment_transactions").update({ status: "failed" }).eq("id", id);
          return fail((e as Error).message);
        }
      },
    },
  },
});
