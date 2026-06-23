import { BrowserWindow, Menu, Tray, app, ipcMain, nativeImage } from "electron";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { pullLarkBase } from "./larkSync.js";
import {
  loadSnapshot,
  patchLocalMeta,
  saveSnapshot,
  updateTaskDueDate,
  updateTaskStatus,
} from "./store.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const isDev = Boolean(process.env.VITE_DEV_SERVER_URL);

let widgetWindow: BrowserWindow | undefined;
let fullWindow: BrowserWindow | undefined;
let tray: Tray | undefined;

async function createWidgetWindow(): Promise<void> {
  const snapshot = await loadSnapshot();
  widgetWindow = new BrowserWindow({
    width: snapshot.settings.miniMode ? 120 : 360,
    height: snapshot.settings.miniMode ? 92 : 220,
    x: snapshot.settings.widgetX,
    y: snapshot.settings.widgetY,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    resizable: false,
    hasShadow: false,
    webPreferences: {
      preload: join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  widgetWindow.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  widgetWindow.setAlwaysOnTop(true, "floating");

  if (isDev && process.env.VITE_DEV_SERVER_URL) {
    await widgetWindow.loadURL(process.env.VITE_DEV_SERVER_URL);
  } else {
    await widgetWindow.loadFile(join(__dirname, "../dist/index.html"));
  }

  widgetWindow.on("moved", async () => {
    if (!widgetWindow) return;
    const [widgetX, widgetY] = widgetWindow.getPosition();
    const current = await loadSnapshot();
    await saveSnapshot({ ...current, settings: { ...current.settings, widgetX, widgetY } });
  });
}

async function openFullWindow(): Promise<void> {
  if (fullWindow && !fullWindow.isDestroyed()) {
    fullWindow.focus();
    return;
  }

  fullWindow = new BrowserWindow({
    width: 980,
    height: 680,
    title: "Aime Task Companion",
    webPreferences: {
      preload: join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  if (isDev && process.env.VITE_DEV_SERVER_URL) {
    await fullWindow.loadURL(`${process.env.VITE_DEV_SERVER_URL}?mode=full`);
  } else {
    await fullWindow.loadFile(join(__dirname, "../dist/index.html"), { query: { mode: "full" } });
  }
}

function createTray(): void {
  const icon = nativeImage.createEmpty();
  tray = new Tray(icon);
  tray.setToolTip("Aime Task Companion");
  tray.setContextMenu(
    Menu.buildFromTemplate([
      { label: "Open Dashboard", click: () => void openFullWindow() },
      { label: "Sync Now", click: () => void syncNow() },
      { type: "separator" },
      { label: "Quit", click: () => app.quit() },
    ]),
  );
}

async function syncNow() {
  const snapshot = await loadSnapshot();
  const next = await pullLarkBase({ ...snapshot, syncState: "syncing" });
  await saveSnapshot(next);
  return next;
}

ipcMain.handle("snapshot:get", () => loadSnapshot());
ipcMain.handle("task:complete", (_event, taskId: string) => updateTaskStatus(taskId, "done"));
ipcMain.handle("task:reschedule", (_event, taskId: string, dueDate: string) =>
  updateTaskDueDate(taskId, dueDate),
);
ipcMain.handle("task:hide", (_event, taskId: string) => patchLocalMeta(taskId, { hidden: true }));
ipcMain.handle("sync:now", () => syncNow());
ipcMain.handle("window:open-full", () => openFullWindow());
ipcMain.handle("window:set-mini-mode", async (_event, miniMode: boolean) => {
  const current = await loadSnapshot();
  await saveSnapshot({ ...current, settings: { ...current.settings, miniMode } });
  widgetWindow?.setSize(miniMode ? 120 : 360, miniMode ? 92 : 220);
});

app.whenReady().then(async () => {
  createTray();
  await createWidgetWindow();
});

app.on("window-all-closed", () => {
  // Keep the companion alive in the menu bar until the user quits explicitly.
});
