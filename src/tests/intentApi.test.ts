import { beforeEach, describe, expect, it } from "vitest";
import { desktopApi, intentApi } from "../lib/desktopApi";

beforeEach(() => {
  window.localStorage.clear();
});

describe("intentApi", () => {
  it("captures explicit events and generates a pending suggestion", async () => {
    await intentApi.captureEvent({
      triggerType: "manual_capture",
      textContext: "整理竞品信息",
      relatedTaskIds: [],
      privacyLevel: "local_only",
    });

    const state = await intentApi.getState();

    expect(state.events).toHaveLength(1);
    expect(state.sessions).toHaveLength(1);
    expect(state.suggestions).toHaveLength(1);
    expect(state.suggestions[0].state).toBe("pending");
  });

  it("suppresses future suggestions after never-suggest feedback", async () => {
    await intentApi.captureEvent({
      triggerType: "manual_capture",
      textContext: "整理竞品信息",
      relatedTaskIds: [],
      privacyLevel: "local_only",
    });
    const firstState = await intentApi.getState();

    await intentApi.neverSuggestType(firstState.suggestions[0].id);
    await intentApi.captureEvent({
      triggerType: "manual_capture",
      textContext: "整理官网素材",
      relatedTaskIds: [],
      privacyLevel: "local_only",
    });

    const state = await intentApi.getState();

    expect(state.settings.suppressedSuggestionTypes).toContain("create_task");
    expect(state.suggestions.filter((suggestion) => suggestion.state === "pending")).toHaveLength(0);
  });

  it("accepts a create-task suggestion by adding a local manual task", async () => {
    await intentApi.captureEvent({
      triggerType: "manual_capture",
      textContext: "整理竞品信息",
      relatedTaskIds: [],
      privacyLevel: "local_only",
    });
    const state = await intentApi.getState();

    await intentApi.acceptSuggestion(state.suggestions[0].id);
    const snapshot = await desktopApi.getSnapshot();

    expect(snapshot.tasks.some((task) => task.title === "整理竞品信息" && task.sourceType === "manual")).toBe(true);
  });

  it("accepts an extracted chat task suggestion with its source type", async () => {
    await intentApi.captureEvent({
      triggerType: "manual_capture",
      textContext: "聊天记录：记得跟进设计反馈。",
      relatedTaskIds: [],
      privacyLevel: "local_only",
    });
    const state = await intentApi.getState();

    await intentApi.acceptSuggestion(state.suggestions[0].id);
    const snapshot = await desktopApi.getSnapshot();

    expect(snapshot.tasks.some((task) => task.title === "跟进设计反馈" && task.sourceType === "group_chat")).toBe(
      true,
    );
  });

  it("completing a task does not create intent suggestions", async () => {
    const snapshot = await desktopApi.getSnapshot();

    await desktopApi.completeTask(snapshot.tasks[0].id);
    const state = await intentApi.getState();

    expect(state.events).toHaveLength(0);
    expect(state.suggestions).toHaveLength(0);
  });

  it("reopens a completed task", async () => {
    const snapshot = await desktopApi.getSnapshot();
    const completed = await desktopApi.completeTask(snapshot.tasks[0].id);
    expect(completed.tasks[0].status).toBe("done");

    const reopened = await desktopApi.reopenTask(snapshot.tasks[0].id);

    expect(reopened.tasks[0].status).toBe("open");
  });
});
