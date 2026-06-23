import type { AppSnapshot } from "../domain/types";
import { sampleSnapshot } from "../data/sampleData";

interface AimeDesktopApi {
  getSnapshot: () => Promise<AppSnapshot>;
  completeTask: (taskId: string) => Promise<AppSnapshot>;
  rescheduleTask: (taskId: string, dueDate: string) => Promise<AppSnapshot>;
  hideTask: (taskId: string) => Promise<AppSnapshot>;
  syncNow: () => Promise<AppSnapshot>;
  openFullWindow: () => Promise<void>;
  setMiniMode: (miniMode: boolean) => Promise<void>;
  setWindowMode: (mode: "widget" | "peek" | "full") => Promise<void>;
}

declare global {
  interface Window {
    aimeDesktop?: AimeDesktopApi;
    webkit?: {
      messageHandlers?: {
        aimeNative?: {
          postMessage: (message: Record<string, unknown>) => void;
        };
      };
    };
  }
}

const localStorageKey = "aime-desktop-task-companion.snapshot";

async function loadLocalSnapshot(): Promise<AppSnapshot> {
  const saved = readLocalSnapshot();
  if (saved) return saved;

  writeLocalSnapshot(sampleSnapshot);
  return sampleSnapshot;
}

async function saveLocalSnapshot(snapshot: AppSnapshot): Promise<AppSnapshot> {
  writeLocalSnapshot(snapshot);
  return snapshot;
}

function readLocalSnapshot(): AppSnapshot | undefined {
  try {
    const saved = window.localStorage.getItem(localStorageKey);
    return saved ? (JSON.parse(saved) as AppSnapshot) : undefined;
  } catch (error) {
    console.warn("Aime local storage is unavailable, using in-memory sample data.", error);
    return undefined;
  }
}

function writeLocalSnapshot(snapshot: AppSnapshot): void {
  try {
    window.localStorage.setItem(localStorageKey, JSON.stringify(snapshot));
  } catch (error) {
    console.warn("Aime local storage write failed; this session will be temporary.", error);
  }
}

function postNative(message: Record<string, unknown>): void {
  window.webkit?.messageHandlers?.aimeNative?.postMessage(message);
}

const webViewApi: AimeDesktopApi = {
  getSnapshot: loadLocalSnapshot,
  completeTask: async (taskId) => {
    const snapshot = await loadLocalSnapshot();
    return saveLocalSnapshot({
      ...snapshot,
      tasks: snapshot.tasks.map((task) =>
        task.id === taskId ? { ...task, status: "done", updatedAt: new Date().toISOString() } : task,
      ),
    });
  },
  rescheduleTask: async (taskId, dueDate) => {
    const snapshot = await loadLocalSnapshot();
    return saveLocalSnapshot({
      ...snapshot,
      tasks: snapshot.tasks.map((task) =>
        task.id === taskId ? { ...task, dueDate, updatedAt: new Date().toISOString() } : task,
      ),
    });
  },
  hideTask: async (taskId) => {
    const snapshot = await loadLocalSnapshot();
    const hasMeta = snapshot.localMeta.some((meta) => meta.taskId === taskId);
    const localMeta = hasMeta
      ? snapshot.localMeta.map((meta) => (meta.taskId === taskId ? { ...meta, hidden: true } : meta))
      : [
          ...snapshot.localMeta,
          { taskId, pinned: false, hidden: true, displayPriority: 0 },
        ];
    return saveLocalSnapshot({ ...snapshot, localMeta });
  },
  syncNow: async () => {
    const snapshot = await loadLocalSnapshot();
    return saveLocalSnapshot({
      ...snapshot,
      syncState: "stale",
      syncMessage: "Using local sample data until Lark credentials and field mapping are configured.",
    });
  },
  openFullWindow: async () => {
    postNative({ command: "openFullWindow" });
  },
  setMiniMode: async (miniMode) => {
    postNative({ command: "setWindowMode", mode: miniMode ? "widget" : "peek" });
  },
  setWindowMode: async (mode) => {
    postNative({ command: "setWindowMode", mode });
  },
};

export const desktopApi: AimeDesktopApi = window.aimeDesktop ?? webViewApi;
