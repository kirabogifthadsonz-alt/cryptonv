import { createFileRoute } from "@tanstack/react-router";
import { syncPayment } from "@/lib/marz.server";
import { z } from "zod";

// Marz Pay callback. The payload is never trusted: we only take the reference
// and re-check the transaction status directly with Marz before applying it.
export const Route = createFileRoute("/api/public/marz/callback")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const body = (await request.json().catch(() => null)) as any;
        const ref = body?.transaction?.reference ?? body?.reference;
        if (!z.string().uuid().safeParse(ref).success) return new Response("Invalid reference", { status: 400 });
        try { await syncPayment(ref); } catch { return new Response("Reconciliation pending", { status: 503 }); }
        return new Response("ok");
      },
    },
  },
});
