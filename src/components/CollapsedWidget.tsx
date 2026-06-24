import type { ProactiveSuggestion } from "../domain/intentTypes";
import type { ComputedProgressTrack, SyncState, TaskViewModel } from "../domain/types";
import { DogPortrait } from "./DogPortrait";

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
  const foodCount = Math.max(1, overdueCount + todayCount);
  const p0Count = nextTask?.title.includes("P0") ? 1 : Math.max(1, Math.min(3, todayCount));
  const rewardLabel = tracks[0]?.name ?? "遛狗 +1";
  const primarySuggestion = suggestions[0];

  return (
    <main className="widget-shell" onDoubleClick={onOpenFull}>
      <button
        className="widget-main"
        type="button"
        onClick={onExpand}
        aria-label={`打开 Aime 小狗，下一件事：${nextTask?.title ?? "没有紧急任务"}`}
      >
        <DogPortrait size="compact" />
        <strong>P0・{p0Count}</strong>
        <small>{foodCount} 粒待领取狗粮</small>
        <span className="compact-reward">{rewardLabel}</span>
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
