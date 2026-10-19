import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";
import { MARZ_COUNTRIES, getUserFromRequest, json, marzPost, toE164 } from "@/lib/marz.server";

const schema = z.object({
  method: z.enum(["mobile_money", "card"]),
  country: z.string().length(2),
  phone: z.string().regex(/^\+?[0-9]{8,15}$/).optional(),
  amount: z.number().positive().max(100000000),
});

export const Route = createFileRoute("/api/public/payments/deposit")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const user = await getUserFromRequest(request);
        if (!user) return json({ error: "Please sign in again." }, 401);
        const parsed = schema.safeParse(await request.json().catch(() => null));
        if (!parsed.success) return json({ error: "Check the amount and phone number." }, 400);
        const { method, country, phone, amount } = parsed.data;
        const c = MARZ_COUNTRIES[country];
        if (!c) return json({ error: "This country is not supported yet." }, 400);
        if (method === "mobile_money" && !phone) return json({ error: "Enter your mobile money number." }, 400);

        const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
        const { data: fx } = await supabaseAdmin.from("fx_rates").select("units_per_usd").eq("currency", c.currency).maybeSingle();
        if (!fx) return json({ error: "Exchange rate unavailable." }, 500);
        const local = c.currency === "USD" ? Math.round(amount * 100) / 100 : Math.ceil(amount);
        const usdCents = Math.floor((local / Number(fx.units_per_usd)) * 100);
        if (usdCents < 100) return json({ error: "Minimum deposit is 1 USD." }, 400);
        const phoneE164 = phone ? toE164(phone, country) : null;

        const id = crypto.randomUUID();
        const { error: insErr } = await supabaseAdmin.from("payment_transactions").insert({
          id, user_id: user.id, kind: "deposit", method, country, currency: c.currency,
          local_amount: local, usd_cents: usdCents, phone: phoneE164, status: "pending",
        });
        if (insErr) return json({ error: "Could not start deposit." }, 500);

        const origin = new URL(request.url).origin;
        try {
          const body: Record<string, unknown> = {
            amount: local, country, reference: id, method,
            description: "CRYPTONVA deposit",
            callback_url: `${origin}/api/public/marz/callback`,
          };
          if (c.currency === "USD") body["currency"] = "USD";
          if (method === "mobile_money") body["phone_number"] = phoneE164;
          const res = await marzPost("/collect-money", body);
          const marzUuid = res?.data?.transaction?.uuid ?? null;
          const redirect = res?.data?.redirect_url ?? null;
          await supabaseAdmin.from("payment_transactions").update({ marz_uuid: marzUuid, redirect_url: redirect, status: "processing" }).eq("id", id);
          return json({ id, redirect_url: redirect, currency: c.currency, local_amount: local, usd_cents: usdCents });
        } catch (e) {
          console.error("Deposit failed at payment provider:", (e as Error).message);
          await supabaseAdmin.from("payment_transactions").update({ status: "failed" }).eq("id", id);
          return json({ error: (e as Error).message }, 502);
        }
      },
    },
  },
});
