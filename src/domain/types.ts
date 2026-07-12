export type TaskStatus = "open" | "done" | "waiting";
export type SourceType = "group_chat" | "meeting_note" | "private_chat" | "manual";
export type ProgressMode = "auto" | "manual";
export type SyncState = "idle" | "syncing" | "stale" | "error";

export interface SyncedTask {
  id: string;
  larkRecordId: string;
  title: string;
  sourceType: SourceType;
  sourceTypes?: SourceType[];
  sourceUrl?: string;
  status: TaskStatus;
  statusText?: string;
  dueDate?: string;
  createdAt: string;
  updatedAt: string;
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
}

export interface LocalTaskMeta {
  taskId: string;
  pinned: boolean;
  hidden: boolean;
  snoozeUntil?: string;
  reminderMinutesBefore?: number;
  displayPriority: number;
  lastSeenAt?: string;
  localNote?: string;
}

export interface TaskViewModel extends SyncedTask {
  meta: LocalTaskMeta;
}

export interface ProgressTrack {
  id: string;
  name: string;
  linkedTaskIds: string[];
  manualPercent?: number;
  mode: ProgressMode;
  targetDate?: string;
  pinned: boolean;
  updatedAt: string;
}

export interface ComputedProgressTrack extends ProgressTrack {
  autoPercent: number;
  displayPercent: number;
  completedTasks: number;
  totalTasks: number;
}

export interface CompanionSettings {
  widgetX: number;
  widgetY: number;
  widgetWidth?: number;
  widgetHeight?: number;
  miniMode: boolean;
  reminderHour: number;
  larkBaseUrl?: string;
  larkTableId?: string;
  larkViewId?: string;
}

export interface AppSnapshot {
  tasks: SyncedTask[];
  localMeta: LocalTaskMeta[];
  tracks: ProgressTrack[];
  settings: CompanionSettings;
  syncState: SyncState;
  syncMessage?: string;
}
