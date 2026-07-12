import { useMemo, useState } from "react";
import type { ProactiveSuggestion } from "../domain/intentTypes";
import type { ComputedProgressTrack, TaskViewModel } from "../domain/types";
import { TaskRow } from "./TaskRow";
import { SuggestionCard } from "./SuggestionCard";

interface PeekPanelProps {
  overdueTasks: TaskViewModel[];
  todayTasks: TaskViewModel[];
  laterTasks: TaskViewModel[];
  completedTasks?: TaskViewModel[];
  tracks: ComputedProgressTrack[];
  suggestions?: ProactiveSuggestion[];
  onCollapse: () => void;
  onComplete: (taskId: string) => void;
  onReopen?: (taskId: string) => void;
  onTomorrow: (taskId: string) => void;
  onHide: (taskId: string) => void;
  onOpenFull: () => void;
  onSetWindowSize?: (width: number, height: number) => void;
  onAcceptSuggestion?: (suggestionId: string) => void;
  onDismissSuggestion?: (suggestionId: string) => void;
  onNeverSuggestType?: (suggestionId: string) => void;
}

export function PeekPanel({
  overdueTasks,
  todayTasks,
  laterTasks,
  completedTasks = [],
  tracks,
  suggestions = [],
  onCollapse,
  onComplete,
  onReopen = () => undefined,
  onTomorrow,
  onHide,
  onOpenFull,
  onSetWindowSize = () => undefined,
  onAcceptSuggestion = () => undefined,
  onDismissSuggestion = () => undefined,
  onNeverSuggestType = () => undefined,
}: PeekPanelProps) {
  const [showCompleted, setShowCompleted] = useState(false);

  const allOpen = useMemo(
    () => [...overdueTasks, ...todayTasks, ...laterTasks],
    [overdueTasks, todayTasks, laterTasks],
  );

  const displayTasks = showCompleted ? completedTasks : [...allOpen, ...completedTasks];
  const title = showCompleted ? "完成" : "今天";
  const titleColor = showCompleted ? "gray" : "blue";
  const totalCompleted = completedTasks.length;

  return (
    <main className="peek-panel">
      <header className="peek-panel__header">
        <h1 className={`peek-panel__title main-header__title--${titleColor}`}>{title}</h1>
        <div style={{ display: "flex", gap: 8 }}>
          <button type="button" className="peek-panel__close" onClick={onOpenFull} aria-label="打开完整窗口">
            ⤢
          </button>
          <button type="button" className="peek-panel__close" onClick={onCollapse} aria-label="收起">
            ×
          </button>
        </div>
      </header>

      <div className="peek-panel__meta">
        {showCompleted
          ? `${totalCompleted} 项完成`
          : `${allOpen.length} 项待办${totalCompleted > 0 ? ` · ${totalCompleted} 项完成` : ""}`}
        <button
          type="button"
          style={{
            marginLeft: 12,
            color: "var(--accent-blue)",
            fontWeight: 600,
          }}
          onClick={() => setShowCompleted((v) => !v)}
        >
          {showCompleted ? "显示待办" : "显示已完成"}
        </button>
      </div>

      <div className="size-presets" aria-label="面板尺寸">
        <button type="button" aria-label="小尺寸" onClick={() => onSetWindowSize(320, 220)}>小</button>
        <button type="button" aria-label="标准尺寸" onClick={() => onSetWindowSize(360, 260)}>标准</button>
        <button type="button" aria-label="大尺寸" onClick={() => onSetWindowSize(480, 420)}>大</button>
      </div>

      <div className="peek-panel__scroll">
        {!showCompleted ? (
          <div className="add-task-row">
            <span className="add-task-row__circle" />
            <input type="text" placeholder="添加新任务…" aria-label="添加新任务" />
          </div>
        ) : null}

        {suggestions.length > 0 && !showCompleted ? (
          <section style={{ margin: "12px 0" }} aria-label="主动建议">
            {suggestions.map((suggestion) => (
              <SuggestionCard
                key={suggestion.id}
                suggestion={suggestion}
                onAccept={onAcceptSuggestion}
                onDismiss={onDismissSuggestion}
                onNeverSuggest={onNeverSuggestType}
              />
            ))}
          </section>
        ) : null}

        {displayTasks.length === 0 ? (
          <div className="empty-state" style={{ minHeight: 200 }}>
            {showCompleted ? "没有已完成事项" : "没有提醒事项"}
          </div>
        ) : (
          <div className="task-list" role="list">
            {displayTasks.map((task) => (
              <TaskRow
                key={task.id}
                task={task}
                onComplete={onComplete}
                onReopen={onReopen}
                onTomorrow={onTomorrow}
                onHide={onHide}
              />
            ))}
          </div>
        )}

        {tracks.length > 0 ? (
          <div className="progress-track" style={{ marginTop: 16 }}>
            <div className="progress-track__header">
              <span>{tracks[0].name}</span>
              <span>{tracks[0].displayPercent}%</span>
            </div>
            <div className="progress-track__bar">
              <span style={{ width: `${tracks[0].displayPercent}%` }} />
            </div>
          </div>
        ) : null}
      </div>
    </main>
  );
}
