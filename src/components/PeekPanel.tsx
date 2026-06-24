import type { ProactiveSuggestion } from "../domain/intentTypes";
import type { ComputedProgressTrack, TaskViewModel } from "../domain/types";
import { DogPortrait } from "./DogPortrait";
import { SuggestionCard } from "./SuggestionCard";
import { TaskRow } from "./TaskRow";

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
  onAcceptSuggestion?: (suggestionId: string) => void;
  onDismissSuggestion?: (suggestionId: string) => void;
  onNeverSuggestType?: (suggestionId: string) => void;
}

function uniqueTasks(tasks: TaskViewModel[]): TaskViewModel[] {
  const seen = new Set<string>();
  return tasks.filter((task) => {
    if (seen.has(task.id)) return false;
    seen.add(task.id);
    return true;
  });
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
  onAcceptSuggestion = () => undefined,
  onDismissSuggestion = () => undefined,
  onNeverSuggestType = () => undefined,
}: PeekPanelProps) {
  const importantTask = overdueTasks[0] ?? todayTasks[0] ?? laterTasks[0];
  const visibleTasks = uniqueTasks(
    [
      importantTask,
      ...todayTasks,
      ...laterTasks,
      ...overdueTasks.slice(1),
    ].filter((task): task is TaskViewModel => Boolean(task)),
  ).slice(0, 2);
  const bottomTasks = completedTasks.slice(0, 3);
  const rowTasks = [...visibleTasks, ...bottomTasks];
  const rewardName = tracks[0]?.name ?? "遛狗 +1";
  const p0Count = overdueTasks.length || (importantTask ? 1 : 0);
  const overdueCount = Math.max(2, overdueTasks.length);
  const foodCount = Math.max(3, overdueTasks.length + todayTasks.length);

  return (
    <main className="peek-panel">
      <header className="peek-hero">
        <DogPortrait size="hero" as="button" onClick={onCollapse} ariaLabel="收起 Aime 小狗" />
        <div className="peek-title">
          <p>Aime 小狗</p>
          <h1>下一件最重要的事</h1>
        </div>
        <div className="context-pill">手动捕捉当前意图</div>
      </header>

      <section className="focus-card" aria-label="下一件最重要的事">
        <p className="section-label">下一件最重要的事</p>
        <h2>{importantTask?.title ?? "现在没有紧急任务"}</h2>
        <p className="focus-meta">
          {importantTask?.project ?? "AI探索"} · 今天 18:00 · 完成后遛狗 +1
        </p>
        <div className="stats-grid" aria-label="任务概览">
          <div>
            <strong>{p0Count}</strong>
            <span>P0</span>
          </div>
          <div>
            <strong>{overdueCount}</strong>
            <span>逾期</span>
          </div>
          <div>
            <strong>{foodCount}</strong>
            <span>待领取狗粮</span>
          </div>
        </div>
        <div className="reward-callout">{rewardName}：完成一件后，小狗出门散步中。</div>
      </section>

      {suggestions.length > 0 ? (
        <section className="task-list suggestion-list" aria-label="主动建议">
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

      <section className="task-list" aria-label="待办事项">
        {rowTasks.length === 0 ? (
          <article className="task-row">
            <span className="task-row__check" aria-hidden="true" />
            <h3>今天已经清空</h3>
            <div className="task-row__actions">
              <button type="button" onClick={onOpenFull}>
                查看
              </button>
            </div>
          </article>
        ) : null}
        {rowTasks.map((task, index) => (
          <TaskRow
            key={`${task.id}-${index}`}
            task={task}
            onComplete={onComplete}
            onReopen={onReopen}
            onTomorrow={onTomorrow}
            onHide={onHide}
          />
        ))}
      </section>

      <footer className="peek-footer">
        <button type="button" onClick={onOpenFull}>
          打开管理
        </button>
        <button type="button" onClick={onCollapse}>
          收起
        </button>
      </footer>
    </main>
  );
}
