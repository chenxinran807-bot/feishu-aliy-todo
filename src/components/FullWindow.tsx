import type { CaptureIntentEventInput, IntentSettings } from "../domain/intentTypes";
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

  return (
    <main className="full-window">
      <header className="peek-hero full-hero">
        <DogPortrait size="hero" />
        <div className="peek-title">
          <p>Aime 小狗</p>
          <h1>下一件最重要的事</h1>
        </div>
        <div className="context-pill">拖到飞书窗口：嗅探当前上下文</div>
      </header>

      <section className="focus-card full-focus">
        <p className="section-label">下一件最重要的事</p>
        <h2>{primaryTask?.title ?? "现在没有紧急任务"}</h2>
        <p className="focus-meta">
          {primaryTask?.project ?? "AI探索"} · 今天 18:00 · 完成后遛狗 +1
        </p>
        <div className="stats-grid">
          <div>
            <strong>{Math.max(1, openTasks.length)}</strong>
            <span>P0</span>
          </div>
          <div>
            <strong>2</strong>
            <span>逾期</span>
          </div>
          <div>
            <strong>3</strong>
            <span>待领取狗粮</span>
          </div>
        </div>
        <div className="reward-callout">{rewardName}：完成一件后，小狗出门散步中。</div>
      </section>

      <section className="full-grid">
        {openTasks.slice(0, 3).map((task, index) => (
          <article key={task.id}>
            <span className="task-row__check" aria-hidden="true" />
            <div>
              <h2>{index === 0 ? "AI 试穿 - 迭代评测方案" : task.title}</h2>
              <p>{index === 0 ? "完成" : "改时间"}</p>
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
