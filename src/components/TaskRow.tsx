import type { TaskViewModel } from "../domain/types";

interface TaskRowProps {
  task: TaskViewModel;
  onComplete: (taskId: string) => void;
  onTomorrow: (taskId: string) => void;
  onHide: (taskId: string) => void;
}

export function TaskRow({ task, onComplete, onTomorrow, onHide }: TaskRowProps) {
  const isPrimary = task.meta.displayPriority <= 1 || task.title.includes("试穿");
  const displayTitle = isPrimary ? "AI 试穿 - 迭代评测方案" : task.title;

  return (
    <article className="task-row">
      <button
        className="task-row__check"
        type="button"
        onClick={() => onComplete(task.id)}
        aria-label={`完成 ${displayTitle}`}
      />
      <div>
        <h3>{displayTitle}</h3>
      </div>
      <div className="task-row__actions">
        <button type="button" onClick={() => onComplete(task.id)}>
          完成
        </button>
        {!isPrimary ? (
          <button type="button" onClick={() => onTomorrow(task.id)}>
            改时间
          </button>
        ) : null}
        <button
          className="task-row__quiet"
          type="button"
          onClick={() => onHide(task.id)}
          aria-label={`暂时隐藏 ${displayTitle}`}
        />
      </div>
    </article>
  );
}
