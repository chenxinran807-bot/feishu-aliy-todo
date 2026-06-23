import type { ComputedProgressTrack, SyncState, TaskViewModel } from "../domain/types";
import { ProgressTrack } from "./ProgressTrack";
import { SyncBadge } from "./SyncBadge";

interface CollapsedWidgetProps {
  overdueCount: number;
  todayCount: number;
  nextTask?: TaskViewModel;
  tracks: ComputedProgressTrack[];
  syncState: SyncState;
  syncMessage?: string;
  onExpand: () => void;
  onOpenFull: () => void;
}

export function CollapsedWidget({
  overdueCount,
  todayCount,
  nextTask,
  tracks,
  syncState,
  syncMessage,
  onExpand,
  onOpenFull,
}: CollapsedWidgetProps) {
  return (
    <main className="widget-shell" onDoubleClick={onOpenFull}>
      <button className="widget-main" type="button" onClick={onExpand}>
        <span className="aime-orb">Ai</span>
        <span>
          <strong>
            {todayCount} today · {overdueCount} overdue
          </strong>
          <small>{nextTask?.title ?? "No urgent task"}</small>
        </span>
      </button>
      <div className="widget-tracks">
        {tracks.slice(0, 2).map((track) => (
          <ProgressTrack key={track.id} track={track} />
        ))}
      </div>
      <SyncBadge state={syncState} message={syncMessage} />
    </main>
  );
}
