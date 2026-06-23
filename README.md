# Aime Desktop Task Companion

Mac-first desktop task companion for Aime todo monitoring.

## Local Run

Install dependencies:

```bash
npm install
```

Run the renderer in a browser:

```bash
npm run dev
```

Build the Mac desktop companion:

```bash
npm run build
```

Run the Mac desktop companion:

```bash
npm run native:run
```

Test:

```bash
npm test
```

## MVP Behavior

- Shows a small always-on-top floating badge using a native Swift/AppKit shell.
- Clicking the badge expands a compact, resizable task list, sorted by pinned state, priority, and due date.
- The expanded panel has a bottom-right resize handle and remembers the user's preferred size.
- Users can choose Minimal, Refined, or Cute display styles from "更多".
- Minimal is low-noise and monochrome, Refined uses a macOS HUD-like glass feel, and Cute adds a companion-style status line and pastel task cards.
- The expanded panel keeps only common actions visible: complete, reschedule, filter, and task-level "more".
- Less frequent actions live behind "更多": opening sources, pinning, hiding, ignoring, P0/P1/P2 priority, creating tasks, screen recognition, and Aime/Base shortcuts.
- The "识别屏幕" action captures the current screen, runs local macOS OCR, and lets you confirm/edit a new task before writing to Base.
- "开始实时识别" runs local OCR every 45 seconds after the user explicitly enables it, and still asks for confirmation before creating a task.
- New-task and overdue reminders use a lightweight sound/panel cue in the local MVP, with friendlier copy in Cute style.
- Cute style can run as a dog-den todo companion: new actionable tasks appear as pending kibble, and completed tasks feed the dog.
- Completion rewards trigger a short "walk the dog" state only after completion writes back to Lark Base.
- P0 and overdue tasks use gentle dog reminder copy instead of punitive alerts.
- Dragging the small dog onto a visible Lark/Feishu window can trigger screen sniffing; the app still asks for confirmation before creating tasks.
- The first companion skin is dog-based; future skins can use cats, birds, plants, or user-uploaded pet photos while reusing the same completion reward model.
- Completion status and due date/time are written back to Lark Base.
- Pinning, hidden state, P0/P1/P2 priority, and filter preferences are stored locally on this Mac.
- Long-term project progress logic is retained but no longer shown in the default compact panel.

The Aime Base shortcut defaults to the current Base URL. The assistant shortcut defaults to this chat:

```text
oc_31661171e477fd90c1d62de8e2f1a84d
```

Set `AIME_ASSISTANT_URL` before launch if you need to override it:

```bash
AIME_ASSISTANT_URL="lark://..." npm run native:run
```

## Lark/Aime Connection Status

The app is designed to connect to the existing Aime Lark Base:

```text
https://bytedance.larkoffice.com/base/F4k1bKUkRaIafPsKxP2cVAyEnwJ?table=tblllGcOFXODLI5I&view=vewBgeF8ZA
```

The current MVP can pull records from the existing Aime Base through `lark-cli`. The sync boundary is:

- Pull task records from the Base table.
- Auto-refresh pulled task records every 5 minutes while the widget is running.
- Write completion status and due date back to Base.
- Keep reminders, hidden state, pinning, and progress overrides local.

Pet state is local to the Mac. Fed count, intimacy, companion mood, and rewarded-task ids are stored in Application Support next to the existing local preferences. Lark Base remains the source of truth for task status and due dates.

## UI References

The current style split borrows product patterns from:

- `ntd4996/agentpet`: desktop companion state and playful task feedback.
- `Wanduforl/MacArkPet`: native macOS desktop-pet presentation.
- `bleeeet/TermiPet`: companion + status cards + quick commands.
- `Liftof/littletodo`: tiny menu-bar todo with low-friction task access.
- `wendybzhang/codex-quota-widget`: compact floating capsule density.

## Lark/Aime Sync Preview

The sync preview uses `lark-cli` and the config in `config/aime-base.example.json`.

If your terminal is not already inside this project, either `cd` first:

```bash
cd "/Users/bytedance/Documents/todo agent/.worktrees/aime-desktop-mvp"
```

Or run commands from anywhere with:

```bash
npm --prefix "/Users/bytedance/Documents/todo agent/.worktrees/aime-desktop-mvp" run lark:fields
```

Authorize Lark if needed:

```bash
lark-cli auth login
```

Inspect fields:

```bash
npm run lark:fields
```

Pull tasks as normalized JSON:

```bash
npm run lark:pull
```

Create a task:

```bash
npm run lark:create -- --title "新的待办" --due-date "2026-06-24 18:00:00" --project "AI试穿"
```

Write completion status back to Base:

```bash
npm run lark:complete -- --record-id rec_xxx
```

Write ignored status back to Base:

```bash
npm run lark:ignore -- --record-id rec_xxx
```

Write a new due date/time back to Base:

```bash
npm run lark:reschedule -- --record-id rec_xxx --due-date "2026-06-24 18:00:00"
```

Before live use, update the field names in `config/aime-base.example.json` to match the real Aime Base table. The current environment needs the `base:field:read` scope before `npm run lark:fields` can succeed.
