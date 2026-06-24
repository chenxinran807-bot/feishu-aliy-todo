import { describe, expect, it } from "vitest";
import { isExternalActionAllowed, shouldSendToAi } from "../domain/intentTypes";

describe("intent type helpers", () => {
  it("keeps local-only and redacted events out of AI analysis", () => {
    expect(shouldSendToAi({ privacyLevel: "local_only" })).toBe(false);
    expect(shouldSendToAi({ privacyLevel: "redacted" })).toBe(false);
    expect(shouldSendToAi({ privacyLevel: "ai_allowed" })).toBe(true);
  });

  it("blocks external actions unless the user explicitly confirms them", () => {
    expect(isExternalActionAllowed({ requiresConfirmation: true, confirmed: false })).toBe(false);
    expect(isExternalActionAllowed({ requiresConfirmation: true, confirmed: true })).toBe(true);
    expect(isExternalActionAllowed({ requiresConfirmation: false, confirmed: false })).toBe(true);
  });
});
