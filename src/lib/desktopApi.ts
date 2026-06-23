import type { AppSnapshot } from "../domain/types";

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
  const saved = window.localStorage.getItem(localStorageKey);
  if (saved) return JSON.parse(saved) as AppSnapshot;

  const { sampleSnapshot } = await import("../data/sampleData");
  window.localStorage.setItem(localStorageKey, JSON.stringify(sampleSnapshot));
  return sampleSnapshot;
}

async function saveLocalSnapshot(snapshot: AppSnapshot): Promise<AppSnapshot> {
  window.localStorage.setItem(localStorageKey, JSON.stringify(snapshot));
  return snapshot;
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
