import { createFileRoute } from "@tanstack/react-router";
import { syncPayment } from "@/lib/marz.server";

// Marz Pay callback. The payload is never trusted: we only take the reference
// and re-check the transaction status directly with Marz before applying it.
export const Route = createFileRoute("/api/public/marz/callback")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const body = (await request.json().catch(() => null)) as any;
        const ref = body?.transaction?.reference ?? body?.reference;
        if (typeof ref !== "string" || !/^[0-9a-f-]{36}$/i.test(ref)) return new Response("ok");
        try { await syncPayment(ref); } catch (e) { console.error("marz callback", e); }
        return new Response("ok");
      },
    },
  },
});
