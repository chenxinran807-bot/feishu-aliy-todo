import type { AppSnapshot } from "../domain/types";

interface AimeDesktopApi {
  getSnapshot: () => Promise<AppSnapshot>;
  completeTask: (taskId: string) => Promise<AppSnapshot>;
  rescheduleTask: (taskId: string, dueDate: string) => Promise<AppSnapshot>;
  hideTask: (taskId: string) => Promise<AppSnapshot>;
  syncNow: () => Promise<AppSnapshot>;
  openFullWindow: () => Promise<void>;
  setMiniMode: (miniMode: boolean) => Promise<void>;
}

declare global {
  interface Window {
    aimeDesktop?: AimeDesktopApi;
  }
}

export const desktopApi: AimeDesktopApi = window.aimeDesktop ?? {
  getSnapshot: async () => {
    const { sampleSnapshot } = await import("../data/sampleData");
    return sampleSnapshot;
  },
  completeTask: async () => {
    const { sampleSnapshot } = await import("../data/sampleData");
    return sampleSnapshot;
  },
  rescheduleTask: async () => {
    const { sampleSnapshot } = await import("../data/sampleData");
    return sampleSnapshot;
  },
  hideTask: async () => {
    const { sampleSnapshot } = await import("../data/sampleData");
    return sampleSnapshot;
  },
  syncNow: async () => {
    const { sampleSnapshot } = await import("../data/sampleData");
    return sampleSnapshot;
  },
  openFullWindow: async () => undefined,
  setMiniMode: async () => undefined,
};
