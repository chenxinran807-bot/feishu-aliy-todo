import type { SourceType, SyncedTask, TaskStatus } from "./types";

export interface LarkFieldMapping {
  title: string;
  status: string;
  dueDate: string;
  sourceType?: string;
  sourceUrl?: string;
  owner?: string;
  project?: string;
  priority?: string;
  details?: string;
  sourceExcerpt?: string;
  result?: string;
  updateRecord?: string;
  larkTaskGuid?: string;
  larkTaskUrl?: string;
  syncStatus?: string;
  sourceId?: string;
  parentRecordId?: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface LarkRecord {
  record_id: string;
  fields: Record<string, unknown>;
}

export interface LarkWritePatch {
  record_id: string;
  fields: Record<string, unknown>;
}

export function mapLarkRecordToTask(record: LarkRecord, mapping: LarkFieldMapping): SyncedTask {
  const sourceTypes = asSourceTypes(readOptional(record, mapping.sourceType));
  const fallbackSourceTypes = sourceTypes.length > 0 ? sourceTypes : ["manual"];
  return {
    id: record.record_id,
    larkRecordId: record.record_id,
    title: asText(record.fields[mapping.title]) || "Untitled task",
    sourceType: fallbackSourceTypes[0] as SourceType,
    sourceTypes: fallbackSourceTypes as SourceType[],
    sourceUrl: asText(readOptional(record, mapping.sourceUrl)) || undefined,
    status: asTaskStatus(record.fields[mapping.status]),
    statusText: asText(record.fields[mapping.status]) || undefined,
    dueDate: asDateKey(record.fields[mapping.dueDate]),
    createdAt: asIsoDate(readOptional(record, mapping.createdAt)) ?? new Date().toISOString(),
    updatedAt: asIsoDate(readOptional(record, mapping.updatedAt)) ?? new Date().toISOString(),
    owner: asText(readOptional(record, mapping.owner)) || undefined,
    project: asText(readOptional(record, mapping.project)) || undefined,
    priority: asPriority(readOptional(record, mapping.priority)) || undefined,
    details: asText(readOptional(record, mapping.details)) || undefined,
    sourceExcerpt: asText(readOptional(record, mapping.sourceExcerpt)) || undefined,
    result: asText(readOptional(record, mapping.result)) || undefined,
    updateRecord: asText(readOptional(record, mapping.updateRecord)) || undefined,
    larkTaskGuid: asText(readOptional(record, mapping.larkTaskGuid)) || undefined,
    larkTaskUrl: asText(readOptional(record, mapping.larkTaskUrl)) || undefined,
    syncStatus: asText(readOptional(record, mapping.syncStatus)) || undefined,
    sourceId: asText(readOptional(record, mapping.sourceId)) || undefined,
    parentRecordId: asText(readOptional(record, mapping.parentRecordId)) || undefined,
  };
}

export function createCompletionPatch(
  task: SyncedTask,
  mapping: LarkFieldMapping,
  doneValue = "已完成",
): LarkWritePatch {
  return {
    record_id: task.larkRecordId,
    fields: {
      [mapping.status]: doneValue,
    },
  };
}

export function createDueDatePatch(
  task: SyncedTask,
  mapping: LarkFieldMapping,
  dueDate: string,
): LarkWritePatch {
  return {
    record_id: task.larkRecordId,
    fields: {
      [mapping.dueDate]: dueDate,
    },
  };
}

function readOptional(record: LarkRecord, fieldName: string | undefined): unknown {
  return fieldName ? record.fields[fieldName] : undefined;
}

function asTaskStatus(value: unknown): TaskStatus {
  const text = asText(value).toLowerCase();
  if (["未完成", "未开始", "todo", "open", "待处理", "待办"].some((item) => text.includes(item))) {
    return "open";
  }
  if (["done", "complete", "completed", "已完成", "完成"].some((item) => text.includes(item))) {
    return "done";
  }
  if (["waiting", "blocked", "等待", "阻塞"].some((item) => text.includes(item))) {
    return "waiting";
  }
  return "open";
}

function asSourceType(value: unknown): SourceType | undefined {
  const text = asText(value).toLowerCase();
  if (!text) return undefined;
  if (text.includes("meeting") || text.includes("会议") || text.includes("纪要")) return "meeting_note";
  if (text.includes("private") || text.includes("私聊")) return "private_chat";
  if (text.includes("group") || text.includes("群") || text.includes("chat") || text.includes("聊天")) {
    return "group_chat";
  }
  if (text.includes("codex") || text.includes("唤起") || text.includes("主动")) return "manual";
  return "manual";
}

function asSourceTypes(value: unknown): SourceType[] {
  if (Array.isArray(value)) {
    return value.map((item) => asSourceType(item) ?? "manual").filter(Boolean);
  }
  const single = asSourceType(value);
  return single ? [single] : [];
}

function asPriority(value: unknown): string | undefined {
  const text = asText(value).toUpperCase();
  const match = text.match(/\bP[0-3]\b/);
  return match?.[0];
}

function asDateKey(value: unknown): string | undefined {
  if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value)) return value;
  if (typeof value === "number") return new Date(value).toISOString().slice(0, 10);

  const text = asText(value);
  const match = text.match(/\d{4}-\d{2}-\d{2}/);
  return match?.[0];
}

function asIsoDate(value: unknown): string | undefined {
  if (typeof value === "number") return new Date(value).toISOString();
  const text = asText(value);
  if (!text) return undefined;
  const date = new Date(text);
  return Number.isNaN(date.getTime()) ? undefined : date.toISOString();
}

function asText(value: unknown): string {
  if (typeof value === "string") return extractMarkdownUrl(value.trim()) ?? value.trim();
  if (typeof value === "number") return String(value);
  if (Array.isArray(value)) return value.map(asText).filter(Boolean).join(", ");
  if (value && typeof value === "object") {
    const objectValue = value as Record<string, unknown>;
    if (typeof objectValue.text === "string") return objectValue.text.trim();
    if (typeof objectValue.name === "string") return objectValue.name.trim();
    if (typeof objectValue.link === "string") return objectValue.link.trim();
    if (typeof objectValue.url === "string") return objectValue.url.trim();
  }
  return "";
}

function extractMarkdownUrl(value: string): string | undefined {
  return value.match(/^\[[^\]]+\]\(([^)]+)\)$/)?.[1];
}
