import type { TaskViewModel } from "../domain/types";

interface TaskRowProps {
  task: TaskViewModel;
  onComplete?: (taskId: string) => void;
  onReopen?: (taskId: string) => void;
  onTomorrow?: (taskId: string) => void;
  onHide?: (taskId: string) => void;
}

export function TaskRow({ task, onComplete, onReopen, onHide }: TaskRowProps) {
  const isDone = task.status === "done";
  const displayTitle = task.title;
  const dueText = task.dueDate ? `截止 ${task.dueDate}` : undefined;
  const projectText = task.project;
  const metaParts = [projectText, dueText].filter(Boolean);

  return (
    <article className={`task-row${isDone ? " task-row--done" : ""}`} role="listitem">
      <button
        className="task-row__check"
        type="button"
        onClick={() => {
          if (isDone) {
            onReopen?.(task.id);
          } else {
            onComplete?.(task.id);
          }
        }}
        aria-label={isDone ? `取消完成 ${displayTitle}` : `完成 ${displayTitle}`}
        aria-pressed={isDone}
      >
        {isDone ? "✓" : ""}
      </button>
      <div>
        <h3 className="task-row__title">{displayTitle}</h3>
        {metaParts.length > 0 ? <p className="task-row__meta">{metaParts.join(" · ")}</p> : null}
      </div>
      <div className="task-row__actions">
        {!isDone ? (
          <>
            <button type="button" onClick={() => onHide?.(task.id)}>
              隐藏
            </button>
          </>
        ) : null}
      </div>
    </article>
  );
}
