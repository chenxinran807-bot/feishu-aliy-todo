import type { ProactiveSuggestion } from "../domain/intentTypes";
import type { ComputedProgressTrack, SyncState, TaskViewModel } from "../domain/types";

interface CollapsedWidgetProps {
  overdueCount: number;
  todayCount: number;
  nextTask?: TaskViewModel;
  tracks: ComputedProgressTrack[];
  syncState: SyncState;
  syncMessage?: string;
  suggestions?: ProactiveSuggestion[];
  onExpand: () => void;
  onOpenFull: () => void;
  onAcceptSuggestion?: (suggestionId: string) => void;
  onDismissSuggestion?: (suggestionId: string) => void;
}

export function CollapsedWidget({
  overdueCount,
  todayCount,
  nextTask,
  tracks,
  syncState: _syncState,
  syncMessage: _syncMessage,
  suggestions = [],
  onExpand,
  onOpenFull,
  onAcceptSuggestion,
  onDismissSuggestion,
}: CollapsedWidgetProps) {
  const total = overdueCount + todayCount;
  const primarySuggestion = suggestions[0];
  const displayTitle = nextTask?.title ?? "没有待办";

  return (
    <main className="widget-shell" onDoubleClick={onOpenFull}>
      <button
        className="widget-main"
        type="button"
        onClick={onExpand}
        aria-label={`打开神仙待办，下一件事：${displayTitle}`}
      >
        <strong>{total}</strong>
        <small>{total} 件待办</small>
        <span className="widget-next-task">{displayTitle}</span>
      </button>
      {primarySuggestion ? (
        <div className="widget-nudge" aria-label="主动建议">
          <span>{primarySuggestion.body}</span>
          <button type="button" onClick={() => onAcceptSuggestion?.(primarySuggestion.id)}>
            {primarySuggestion.suggestedAction.label}
          </button>
          <button type="button" onClick={() => onDismissSuggestion?.(primarySuggestion.id)}>
            忽略
          </button>
        </div>
      ) : null}
    </main>
  );
}
