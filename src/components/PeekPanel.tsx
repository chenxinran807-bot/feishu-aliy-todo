import type { ComputedProgressTrack, TaskViewModel } from "../domain/types";
import { ProgressTrack } from "./ProgressTrack";
import { TaskRow } from "./TaskRow";

interface PeekPanelProps {
  overdueTasks: TaskViewModel[];
  todayTasks: TaskViewModel[];
  laterTasks: TaskViewModel[];
  tracks: ComputedProgressTrack[];
  onCollapse: () => void;
  onComplete: (taskId: string) => void;
  onTomorrow: (taskId: string) => void;
  onHide: (taskId: string) => void;
  onOpenFull: () => void;
}

export function PeekPanel({
  overdueTasks,
  todayTasks,
  laterTasks,
  tracks,
  onCollapse,
  onComplete,
  onTomorrow,
  onHide,
  onOpenFull,
}: PeekPanelProps) {
  return (
    <main className="peek-panel">
      <header>
        <div>
          <p>Aime</p>
          <h1>Today</h1>
        </div>
        <div className="header-actions">
          <button type="button" onClick={onCollapse}>
            Collapse
          </button>
          <button type="button" onClick={onOpenFull}>
            Open
          </button>
        </div>
      </header>
      <section>
        <h2>Overdue</h2>
        {overdueTasks.length === 0 ? (
          <p className="empty">Nothing overdue.</p>
        ) : (
          overdueTasks.map((task) => (
            <TaskRow
              key={task.id}
              task={task}
              onComplete={onComplete}
              onTomorrow={onTomorrow}
              onHide={onHide}
            />
          ))
        )}
      </section>
      <section>
        <h2>Today</h2>
        {todayTasks.length === 0 ? (
          <p className="empty">Today is clear.</p>
        ) : (
          todayTasks.map((task) => (
            <TaskRow
              key={task.id}
              task={task}
              onComplete={onComplete}
              onTomorrow={onTomorrow}
              onHide={onHide}
            />
          ))
        )}
      </section>
      <section>
        <h2>Long-term</h2>
        {tracks.slice(0, 3).map((track) => (
          <ProgressTrack key={track.id} track={track} />
        ))}
      </section>
      <section>
        <h2>Later this week</h2>
        {laterTasks.slice(0, 3).map((task) => (
          <TaskRow
            key={task.id}
            task={task}
            onComplete={onComplete}
            onTomorrow={onTomorrow}
            onHide={onHide}
          />
        ))}
      </section>
    </main>
  );
}
