import type { CategoryKey } from "./Sidebar";
import type { TaskViewModel } from "../domain/types";
import { TaskRow } from "./TaskRow";

type CategoryColor = "blue" | "red" | "dark" | "gray";

const categoryTitles: Record<CategoryKey, { title: string; color: CategoryColor }> = {
  today: { title: "今天", color: "blue" },
  planned: { title: "计划", color: "red" },
  all: { title: "全部", color: "dark" },
  completed: { title: "完成", color: "gray" },
};

interface MainContentProps {
  activeCategory: CategoryKey;
  tasks: TaskViewModel[];
  completedCount: number;
  onComplete?: (taskId: string) => void;
  onReopen?: (taskId: string) => void;
  onTomorrow?: (taskId: string) => void;
  onHide?: (taskId: string) => void;
  onAddTask?: () => void;
}

export function MainContent({
  activeCategory,
  tasks,
  completedCount,
  onComplete,
  onReopen,
  onTomorrow,
  onHide,
  onAddTask,
}: MainContentProps) {
  const config = categoryTitles[activeCategory];
  const visibleTasks = tasks;
  const emptyText = activeCategory === "completed" ? "没有已完成事项" : "没有提醒事项";

  return (
    <main className="main-area">
      <header className="main-header">
        <h1 className={`main-header__title main-header__title--${config.color}`}>{config.title}</h1>
        <button type="button" className="main-header__add" onClick={onAddTask} aria-label="添加提醒">
          ＋
        </button>
      </header>

      <div className="main-meta">
        <span className="main-meta__count">
          {visibleTasks.length} 项{activeCategory === "completed" ? "完成" : "未完成"}
          {activeCategory !== "completed" && completedCount > 0 ? ` · ${completedCount} 项完成` : null}
        </span>
        <div className="main-meta__actions">
          {activeCategory !== "completed" ? (
            <button type="button">显示</button>
          ) : (
            <button type="button">清除</button>
          )}
        </div>
      </div>

      <div className="main-scroll">
        {activeCategory !== "completed" ? (
          <div className="add-task-row">
            <span className="add-task-row__circle" />
            <input type="text" placeholder="添加新任务…" aria-label="添加新任务" />
          </div>
        ) : null}

        {visibleTasks.length === 0 ? (
          <div className="empty-state">{emptyText}</div>
        ) : (
          <div className="task-list" role="list">
            {visibleTasks.map((task) => (
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
      </div>
    </main>
  );
}
