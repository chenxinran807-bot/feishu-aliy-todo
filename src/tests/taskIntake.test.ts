import { describe, expect, it } from "vitest";
import { extractTaskDraftsFromMaterial } from "../domain/taskIntake";

describe("task intake", () => {
  it("extracts action items from meeting notes and chat records", () => {
    expect(
      extractTaskDraftsFromMaterial(
        "会议纪要：1. 周三前整理竞品信息；2. 明天发评审材料给团队；聊天记录：记得跟进设计反馈。",
      ),
    ).toEqual([
      { title: "周三前整理竞品信息", sourceType: "meeting_note" },
      { title: "明天发评审材料给团队", sourceType: "meeting_note" },
      { title: "跟进设计反馈", sourceType: "group_chat" },
    ]);
  });

  it("treats a direct instruction as one manual task", () => {
    expect(extractTaskDraftsFromMaterial("帮我新增任务：整理明天的 demo checklist")).toEqual([
      { title: "整理明天的 demo checklist", sourceType: "manual" },
    ]);
  });
});
