# DESIGN.md Reminders UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the 360 × 260px always-on task panel as the approved macOS Reminders-style interface defined in the project `DESIGN.md`.

**Architecture:** Keep Base synchronization, task mutation, and window lifecycle unchanged. Move all deterministic presentation decisions—preview limit, group assignment, subtitle copy, and task metadata—into pure Swift policies in `AimeModels.swift`; let `main.swift` translate those policies into AppKit views using a small semantic token set.

**Tech Stack:** Swift, AppKit, existing native policy tests, Node/Vite regression suite, macOS packaged-app visual inspection.

---

### Task 1: Encode the approved panel policy

**Files:**
- Modify: `native/AimeCompanion/AimeModels.swift`
- Test: `native/AimeCompanion/PetStateTests.swift`

- [ ] **Step 1: Write failing grouping and copy tests**

Add assertions proving the approved UI has no dashboard statistics and partitions the three preview tasks into two groups:

```swift
let groupedPreview = TaskPanelVisualPolicy.groupedPreview(
    tasks: tasks,
    priorities: ["p0": "P0", "normal": "P2", "early": "P2"],
    today: today
)
assertEqual(groupedPreview.priority.map(\.id), ["p0", "early"], "P0 and overdue tasks should be handled first")
assertEqual(groupedPreview.next.map(\.id), ["normal"], "remaining preview tasks should appear next")
assertEqual(TaskPanelVisualPolicy.subtitle(openCount: 4, syncSucceeded: true), "4 项待办 · 飞书已同步", "subtitle should combine count and sync state")
assertEqual(TaskPanelVisualPolicy.showsDashboardStats, false, "reminders mode must not render dashboard cards")
```

- [ ] **Step 2: Run the native test and verify RED**

Run: `npm run native:test`

Expected: compilation fails because `groupedPreview`, `subtitle`, and `showsDashboardStats` do not exist.

- [ ] **Step 3: Implement the minimal pure policy**

Add focused types to `AimeModels.swift`:

```swift
struct TaskPanelGroups: Equatable {
    let priority: [AimeTask]
    let next: [AimeTask]
}

extension TaskPanelVisualPolicy {
    static let showsDashboardStats = false

    static func subtitle(openCount: Int, syncSucceeded: Bool) -> String {
        "\(openCount) 项待办 · \(syncSucceeded ? "飞书已同步" : "等待飞书同步")"
    }

    static func groupedPreview(tasks: [AimeTask], priorities: [String: String], today: String) -> TaskPanelGroups {
        let preview = Array(tasks.filter { $0.status == "open" || $0.status == "waiting" }.prefix(previewTaskLimit))
        let priority = preview.filter { task in
            priorities[task.id] == "P0" || (task.dueDate.map { String($0.prefix(10)) < today } ?? false)
        }
        return TaskPanelGroups(priority: priority, next: preview.filter { task in !priority.contains(where: { $0.id == task.id }) })
    }
}
```

- [ ] **Step 4: Run the native test and verify GREEN**

Run: `npm run native:test`

Expected: `PetStateTests passed`.

- [ ] **Step 5: Commit the policy slice**

```bash
git add native/AimeCompanion/AimeModels.swift native/AimeCompanion/PetStateTests.swift
git commit -m "test: define reminders panel policy"
```

### Task 2: Replace the dashboard with the reminders hierarchy

**Files:**
- Modify: `native/AimeCompanion/main.swift`
- Test: `native/AimeCompanion/PetStateTests.swift`

- [ ] **Step 1: Add a failing metadata-copy test**

Add a pure policy assertion so right-side metadata stays compact and deterministic:

```swift
assertEqual(TaskPanelVisualPolicy.metadata(dueDate: "2026-07-17 10:30:00", today: "2026-07-17"), "10:30", "today tasks should show time")
assertEqual(TaskPanelVisualPolicy.metadata(dueDate: nil, today: "2026-07-17"), "飞书", "undated remote tasks should show source")
```

- [ ] **Step 2: Run the native test and verify RED**

Run: `npm run native:test`

Expected: compilation fails because `metadata(dueDate:today:)` does not exist.

- [ ] **Step 3: Implement metadata policy**

```swift
static func metadata(dueDate: String?, today: String) -> String {
    guard let dueDate, !dueDate.isEmpty else { return "飞书" }
    if dueDate.hasPrefix(today), dueDate.count >= 16 {
        return String(dueDate.dropFirst(11).prefix(5))
    }
    return String(dueDate.prefix(10))
}
```

- [ ] **Step 4: Rebuild `lightweightFeishuPanel` from DESIGN.md**

Change `reloadTasks` to pass the existing sorted tasks to a reminders panel that renders:

```swift
let groups = TaskPanelVisualPolicy.groupedPreview(
    tasks: tasks,
    priorities: preferences.priorityByTaskId,
    today: todayKey()
)

stack.addArrangedSubview(remindersHeader(openCount: openCount))
if !groups.priority.isEmpty {
    stack.addArrangedSubview(sectionLabel("优先处理"))
    groups.priority.forEach { stack.addArrangedSubview(remindersTaskRow($0)) }
}
if !groups.next.isEmpty {
    stack.addArrangedSubview(sectionLabel("接下来"))
    groups.next.forEach { stack.addArrangedSubview(remindersTaskRow($0)) }
}
```

The header must contain “今天”, `TaskPanelVisualPolicy.subtitle(...)`, and one `+` button. Delete the calls to `lightweightStats`; do not add filters, Base, refresh, sort, or per-row more buttons.

- [ ] **Step 5: Apply semantic AppKit tokens**

Add private constants in `AppDelegate` and use them consistently:

```swift
private let feishuBlue = NSColor(calibratedRed: 0.20, green: 0.44, blue: 1.00, alpha: 1)
private let dangerRed = NSColor(calibratedRed: 0.96, green: 0.29, blue: 0.27, alpha: 1)
private let subtleSurface = NSColor(calibratedWhite: 0.96, alpha: 1)
private let divider = NSColor.separatorColor.withAlphaComponent(0.35)
```

Use 19px semibold for “今天”, 10px for subtitle/section/meta, 13px regular for task titles, 36px task rows, 14px circular completion controls, 6px meta pills, and 18px panel radius. Red may appear only in overdue metadata; blue may appear only in actions and focus states.

- [ ] **Step 6: Remove obsolete always-on dashboard helpers**

Delete `lightweightStats`, `lightweightStat`, and the dashboard-only summary path. Keep full-window and synchronization helpers unchanged.

- [ ] **Step 7: Run native tests and build**

Run: `npm run native:test && npm run native:build`

Expected: tests pass and Swift compilation exits 0.

- [ ] **Step 8: Commit the AppKit slice**

```bash
git add native/AimeCompanion/main.swift native/AimeCompanion/AimeModels.swift native/AimeCompanion/PetStateTests.swift
git commit -m "feat: apply Design MD reminders panel"
```

### Task 3: Verify the real packaged application

**Files:**
- Modify only if verification exposes a concrete mismatch: `native/AimeCompanion/main.swift`

- [ ] **Step 1: Run the full automated suite**

Run:

```bash
npm test
npm run lint
npm run lark:self-test
npm run build
```

Expected: 42 frontend tests pass, native tests pass, TypeScript reports no errors, sync self-test reports `ok: true`, and production build exits 0.

- [ ] **Step 2: Package and launch a clean instance**

Run:

```bash
pkill -f 'aime-companion-bin|神仙待办.app|aime-companion' || true
npm run native:package
open '.build/神仙待办.app'
```

Expected: a 360 × 260px reminders-style panel opens.

- [ ] **Step 3: Inspect the live application window**

Use the local application inspection capability and verify all of the following:

- Header: “今天”, task count + sync state, one `+` action.
- Groups: “优先处理” and/or “接下来”.
- At most three task rows.
- No statistic cards, filters, sort controls, Base/refresh toolbar, priority letters, colored cards, or row overflow menus.
- Task rows use completion circle, title, and one compact right-side metadata value.
- Expanded size is 360 × 260px; collapsed size is 120 × 104px.

- [ ] **Step 4: Verify the diff**

Run: `git diff --check && git status -sb`

Expected: no whitespace errors; only intended native UI and test files are modified.

- [ ] **Step 5: Commit any verification correction**

If the live window required a correction, commit only that correction:

```bash
git add native/AimeCompanion/main.swift native/AimeCompanion/PetStateTests.swift
git commit -m "fix: align live panel with Design MD"
```

If no correction was needed, skip this commit.
