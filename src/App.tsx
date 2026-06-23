import { useEffect, useMemo, useState } from "react";
import { CollapsedWidget } from "./components/CollapsedWidget";
import { FullWindow } from "./components/FullWindow";
import { PeekPanel } from "./components/PeekPanel";
import { computeTracks } from "./domain/progress";
import {
  getLaterThisWeekTasks,
  getOverdueTasks,
  getTodayTasks,
  toDateKey,
} from "./domain/taskFilters";
import type { AppSnapshot, TaskViewModel } from "./domain/types";
import { desktopApi } from "./lib/desktopApi";

function mergeTaskMeta(snapshot: AppSnapshot): TaskViewModel[] {
  return snapshot.tasks.map((task) => ({
    ...task,
    meta: snapshot.localMeta.find((meta) => meta.taskId === task.id) ?? {
      taskId: task.id,
      pinned: false,
      hidden: false,
      displayPriority: 0,
    },
  }));
}

function tomorrowDateKey(): string {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  return toDateKey(tomorrow);
}

export function App() {
  const [snapshot, setSnapshot] = useState<AppSnapshot | null>(null);
  const [expanded, setExpanded] = useState(
    new URLSearchParams(window.location.search).get("mode") === "full",
  );

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
    return (
      <main className="widget-shell">
        <p>Loading Aime...</p>
      </main>
    );
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
        onCollapse={() => {
          void desktopApi.setWindowMode("widget");
          setExpanded(false);
        }}
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
      onExpand={() => {
        void desktopApi.setWindowMode("peek");
        setExpanded(true);
      }}
      onOpenFull={() => {
        void desktopApi.setWindowMode("full");
        void desktopApi.openFullWindow();
      }}
    />
  );
}
