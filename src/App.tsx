import { useEffect, useMemo, useState } from "react";
import { CollapsedWidget } from "./components/CollapsedWidget";
import { FullWindow } from "./components/FullWindow";
import { PeekPanel } from "./components/PeekPanel";
import { defaultIntentSettings } from "./domain/intentTypes";
import { computeTracks } from "./domain/progress";
import {
  getLaterThisWeekTasks,
  getCompletedTasks,
  getOverdueTasks,
  getTodayTasks,
  toDateKey,
} from "./domain/taskFilters";
import type { AppSnapshot, TaskViewModel } from "./domain/types";
import type { CaptureIntentEventInput, IntentSettings, IntentState } from "./domain/intentTypes";
import { desktopApi, intentApi } from "./lib/desktopApi";

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
  const [intentState, setIntentState] = useState<IntentState | null>(null);
  const initialMode = new URLSearchParams(window.location.search).get("mode");
  const [expanded, setExpanded] = useState(
    initialMode === "peek" || initialMode === "full",
  );

  useEffect(() => {
    void desktopApi.getSnapshot().then(setSnapshot);
    void intentApi.getState().then(setIntentState);
  }, []);

  const view = useMemo(() => {
    if (!snapshot) return null;
    const taskViewModels = mergeTaskMeta(snapshot);
    const now = new Date();
    const overdueTasks = getOverdueTasks(taskViewModels, now);
    const todayTasks = getTodayTasks(taskViewModels, now);
    const laterTasks = getLaterThisWeekTasks(taskViewModels, now);
    const completedTasks = getCompletedTasks(taskViewModels);
    const tracks = computeTracks(snapshot.tracks, snapshot.tasks).filter((track) => track.pinned);
    return { taskViewModels, overdueTasks, todayTasks, laterTasks, completedTasks, tracks };
  }, [snapshot]);

  const pendingSuggestions = useMemo(
    () => intentState?.suggestions.filter((suggestion) => suggestion.state === "pending") ?? [],
    [intentState],
  );

  if (!snapshot || !view) {
    return (
      <main className="widget-shell">
        <p>Loading Aime...</p>
      </main>
    );
  }

  async function completeTask(taskId: string) {
    if (!view) return;
    setSnapshot(await desktopApi.completeTask(taskId));
  }

  async function reopenTask(taskId: string) {
    if (!view) return;
    setSnapshot(await desktopApi.reopenTask(taskId));
  }

  async function moveToTomorrow(taskId: string) {
    if (!view) return;
    const task = view.taskViewModels.find((item) => item.id === taskId);
    setSnapshot(await desktopApi.rescheduleTask(taskId, tomorrowDateKey()));
    await captureTaskAction("改到明天", task);
  }

  async function hideTask(taskId: string) {
    if (!view) return;
    const task = view.taskViewModels.find((item) => item.id === taskId);
    setSnapshot(await desktopApi.hideTask(taskId));
    await captureTaskAction("暂时隐藏", task);
  }

  async function refreshIntentState() {
    setIntentState(await intentApi.getState());
  }

  async function captureIntent(input: CaptureIntentEventInput) {
    await intentApi.captureEvent(input);
    await refreshIntentState();
  }

  async function captureTaskAction(actionName: string, task?: TaskViewModel) {
    if (!task) return;

    await captureIntent({
      triggerType: "task_action",
      textContext: `任务动作：${actionName} - ${task.title}`,
      relatedTaskIds: [task.id],
      privacyLevel: "local_only",
    });
  }

  async function acceptSuggestion(suggestionId: string) {
    await intentApi.acceptSuggestion(suggestionId);
    setSnapshot(await desktopApi.getSnapshot());
    await refreshIntentState();
  }

  async function dismissSuggestion(suggestionId: string) {
    await intentApi.dismissSuggestion(suggestionId);
    await refreshIntentState();
  }

  async function neverSuggestType(suggestionId: string) {
    await intentApi.neverSuggestType(suggestionId);
    await refreshIntentState();
  }

  async function updateIntentSettings(settings: Partial<IntentSettings>) {
    await intentApi.updateSettings(settings);
    await refreshIntentState();
  }

  async function clearIntentHistory() {
    await intentApi.clearHistory();
    await refreshIntentState();
  }

  if (new URLSearchParams(window.location.search).get("mode") === "full") {
    return (
      <FullWindow
        snapshot={snapshot}
        tracks={view.tracks}
        intentSettings={intentState?.settings ?? defaultIntentSettings}
        intentEventCount={intentState?.events.length ?? 0}
        intentSuggestionCount={intentState?.suggestions.length ?? 0}
        onCaptureIntent={(input) => void captureIntent(input)}
        onUpdateIntentSettings={(settings) => void updateIntentSettings(settings)}
        onClearIntentHistory={() => void clearIntentHistory()}
      />
    );
  }

  if (expanded) {
    return (
      <PeekPanel
        overdueTasks={view.overdueTasks}
        todayTasks={view.todayTasks}
        laterTasks={view.laterTasks}
        completedTasks={view.completedTasks}
        tracks={view.tracks}
        suggestions={pendingSuggestions}
        onCollapse={() => {
          void desktopApi.setWindowMode("widget");
          setExpanded(false);
        }}
        onComplete={(taskId) => void completeTask(taskId)}
        onReopen={(taskId) => void reopenTask(taskId)}
        onTomorrow={(taskId) => void moveToTomorrow(taskId)}
        onHide={(taskId) => void hideTask(taskId)}
        onOpenFull={() => void desktopApi.openFullWindow()}
        onAcceptSuggestion={(suggestionId) => void acceptSuggestion(suggestionId)}
        onDismissSuggestion={(suggestionId) => void dismissSuggestion(suggestionId)}
        onNeverSuggestType={(suggestionId) => void neverSuggestType(suggestionId)}
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
      suggestions={pendingSuggestions}
      onExpand={() => {
        void desktopApi.setWindowMode("peek");
        setExpanded(true);
      }}
      onOpenFull={() => {
        void desktopApi.setWindowMode("full");
        void desktopApi.openFullWindow();
      }}
      onAcceptSuggestion={(suggestionId) => void acceptSuggestion(suggestionId)}
      onDismissSuggestion={(suggestionId) => void dismissSuggestion(suggestionId)}
    />
  );
}
