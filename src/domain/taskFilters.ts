import type { TaskViewModel } from "./types";

export function getVisibleOpenTasks(tasks: TaskViewModel[]): TaskViewModel[] {
  return tasks
    .filter((task) => task.status !== "done")
    .filter((task) => !task.meta.hidden)
    .sort((a, b) => b.meta.displayPriority - a.meta.displayPriority);
}

export function getOverdueTasks(tasks: TaskViewModel[], now: Date): TaskViewModel[] {
  const today = toDateKey(now);
  return getVisibleOpenTasks(tasks).filter((task) => task.dueDate && task.dueDate < today);
}

export function getTodayTasks(tasks: TaskViewModel[], now: Date): TaskViewModel[] {
  const today = toDateKey(now);
  return getVisibleOpenTasks(tasks).filter((task) => task.dueDate === today);
}

export function getLaterThisWeekTasks(tasks: TaskViewModel[], now: Date): TaskViewModel[] {
  const today = toDateKey(now);
  const end = new Date(now);
  end.setDate(now.getDate() + 6);
  const weekEnd = toDateKey(end);

  return getVisibleOpenTasks(tasks).filter(
    (task) => task.dueDate && task.dueDate > today && task.dueDate <= weekEnd,
  );
}

export function toDateKey(date: Date): string {
  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, "0");
  const day = `${date.getDate()}`.padStart(2, "0");
  return `${year}-${month}-${day}`;
}
