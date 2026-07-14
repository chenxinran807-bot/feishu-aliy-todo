import type {
  IntentEvent,
  IntentSettings,
  ProactiveSuggestion,
  WorkSession,
} from "./intentTypes";
import { extractTaskDraftsFromMaterial } from "./taskIntake";

export interface GenerateSuggestionsInput {
  events: IntentEvent[];
  sessions: WorkSession[];
  existingSuggestions: ProactiveSuggestion[];
  settings: IntentSettings;
  now: string;
}

function addHours(timestamp: string, hours: number): string {
  return new Date(new Date(timestamp).getTime() + hours * 60 * 60 * 1000).toISOString();
}

function hasExistingSuggestion(existingSuggestions: ProactiveSuggestion[], session: WorkSession): boolean {
  return existingSuggestions.some((suggestion) =>
    suggestion.sourceEventIds.some((eventId) => session.eventIds.includes(eventId)),
  );
}

function isTypeAllowed(settings: IntentSettings, type: ProactiveSuggestion["type"]): boolean {
  return !settings.suppressedSuggestionTypes.includes(type);
}

export function generateSuggestions(input: GenerateSuggestionsInput): ProactiveSuggestion[] {
  const { events, sessions, existingSuggestions, settings, now } = input;

  if (!settings.intentCollectionEnabled || !settings.proactiveSuggestionsEnabled) {
    return [];
  }

  const suggestions: ProactiveSuggestion[] = [];
  const eventsById = new Map(events.map((event) => [event.id, event]));

  if (isTypeAllowed(settings, "create_task")) {
    for (const event of events) {
      const textContext = event.textContext ?? "";
      if (event.relatedTaskIds.length > 0 || !isMaterialTaskIntake(textContext)) {
        continue;
      }

      const drafts = extractTaskDraftsFromMaterial(textContext);
      drafts.forEach((draft, index) => {
        const id = `suggestion-${event.id}-${index}`;
        if (existingSuggestions.some((suggestion) => suggestion.id === id)) return;

        suggestions.push({
          id,
          type: "create_task",
          title: "确认飞书机器人提炼的任务",
          body: draft.title,
          confidence: 0.78,
          sourceEventIds: [event.id],
          relatedTaskIds: [],
          suggestedAction: {
            kind: "create_task",
            label: "加入待办",
            payload: {
              title: draft.title,
              sourceType: draft.sourceType,
            },
            requiresConfirmation: true,
            confirmed: false,
          },
          state: "pending",
          createdAt: now,
          expiresAt: addHours(now, 2),
        });
      });
    }
  }

  for (const session of sessions) {
    if (session.eventIds.some((eventId) => isMaterialTaskIntake(eventsById.get(eventId)?.textContext ?? ""))) {
      continue;
    }

    if (session.relatedTaskIds.length > 0 || hasExistingSuggestion(existingSuggestions, session)) {
      continue;
    }

    if (!isTypeAllowed(settings, "create_task")) {
      continue;
    }

    suggestions.push({
      id: `suggestion-${session.id}`,
      type: "create_task",
      title: "把这个意图沉淀成任务",
      body: session.inferredTopic,
      confidence: session.confidence,
      sourceEventIds: session.eventIds,
      relatedTaskIds: [],
      suggestedAction: {
        kind: "create_task",
        label: "创建任务",
        payload: {
          title: session.inferredTopic,
        },
        requiresConfirmation: true,
        confirmed: false,
      },
      state: "pending",
      createdAt: now,
      expiresAt: addHours(now, 2),
    });
  }

  return suggestions;
}

function isMaterialTaskIntake(textContext: string): boolean {
  return /会议纪要|聊天记录|帮我新增任务|新增任务|创建任务/.test(textContext);
}

export function expireSuggestions(suggestions: ProactiveSuggestion[], now: string): ProactiveSuggestion[] {
  const nowTime = new Date(now).getTime();

  return suggestions.map((suggestion) => {
    if (suggestion.state !== "pending") {
      return suggestion;
    }

    if (new Date(suggestion.expiresAt).getTime() > nowTime) {
      return suggestion;
    }

    return {
      ...suggestion,
      state: "expired",
    };
  });
}
