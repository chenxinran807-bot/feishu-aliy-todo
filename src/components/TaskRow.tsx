import type { TaskViewModel } from "../domain/types";

interface TaskRowProps {
  task: TaskViewModel;
  onComplete: (taskId: string) => void;
  onReopen: (taskId: string) => void;
  onTomorrow: (taskId: string) => void;
  onHide: (taskId: string) => void;
}

export function TaskRow({ task, onComplete, onReopen, onHide }: TaskRowProps) {
  const isDone = task.status === "done";
  const isPrimary = !isDone && task.title.includes("试穿");
  const displayTitle = isPrimary ? "AI 试穿 - 迭代评测方案" : task.title;

  return (
    <article className={`task-row${isDone ? " task-row--done" : ""}`}>
      <button
        className="task-row__check"
        type="button"
        onClick={() => {
          if (isDone) {
            onReopen(task.id);
          } else {
            onComplete(task.id);
          }
        }}
        aria-label={isDone ? `取消完成 ${displayTitle}` : `完成 ${displayTitle}`}
        aria-pressed={isDone}
      >
        {isDone ? "✓" : ""}
      </button>
      <div>
        <h3>{displayTitle}</h3>
      </div>
      <div className="task-row__actions">
        {isDone ? (
          <span className="task-row__done-label">已完成</span>
        ) : null}
        {!isDone ? (
          <button
            className="task-row__quiet"
            type="button"
            onClick={() => onHide(task.id)}
            aria-label={`暂时隐藏 ${displayTitle}`}
          />
        ) : null}
      </div>
    </article>
  );
}
