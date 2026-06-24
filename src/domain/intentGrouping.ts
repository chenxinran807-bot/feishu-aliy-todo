import type { IntentEvent, WorkSession } from "./intentTypes";

export interface GroupIntentEventsOptions {
  sessionWindowMinutes: number;
}

function minutesBetween(a: string, b: string): number {
  return Math.abs(new Date(b).getTime() - new Date(a).getTime()) / 60000;
}

function inferTopic(events: IntentEvent[]): string {
  const firstText = events.find((event) => event.textContext?.trim())?.textContext?.trim();
  return firstText ? firstText.slice(0, 48) : "Recent work session";
}

function unique(values: string[]): string[] {
  return Array.from(new Set(values));
}

function toSession(events: IntentEvent[], index: number): WorkSession {
  const first = events[0];
  const last = events[events.length - 1];

  return {
    id: `session-${first.id}-${index}`,
    eventIds: events.map((event) => event.id),
    inferredTopic: inferTopic(events),
    relatedTaskIds: unique(events.flatMap((event) => event.relatedTaskIds)),
    startedAt: first.createdAt,
    lastActivityAt: last.createdAt,
    confidence: events.length > 1 ? 0.72 : 0.52,
  };
}

export function groupIntentEvents(
  events: IntentEvent[],
  options: GroupIntentEventsOptions = { sessionWindowMinutes: 30 },
): WorkSession[] {
  const sortedEvents = [...events].sort((a, b) => a.createdAt.localeCompare(b.createdAt));
  const sessions: WorkSession[] = [];
  let current: IntentEvent[] = [];

  for (const event of sortedEvents) {
    const previous = current[current.length - 1];
    if (!previous || minutesBetween(previous.createdAt, event.createdAt) <= options.sessionWindowMinutes) {
      current.push(event);
      continue;
    }

    sessions.push(toSession(current, sessions.length));
    current = [event];
  }

  if (current.length > 0) {
    sessions.push(toSession(current, sessions.length));
  }

  return sessions;
}
