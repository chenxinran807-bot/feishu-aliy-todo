# Aime Desktop Task Companion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Mac-first Electron MVP for Aime as an always-visible desktop task companion with a collapsed widget, peek panel, local task state, long-term progress bars, reminders, and a configurable Lark Base sync boundary.

**Architecture:** Use Electron for native desktop windows, tray, notifications, always-on-top behavior, transparent widget shell, and app packaging. Use Vite + React + TypeScript for the renderer, with a small domain layer for tasks/tracks and an Electron main process service layer for persistence and future Lark sync. The MVP ships with a local JSON store and sample data, while keeping interfaces ready for SQLite and Lark OpenAPI.

**Tech Stack:** Electron, Vite, React, TypeScript, Vitest, Testing Library, local JSON persistence, macOS Notification API through Electron.

---

## File Structure

- `package.json`: scripts, dependencies, Electron entry points.
- `tsconfig.json`, `tsconfig.node.json`, `vite.config.ts`: TypeScript and Vite configuration.
- `index.html`: renderer mount point.
- `electron/main.ts`: creates the widget window, peek behavior, tray menu, IPC handlers, local store wiring.
- `electron/preload.ts`: typed bridge exposed to the renderer.
- `electron/store.ts`: local JSON persistence for tasks, tracks, settings, and pending sync actions.
- `electron/larkSync.ts`: configurable Lark Base sync adapter boundary; MVP includes validation and mock-safe stubs.
- `electron/reminders.ts`: notification scheduling helpers.
- `src/main.tsx`: React bootstrap.
- `src/App.tsx`: top-level UI state and layout switching.
- `src/styles.css`: widget-first visual system.
- `src/domain/types.ts`: task, track, settings, and sync types.
- `src/domain/progress.ts`: long-term progress calculation.
- `src/domain/taskFilters.ts`: today, overdue, and later-this-week selectors.
- `src/data/sampleData.ts`: sample tasks and tracks for first local run.
- `src/components/CollapsedWidget.tsx`: always-visible compact component.
- `src/components/PeekPanel.tsx`: floating task list and quick actions.
- `src/components/FullWindow.tsx`: setup and management view shell.
- `src/components/ProgressTrack.tsx`: progress bar display with auto/manual mode label.
- `src/components/TaskRow.tsx`: task display and quick actions.
- `src/components/SyncBadge.tsx`: quiet sync state display.
- `src/lib/desktopApi.ts`: renderer-side wrapper around preload bridge.
- `src/tests/progress.test.ts`: progress calculation tests.
- `src/tests/taskFilters.test.ts`: task filtering tests.
- `src/tests/components.test.tsx`: basic component behavior tests.

## Task 1: Project Scaffold

**Files:**
- Create: `package.json`
- Create: `tsconfig.json`
- Create: `tsconfig.node.json`
- Create: `vite.config.ts`
- Create: `index.html`

- [ ] **Step 1: Create package manifest**

Create `package.json`:

```json
{
  "name": "aime-desktop-task-companion",
  "version": "0.1.0",
  "private": true,
  "description": "Mac-first desktop task companion for Aime todo monitoring.",
  "main": "dist-electron/main.js",
  "type": "module",
  "scripts": {
    "dev": "vite --host 127.0.0.1",
    "dev:electron": "concurrently -k \"npm run dev\" \"wait-on tcp:5173 && cross-env VITE_DEV_SERVER_URL=http://127.0.0.1:5173 electron .\"",
    "build": "tsc -p tsconfig.node.json && vite build",
    "test": "vitest run",
    "test:watch": "vitest",
    "lint": "tsc --noEmit && tsc -p tsconfig.node.json --noEmit"
  },
  "dependencies": {
    "@vitejs/plugin-react": "^5.0.0",
    "electron": "^41.0.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "@testing-library/jest-dom": "^6.0.0",
    "@testing-library/react": "^16.0.0",
    "@types/node": "^24.0.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "concurrently": "^9.0.0",
    "cross-env": "^10.0.0",
    "typescript": "^5.0.0",
    "vite": "^7.0.0",
    "vitest": "^4.0.0",
    "wait-on": "^9.0.0"
  }
}
```

- [ ] **Step 2: Create TypeScript configs**

Create `tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "useDefineForClassFields": true,
    "lib": ["DOM", "DOM.Iterable", "ES2022"],
    "allowJs": false,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "types": ["vitest/globals"]
  },
  "include": ["src"]
}
```

Create `tsconfig.node.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "dist-electron",
    "rootDir": "electron",
    "types": ["node", "electron"]
  },
  "include": ["electron"]
}
```

- [ ] **Step 3: Create Vite config and HTML**

Create `vite.config.ts`:

```ts
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react()],
  server: {
    host: "127.0.0.1",
    port: 5173,
  },
  build: {
    outDir: "dist",
    emptyOutDir: true,
  },
  test: {
    environment: "jsdom",
    setupFiles: ["src/tests/setup.ts"],
  },
});
```

Create `index.html`:

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Aime Task Companion</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

- [ ] **Step 4: Install dependencies**

Run:

```bash
npm install
```

Expected: `package-lock.json` is created and dependencies install successfully.

- [ ] **Step 5: Commit scaffold**

Run:

```bash
git add package.json package-lock.json tsconfig.json tsconfig.node.json vite.config.ts index.html
git commit -m "chore: scaffold Electron React app"
```

## Task 2: Domain Model and Tests

**Files:**
- Create: `src/domain/types.ts`
- Create: `src/domain/progress.ts`
- Create: `src/domain/taskFilters.ts`
- Create: `src/data/sampleData.ts`
- Create: `src/tests/setup.ts`
- Create: `src/tests/progress.test.ts`
- Create: `src/tests/taskFilters.test.ts`

- [ ] **Step 1: Define domain types**

Create `src/domain/types.ts`:

```ts
export type TaskStatus = "open" | "done" | "waiting";
export type SourceType = "group_chat" | "meeting_note" | "private_chat" | "manual";
export type ProgressMode = "auto" | "manual";
export type SyncState = "idle" | "syncing" | "stale" | "error";

export interface SyncedTask {
  id: string;
  larkRecordId: string;
  title: string;
  sourceType: SourceType;
  sourceUrl?: string;
  status: TaskStatus;
  dueDate?: string;
  createdAt: string;
  updatedAt: string;
  owner?: string;
  project?: string;
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
```

- [ ] **Step 2: Write failing progress tests**

Create `src/tests/setup.ts`:

```ts
import "@testing-library/jest-dom/vitest";
```

Create `src/tests/progress.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { computeTracks } from "../domain/progress";
import type { ProgressTrack, SyncedTask } from "../domain/types";

const tasks: SyncedTask[] = [
  {
    id: "task-1",
    larkRecordId: "rec1",
    title: "First",
    sourceType: "meeting_note",
    status: "done",
    createdAt: "2026-06-23T00:00:00.000Z",
    updatedAt: "2026-06-23T00:00:00.000Z",
  },
  {
    id: "task-2",
    larkRecordId: "rec2",
    title: "Second",
    sourceType: "group_chat",
    status: "open",
    createdAt: "2026-06-23T00:00:00.000Z",
    updatedAt: "2026-06-23T00:00:00.000Z",
  },
];

describe("computeTracks", () => {
  it("calculates auto progress from linked completed tasks", () => {
    const tracks: ProgressTrack[] = [
      {
        id: "track-1",
        name: "Launch",
        linkedTaskIds: ["task-1", "task-2"],
        mode: "auto",
        pinned: true,
        updatedAt: "2026-06-23T00:00:00.000Z",
      },
    ];

    expect(computeTracks(tracks, tasks)[0]).toMatchObject({
      autoPercent: 50,
      displayPercent: 50,
      completedTasks: 1,
      totalTasks: 2,
    });
  });

  it("uses manual progress when mode is manual", () => {
    const tracks: ProgressTrack[] = [
      {
        id: "track-2",
        name: "Aime Desktop",
        linkedTaskIds: ["task-1", "task-2"],
        mode: "manual",
        manualPercent: 62,
        pinned: true,
        updatedAt: "2026-06-23T00:00:00.000Z",
      },
    ];

    expect(computeTracks(tracks, tasks)[0]).toMatchObject({
      autoPercent: 50,
      displayPercent: 62,
      completedTasks: 1,
      totalTasks: 2,
    });
  });
});
```

- [ ] **Step 3: Implement progress calculator**

Create `src/domain/progress.ts`:

```ts
import type { ComputedProgressTrack, ProgressTrack, SyncedTask } from "./types";

export function computeTracks(
  tracks: ProgressTrack[],
  tasks: SyncedTask[],
): ComputedProgressTrack[] {
  const tasksById = new Map(tasks.map((task) => [task.id, task]));

  return tracks.map((track) => {
    const linkedTasks = track.linkedTaskIds
      .map((taskId) => tasksById.get(taskId))
      .filter((task): task is SyncedTask => Boolean(task));
    const totalTasks = linkedTasks.length;
    const completedTasks = linkedTasks.filter((task) => task.status === "done").length;
    const autoPercent =
      totalTasks === 0 ? 0 : Math.round((completedTasks / totalTasks) * 100);
    const displayPercent =
      track.mode === "manual" ? clampPercent(track.manualPercent ?? autoPercent) : autoPercent;

    return {
      ...track,
      autoPercent,
      displayPercent,
      completedTasks,
      totalTasks,
    };
  });
}

function clampPercent(value: number): number {
  return Math.max(0, Math.min(100, Math.round(value)));
}
```

- [ ] **Step 4: Write failing task filter tests**

Create `src/tests/taskFilters.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { getLaterThisWeekTasks, getOverdueTasks, getTodayTasks } from "../domain/taskFilters";
import type { TaskViewModel } from "../domain/types";

const baseTask = {
  larkRecordId: "rec",
  sourceType: "group_chat" as const,
  status: "open" as const,
  createdAt: "2026-06-23T00:00:00.000Z",
  updatedAt: "2026-06-23T00:00:00.000Z",
  meta: {
    taskId: "task",
    pinned: false,
    hidden: false,
    displayPriority: 0,
  },
};

const tasks: TaskViewModel[] = [
  { ...baseTask, id: "overdue", title: "Overdue", dueDate: "2026-06-22" },
  { ...baseTask, id: "today", title: "Today", dueDate: "2026-06-23" },
  { ...baseTask, id: "later", title: "Later", dueDate: "2026-06-26" },
  { ...baseTask, id: "hidden", title: "Hidden", dueDate: "2026-06-23", meta: { ...baseTask.meta, taskId: "hidden", hidden: true } },
  { ...baseTask, id: "done", title: "Done", dueDate: "2026-06-23", status: "done" },
];

describe("task filters", () => {
  it("returns open overdue tasks", () => {
    expect(getOverdueTasks(tasks, new Date("2026-06-23T12:00:00+08:00")).map((task) => task.id)).toEqual(["overdue"]);
  });

  it("returns open today tasks", () => {
    expect(getTodayTasks(tasks, new Date("2026-06-23T12:00:00+08:00")).map((task) => task.id)).toEqual(["today"]);
  });

  it("returns open later-this-week tasks", () => {
    expect(getLaterThisWeekTasks(tasks, new Date("2026-06-23T12:00:00+08:00")).map((task) => task.id)).toEqual(["later"]);
  });
});
```

- [ ] **Step 5: Implement task filters**

Create `src/domain/taskFilters.ts`:

```ts
import type { TaskViewModel } from "./types";

export function getVisibleOpenTasks(tasks: TaskViewModel[]): TaskViewModel[] {
  return tasks
    .filter((task) => task.status !== "done")
    .filter((task) => !task.meta.hidden)
    .sort((a, b) => b.meta.displayPriority - a.meta.displayPriority);
}

export function getOverdueTasks(tasks: TaskViewModel[], now: Date): TaskViewModel[] {
  const today = toDateKey(now);
  return getVisibleOpenTasks(tasks).filter((task) => task.dueDate && task.dueDate < today);
}

export function getTodayTasks(tasks: TaskViewModel[], now: Date): TaskViewModel[] {
  const today = toDateKey(now);
  return getVisibleOpenTasks(tasks).filter((task) => task.dueDate === today);
}

export function getLaterThisWeekTasks(tasks: TaskViewModel[], now: Date): TaskViewModel[] {
  const today = toDateKey(now);
  const end = new Date(now);
  end.setDate(now.getDate() + 6);
  const weekEnd = toDateKey(end);

  return getVisibleOpenTasks(tasks).filter(
    (task) => task.dueDate && task.dueDate > today && task.dueDate <= weekEnd,
  );
}

export function toDateKey(date: Date): string {
  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, "0");
  const day = `${date.getDate()}`.padStart(2, "0");
  return `${year}-${month}-${day}`;
}
```

- [ ] **Step 6: Add sample data**

Create `src/data/sampleData.ts`:

```ts
import type { AppSnapshot } from "../domain/types";

export const sampleSnapshot: AppSnapshot = {
  syncState: "idle",
  tasks: [
    {
      id: "task-aime-spec",
      larkRecordId: "rec_aime_spec",
      title: "Review Aime desktop companion spec",
      sourceType: "meeting_note",
      sourceUrl: "https://bytedance.larkoffice.com/base/F4k1bKUkRaIafPsKxP2cVAyEnwJ",
      status: "open",
      dueDate: "2026-06-23",
      createdAt: "2026-06-23T09:00:00.000Z",
      updatedAt: "2026-06-23T09:00:00.000Z",
      project: "Aime Desktop",
    },
    {
      id: "task-aime-widget",
      larkRecordId: "rec_aime_widget",
      title: "Build floating widget prototype",
      sourceType: "manual",
      status: "open",
      dueDate: "2026-06-24",
      createdAt: "2026-06-23T09:00:00.000Z",
      updatedAt: "2026-06-23T09:00:00.000Z",
      project: "Aime Desktop",
    },
    {
      id: "task-aime-sync",
      larkRecordId: "rec_aime_sync",
      title: "Map Lark Base fields for sync",
      sourceType: "group_chat",
      status: "done",
      dueDate: "2026-06-22",
      createdAt: "2026-06-22T09:00:00.000Z",
      updatedAt: "2026-06-23T09:00:00.000Z",
      project: "Aime Desktop",
    }
  ],
  localMeta: [
    { taskId: "task-aime-spec", pinned: true, hidden: false, displayPriority: 3, reminderMinutesBefore: 60 },
    { taskId: "task-aime-widget", pinned: false, hidden: false, displayPriority: 2 },
    { taskId: "task-aime-sync", pinned: false, hidden: false, displayPriority: 1 }
  ],
  tracks: [
    {
      id: "track-aime-desktop",
      name: "Aime Desktop MVP",
      linkedTaskIds: ["task-aime-spec", "task-aime-widget", "task-aime-sync"],
      mode: "auto",
      pinned: true,
      targetDate: "2026-07-05",
      updatedAt: "2026-06-23T09:00:00.000Z"
    },
    {
      id: "track-q3-launch",
      name: "Q3 Launch",
      linkedTaskIds: ["task-aime-spec"],
      mode: "manual",
      manualPercent: 62,
      pinned: true,
      targetDate: "2026-07-31",
      updatedAt: "2026-06-23T09:00:00.000Z"
    }
  ],
  settings: {
    widgetX: 40,
    widgetY: 80,
    miniMode: false,
    reminderHour: 9,
    larkBaseUrl: "https://bytedance.larkoffice.com/base/F4k1bKUkRaIafPsKxP2cVAyEnwJ"
  }
};
```

- [ ] **Step 7: Run tests**

Run:

```bash
npm test
```

Expected: progress and filter tests pass.

- [ ] **Step 8: Commit domain layer**

Run:

```bash
git add src/domain src/data src/tests
git commit -m "feat: add task domain model"
```

## Task 3: Electron Main Process and Persistence

**Files:**
- Create: `electron/store.ts`
- Create: `electron/larkSync.ts`
- Create: `electron/reminders.ts`
- Create: `electron/preload.ts`
- Create: `electron/main.ts`
- Create: `src/lib/desktopApi.ts`

- [ ] **Step 1: Implement local store**

Create `electron/store.ts`:

```ts
import { app } from "electron";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import type { AppSnapshot, LocalTaskMeta, SyncedTask } from "../src/domain/types";
import { sampleSnapshot } from "../src/data/sampleData";

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

export async function updateTaskStatus(taskId: string, status: SyncedTask["status"]): Promise<AppSnapshot> {
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

export async function patchLocalMeta(taskId: string, patch: Partial<LocalTaskMeta>): Promise<AppSnapshot> {
  const snapshot = await loadSnapshot();
  const hasMeta = snapshot.localMeta.some((meta) => meta.taskId === taskId);
  const localMeta = hasMeta
    ? snapshot.localMeta.map((meta) => (meta.taskId === taskId ? { ...meta, ...patch } : meta))
    : [...snapshot.localMeta, { taskId, pinned: false, hidden: false, displayPriority: 0, ...patch }];
  const next = { ...snapshot, localMeta };
  await saveSnapshot(next);
  return next;
}
```

- [ ] **Step 2: Implement sync boundary stub**

Create `electron/larkSync.ts`:

```ts
import type { AppSnapshot } from "../src/domain/types";

export interface LarkSyncConfig {
  baseUrl?: string;
  tableId?: string;
  viewId?: string;
  appId?: string;
  appSecret?: string;
}

export function validateLarkConfig(config: LarkSyncConfig): string[] {
  const errors: string[] = [];
  if (!config.baseUrl) errors.push("Lark Base URL is required.");
  if (!config.tableId) errors.push("Table ID is required before live sync.");
  if (!config.appId) errors.push("Lark app ID is required before live sync.");
  if (!config.appSecret) errors.push("Lark app secret is required before live sync.");
  return errors;
}

export async function pullLarkBase(snapshot: AppSnapshot): Promise<AppSnapshot> {
  const errors = validateLarkConfig({
    baseUrl: snapshot.settings.larkBaseUrl,
    tableId: snapshot.settings.larkTableId,
    viewId: snapshot.settings.larkViewId,
    appId: process.env.LARK_APP_ID,
    appSecret: process.env.LARK_APP_SECRET,
  });

  if (errors.length > 0) {
    return {
      ...snapshot,
      syncState: "stale",
      syncMessage: "Using local sample data until Lark credentials and field mapping are configured.",
    };
  }

  return {
    ...snapshot,
    syncState: "idle",
    syncMessage: "Lark sync adapter is configured but live API calls are not enabled in this MVP slice.",
  };
}
```

- [ ] **Step 3: Implement notifications helper**

Create `electron/reminders.ts`:

```ts
import { Notification } from "electron";
import type { TaskViewModel } from "../src/domain/types";

export function notifyDueTask(task: TaskViewModel): void {
  if (!Notification.isSupported()) return;

  const notification = new Notification({
    title: "Aime reminder",
    body: task.dueDate ? `${task.title} is due ${task.dueDate}` : task.title,
    silent: false,
  });

  notification.show();
}
```

- [ ] **Step 4: Add preload bridge**

Create `electron/preload.ts`:

```ts
import { contextBridge, ipcRenderer } from "electron";
import type { AppSnapshot } from "../src/domain/types";

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
```

- [ ] **Step 5: Implement Electron main process**

Create `electron/main.ts`:

```ts
import { BrowserWindow, Menu, Tray, app, ipcMain, nativeImage } from "electron";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { pullLarkBase } from "./larkSync";
import { loadSnapshot, patchLocalMeta, saveSnapshot, updateTaskDueDate, updateTaskStatus } from "./store";

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
ipcMain.handle("task:reschedule", (_event, taskId: string, dueDate: string) => updateTaskDueDate(taskId, dueDate));
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

app.on("window-all-closed", (event) => {
  event.preventDefault();
});
```

- [ ] **Step 6: Add renderer API wrapper**

Create `src/lib/desktopApi.ts`:

```ts
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
```

- [ ] **Step 7: Run build**

Run:

```bash
npm run build
```

Expected: TypeScript compiles Electron files and Vite builds renderer.

- [ ] **Step 8: Commit desktop shell**

Run:

```bash
git add electron src/lib package.json package-lock.json
git commit -m "feat: add Electron desktop shell"
```

## Task 4: Widget-first React UI

**Files:**
- Create: `src/main.tsx`
- Create: `src/App.tsx`
- Create: `src/styles.css`
- Create: `src/components/CollapsedWidget.tsx`
- Create: `src/components/PeekPanel.tsx`
- Create: `src/components/FullWindow.tsx`
- Create: `src/components/ProgressTrack.tsx`
- Create: `src/components/TaskRow.tsx`
- Create: `src/components/SyncBadge.tsx`
- Create: `src/tests/components.test.tsx`

- [ ] **Step 1: Create UI components**

Create `src/components/ProgressTrack.tsx`:

```tsx
import type { ComputedProgressTrack } from "../domain/types";

export function ProgressTrack({ track }: { track: ComputedProgressTrack }) {
  const modeLabel =
    track.mode === "manual"
      ? "manual override"
      : `auto from ${track.completedTasks}/${track.totalTasks} tasks`;

  return (
    <section className="progress-track">
      <div className="progress-track__header">
        <span>{track.name}</span>
        <strong>{track.displayPercent}%</strong>
      </div>
      <div className="progress-track__bar" aria-label={`${track.name} progress`}>
        <span style={{ width: `${track.displayPercent}%` }} />
      </div>
      <p>{modeLabel}</p>
    </section>
  );
}
```

Create `src/components/SyncBadge.tsx`:

```tsx
import type { SyncState } from "../domain/types";

export function SyncBadge({ state, message }: { state: SyncState; message?: string }) {
  return (
    <div className={`sync-badge sync-badge--${state}`} title={message}>
      {state === "idle" ? "Synced" : state === "syncing" ? "Syncing" : state === "stale" ? "Local" : "Sync issue"}
    </div>
  );
}
```

Create `src/components/TaskRow.tsx`:

```tsx
import type { TaskViewModel } from "../domain/types";

interface TaskRowProps {
  task: TaskViewModel;
  onComplete: (taskId: string) => void;
  onTomorrow: (taskId: string) => void;
  onHide: (taskId: string) => void;
}

export function TaskRow({ task, onComplete, onTomorrow, onHide }: TaskRowProps) {
  return (
    <article className="task-row">
      <div>
        <h3>{task.title}</h3>
        <p>{task.dueDate ?? "No due date"} · {task.project ?? task.sourceType}</p>
      </div>
      <div className="task-row__actions">
        <button type="button" onClick={() => onComplete(task.id)}>Done</button>
        <button type="button" onClick={() => onTomorrow(task.id)}>Tomorrow</button>
        <button type="button" onClick={() => onHide(task.id)}>Hide</button>
      </div>
    </article>
  );
}
```

Create `src/components/CollapsedWidget.tsx`:

```tsx
import type { ComputedProgressTrack, TaskViewModel, SyncState } from "../domain/types";
import { ProgressTrack } from "./ProgressTrack";
import { SyncBadge } from "./SyncBadge";

interface CollapsedWidgetProps {
  overdueCount: number;
  todayCount: number;
  nextTask?: TaskViewModel;
  tracks: ComputedProgressTrack[];
  syncState: SyncState;
  syncMessage?: string;
  onExpand: () => void;
  onOpenFull: () => void;
}

export function CollapsedWidget({
  overdueCount,
  todayCount,
  nextTask,
  tracks,
  syncState,
  syncMessage,
  onExpand,
  onOpenFull,
}: CollapsedWidgetProps) {
  return (
    <main className="widget-shell" onDoubleClick={onOpenFull}>
      <button className="widget-main" type="button" onClick={onExpand}>
        <span className="aime-orb">Ai</span>
        <span>
          <strong>{todayCount} today · {overdueCount} overdue</strong>
          <small>{nextTask?.title ?? "No urgent task"}</small>
        </span>
      </button>
      <div className="widget-tracks">
        {tracks.slice(0, 2).map((track) => (
          <ProgressTrack key={track.id} track={track} />
        ))}
      </div>
      <SyncBadge state={syncState} message={syncMessage} />
    </main>
  );
}
```

Create `src/components/PeekPanel.tsx`:

```tsx
import type { ComputedProgressTrack, TaskViewModel } from "../domain/types";
import { ProgressTrack } from "./ProgressTrack";
import { TaskRow } from "./TaskRow";

interface PeekPanelProps {
  overdueTasks: TaskViewModel[];
  todayTasks: TaskViewModel[];
  laterTasks: TaskViewModel[];
  tracks: ComputedProgressTrack[];
  onCollapse: () => void;
  onComplete: (taskId: string) => void;
  onTomorrow: (taskId: string) => void;
  onHide: (taskId: string) => void;
  onOpenFull: () => void;
}

export function PeekPanel({
  overdueTasks,
  todayTasks,
  laterTasks,
  tracks,
  onCollapse,
  onComplete,
  onTomorrow,
  onHide,
  onOpenFull,
}: PeekPanelProps) {
  return (
    <main className="peek-panel">
      <header>
        <div>
          <p>Aime</p>
          <h1>Today</h1>
        </div>
        <div>
          <button type="button" onClick={onCollapse}>Collapse</button>
          <button type="button" onClick={onOpenFull}>Open</button>
        </div>
      </header>
      <section>
        <h2>Overdue</h2>
        {overdueTasks.length === 0 ? <p className="empty">Nothing overdue.</p> : overdueTasks.map((task) => (
          <TaskRow key={task.id} task={task} onComplete={onComplete} onTomorrow={onTomorrow} onHide={onHide} />
        ))}
      </section>
      <section>
        <h2>Today</h2>
        {todayTasks.length === 0 ? <p className="empty">Today is clear.</p> : todayTasks.map((task) => (
          <TaskRow key={task.id} task={task} onComplete={onComplete} onTomorrow={onTomorrow} onHide={onHide} />
        ))}
      </section>
      <section>
        <h2>Long-term</h2>
        {tracks.slice(0, 3).map((track) => <ProgressTrack key={track.id} track={track} />)}
      </section>
      <section>
        <h2>Later this week</h2>
        {laterTasks.slice(0, 3).map((task) => (
          <TaskRow key={task.id} task={task} onComplete={onComplete} onTomorrow={onTomorrow} onHide={onHide} />
        ))}
      </section>
    </main>
  );
}
```

Create `src/components/FullWindow.tsx`:

```tsx
import type { AppSnapshot, ComputedProgressTrack } from "../domain/types";
import { ProgressTrack } from "./ProgressTrack";

export function FullWindow({ snapshot, tracks }: { snapshot: AppSnapshot; tracks: ComputedProgressTrack[] }) {
  return (
    <main className="full-window">
      <header>
        <div>
          <p>Aime Desktop Task Companion</p>
          <h1>Management</h1>
        </div>
      </header>
      <section className="full-grid">
        <article>
          <h2>Lark Base</h2>
          <p>{snapshot.settings.larkBaseUrl ?? "No Base configured"}</p>
          <p>{snapshot.syncMessage ?? "Ready"}</p>
        </article>
        <article>
          <h2>Long-term tracks</h2>
          {tracks.map((track) => <ProgressTrack key={track.id} track={track} />)}
        </article>
        <article>
          <h2>Local tasks</h2>
          <p>{snapshot.tasks.length} mirrored tasks</p>
          <p>{snapshot.localMeta.filter((meta) => meta.hidden).length} hidden</p>
        </article>
      </section>
    </main>
  );
}
```

- [ ] **Step 2: Create app shell**

Create `src/App.tsx`:

```tsx
import { useEffect, useMemo, useState } from "react";
import { CollapsedWidget } from "./components/CollapsedWidget";
import { FullWindow } from "./components/FullWindow";
import { PeekPanel } from "./components/PeekPanel";
import { computeTracks } from "./domain/progress";
import { getLaterThisWeekTasks, getOverdueTasks, getTodayTasks, toDateKey } from "./domain/taskFilters";
import type { AppSnapshot, TaskViewModel } from "./domain/types";
import { desktopApi } from "./lib/desktopApi";

function mergeTaskMeta(snapshot: AppSnapshot): TaskViewModel[] {
  return snapshot.tasks.map((task) => ({
    ...task,
    meta:
      snapshot.localMeta.find((meta) => meta.taskId === task.id) ??
      { taskId: task.id, pinned: false, hidden: false, displayPriority: 0 },
  }));
}

function tomorrowDateKey(): string {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  return toDateKey(tomorrow);
}

export function App() {
  const [snapshot, setSnapshot] = useState<AppSnapshot | null>(null);
  const [expanded, setExpanded] = useState(new URLSearchParams(window.location.search).get("mode") === "full");

  useEffect(() => {
    void desktopApi.getSnapshot().then(setSnapshot);
  }, []);

  const view = useMemo(() => {
    if (!snapshot) return null;
    const taskViewModels = mergeTaskMeta(snapshot);
    const now = new Date();
    const overdueTasks = getOverdueTasks(taskViewModels, now);
    const todayTasks = getTodayTasks(taskViewModels, now);
    const laterTasks = getLaterThisWeekTasks(taskViewModels, now);
    const tracks = computeTracks(snapshot.tracks, snapshot.tasks).filter((track) => track.pinned);
    return { taskViewModels, overdueTasks, todayTasks, laterTasks, tracks };
  }, [snapshot]);

  if (!snapshot || !view) {
    return <main className="widget-shell"><p>Loading Aime...</p></main>;
  }

  async function completeTask(taskId: string) {
    setSnapshot(await desktopApi.completeTask(taskId));
  }

  async function moveToTomorrow(taskId: string) {
    setSnapshot(await desktopApi.rescheduleTask(taskId, tomorrowDateKey()));
  }

  async function hideTask(taskId: string) {
    setSnapshot(await desktopApi.hideTask(taskId));
  }

  if (new URLSearchParams(window.location.search).get("mode") === "full") {
    return <FullWindow snapshot={snapshot} tracks={view.tracks} />;
  }

  if (expanded) {
    return (
      <PeekPanel
        overdueTasks={view.overdueTasks}
        todayTasks={view.todayTasks}
        laterTasks={view.laterTasks}
        tracks={view.tracks}
        onCollapse={() => setExpanded(false)}
        onComplete={(taskId) => void completeTask(taskId)}
        onTomorrow={(taskId) => void moveToTomorrow(taskId)}
        onHide={(taskId) => void hideTask(taskId)}
        onOpenFull={() => void desktopApi.openFullWindow()}
      />
    );
  }

  return (
    <CollapsedWidget
      overdueCount={view.overdueTasks.length}
      todayCount={view.todayTasks.length}
      nextTask={view.overdueTasks[0] ?? view.todayTasks[0]}
      tracks={view.tracks}
      syncState={snapshot.syncState}
      syncMessage={snapshot.syncMessage}
      onExpand={() => setExpanded(true)}
      onOpenFull={() => void desktopApi.openFullWindow()}
    />
  );
}
```

Create `src/main.tsx`:

```tsx
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import "./styles.css";

const root = document.getElementById("root");

if (!root) {
  throw new Error("Root element not found.");
}

createRoot(root).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
```

- [ ] **Step 3: Add widget-first styling**

Create `src/styles.css`:

```css
:root {
  color: #1d2428;
  background: transparent;
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  min-width: 100vw;
  min-height: 100vh;
  overflow: hidden;
  background: transparent;
}

button {
  border: 0;
  border-radius: 7px;
  background: #235b51;
  color: white;
  font: inherit;
  cursor: pointer;
  padding: 7px 10px;
}

.widget-shell,
.peek-panel,
.full-window {
  background: rgba(250, 252, 249, 0.94);
  border: 1px solid rgba(26, 42, 38, 0.14);
  box-shadow: 0 16px 50px rgba(20, 30, 26, 0.16);
  backdrop-filter: blur(20px);
}

.widget-shell {
  width: 360px;
  min-height: 200px;
  border-radius: 18px;
  padding: 14px;
}

.widget-main {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 12px;
  color: #1d2428;
  background: transparent;
  text-align: left;
  padding: 0;
}

.widget-main strong,
.widget-main small {
  display: block;
}

.widget-main small {
  margin-top: 4px;
  color: #5f6f6b;
}

.aime-orb {
  width: 48px;
  height: 48px;
  flex: 0 0 48px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  color: white;
  background: linear-gradient(145deg, #235b51, #b4472f);
  font-weight: 800;
}

.widget-tracks {
  display: grid;
  gap: 8px;
  margin-top: 12px;
}

.progress-track {
  padding: 9px;
  border: 1px solid rgba(35, 91, 81, 0.16);
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.62);
}

.progress-track__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  font-size: 13px;
}

.progress-track__bar {
  height: 7px;
  margin-top: 7px;
  overflow: hidden;
  border-radius: 999px;
  background: #d8e4df;
}

.progress-track__bar span {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: #e0714f;
}

.progress-track p,
.empty {
  margin: 6px 0 0;
  color: #65736f;
  font-size: 12px;
}

.sync-badge {
  display: inline-flex;
  margin-top: 10px;
  padding: 4px 8px;
  border-radius: 999px;
  font-size: 12px;
  background: #e7eee9;
  color: #48625a;
}

.sync-badge--error {
  background: #ffe4dc;
  color: #8a321f;
}

.sync-badge--stale {
  background: #fff0cf;
  color: #76511a;
}

.peek-panel {
  width: 520px;
  max-height: 680px;
  overflow: auto;
  border-radius: 18px;
  padding: 16px;
}

.peek-panel header,
.full-window header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.peek-panel h1,
.full-window h1,
.peek-panel p,
.full-window p {
  margin: 0;
}

.peek-panel h2,
.full-window h2 {
  margin: 18px 0 8px;
  font-size: 15px;
}

.task-row {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 12px;
  padding: 10px 0;
  border-top: 1px solid rgba(29, 36, 40, 0.1);
}

.task-row h3 {
  margin: 0;
  font-size: 14px;
}

.task-row p {
  margin-top: 4px;
  color: #65736f;
  font-size: 12px;
}

.task-row__actions {
  display: flex;
  gap: 6px;
  align-items: center;
}

.task-row__actions button {
  padding: 5px 7px;
  font-size: 12px;
}

.full-window {
  min-height: 100vh;
  padding: 28px;
  border-radius: 0;
  background: #f6f8f5;
}

.full-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 16px;
  margin-top: 24px;
}

.full-grid article {
  min-height: 180px;
  border: 1px solid rgba(29, 36, 40, 0.12);
  border-radius: 8px;
  padding: 16px;
  background: white;
}
```

- [ ] **Step 4: Add component test**

Create `src/tests/components.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { ProgressTrack } from "../components/ProgressTrack";

describe("ProgressTrack", () => {
  it("shows manual override label", () => {
    render(
      <ProgressTrack
        track={{
          id: "track",
          name: "Aime Desktop MVP",
          linkedTaskIds: [],
          mode: "manual",
          manualPercent: 62,
          autoPercent: 0,
          displayPercent: 62,
          completedTasks: 0,
          totalTasks: 0,
          pinned: true,
          updatedAt: "2026-06-23T00:00:00.000Z",
        }}
      />,
    );

    expect(screen.getByText("Aime Desktop MVP")).toBeInTheDocument();
    expect(screen.getByText("62%")).toBeInTheDocument();
    expect(screen.getByText("manual override")).toBeInTheDocument();
  });
});
```

- [ ] **Step 5: Run tests and build**

Run:

```bash
npm test
npm run build
```

Expected: tests pass and app builds.

- [ ] **Step 6: Commit UI**

Run:

```bash
git add src
git commit -m "feat: build widget-first task UI"
```

## Task 5: MVP Verification and Run Instructions

**Files:**
- Create: `README.md`
- Modify: `docs/superpowers/specs/2026-06-23-aime-desktop-task-companion-design.md`

- [ ] **Step 1: Create README with local run path**

Create `README.md`:

```md
# Aime Desktop Task Companion

Mac-first desktop task companion for Aime todo monitoring.

## Local Run

Install dependencies:

```bash
npm install
```

Run the renderer in a browser:

```bash
npm run dev
```

Run the desktop shell:

```bash
npm run dev:electron
```

Build:

```bash
npm run build
```

Test:

```bash
npm test
```

## MVP Behavior

- Shows an always-on-top floating widget.
- Click expands a peek panel with overdue, today, later-this-week tasks.
- Double-click opens the management window.
- Completion, reschedule, and hide actions update the local store.
- Lark Base sync is represented by a configurable adapter boundary and stays in local sample mode until credentials and field mapping are configured.
```

- [ ] **Step 2: Verify app locally**

Run:

```bash
npm test
npm run build
npm run dev:electron
```

Expected:

- Tests pass.
- Production build succeeds.
- Electron opens a transparent, always-on-top widget.
- Clicking the widget opens the peek panel.
- Double-clicking opens the management window.
- Completing or hiding a task updates the displayed counts.

- [ ] **Step 3: Commit verification docs**

Run:

```bash
git add README.md docs/superpowers/specs/2026-06-23-aime-desktop-task-companion-design.md
git commit -m "docs: add local MVP run instructions"
```

## Self-Review

Spec coverage:

- Always-visible widget: Task 3 creates the frameless always-on-top Electron window; Task 4 implements the collapsed widget UI.
- Peek panel: Task 4 implements `PeekPanel`.
- Full management window: Task 3 opens a full window; Task 4 implements `FullWindow`.
- Lark Base source-of-record boundary: Task 3 adds `larkSync.ts` and restricts live behavior to a config-gated adapter.
- Completion/due-date write-back boundary: Task 3 adds IPC actions for complete and reschedule; live Lark API write-back remains the next implementation slice after credentials and field mapping are known.
- Local desktop metadata: Task 3 persists hidden/pinned-style metadata locally.
- Long-term tracks: Task 2 adds progress calculation and Task 4 displays progress tracks.
- Reminders: Task 3 adds notification helper; recurring scheduler is a follow-up slice after first desktop shell verification.
- Skill/deployment path: README and spec keep setup boundaries visible for later skill packaging.

No placeholder scan:

- The plan intentionally leaves live Lark API calls out of this MVP slice because the current field mapping and auth mode are not known. It includes a working config boundary and sample-local mode instead of a vague future implementation.

