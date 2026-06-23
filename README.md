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

- Shows an always-on-top floating widget using a native Swift/AppKit shell.
- Click expands a peek panel with overdue, today, later-this-week tasks.
- Double-click expands to a management-sized window.
- Completion, reschedule, and hide actions update local WebView storage.
- Lark Base sync is represented by a configurable adapter boundary and stays in local sample mode until credentials and field mapping are configured.

## Lark/Aime Connection Status

The app is designed to connect to the existing Aime Lark Base:

```text
https://bytedance.larkoffice.com/base/F4k1bKUkRaIafPsKxP2cVAyEnwJ?table=tblllGcOFXODLI5I&view=vewBgeF8ZA
```

The current MVP uses local sample data until Lark authorization and field mapping are available. The expected sync boundary is:

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

Write completion status back to Base:

```bash
npm run lark:complete -- --record-id rec_xxx
```

Write a new due date back to Base:

```bash
npm run lark:reschedule -- --record-id rec_xxx --due-date 2026-06-24
```

Before live use, update the field names in `config/aime-base.example.json` to match the real Aime Base table. The current environment needs the `base:field:read` scope before `npm run lark:fields` can succeed.
