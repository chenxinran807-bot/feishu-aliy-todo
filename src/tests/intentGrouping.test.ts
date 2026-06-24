import { describe, expect, it } from "vitest";
import type { IntentEvent } from "../domain/intentTypes";
import { groupIntentEvents } from "../domain/intentGrouping";

function event(id: string, createdAt: string, textContext: string, relatedTaskIds: string[] = []): IntentEvent {
  return {
    id,
    triggerType: "manual_capture",
    textContext,
    relatedTaskIds,
    createdAt,
    privacyLevel: "local_only",
  };
}

describe("groupIntentEvents", () => {
  it("groups events within the session window", () => {
    const sessions = groupIntentEvents(
      [
        event("evt-1", "2026-06-24T09:00:00.000Z", "整理竞品信息", ["task-1"]),
        event("evt-2", "2026-06-24T09:10:00.000Z", "补充价格对比", ["task-1"]),
      ],
      { sessionWindowMinutes: 30 },
    );

    expect(sessions).toHaveLength(1);
    expect(sessions[0]).toMatchObject({
      eventIds: ["evt-1", "evt-2"],
      relatedTaskIds: ["task-1"],
      inferredTopic: "整理竞品信息",
    });
  });

  it("splits events outside the session window", () => {
    const sessions = groupIntentEvents(
      [
        event("evt-1", "2026-06-24T09:00:00.000Z", "整理竞品信息"),
        event("evt-2", "2026-06-24T10:00:00.000Z", "跟进会议纪要"),
      ],
      { sessionWindowMinutes: 30 },
    );

    expect(sessions).toHaveLength(2);
    expect(sessions[0].eventIds).toEqual(["evt-1"]);
    expect(sessions[1].eventIds).toEqual(["evt-2"]);
  });
});
