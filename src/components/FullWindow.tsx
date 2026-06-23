import type { AppSnapshot, ComputedProgressTrack } from "../domain/types";
import { ProgressTrack } from "./ProgressTrack";

export function FullWindow({
  snapshot,
  tracks,
}: {
  snapshot: AppSnapshot;
  tracks: ComputedProgressTrack[];
}) {
  return (
    <main className="full-window">
      <header>
        <div>
          <p>Aime Desktop Task Companion</p>
          <h1>Management</h1>
        </div>
      </header>
      <section className="full-grid">
        <article>
          <h2>Lark Base</h2>
          <p>{snapshot.settings.larkBaseUrl ?? "No Base configured"}</p>
          <p>{snapshot.syncMessage ?? "Ready"}</p>
        </article>
        <article>
          <h2>Long-term tracks</h2>
          {tracks.map((track) => (
            <ProgressTrack key={track.id} track={track} />
          ))}
        </article>
        <article>
          <h2>Local tasks</h2>
          <p>{snapshot.tasks.length} mirrored tasks</p>
          <p>{snapshot.localMeta.filter((meta) => meta.hidden).length} hidden</p>
        </article>
      </section>
    </main>
  );
}
