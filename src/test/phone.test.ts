import { describe, expect, it } from "vitest";
import { toE164 } from "@/lib/marz.server";

describe("toE164", () => {
  it("converts a local Ugandan number starting with 0", () => {
    expect(toE164("0768412345", "UG")).toBe("+256768412345");
  });
  it("fixes a local number typed with a plus", () => {
    expect(toE164("+0768412345", "UG")).toBe("+256768412345");
  });
  it("keeps a number already in international format", () => {
    expect(toE164("+256768412345", "UG")).toBe("+256768412345");
  });
});
