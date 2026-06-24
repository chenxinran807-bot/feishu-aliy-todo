import type { CaptureIntentEventInput, IntentSettings } from "../domain/intentTypes";
import { toDateKey } from "../domain/taskFilters";
import type { AppSnapshot, ComputedProgressTrack } from "../domain/types";
import { DogPortrait } from "./DogPortrait";
import { ManualCaptureForm } from "./ManualCaptureForm";
import { SuggestionSettings } from "./SuggestionSettings";

export function FullWindow({
  snapshot,
  tracks,
  intentSettings,
  intentEventCount = 0,
  intentSuggestionCount = 0,
  onCaptureIntent,
  onUpdateIntentSettings,
  onClearIntentHistory,
}: {
  snapshot: AppSnapshot;
  tracks: ComputedProgressTrack[];
  intentSettings?: IntentSettings;
  intentEventCount?: number;
  intentSuggestionCount?: number;
  onCaptureIntent?: (input: CaptureIntentEventInput) => void;
  onUpdateIntentSettings?: (settings: Partial<IntentSettings>) => void;
  onClearIntentHistory?: () => void;
}) {
  const openTasks = snapshot.tasks.filter((task) => task.status === "open");
  const primaryTask = openTasks[0];
  const rewardName = tracks[0]?.name ?? "遛狗 +1";
  const today = toDateKey(new Date());
  const p0Count = openTasks.filter((task) => task.title.includes("P0") || task.title.includes("p0"))
    .length;
  const overdueCount = openTasks.filter((task) => task.dueDate && task.dueDate < today).length;
  const foodCount = openTasks.length;

  return (
    <main className="full-window">
      <header className="peek-hero full-hero">
        <DogPortrait size="hero" />
        <div className="peek-title">
          <p>Aime 小狗</p>
          <h1>下一件最重要的事</h1>
        </div>
        <div className="context-pill">手动捕捉当前意图</div>
      </header>

      <section className="focus-card full-focus">
        <p className="section-label">下一件最重要的事</p>
        <h2>{primaryTask?.title ?? "现在没有紧急任务"}</h2>
        <p className="focus-meta">
          {primaryTask?.project ?? "AI探索"} · 今天 18:00 · 完成后遛狗 +1
        </p>
        <div className="stats-grid">
          {p0Count > 0 ? (
            <div className="stats-card">
              <strong>{p0Count}</strong>
              <span>P0</span>
            </div>
          ) : null}
          {overdueCount > 0 ? (
            <div className="stats-card">
              <strong>{overdueCount}</strong>
              <span>逾期</span>
            </div>
          ) : null}
          {foodCount > 0 ? (
            <div className="stats-card">
              <strong>{foodCount}</strong>
              <span>待领取狗粮</span>
            </div>
          ) : null}
        </div>
        <div className="reward-callout">{rewardName}：完成一件后，小狗出门散步中。</div>
      </section>

      <section className="full-grid">
        {openTasks.slice(0, 3).map((task, index) => (
          <article key={task.id}>
            <span className="task-row__check" aria-hidden="true" />
            <div>
              <h2>{index === 0 ? "AI 试穿 - 迭代评测方案" : task.title}</h2>
              <p>{task.project ?? "AI探索"}</p>
            </div>
          </article>
        ))}
      </section>

      {onCaptureIntent ? (
        <section className="full-grid intent-grid">
          <ManualCaptureForm onCapture={onCaptureIntent} />
          {intentSettings && onUpdateIntentSettings && onClearIntentHistory ? (
            <SuggestionSettings
              settings={intentSettings}
              eventCount={intentEventCount}
              suggestionCount={intentSuggestionCount}
              onUpdateSettings={onUpdateIntentSettings}
              onClearHistory={onClearIntentHistory}
            />
          ) : null}
        </section>
      ) : null}
    </main>
  );
}
