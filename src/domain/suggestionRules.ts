import type {
  IntentEvent,
  IntentSettings,
  ProactiveSuggestion,
  WorkSession,
} from "./intentTypes";

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
  const { sessions, existingSuggestions, settings, now } = input;

  if (!settings.intentCollectionEnabled || !settings.proactiveSuggestionsEnabled) {
    return [];
  }

  const suggestions: ProactiveSuggestion[] = [];

  for (const session of sessions) {
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
