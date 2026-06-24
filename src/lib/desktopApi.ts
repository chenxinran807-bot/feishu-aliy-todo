import { groupIntentEvents } from "../domain/intentGrouping";
import type {
  CaptureIntentEventInput,
  IntentFeedback,
  IntentSettings,
  IntentState,
  ProactiveSuggestion,
} from "../domain/intentTypes";
import { defaultIntentSettings, emptyIntentState } from "../domain/intentTypes";
import { expireSuggestions, generateSuggestions } from "../domain/suggestionRules";
import type { AppSnapshot, SyncedTask } from "../domain/types";
import { sampleSnapshot } from "../data/sampleData";

interface AimeDesktopApi {
  getSnapshot: () => Promise<AppSnapshot>;
  completeTask: (taskId: string) => Promise<AppSnapshot>;
  reopenTask: (taskId: string) => Promise<AppSnapshot>;
  rescheduleTask: (taskId: string, dueDate: string) => Promise<AppSnapshot>;
  hideTask: (taskId: string) => Promise<AppSnapshot>;
  syncNow: () => Promise<AppSnapshot>;
  openFullWindow: () => Promise<void>;
  setMiniMode: (miniMode: boolean) => Promise<void>;
  setWindowMode: (mode: "widget" | "peek" | "full") => Promise<void>;
}

interface AimeIntentApi {
  getState: () => Promise<IntentState>;
  captureEvent: (input: CaptureIntentEventInput) => Promise<void>;
  acceptSuggestion: (suggestionId: string) => Promise<void>;
  dismissSuggestion: (suggestionId: string) => Promise<void>;
  neverSuggestType: (suggestionId: string) => Promise<void>;
  updateSettings: (settings: Partial<IntentSettings>) => Promise<void>;
  clearHistory: () => Promise<void>;
}

declare global {
  interface Window {
    aimeDesktop?: AimeDesktopApi;
    aimeIntent?: AimeIntentApi;
    webkit?: {
      messageHandlers?: {
        aimeNative?: {
          postMessage: (message: Record<string, unknown>) => void;
        };
      };
    };
  }
}

const localStorageKey = "aime-desktop-task-companion.snapshot";
const intentStorageKey = "aime-desktop-task-companion.intent";

async function loadLocalSnapshot(): Promise<AppSnapshot> {
  const saved = readLocalSnapshot();
  if (saved) return saved;

  writeLocalSnapshot(sampleSnapshot);
  return sampleSnapshot;
}

async function saveLocalSnapshot(snapshot: AppSnapshot): Promise<AppSnapshot> {
  writeLocalSnapshot(snapshot);
  return snapshot;
}

function readLocalSnapshot(): AppSnapshot | undefined {
  try {
    const saved = window.localStorage.getItem(localStorageKey);
    return saved ? (JSON.parse(saved) as AppSnapshot) : undefined;
  } catch (error) {
    console.warn("Aime local storage is unavailable, using in-memory sample data.", error);
    return undefined;
  }
}

function writeLocalSnapshot(snapshot: AppSnapshot): void {
  try {
    window.localStorage.setItem(localStorageKey, JSON.stringify(snapshot));
  } catch (error) {
    console.warn("Aime local storage write failed; this session will be temporary.", error);
  }
}

function readLocalIntentState(): IntentState {
  try {
    const saved = window.localStorage.getItem(intentStorageKey);
    if (!saved) return emptyIntentState;
    const parsed = JSON.parse(saved) as Partial<IntentState>;

    return {
      events: parsed.events ?? [],
      sessions: parsed.sessions ?? [],
      suggestions: parsed.suggestions ?? [],
      feedback: parsed.feedback ?? [],
      settings: {
        ...defaultIntentSettings,
        ...parsed.settings,
      },
    };
  } catch (error) {
    console.warn("Aime intent state is unavailable, using an empty local state.", error);
    return emptyIntentState;
  }
}

function writeLocalIntentState(state: IntentState): void {
  try {
    window.localStorage.setItem(intentStorageKey, JSON.stringify(state));
  } catch (error) {
    console.warn("Aime intent state write failed; this session will be temporary.", error);
  }
}

function nowIso(): string {
  return new Date().toISOString();
}

function createId(prefix: string): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return `${prefix}-${crypto.randomUUID()}`;
  }

  return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function rebuildIntentState(state: IntentState): IntentState {
  const sessions = groupIntentEvents(state.events);
  const expiredSuggestions = expireSuggestions(state.suggestions, nowIso());
  const newSuggestions = generateSuggestions({
    events: state.events,
    sessions,
    existingSuggestions: expiredSuggestions,
    settings: state.settings,
    now: nowIso(),
  });

  return {
    ...state,
    sessions,
    suggestions: [...expiredSuggestions, ...newSuggestions],
  };
}

function updateSuggestionState(
  suggestions: ProactiveSuggestion[],
  suggestionId: string,
  state: ProactiveSuggestion["state"],
): ProactiveSuggestion[] {
  return suggestions.map((suggestion) =>
    suggestion.id === suggestionId ? { ...suggestion, state } : suggestion,
  );
}

function appendFeedback(
  state: IntentState,
  suggestion: ProactiveSuggestion,
  action: IntentFeedback["action"],
): IntentState {
  return {
    ...state,
    feedback: [
      ...state.feedback,
      {
        suggestionId: suggestion.id,
        action,
        suggestionType: suggestion.type,
        createdAt: nowIso(),
      },
    ],
  };
}

async function createTaskFromSuggestion(suggestion: ProactiveSuggestion): Promise<void> {
  if (suggestion.suggestedAction.kind !== "create_task") return;

  const title =
    typeof suggestion.suggestedAction.payload?.title === "string"
      ? suggestion.suggestedAction.payload.title
      : suggestion.body;
  const snapshot = await loadLocalSnapshot();
  const createdAt = nowIso();
  const task: SyncedTask = {
    id: createId("task"),
    larkRecordId: createId("local"),
    title,
    sourceType: "manual",
    status: "open",
    createdAt,
    updatedAt: createdAt,
    project: "Intent Layer",
  };

  await saveLocalSnapshot({
    ...snapshot,
    tasks: [task, ...snapshot.tasks],
    localMeta: [
      {
        taskId: task.id,
        pinned: false,
        hidden: false,
        displayPriority: 1,
      },
      ...snapshot.localMeta,
    ],
  });
}

function postNative(message: Record<string, unknown>): void {
  window.webkit?.messageHandlers?.aimeNative?.postMessage(message);
}

const webViewApi: AimeDesktopApi = {
  getSnapshot: loadLocalSnapshot,
  completeTask: async (taskId) => {
    const snapshot = await loadLocalSnapshot();
    return saveLocalSnapshot({
      ...snapshot,
      tasks: snapshot.tasks.map((task) =>
        task.id === taskId ? { ...task, status: "done", updatedAt: new Date().toISOString() } : task,
      ),
    });
  },
  reopenTask: async (taskId) => {
    const snapshot = await loadLocalSnapshot();
    return saveLocalSnapshot({
      ...snapshot,
      tasks: snapshot.tasks.map((task) =>
        task.id === taskId ? { ...task, status: "open", updatedAt: new Date().toISOString() } : task,
      ),
    });
  },
  rescheduleTask: async (taskId, dueDate) => {
    const snapshot = await loadLocalSnapshot();
    return saveLocalSnapshot({
      ...snapshot,
      tasks: snapshot.tasks.map((task) =>
        task.id === taskId ? { ...task, dueDate, updatedAt: new Date().toISOString() } : task,
      ),
    });
  },
  hideTask: async (taskId) => {
    const snapshot = await loadLocalSnapshot();
    const hasMeta = snapshot.localMeta.some((meta) => meta.taskId === taskId);
    const localMeta = hasMeta
      ? snapshot.localMeta.map((meta) => (meta.taskId === taskId ? { ...meta, hidden: true } : meta))
      : [
          ...snapshot.localMeta,
          { taskId, pinned: false, hidden: true, displayPriority: 0 },
        ];
    return saveLocalSnapshot({ ...snapshot, localMeta });
  },
  syncNow: async () => {
    const snapshot = await loadLocalSnapshot();
    return saveLocalSnapshot({
      ...snapshot,
      syncState: "stale",
      syncMessage: "Using local sample data until Lark credentials and field mapping are configured.",
    });
  },
  openFullWindow: async () => {
    postNative({ command: "openFullWindow" });
  },
  setMiniMode: async (miniMode) => {
    postNative({ command: "setWindowMode", mode: miniMode ? "widget" : "peek" });
  },
  setWindowMode: async (mode) => {
    postNative({ command: "setWindowMode", mode });
  },
};

export const desktopApi: AimeDesktopApi = window.aimeDesktop ?? webViewApi;

const webIntentApi: AimeIntentApi = {
  getState: async () => {
    const state = rebuildIntentState(readLocalIntentState());
    writeLocalIntentState(state);
    return state;
  },
  captureEvent: async (input) => {
    const state = readLocalIntentState();
    if (!state.settings.intentCollectionEnabled || !state.settings.enabledTriggers.includes(input.triggerType)) {
      return;
    }

    writeLocalIntentState(
      rebuildIntentState({
        ...state,
        events: [
          ...state.events,
          {
            id: createId("evt"),
            triggerType: input.triggerType,
            sourceApp: input.sourceApp,
            sourceUrl: input.sourceUrl,
            textContext: input.textContext,
            relatedTaskIds: input.relatedTaskIds ?? [],
            createdAt: nowIso(),
            privacyLevel: input.privacyLevel ?? "local_only",
          },
        ],
      }),
    );
  },
  acceptSuggestion: async (suggestionId) => {
    let state = readLocalIntentState();
    const suggestion = state.suggestions.find((item) => item.id === suggestionId);
    if (!suggestion) return;

    await createTaskFromSuggestion(suggestion);
    state = appendFeedback(
      {
        ...state,
        suggestions: updateSuggestionState(state.suggestions, suggestionId, "accepted"),
      },
      suggestion,
      "accepted",
    );
    writeLocalIntentState(rebuildIntentState(state));
  },
  dismissSuggestion: async (suggestionId) => {
    let state = readLocalIntentState();
    const suggestion = state.suggestions.find((item) => item.id === suggestionId);
    if (!suggestion) return;

    state = appendFeedback(
      {
        ...state,
        suggestions: updateSuggestionState(state.suggestions, suggestionId, "dismissed"),
      },
      suggestion,
      "dismissed",
    );
    writeLocalIntentState(rebuildIntentState(state));
  },
  neverSuggestType: async (suggestionId) => {
    let state = readLocalIntentState();
    const suggestion = state.suggestions.find((item) => item.id === suggestionId);
    if (!suggestion) return;

    state = appendFeedback(
      {
        ...state,
        suggestions: updateSuggestionState(state.suggestions, suggestionId, "dismissed"),
        settings: {
          ...state.settings,
          suppressedSuggestionTypes: Array.from(
            new Set([...state.settings.suppressedSuggestionTypes, suggestion.type]),
          ),
        },
      },
      suggestion,
      "never_suggest_type",
    );
    writeLocalIntentState(rebuildIntentState(state));
  },
  updateSettings: async (settings) => {
    const state = readLocalIntentState();
    writeLocalIntentState(
      rebuildIntentState({
        ...state,
        settings: {
          ...state.settings,
          ...settings,
        },
      }),
    );
  },
  clearHistory: async () => {
    const state = readLocalIntentState();
    writeLocalIntentState({
      ...emptyIntentState,
      settings: state.settings,
    });
  },
};

export const intentApi: AimeIntentApi = window.aimeIntent ?? webIntentApi;
