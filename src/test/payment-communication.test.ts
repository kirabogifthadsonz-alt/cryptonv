import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { marzPost, marzTransactionStatus, syncPayment } from "@/lib/marz.server";

const mock = vi.hoisted(() => ({ from: vi.fn(), rpc: vi.fn() }));
vi.mock("@/integrations/supabase/client.server", () => ({ supabaseAdmin: mock }));

beforeEach(() => {
  vi.stubEnv("MARZ_API_KEY", "test-only");
  vi.stubEnv("MARZ_API_SECRET", "test-only");
  vi.stubGlobal("fetch", vi.fn());
});
afterEach(() => { vi.unstubAllGlobals(); vi.unstubAllEnvs(); vi.resetAllMocks(); });

describe("Payment communication", () => {
  it("does not treat a payout timeout as a confirmed failure", async () => {
    vi.mocked(fetch).mockRejectedValue(new Error("connection interrupted"));
    await expect(marzPost("/send-money", { reference: "local-reference" })).rejects.toMatchObject({ uncertain: true });
  });
  it("keeps a provider server error ambiguous", async () => {
    vi.mocked(fetch).mockResolvedValue(Response.json({ message: "unavailable" }, { status: 503 }));
    await expect(marzPost("/send-money", {})).rejects.toMatchObject({ uncertain: true });
  });
  it("recognizes an explicit rejected request", async () => {
    vi.mocked(fetch).mockResolvedValue(Response.json({ status: "error", message: "Rejected" }, { status: 400 }));
    await expect(marzPost("/send-money", {})).rejects.toMatchObject({ uncertain: false });
  });
  it("does not report success for a missing provider transaction", async () => {
    vi.mocked(fetch).mockResolvedValue(Response.json({ status: "success", data: {} }));
    await expect(marzPost("/collect-money", {})).rejects.toMatchObject({ uncertain: true });
  });
  it("accepts a recorded provider transaction", async () => {
    vi.mocked(fetch).mockResolvedValue(Response.json({ data: { transaction: { uuid: "provider-reference" } } }));
    await expect(marzPost("/collect-money", {})).resolves.toMatchObject({ data: { transaction: { uuid: "provider-reference" } } });
  });
  it("rejects a mismatched reference before crediting", async () => {
    vi.mocked(fetch).mockResolvedValue(Response.json({ transaction: { reference: "other", status: "completed" } }));
    await expect(marzTransactionStatus("provider", { id: "expected", local_amount: 3700, currency: "UGX" })).rejects.toThrow("reference does not match");
  });
  it("rejects a mismatched currency", async () => {
    vi.mocked(fetch).mockResolvedValue(Response.json({ transaction: { currency: "USD", status: "completed" } }));
    await expect(marzTransactionStatus("provider", { id: "expected", local_amount: 3700, currency: "UGX" })).rejects.toThrow("currency does not match");
  });
  it("rejects a mismatched amount", async () => {
    vi.mocked(fetch).mockResolvedValue(Response.json({ transaction: { amount: 1, status: "completed" } }));
    await expect(marzTransactionStatus("provider", { id: "expected", local_amount: 3700, currency: "UGX" })).rejects.toThrow("amount does not match");
  });
  it("does not mark a withdrawal terminal when finalization fails", async () => {
    const tx = { id: "local", kind: "withdrawal", marz_uuid: "provider", local_amount: 3700, currency: "UGX", withdrawal_request_id: "withdrawal", status: "processing" };
    const chain = { select: vi.fn().mockReturnThis(), eq: vi.fn().mockReturnThis(), maybeSingle: vi.fn().mockResolvedValue({ data: tx, error: null }) };
    mock.from.mockReturnValue(chain);
    mock.rpc.mockResolvedValue({ error: { message: "temporarily unavailable" } });
    vi.mocked(fetch).mockResolvedValue(Response.json({ transaction: { status: "completed", reference: "local", amount: 3700, currency: "UGX" } }));
    await expect(syncPayment("local")).rejects.toThrow("reconciliation is pending");
    expect(mock.rpc).toHaveBeenCalledWith("finalize_withdrawal", { p_request_id: "withdrawal", p_success: true });
    expect(mock.from).toHaveBeenCalledTimes(1);
  });
});