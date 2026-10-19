import { createFileRoute } from "@tanstack/react-router";
import legacyHtml from "../legacy/index.html.txt?raw";

// Serves the original CRYPTONVA app (migrated from Manus) unchanged.
// The UI lives in public/app.js + public/app.css and talks to its existing backend.
export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "CRYPTONVA — Invest in the digital future" },
      { name: "description", content: "Investment plans, wallet activity and CN rewards with CRYPTONVA." },
      { property: "og:title", content: "CRYPTONVA — Invest in the digital future" },
      { property: "og:description", content: "Investment plans, wallet activity and CN rewards with CRYPTONVA." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  server: {
    handlers: {
      GET: () =>
        new Response(legacyHtml, {
          headers: { "Content-Type": "text/html; charset=utf-8" },
        }),
    },
  },
  component: () => null,
});
