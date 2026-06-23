import { contextBridge, ipcRenderer } from "electron";
import type { AppSnapshot } from "./types.js";

export interface AimeDesktopApi {
  getSnapshot: () => Promise<AppSnapshot>;
  completeTask: (taskId: string) => Promise<AppSnapshot>;
  rescheduleTask: (taskId: string, dueDate: string) => Promise<AppSnapshot>;
  hideTask: (taskId: string) => Promise<AppSnapshot>;
  syncNow: () => Promise<AppSnapshot>;
  openFullWindow: () => Promise<void>;
  setMiniMode: (miniMode: boolean) => Promise<void>;
}

const api: AimeDesktopApi = {
  getSnapshot: () => ipcRenderer.invoke("snapshot:get"),
  completeTask: (taskId) => ipcRenderer.invoke("task:complete", taskId),
  rescheduleTask: (taskId, dueDate) => ipcRenderer.invoke("task:reschedule", taskId, dueDate),
  hideTask: (taskId) => ipcRenderer.invoke("task:hide", taskId),
  syncNow: () => ipcRenderer.invoke("sync:now"),
  openFullWindow: () => ipcRenderer.invoke("window:open-full"),
  setMiniMode: (miniMode) => ipcRenderer.invoke("window:set-mini-mode", miniMode),
};

contextBridge.exposeInMainWorld("aimeDesktop", api);
