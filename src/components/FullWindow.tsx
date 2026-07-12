import { useMemo, useState } from "react";
import type { CaptureIntentEventInput, IntentSettings } from "../domain/intentTypes";
import type { AppSnapshot, ComputedProgressTrack, TaskViewModel } from "../domain/types";
import { getCompletedTasks, getLaterThisWeekTasks, getOverdueTasks, getTodayTasks, getVisibleOpenTasks } from "../domain/taskFilters";
import { Sidebar, type CategoryKey } from "./Sidebar";
import { MainContent } from "./MainContent";
import { ManualCaptureForm } from "./ManualCaptureForm";
import { SuggestionSettings } from "./SuggestionSettings";

interface FullWindowProps {
  snapshot: AppSnapshot;
  tracks: ComputedProgressTrack[];
  intentSettings?: IntentSettings;
  intentEventCount?: number;
  intentSuggestionCount?: number;
  onCompleteTask?: (taskId: string) => void;
  onReopenTask?: (taskId: string) => void;
  onRescheduleTask?: (taskId: string, date: string) => void;
  onHideTask?: (taskId: string) => void;
  onCaptureIntent?: (input: CaptureIntentEventInput) => void;
  onUpdateIntentSettings?: (settings: Partial<IntentSettings>) => void;
  onClearIntentHistory?: () => void;
}

export function FullWindow({
  snapshot,
  tracks,
  intentSettings,
  intentEventCount = 0,
  intentSuggestionCount = 0,
  onCompleteTask,
  onReopenTask,
  onRescheduleTask,
  onHideTask,
  onCaptureIntent,
  onUpdateIntentSettings,
  onClearIntentHistory,
}: FullWindowProps) {
  const [activeCategory, setActiveCategory] = useState<CategoryKey>("today");

  const taskViewModels: TaskViewModel[] = useMemo(() => {
    return snapshot.tasks.map((task) => ({
      ...task,
      meta: snapshot.localMeta.find((meta) => meta.taskId === task.id) ?? {
        taskId: task.id,
        pinned: false,
        hidden: false,
        displayPriority: 0,
      },
    }));
  }, [snapshot]);

  const now = new Date();
  const visibleOpenTasks = getVisibleOpenTasks(taskViewModels);
  const overdueTasks = getOverdueTasks(taskViewModels, now);
  const todayTasks = getTodayTasks(taskViewModels, now);
  const laterTasks = getLaterThisWeekTasks(taskViewModels, now);
  const completedTasks = getCompletedTasks(taskViewModels);

  const displayedTasks = useMemo(() => {
    switch (activeCategory) {
      case "today":
        return [...overdueTasks, ...todayTasks];
      case "planned":
        return laterTasks;
      case "completed":
        return completedTasks;
      case "all":
      default:
        return visibleOpenTasks;
    }
  }, [activeCategory, overdueTasks, todayTasks, laterTasks, completedTasks, visibleOpenTasks]);

  function tomorrowDateKey(): string {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const year = tomorrow.getFullYear();
    const month = `${tomorrow.getMonth() + 1}`.padStart(2, "0");
    const day = `${tomorrow.getDate()}`.padStart(2, "0");
    return `${year}-${month}-${day}`;
  }

  return (
    <div className="app-shell full-window">
      <Sidebar
        activeCategory={activeCategory}
        onSelectCategory={setActiveCategory}
        todayCount={overdueTasks.length + todayTasks.length}
        plannedCount={laterTasks.length}
        allCount={visibleOpenTasks.length}
        completedCount={completedTasks.length}
        listCount={visibleOpenTasks.length}
        listLabel={snapshot.settings.larkBaseUrl ? "飞书待办" : "提醒事项"}
        track={tracks[0] ? { name: tracks[0].name, displayPercent: tracks[0].displayPercent } : undefined}
        tools={
          onCaptureIntent || (intentSettings && onUpdateIntentSettings && onClearIntentHistory) ? (
            <>
              {onCaptureIntent ? <ManualCaptureForm onCapture={onCaptureIntent} /> : null}
              {intentSettings && onUpdateIntentSettings && onClearIntentHistory ? (
                <SuggestionSettings
                  settings={intentSettings}
                  eventCount={intentEventCount}
                  suggestionCount={intentSuggestionCount}
                  onUpdateSettings={onUpdateIntentSettings}
                  onClearHistory={onClearIntentHistory}
                />
              ) : null}
            </>
          ) : undefined
        }
      />
      <MainContent
        activeCategory={activeCategory}
        tasks={displayedTasks}
        completedCount={completedTasks.length}
        onComplete={onCompleteTask}
        onReopen={onReopenTask}
        onTomorrow={(taskId) => onRescheduleTask?.(taskId, tomorrowDateKey())}
        onHide={onHideTask}
      />
    </div>
  );
}
