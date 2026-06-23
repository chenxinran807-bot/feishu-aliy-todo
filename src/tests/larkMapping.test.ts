import { describe, expect, it } from "vitest";
import {
  createCompletionPatch,
  createDueDatePatch,
  mapLarkRecordToTask,
  type LarkFieldMapping,
} from "../domain/larkMapping";

const mapping: LarkFieldMapping = {
  title: "任务",
  status: "状态",
  dueDate: "截止日期",
  sourceType: "来源",
  sourceUrl: "来源链接",
  project: "项目",
};

describe("larkMapping", () => {
  it("maps a Lark Base record into a synced task", () => {
    const task = mapLarkRecordToTask(
      {
        record_id: "rec123",
        fields: {
          任务: [{ text: "整理会议纪要 todo" }],
          状态: "未完成",
          截止日期: "2026-06-23",
          来源: "聊天记录",
          来源链接: "[证据](https://bytedance.larkoffice.com/docx/example)",
          项目: "Aime",
        },
      },
      mapping,
    );

    expect(task).toMatchObject({
      id: "rec123",
      larkRecordId: "rec123",
      title: "整理会议纪要 todo",
      status: "open",
      dueDate: "2026-06-23",
      sourceType: "group_chat",
      sourceUrl: "https://bytedance.larkoffice.com/docx/example",
      project: "Aime",
    });
  });

  it("creates write-back patches for completion and due date", () => {
    const task = mapLarkRecordToTask(
      {
        record_id: "rec123",
        fields: {
          任务: "Follow up",
          状态: "未完成",
          截止日期: "2026-06-23",
        },
      },
      mapping,
    );

    expect(createCompletionPatch(task, mapping)).toEqual({
      record_id: "rec123",
      fields: { 状态: "已完成" },
    });
    expect(createDueDatePatch(task, mapping, "2026-06-24")).toEqual({
      record_id: "rec123",
      fields: { 截止日期: "2026-06-24" },
    });
  });
});
