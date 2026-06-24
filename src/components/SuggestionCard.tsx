import type { ProactiveSuggestion } from "../domain/intentTypes";

interface SuggestionCardProps {
  suggestion: ProactiveSuggestion;
  onAccept: (suggestionId: string) => void;
  onDismiss: (suggestionId: string) => void;
  onNeverSuggest: (suggestionId: string) => void;
}

export function SuggestionCard({
  suggestion,
  onAccept,
  onDismiss,
  onNeverSuggest,
}: SuggestionCardProps) {
  return (
    <article className="suggestion-card" aria-label="主动建议">
      <div className="suggestion-card__content">
        <strong>{suggestion.title}</strong>
        <p>{suggestion.body}</p>
      </div>
      <div className="suggestion-card__actions">
        <button type="button" onClick={() => onAccept(suggestion.id)}>
          {suggestion.suggestedAction.label}
        </button>
        <button type="button" onClick={() => onDismiss(suggestion.id)}>
          忽略
        </button>
        <button type="button" onClick={() => onNeverSuggest(suggestion.id)}>
          不再建议这类
        </button>
      </div>
    </article>
  );
}
