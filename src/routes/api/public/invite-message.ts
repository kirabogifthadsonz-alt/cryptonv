import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";
import { createOpenAI } from "@ai-sdk/openai";
import { streamText } from "ai";
import { getUserFromRequest, json } from "@/lib/marz.server";
import { createLovableAiGatewayRunIdFetch } from "@/lib/ai/run-id.server";

const schema = z.object({
  name: z.string().trim().min(1).max(60),
  relationship: z.string().trim().max(60).optional().default(""),
  interests: z.string().trim().max(200).optional().default(""),
  channel: z.enum(["whatsapp", "sms", "email", "social"]).default("whatsapp"),
  code: z.string().trim().min(3).max(16),
});

const INSTRUCTIONS = `You write short, neutral invitation messages for members of CRYPTONVA, a digital investment platform, to send to people they know.
Rules: friendly and factual tone; no hype, no guaranteed returns, no profit promises, no pressure or urgency; mention that investing involves risk only briefly if relevant.
Always include the exact invitation code given, and say it is entered in the "Invitation code" field when signing up. Never include links.
Adapt length to the channel (SMS/WhatsApp: under 60 words; email: under 120 words with a greeting and sign-off; social: under 50 words).
Return only the message text.`;

export const Route = createFileRoute("/api/public/invite-message")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const user = await getUserFromRequest(request);
        if (!user) return json({ error: "Please sign in again." }, 401);
        const parsed = schema.safeParse(await request.json().catch(() => null));
        if (!parsed.success) return json({ error: "Enter the person's name (and keep details short)." }, 400);
        const apiKey = process.env["LOVABLE_API_KEY"];
        if (!apiKey) return json({ error: "AI is not configured." }, 500);
        const d = parsed.data;
        const runIdFetch = createLovableAiGatewayRunIdFetch();
        const provider = createOpenAI({
          baseURL: "https://ai.gateway.lovable.dev/v1",
          apiKey,
          headers: { "Lovable-API-Key": apiKey, "X-Lovable-AIG-SDK": "vercel-ai-sdk" },
          fetch: runIdFetch.fetch,
        });
        try {
          const result = streamText({
            model: provider.responses("openai/gpt-6-astra"),
            instructions: INSTRUCTIONS,
            messages: [{
              role: "user",
              content: `Recipient name: ${d.name}\nRelationship: ${d.relationship || "not given"}\nInterests: ${d.interests || "not given"}\nChannel: ${d.channel}\nInvitation code: ${d.code}`,
            }],
            abortSignal: request.signal,
            providerOptions: {
              openai: {
                store: false,
                forceReasoning: true,
                reasoningEffort: "low",
                reasoningSummary: "auto",
                include: ["reasoning.encrypted_content"],
              },
            },
          } as Parameters<typeof streamText>[0]);
          const text = (await result.text).trim();
          if (!text) return json({ error: "No message was generated. Please try again later." }, 502);
          return json({ message: text });
        } catch (e: unknown) {
          const err = e as { statusCode?: number; message?: string; name?: string };
          if (err?.name === "AbortError") return json({ error: "Cancelled" }, 499);
          const status = err?.statusCode;
          if (status === 429) return json({ error: "Too many requests right now. Please wait a moment and try again." }, 429);
          if (status === 402) return json({ error: "AI credits are used up for now. Please try again later." }, 402);
          if (status === 403) return json({ error: "AI drafting is not available right now." }, 403);
          return json({ error: "Could not draft the message. Please try again later." }, status && status >= 400 ? status : 502);
        }
      },
    },
  },
});
