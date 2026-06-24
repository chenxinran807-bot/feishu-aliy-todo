import type { IntentSettings } from "../domain/intentTypes";

interface SuggestionSettingsProps {
  settings: IntentSettings;
  eventCount: number;
  suggestionCount: number;
  onUpdateSettings: (settings: Partial<IntentSettings>) => void;
  onClearHistory: () => void;
}

export function SuggestionSettings({
  settings,
  eventCount,
  suggestionCount,
  onUpdateSettings,
  onClearHistory,
}: SuggestionSettingsProps) {
  return (
    <section className="intent-settings" aria-label="意图层设置">
      <div>
        <p className="section-label">Intent Layer</p>
        <h2>意图感知与主动建议</h2>
      </div>
      <label>
        <input
          type="checkbox"
          checked={settings.intentCollectionEnabled}
          onChange={(event) => onUpdateSettings({ intentCollectionEnabled: event.currentTarget.checked })}
        />
        意图捕捉
      </label>
      <label>
        <input
          type="checkbox"
          checked={settings.proactiveSuggestionsEnabled}
          onChange={(event) => onUpdateSettings({ proactiveSuggestionsEnabled: event.currentTarget.checked })}
        />
        主动建议
      </label>
      <label>
        <input
          type="checkbox"
          checked={settings.aiAnalysisEnabled}
          onChange={(event) => onUpdateSettings({ aiAnalysisEnabled: event.currentTarget.checked })}
        />
        AI 分析
      </label>
      <p>
        本地历史：{eventCount} 条意图事件，{suggestionCount} 条建议。
      </p>
      <button type="button" onClick={onClearHistory}>
        清空本地意图历史
      </button>
    </section>
  );
}
