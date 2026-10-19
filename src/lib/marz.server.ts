// Marz Pay integration helpers (server-only).
const BASE = "https://wallet.wearemarz.com/api/v1";

export const MARZ_COUNTRIES: Record<string, { currency: string; dial: string; name: string }> = {
  UG: { currency: "UGX", dial: "256", name: "Uganda" },
  KE: { currency: "KES", dial: "254", name: "Kenya" },
  RW: { currency: "RWF", dial: "250", name: "Rwanda" },
  CD: { currency: "USD", dial: "243", name: "DR Congo" },
  ZM: { currency: "ZMW", dial: "260", name: "Zambia" },
  CM: { currency: "XAF", dial: "237", name: "Cameroon" },
  BJ: { currency: "XOF", dial: "229", name: "Benin" },
  CI: { currency: "XOF", dial: "225", name: "Côte d'Ivoire" },
  GA: { currency: "XAF", dial: "241", name: "Gabon" },
  CG: { currency: "XAF", dial: "242", name: "Congo-Brazzaville" },
  SN: { currency: "XOF", dial: "221", name: "Senegal" },
  SL: { currency: "SLE", dial: "232", name: "Sierra Leone" },
};

function authHeader() {
  const key = process.env["MARZ_API_KEY"];
  const secret = process.env["MARZ_API_SECRET"];
  if (!key || !secret) throw new Error("Payment gateway is not configured");
  return "Basic " + btoa(`${key}:${secret}`);
}

export async function marzPost(path: string, body: Record<string, unknown>) {
  const res = await fetch(BASE + path, {
    method: "POST",
    headers: { Authorization: authHeader(), "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify(body),
  });
  const json = (await res.json().catch(() => ({}))) as any;
  if (!res.ok || json?.status === "error") {
    throw new Error(json?.message || `Payment gateway error (${res.status})`);
  }
  return json;
}

/** Returns the verified transaction status from Marz: completed | failed | processing | ... */
export async function marzTransactionStatus(idOrRef: string): Promise<string | null> {
  const res = await fetch(`${BASE}/transactions/${encodeURIComponent(idOrRef)}`, {
    headers: { Authorization: authHeader(), Accept: "application/json" },
  });
  if (!res.ok) return null;
  const json = (await res.json().catch(() => ({}))) as any;
  const t = json?.transaction ?? json?.data?.transaction ?? json?.data;
  return (t?.status as string) ?? null;
}

export async function getUserFromRequest(request: Request) {
  const auth = request.headers.get("authorization") || "";
  const token = auth.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const { data, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !data.user) return null;
  return data.user;
}

/** Re-checks a payment with Marz and applies the final result. Idempotent. */
export async function syncPayment(id: string) {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const { data: tx } = await supabaseAdmin.from("payment_transactions").select("*").eq("id", id).maybeSingle();
  if (!tx) return null;
  if (["completed", "failed"].includes(tx.status)) return tx.status;
  const status = (await marzTransactionStatus(tx.marz_uuid || tx.id)) ?? tx.status;
  const done = status === "completed" || status === "successful" || status === "success";
  const failed = ["failed", "cancelled", "declined", "expired", "rejected"].includes(status);
  if (tx.kind === "deposit") {
    if (done) await supabaseAdmin.rpc("credit_deposit", { p_id: tx.id });
    else if (failed) await supabaseAdmin.from("payment_transactions").update({ status: "failed", updated_at: new Date().toISOString() }).eq("id", tx.id);
  } else if (tx.withdrawal_request_id && (done || failed)) {
    await supabaseAdmin.from("payment_transactions").update({ status: done ? "completed" : "failed", updated_at: new Date().toISOString() }).eq("id", tx.id);
    await supabaseAdmin.rpc("finalize_withdrawal", { p_request_id: tx.withdrawal_request_id, p_success: done });
  }
  return done ? "completed" : failed ? "failed" : "processing";
}

export function json(data: unknown, status = 200) {
  return Response.json(data, { status });
}

/** Normalizes local numbers (e.g. 0768…, +0768…, 768…) to international format for the given country. */
export function toE164(phone: string, country: string): string {
  const dial = MARZ_COUNTRIES[country]?.dial ?? "";
  let d = phone.replace(/[^0-9]/g, "");
  if (dial && d.startsWith(dial)) return "+" + d;
  d = d.replace(/^0+/, "");
  return "+" + dial + d;
}
