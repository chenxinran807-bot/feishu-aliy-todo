import { app } from "electron";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { sampleSnapshot } from "./sampleData.js";
import type { AppSnapshot, LocalTaskMeta, SyncedTask } from "./types.js";

const storePath = join(app.getPath("userData"), "aime-task-companion.json");

export async function loadSnapshot(): Promise<AppSnapshot> {
  try {
    const raw = await readFile(storePath, "utf8");
    return JSON.parse(raw) as AppSnapshot;
  } catch {
    await saveSnapshot(sampleSnapshot);
    return sampleSnapshot;
  }
}

export async function saveSnapshot(snapshot: AppSnapshot): Promise<void> {
  await mkdir(dirname(storePath), { recursive: true });
  await writeFile(storePath, JSON.stringify(snapshot, null, 2), "utf8");
}

export async function updateTaskStatus(
  taskId: string,
  status: SyncedTask["status"],
): Promise<AppSnapshot> {
  const snapshot = await loadSnapshot();
  const updatedTasks = snapshot.tasks.map((task) =>
    task.id === taskId ? { ...task, status, updatedAt: new Date().toISOString() } : task,
  );
  const next = { ...snapshot, tasks: updatedTasks };
  await saveSnapshot(next);
  return next;
}

export async function updateTaskDueDate(taskId: string, dueDate: string): Promise<AppSnapshot> {
  const snapshot = await loadSnapshot();
  const updatedTasks = snapshot.tasks.map((task) =>
    task.id === taskId ? { ...task, dueDate, updatedAt: new Date().toISOString() } : task,
  );
  const next = { ...snapshot, tasks: updatedTasks };
  await saveSnapshot(next);
  return next;
}

export async function patchLocalMeta(
  taskId: string,
  patch: Partial<LocalTaskMeta>,
): Promise<AppSnapshot> {
  const snapshot = await loadSnapshot();
  const hasMeta = snapshot.localMeta.some((meta) => meta.taskId === taskId);
  const localMeta = hasMeta
    ? snapshot.localMeta.map((meta) => (meta.taskId === taskId ? { ...meta, ...patch } : meta))
    : [...snapshot.localMeta, { taskId, pinned: false, hidden: false, displayPriority: 0, ...patch }];
  const next = { ...snapshot, localMeta };
  await saveSnapshot(next);
  return next;
}
