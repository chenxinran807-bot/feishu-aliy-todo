import type { SyncState } from "../domain/types";

export function SyncBadge({ state, message }: { state: SyncState; message?: string }) {
  return (
    <div className={`sync-badge sync-badge--${state}`} title={message}>
      {state === "idle"
        ? "Synced"
        : state === "syncing"
          ? "Syncing"
          : state === "stale"
            ? "Local"
            : "Sync issue"}
    </div>
  );
}
