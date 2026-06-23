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

Run the desktop shell:

```bash
npm run dev:electron
```

Build:

```bash
npm run build
```

Test:

```bash
npm test
```

## MVP Behavior

- Shows an always-on-top floating widget.
- Click expands a peek panel with overdue, today, later-this-week tasks.
- Double-click opens the management window.
- Completion, reschedule, and hide actions update the local store.
- Lark Base sync is represented by a configurable adapter boundary and stays in local sample mode until credentials and field mapping are configured.
