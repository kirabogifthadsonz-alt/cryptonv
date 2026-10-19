import { createFileRoute } from "@tanstack/react-router";
import { getUserFromRequest, json, syncPayment } from "@/lib/marz.server";

export const Route = createFileRoute("/api/public/payments/status")({
  server: {
    handlers: {
      GET: async ({ request }) => {
        const user = await getUserFromRequest(request);
        if (!user) return json({ error: "Unauthorized" }, 401);
        const id = new URL(request.url).searchParams.get("id") || "";
        if (!/^[0-9a-f-]{36}$/i.test(id)) return json({ error: "Bad id" }, 400);
        const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
        const { data: tx } = await supabaseAdmin.from("payment_transactions").select("user_id").eq("id", id).maybeSingle();
        if (!tx || tx.user_id !== user.id) return json({ error: "Not found" }, 404);
        try {
          const status = await syncPayment(id);
          return json({ status });
        } catch {
          return json({ error: "Payment confirmation is temporarily unavailable. Please check again." }, 503);
        }
      },
    },
  },
});
