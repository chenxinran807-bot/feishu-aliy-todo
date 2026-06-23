# Aime Pet Todo Companion Design

## Goal

Upgrade the current Aime desktop task companion into a pet-style todo manager while keeping task capture, reminders, and completion as the primary product value.

The pet is an interaction layer, not the core workflow. Its job is to make automated todo capture and follow-through feel lighter, more visible, and more emotionally rewarding.

## Product Boundary

The MVP remains a Mac desktop companion for Aime-generated todos:

- Pull tasks from the existing Aime Lark Base.
- Let users see the next important task without opening Lark.
- Support completion, ignore/archive, due-date edits, manual creation, filters, and shortcuts.
- Keep completion and due-date changes written back to Lark Base.
- Keep local-only preferences such as pinning, hiding, priority, style, and panel size on this Mac.

The pet layer adds:

- A small dog den presentation for the collapsed and expanded widget.
- A "pending kibble" metaphor for newly captured tasks.
- A completion-only reward loop: completed tasks feed the dog.
- A short "walk the dog" feedback state after completion.
- Gentle overdue and P0 reminders through dog posture/copy.
- A drag-to-Lark "sniff current context" trigger that uses screen recognition first.

The MVP does not include shops, outfits, complex levels, streak pressure, penalties, or a full game loop.

## Core Interaction Model

### New Task

When Aime finds or the user creates a task, the dog den shows one pending kibble item. This is not a reward yet. The copy should imply "I found something for you" rather than "great job."

Examples:

- "发现 2 件新事，狗粮先放在碗边。"
- "有 1 粒待领取狗粮，完成后再喂我。"

### Complete Task

When the user completes a task:

- The task is marked complete and written back to Lark Base.
- One pending kibble is fed to the dog.
- The dog enters a short "walk" state, such as holding a leash, walking out, then returning happy.
- Today fed count and intimacy increase locally.

This replaces the earlier "spin around" idea. The reward is "完成后遛狗."

### Overdue or P0 Task

Overdue and P0 tasks trigger gentle reminder states:

- Sitting at the door.
- Holding a leash.
- Looking toward the next important task.
- Short copy such as "这件 P0 还在门口等你."

The system must avoid punishment, guilt, or noisy animation.

### Drag to Lark Window

Dragging the dog onto or near a Lark chat/minutes window triggers "sniff current context."

MVP behavior:

- Detect the drag gesture and position.
- Capture the current screen or likely foreground window area.
- Run local OCR through the existing macOS Vision path.
- Extract candidate action items.
- Ask the user to confirm/edit before creating tasks in Base.

Future behavior:

- If Lark permissions and conversation identity are available, use the drag action as a trigger for API-based message/minutes retrieval.
- The known Aime assistant chat id can remain a shortcut, but direct chat reading depends on Lark permission and data visibility.

## UI Design

### Collapsed Den

The collapsed widget should stay small and desktop-friendly:

- Dog avatar as the primary visual.
- One compact risk indicator: P0 count or overdue count.
- Pending kibble count.
- Click expands the den.
- Drag moves the den; drag over Lark can trigger sniff mode.

Suggested collapsed content:

- Dog face.
- `P0 · 1` or `逾期 · 2`.
- `3 粒待领取狗粮`.

### Expanded Den

The expanded panel prioritizes task management:

1. Next most important task.
2. Today risk overview: P0, overdue, pending kibble.
3. Dog state line.
4. Compact task list and filters.
5. More actions: create task, sniff screen, open Base, open Aime assistant.

The dog is visible but not dominant. The next important task and risk overview must remain the highest-signal elements.

### Visual Tone

Use a warm macOS-native dog den style:

- Soft off-white or warm neutral panel.
- Rounded but restrained card geometry.
- Subtle shadow and material effects.
- Cute dog state, but concise task copy.
- Avoid large cartoon scenes in the MVP.

## State Model

Existing task data remains the source for task records.

Add local pet state:

- `pendingKibbleCount`: derived from actionable tasks that have not been completed and rewarded. Each completed task consumes one pending kibble after Lark writeback succeeds.
- `fedTodayCount`: completed tasks fed today.
- `intimacy`: lightweight local score, capped and optional in UI.
- `dogMood`: `idle`, `foundTask`, `readyToWalk`, `walking`, `happyReturn`, `concerned`, `sniffing`.
- `lastRewardedTaskIds`: local set to avoid double-feeding the same completed task.

Completion remains authoritative through Lark writeback. Pet state is local and recoverable.

## Data Flow

### Pull

1. Lark Base pull refreshes normalized tasks.
2. App calculates actionable tasks, overdue tasks, P0 tasks, and next important task.
3. Pet state derives pending kibble and reminder mood from task changes.

### Complete

1. User completes a task from the den.
2. App calls the existing Lark completion path.
3. On success, local pet reward is applied.
4. Task disappears from actionable list.
5. Dog enters walk feedback state.

If Lark writeback fails, do not reward yet. Show a compact error and keep the task actionable.

### Screen Sniff

1. User clicks "sniff screen" or drags dog to Lark.
2. App captures screen/window content.
3. OCR extracts text.
4. Candidate tasks are shown for confirmation.
5. Confirmed tasks are created in Base.
6. Newly created tasks appear as pending kibble, not as fed rewards.

## Error Handling

- Lark pull failure: keep the last local task snapshot and show a quiet stale-data state.
- Lark completion failure: do not feed the dog; show "写回失败，先别遛狗".
- OCR failure: dog returns to idle with "这次没闻到明确待办".
- Screen permission missing: show a clear permission hint and keep manual create available.
- Drag target uncertain: fall back to current-screen sniff with user confirmation.

## Testing

Automated tests should cover:

- Pending kibble is created for new actionable tasks.
- Completed tasks reward only once.
- Lark completion failure does not trigger reward.
- Next important task sorting still respects pinned, priority, and due date.
- Overdue/P0 states map to concerned dog mood.
- Sniff-created tasks appear as pending kibble, not completed rewards.

Manual verification should cover:

- Collapsed widget stays small on desktop.
- Expanded den remains readable at minimum and maximum panel sizes.
- Dragging the dog still moves the widget normally.
- Drag-to-Lark sniff does not create tasks without user confirmation.
- Cute animation does not block core task controls.

## Implementation Notes

Keep the MVP native AppKit path. Do not reintroduce Electron or WebView for the pet layer.

Prefer simple AppKit-rendered dog states first:

- Text/emoji or lightweight vector shapes for dog states.
- Timed state transitions for walk feedback.
- Local JSON preference storage for pet state.

If richer animation is needed later, add a small local asset set or Lottie-like renderer only after the MVP behavior is proven stable.
