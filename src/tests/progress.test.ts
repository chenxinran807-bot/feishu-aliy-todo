import { describe, expect, it } from "vitest";
import { computeTracks } from "../domain/progress";
import type { ProgressTrack, SyncedTask } from "../domain/types";

const tasks: SyncedTask[] = [
  {
    id: "task-1",
    larkRecordId: "rec1",
    title: "First",
    sourceType: "meeting_note",
    status: "done",
    createdAt: "2026-06-23T00:00:00.000Z",
    updatedAt: "2026-06-23T00:00:00.000Z",
  },
  {
    id: "task-2",
    larkRecordId: "rec2",
    title: "Second",
    sourceType: "group_chat",
    status: "open",
    createdAt: "2026-06-23T00:00:00.000Z",
    updatedAt: "2026-06-23T00:00:00.000Z",
  },
];

describe("computeTracks", () => {
  it("calculates auto progress from linked completed tasks", () => {
    const tracks: ProgressTrack[] = [
      {
        id: "track-1",
        name: "Launch",
        linkedTaskIds: ["task-1", "task-2"],
        mode: "auto",
        pinned: true,
        updatedAt: "2026-06-23T00:00:00.000Z",
      },
    ];

    expect(computeTracks(tracks, tasks)[0]).toMatchObject({
      autoPercent: 50,
      displayPercent: 50,
      completedTasks: 1,
      totalTasks: 2,
    });
  });

  it("uses manual progress when mode is manual", () => {
    const tracks: ProgressTrack[] = [
      {
        id: "track-2",
        name: "Aime Desktop",
        linkedTaskIds: ["task-1", "task-2"],
        mode: "manual",
        manualPercent: 62,
        pinned: true,
        updatedAt: "2026-06-23T00:00:00.000Z",
      },
    ];

    expect(computeTracks(tracks, tasks)[0]).toMatchObject({
      autoPercent: 50,
      displayPercent: 62,
      completedTasks: 1,
      totalTasks: 2,
    });
  });
});
