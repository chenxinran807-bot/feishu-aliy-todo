import { describe, expect, it } from "vitest";
import type { IntentEvent, IntentSettings, WorkSession } from "../domain/intentTypes";
import { defaultIntentSettings } from "../domain/intentTypes";
import { expireSuggestions, generateSuggestions } from "../domain/suggestionRules";

const session: WorkSession = {
  id: "session-1",
  eventIds: ["evt-1"],
  inferredTopic: "整理竞品信息",
  relatedTaskIds: [],
  startedAt: "2026-06-24T09:00:00.000Z",
  lastActivityAt: "2026-06-24T09:00:00.000Z",
  confidence: 0.72,
};

const event: IntentEvent = {
  id: "evt-1",
  triggerType: "manual_capture",
  textContext: "整理竞品信息",
  relatedTaskIds: [],
  createdAt: "2026-06-24T09:00:00.000Z",
  privacyLevel: "local_only",
};

describe("generateSuggestions", () => {
  it("creates a task suggestion from an unlinked work session", () => {
    const suggestions = generateSuggestions({
      events: [event],
      sessions: [session],
      existingSuggestions: [],
      settings: defaultIntentSettings,
      now: "2026-06-24T09:01:00.000Z",
    });

    expect(suggestions).toHaveLength(1);
    expect(suggestions[0]).toMatchObject({
      type: "create_task",
      title: "把这个意图沉淀成任务",
      state: "pending",
      relatedTaskIds: [],
      suggestedAction: {
        kind: "create_task",
        requiresConfirmation: true,
      },
    });
  });

  it("does not generate suppressed or disabled suggestions", () => {
    const settings: IntentSettings = {
      ...defaultIntentSettings,
      suppressedSuggestionTypes: ["create_task"],
    };

    expect(
      generateSuggestions({
        events: [event],
        sessions: [session],
        existingSuggestions: [],
        settings,
        now: "2026-06-24T09:01:00.000Z",
      }),
    ).toHaveLength(0);

    expect(
      generateSuggestions({
        events: [event],
        sessions: [session],
        existingSuggestions: [],
        settings: { ...defaultIntentSettings, proactiveSuggestionsEnabled: false },
        now: "2026-06-24T09:01:00.000Z",
      }),
    ).toHaveLength(0);
  });
});

describe("expireSuggestions", () => {
  it("marks pending suggestions as expired after expiresAt", () => {
    const [suggestion] = generateSuggestions({
      events: [event],
      sessions: [session],
      existingSuggestions: [],
      settings: defaultIntentSettings,
      now: "2026-06-24T09:01:00.000Z",
    });

    const expired = expireSuggestions([suggestion], "2026-06-24T11:02:00.000Z");

    expect(expired[0].state).toBe("expired");
  });
});
