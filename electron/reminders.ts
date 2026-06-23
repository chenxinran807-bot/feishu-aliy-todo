import { Notification } from "electron";
import type { TaskViewModel } from "./types.js";

export function notifyDueTask(task: TaskViewModel): void {
  if (!Notification.isSupported()) return;

  const notification = new Notification({
    title: "Aime reminder",
    body: task.dueDate ? `${task.title} is due ${task.dueDate}` : task.title,
    silent: false,
  });

  notification.show();
}
