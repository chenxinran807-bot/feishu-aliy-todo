export type IntentTriggerType = "enter" | "task_action" | "window_focus" | "manual_capture";
export type IntentPrivacyLevel = "local_only" | "ai_allowed" | "redacted";

export interface IntentEvent {
  id: string;
  triggerType: IntentTriggerType;
  sourceApp?: string;
  sourceUrl?: string;
  textContext?: string;
  screenshotRef?: string;
  relatedTaskIds: string[];
  createdAt: string;
  privacyLevel: IntentPrivacyLevel;
}

export interface WorkSession {
  id: string;
  eventIds: string[];
  inferredTopic: string;
  relatedTaskIds: string[];
  startedAt: string;
  lastActivityAt: string;
  confidence: number;
}

export type SuggestionType = "create_task" | "update_task" | "next_step" | "draft_reply";
export type SuggestionState = "pending" | "accepted" | "dismissed" | "edited" | "expired";

export interface SuggestedAction {
  kind: "create_task" | "update_due_date" | "mark_done" | "copy_draft" | "none";
  label: string;
  payload?: Record<string, unknown>;
  requiresConfirmation: boolean;
  confirmed?: boolean;
}

export interface ProactiveSuggestion {
  id: string;
  type: SuggestionType;
  title: string;
  body: string;
  confidence: number;
  sourceEventIds: string[];
  relatedTaskIds: string[];
  suggestedAction: SuggestedAction;
  state: SuggestionState;
  createdAt: string;
  expiresAt: string;
}

export interface IntentSettings {
  intentCollectionEnabled: boolean;
  proactiveSuggestionsEnabled: boolean;
  enabledTriggers: IntentTriggerType[];
  suppressedSuggestionTypes: SuggestionType[];
  aiAnalysisEnabled: boolean;
}

export interface IntentFeedback {
  suggestionId: string;
  action: "accepted" | "dismissed" | "edited" | "never_suggest_type";
  suggestionType: SuggestionType;
  createdAt: string;
}

export interface IntentState {
  events: IntentEvent[];
  sessions: WorkSession[];
  suggestions: ProactiveSuggestion[];
  feedback: IntentFeedback[];
  settings: IntentSettings;
}

export interface CaptureIntentEventInput {
  triggerType: IntentTriggerType;
  sourceApp?: string;
  sourceUrl?: string;
  textContext?: string;
  relatedTaskIds?: string[];
  privacyLevel?: IntentPrivacyLevel;
}

export const defaultIntentSettings: IntentSettings = {
  intentCollectionEnabled: true,
  proactiveSuggestionsEnabled: true,
  enabledTriggers: ["enter", "task_action", "window_focus", "manual_capture"],
  suppressedSuggestionTypes: [],
  aiAnalysisEnabled: false,
};

export const emptyIntentState: IntentState = {
  events: [],
  sessions: [],
  suggestions: [],
  feedback: [],
  settings: defaultIntentSettings,
};

export function shouldSendToAi(input: { privacyLevel: IntentPrivacyLevel }): boolean {
  return input.privacyLevel === "ai_allowed";
}

export function isExternalActionAllowed(input: {
  requiresConfirmation: boolean;
  confirmed?: boolean;
}): boolean {
  return !input.requiresConfirmation || input.confirmed === true;
}
