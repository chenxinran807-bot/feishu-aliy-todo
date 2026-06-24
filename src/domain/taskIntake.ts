import type { SourceType } from "./types";

export interface TaskDraft {
  title: string;
  sourceType: SourceType;
}

export function extractTaskDraftsFromMaterial(material: string): TaskDraft[] {
  const normalized = material.trim();
  if (!normalized) return [];

  const direct = normalized.match(/(?:帮我新增任务|新增任务|创建任务)[:：]?\s*(.+)$/);
  if (direct?.[1]) {
    const draft: TaskDraft = { title: cleanTitle(direct[1]), sourceType: "manual" };
    return draft.title ? [draft] : [];
  }

  const chunks = splitMaterial(normalized);
  const drafts = chunks
    .map((chunk) => ({
      title: cleanTitle(chunk.title),
      sourceType: chunk.sourceType,
    }))
    .filter((draft) => draft.title)
    .filter((draft) => isTaskLike(draft.title));

  return dedupeDrafts(drafts);
}

function splitMaterial(value: string): TaskDraft[] {
  const result: TaskDraft[] = [];
  let currentSourceType: SourceType = inferSourceType(value);

  for (const rawPart of value.split(/(?:\d+[.、]\s*|；|;|\n)/)) {
    const part = rawPart.trim();
    if (!part) continue;

    const meetingParts = part.split(/会议纪要[:：]/);
    const chatParts = meetingParts.flatMap((item) => item.split(/聊天记录[:：]/));

    if (part.includes("会议纪要")) currentSourceType = "meeting_note";
    if (part.includes("聊天记录")) currentSourceType = "group_chat";

    for (const candidate of chatParts) {
      const text = candidate.trim();
      if (!text) continue;
      result.push({ title: text, sourceType: currentSourceType });
    }
  }

  return result;
}

function inferSourceType(value: string): SourceType {
  if (value.includes("聊天记录")) return "group_chat";
  if (value.includes("会议纪要") || value.includes("会议")) return "meeting_note";
  return "manual";
}

function cleanTitle(value: string): string {
  return value
    .replace(/^(记得|需要|请|待办|任务)[:：]?\s*/u, "")
    .replace(/[。.!！]+$/u, "")
    .trim();
}

function isTaskLike(value: string): boolean {
  return /整理|发送|发|跟进|确认|同步|补充|更新|创建|新增|评审|checklist/i.test(value);
}

function dedupeDrafts(drafts: TaskDraft[]): TaskDraft[] {
  const seen = new Set<string>();
  return drafts.filter((draft) => {
    const key = `${draft.sourceType}:${draft.title}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}
