import type { ComputedProgressTrack } from "../domain/types";

export function ProgressTrack({ track }: { track: ComputedProgressTrack }) {
  const modeLabel =
    track.mode === "manual"
      ? "manual override"
      : `auto from ${track.completedTasks}/${track.totalTasks} tasks`;

  return (
    <section className="progress-track">
      <div className="progress-track__header">
        <span>{track.name}</span>
        <strong>{track.displayPercent}%</strong>
      </div>
      <div className="progress-track__bar" aria-label={`${track.name} progress`}>
        <span style={{ width: `${track.displayPercent}%` }} />
      </div>
      <p>{modeLabel}</p>
    </section>
  );
}
