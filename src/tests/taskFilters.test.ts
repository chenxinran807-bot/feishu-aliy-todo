import { describe, expect, it } from "vitest";
import {
  getCompletedTasks,
  getLaterThisWeekTasks,
  getOverdueTasks,
  getTodayTasks,
} from "../domain/taskFilters";
import type { TaskViewModel } from "../domain/types";

const baseTask = {
  larkRecordId: "rec",
  sourceType: "group_chat" as const,
  status: "open" as const,
  createdAt: "2026-06-23T00:00:00.000Z",
  updatedAt: "2026-06-23T00:00:00.000Z",
  meta: {
    taskId: "task",
    pinned: false,
    hidden: false,
    displayPriority: 0,
  },
};

const tasks: TaskViewModel[] = [
  { ...baseTask, id: "overdue", title: "Overdue", dueDate: "2026-06-22" },
  { ...baseTask, id: "today", title: "Today", dueDate: "2026-06-23" },
  { ...baseTask, id: "later", title: "Later", dueDate: "2026-06-26" },
  {
    ...baseTask,
    id: "hidden",
    title: "Hidden",
    dueDate: "2026-06-23",
    meta: { ...baseTask.meta, taskId: "hidden", hidden: true },
  },
  { ...baseTask, id: "done", title: "Done", dueDate: "2026-06-23", status: "done" },
];

describe("task filters", () => {
  it("returns open overdue tasks", () => {
    expect(
      getOverdueTasks(tasks, new Date("2026-06-23T12:00:00+08:00")).map((task) => task.id),
    ).toEqual(["overdue"]);
  });

  it("returns open today tasks", () => {
    expect(
      getTodayTasks(tasks, new Date("2026-06-23T12:00:00+08:00")).map((task) => task.id),
    ).toEqual(["today"]);
  });

  it("returns open later-this-week tasks", () => {
    expect(
      getLaterThisWeekTasks(tasks, new Date("2026-06-23T12:00:00+08:00")).map((task) => task.id),
    ).toEqual(["later"]);
  });

  it("returns completed visible tasks for bottom placement", () => {
    expect(getCompletedTasks(tasks).map((task) => task.id)).toEqual(["done"]);
  });
});
