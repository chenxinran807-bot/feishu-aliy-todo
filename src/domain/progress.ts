import type { ComputedProgressTrack, ProgressTrack, SyncedTask } from "./types";

export function computeTracks(
  tracks: ProgressTrack[],
  tasks: SyncedTask[],
): ComputedProgressTrack[] {
  const tasksById = new Map(tasks.map((task) => [task.id, task]));

  return tracks.map((track) => {
    const linkedTasks = track.linkedTaskIds
      .map((taskId) => tasksById.get(taskId))
      .filter((task): task is SyncedTask => Boolean(task));
    const totalTasks = linkedTasks.length;
    const completedTasks = linkedTasks.filter((task) => task.status === "done").length;
    const autoPercent =
      totalTasks === 0 ? 0 : Math.round((completedTasks / totalTasks) * 100);
    const displayPercent =
      track.mode === "manual" ? clampPercent(track.manualPercent ?? autoPercent) : autoPercent;

    return {
      ...track,
      autoPercent,
      displayPercent,
      completedTasks,
      totalTasks,
    };
  });
}

function clampPercent(value: number): number {
  return Math.max(0, Math.min(100, Math.round(value)));
}
