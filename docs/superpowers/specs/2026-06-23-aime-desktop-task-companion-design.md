# Aime Desktop Task Companion Design

Date: 2026-06-23

## Summary

Aime Desktop Task Companion is a Mac-first, always-visible desktop widget for monitoring personal todo status without opening Lark Base or the Aime Lark chat.

The first version is not a full task manager. It is a quiet companion layer on top of the existing Aime workflow:

- Lark Base remains the task source of record.
- The desktop companion shows what needs attention now.
- The companion writes only completion status and due-date changes back to Lark Base.
- Local desktop-only fields handle reminders, pinning, hiding, and progress overrides.

## Product Shape

The primary form is a long-lived desktop widget, inspired more by desktop pets and floating widgets than by normal productivity dashboards.

Reference patterns:

- `clawd-on-desk`: desktop companion with draggable always-on-top presence, mini mode, position memory, tray controls, click-through behavior, and auto-update.
- `vibebud`: floating AI companion model.
- `Shijima-Qt`: cross-platform desktop pet runner, useful as proof that desktop companion behavior is a mature interaction pattern.

Aime should borrow the interaction model, not the entertainment-heavy personality. It should feel calm, useful, and present.

## User Goals

1. See today's todo status without opening Lark Base.
2. Keep long-term work visible through progress bars.
3. Finish, snooze, or reschedule small tasks quickly.
4. Preserve Aime's existing Lark ingestion workflow.
5. Keep the design deployable for other people later through a skill or setup pack.

## MVP Scope

### In Scope

- Mac-first desktop app.
- Always-visible floating widget.
- Draggable widget with remembered position.
- Edge mini mode for long-running display.
- Peek panel for today's and overdue tasks.
- Full management window for setup, search, sync logs, and long-term track management.
- Lark Base sync for task import.
- Write-back to Lark Base for completion status and due date.
- Local store for desktop-only metadata.
- Long-term task progress bars.
- Progress computed from child tasks by default, with manual override.
- Local reminders and native macOS notifications.
- System tray/menu bar controls.

### Out of Scope for MVP

- Windows support.
- Replacing Lark Base as the source of record.
- Full project management features such as dependencies, team assignment, and reports.
- Writing all desktop-only settings back into Lark Base.
- Complex AI task rewriting or prioritization beyond what existing Aime already provides.

## Interaction Model

### Layer 1: Collapsed Widget

The collapsed widget is the default state and should be safe to keep visible for hours.

It shows:

- Today task count.
- Overdue count.
- Next important task.
- One or two pinned long-term progress bars.
- Sync state if there is an error or stale data.

Expected behavior:

- Drag to move.
- Remember position across restarts.
- Drag to screen edge or choose menu item to enter mini mode.
- Hover or click to open the peek panel.
- Right-click for menu actions.

### Layer 2: Peek Panel

The peek panel is a small floating panel opened from the widget.

It shows:

- Overdue tasks.
- Today tasks.
- Later-this-week preview.
- Quick actions: complete, snooze, reschedule, pin, hide.
- Long-term track cards when relevant.

It should stay lightweight. Users should not feel like they opened a full app.

### Layer 3: Full Management Window

The full window is secondary and used only for heavier work:

- First-run setup.
- Lark Base configuration.
- Field mapping.
- Search and bulk edit.
- Long-term track management.
- Reminder defaults.
- Sync logs and error recovery.
- Future skill/deployment export guidance.

## Data Model

### Synced Task Fields

These come from Lark Base:

- Base record ID.
- Title.
- Source type, such as group chat, meeting note, or private chat.
- Source URL or reference.
- Status.
- Due date.
- Created time.
- Updated time.
- Owner if available.
- Project or category if available.

### Local Task Metadata

These stay local:

- Pinned state.
- Hidden state.
- Snooze-until timestamp.
- Reminder preferences.
- Display priority.
- Last-seen timestamp.
- Local notes if needed.

### Long-term Track Fields

Long-term tracks are local-first objects that can reference multiple synced tasks.

Fields:

- Track ID.
- Name.
- Linked task record IDs.
- Auto progress percentage.
- Manual override percentage.
- Progress mode: auto or manual.
- Target date.
- Pinned state.
- Last updated timestamp.

Progress calculation:

- Auto mode: completed linked tasks divided by all linked tasks.
- Manual mode: user-set percentage overrides auto progress.
- UI must show the mode so users know whether a progress bar is computed or manually controlled.

## Sync Design

### Source of Record

Lark Base is the source of record for task facts. The desktop app keeps a local mirror for speed and offline display.

### Pull

The app pulls from Lark Base:

- On app launch.
- On a short background interval.
- On manual refresh.
- After write-back actions.

### Write-back

The app writes back only:

- Completion status.
- Due date.

All other desktop workflow state remains local.

### Conflict Handling

If the same field changes locally and remotely:

- Prefer the newest remote value for fields owned by Lark Base.
- Keep local-only fields untouched.
- If write-back fails, mark the task as pending sync and retry.
- Show a small sync warning in the widget only when user action is needed.

## Reminders

Reminders are local and use macOS notifications.

MVP reminder types:

- Due soon.
- Due today.
- Overdue.
- Snoozed task returns.

Notification actions:

- Complete.
- Snooze.
- Open peek panel.
- Reschedule to tomorrow.

## Technical Direction

Recommended stack:

- Tauri or Electron for desktop shell.
- React or similar web UI for widget, peek panel, and full window.
- Local SQLite store.
- Lark OpenAPI/Base connector.
- macOS notifications.
- System tray/menu bar integration.
- Auto-update path planned from the start.

Tauri is attractive for a lightweight widget, but Electron may be faster if borrowing patterns from existing desktop companion projects matters more than binary size. The implementation plan should decide after checking Lark SDK needs, window transparency requirements, click-through support, and auto-update packaging.

## First-run Setup

First-run flow:

1. Connect Lark credentials.
2. Enter or select Lark Base URL.
3. Map required fields.
4. Run a sync test.
5. Choose widget location and default reminder behavior.
6. Select which long-term tracks should be pinned.

The later deployable skill should guide another user through the same flow.

## Skill/deployment Path

The future reusable package should contain:

- Skill instructions for setting up Aime Desktop Task Companion.
- Lark app permission checklist.
- Base field mapping reference.
- Local environment setup script.
- Packaging or release instructions.
- Troubleshooting steps for auth, sync, and notification permission issues.

The skill should not require users to understand the internals. It should lead them from "I have an Aime-style Lark Base" to "I have a desktop widget running on my Mac."

## Open Questions for Implementation Planning

1. Which exact fields exist in the current Lark Base table?
2. Does the current Aime assistant already write stable task IDs and source URLs?
3. Which Lark auth mode should be used for personal deployment?
4. Should the widget use a character/avatar visual, or stay as an abstract status chip?
5. Should long-term tracks be inferred from Base fields or created only in the desktop app?

## Acceptance Criteria

- The app can run on the user's Mac as a long-lived floating widget.
- The widget shows today count, overdue count, next task, and pinned progress bars.
- The peek panel supports completing and rescheduling tasks.
- Completion status and due date write back to Lark Base.
- Local reminders work without changing Lark Base schema.
- Long-term tracks support auto progress and manual override.
- Position and mini mode persist across app restarts.
- A sync failure is visible but not noisy.
- The design can later be converted into a reusable setup skill.

