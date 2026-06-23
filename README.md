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
- Clicking the badge expands a scrollable task list, sorted by pinned state and due date.
- Each task supports opening the source link, choosing an exact due date/time, pinning, hiding, and marking complete.
- The expanded panel and menu bar include shortcuts for the Aime Base and the Aime assistant conversation.
- The expanded panel supports creating new tasks, ignoring tasks, marking local P0/P1/P2 priority, and filtering by priority, project, and status.
- The "识别屏幕" action captures the current screen, runs local macOS OCR, and lets you confirm/edit a new task before writing to Base.
- Completion status and due date/time are written back to Lark Base.
- Pinning, hidden state, P0/P1/P2 priority, and filter preferences are stored locally on this Mac.
- Long-term project progress is shown as native progress bars, currently calculated from completed tasks per project.

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
- Write completion status and due date back to Base.
- Keep reminders, hidden state, pinning, and progress overrides local.

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
