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
        <p>
          {task.dueDate ?? "No due date"} · {task.project ?? task.sourceType}
        </p>
      </div>
      <div className="task-row__actions">
        <button type="button" onClick={() => onComplete(task.id)}>
          Done
        </button>
        <button type="button" onClick={() => onTomorrow(task.id)}>
          Tomorrow
        </button>
        <button type="button" onClick={() => onHide(task.id)}>
          Hide
        </button>
      </div>
    </article>
  );
}
