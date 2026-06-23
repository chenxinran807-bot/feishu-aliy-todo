# Aime Pet Todo Companion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current Mac desktop Aime task companion into a pet-style todo manager where completing tasks feeds the dog and triggers a short walk reward, while task capture and reminders remain primary.

**Architecture:** Add a small, testable Swift pet-state module and keep native AppKit as the UI shell. `main.swift` will consume derived pet state to render the collapsed dog den, expanded task panel, completion reward, and drag-to-Lark sniff trigger. Lark Base remains authoritative for task completion and due dates; pet state stays local and recoverable.

**Tech Stack:** Swift/AppKit, macOS Vision OCR, existing Node Lark sync script, `swiftc`, `npm run build`, Vitest for existing web/domain tests.

---

## File Structure

- Create `native/AimeCompanion/PetState.swift`: pure Swift state and rule functions for pending kibble, fed count, dog mood, reward dedupe, and next important task selection.
- Create `native/AimeCompanion/AimeModels.swift`: shared `TaskFeed`, `AimeTask`, and `LocalPreferences` definitions used by both the app and native tests.
- Create `native/AimeCompanion/PetStateTests.swift`: executable Swift assertions for pet-state rules.
- Modify `native/AimeCompanion/main.swift`: load/save pet state, render dog den UI, reward on successful completion, trigger sniff mode on drag-to-Lark, and rename cute style copy.
- Modify `package.json`: compile `PetState.swift` with the app and add `native:test`.
- Modify `README.md`: document the pet Todo behavior and local run/test commands.

Future personalization note: this plan implements the first dog-den skin only. Keep the core state model focused on generic reward and companion mood concepts so later skins can support cats, birds, plants, or a user-uploaded pet photo without rewriting task logic.

---

### Task 1: Add Testable Pet State Rules

**Files:**
- Create: `native/AimeCompanion/AimeModels.swift`
- Create: `native/AimeCompanion/PetState.swift`
- Create: `native/AimeCompanion/PetStateTests.swift`
- Modify: `native/AimeCompanion/main.swift`
- Modify: `package.json`

- [ ] **Step 1: Extract shared Aime models**

Create `native/AimeCompanion/AimeModels.swift` with the model definitions currently at the top of `native/AimeCompanion/main.swift`:

```swift
import Foundation

struct TaskFeed: Decodable {
    let tasks: [AimeTask]
}

struct AimeTask: Decodable, Equatable {
    let id: String
    let title: String
    let status: String
    let dueDate: String?
    let project: String?
    let sourceUrl: String?
}

struct LocalPreferences: Codable, Equatable {
    var pinnedTaskIds: Set<String> = []
    var hiddenTaskIds: Set<String> = []
    var priorityByTaskId: [String: String] = [:]
    var priorityFilter: String = "all"
    var projectFilter: String = "all"
    var statusFilter: String = "open"
    var expandedPanelWidth: Double = 400
    var expandedPanelHeight: Double = 560
    var displayStyle: String = "refined"
}
```

Remove the duplicate `TaskFeed`, `AimeTask`, and `LocalPreferences` definitions from `native/AimeCompanion/main.swift`.

- [ ] **Step 2: Create the failing pet-state test file**

Create `native/AimeCompanion/PetStateTests.swift` with:

```swift
import Foundation

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    if actual != expected {
        fatalError("\(message). Expected \(expected), got \(actual)")
    }
}

@main
enum PetStateTestRunner {
    static func main() {
        let tasks = [
            AimeTask(id: "p0", title: "评审迭代方案", status: "open", dueDate: "2026-06-23", project: "AI探索", sourceUrl: nil),
            AimeTask(id: "p2", title: "整理会议纪要", status: "open", dueDate: "2026-06-24", project: "AI探索", sourceUrl: nil),
            AimeTask(id: "done", title: "已经完成", status: "done", dueDate: "2026-06-22", project: "AI探索", sourceUrl: nil),
        ]

        let priority = ["p0": "P0", "p2": "P2"]
        let snapshot = PetState.derive(
            tasks: tasks,
            preferences: LocalPreferences(priorityByTaskId: priority),
            previous: PetState(),
            today: "2026-06-23"
        )

        assertEqual(snapshot.pendingKibbleCount, 2, "open tasks should become pending kibble")
        assertEqual(snapshot.overdueCount, 0, "today is not overdue")
        assertEqual(snapshot.p0Count, 1, "P0 count should be derived from local priority")
        assertEqual(snapshot.nextTaskId, "p0", "P0 task should be next")
        assertEqual(snapshot.dogMood, .foundTask, "open tasks should put dog in found-task mood")

        var rewarded = PetState()
        rewarded.pendingKibbleCount = 2
        rewarded = rewarded.rewardIfNeeded(taskId: "p0", today: "2026-06-23")
        assertEqual(rewarded.pendingKibbleCount, 1, "reward should consume one kibble")
        assertEqual(rewarded.fedTodayCount, 1, "reward should increment today's fed count")
        assertEqual(rewarded.intimacy, 1, "reward should increment intimacy")
        assertEqual(rewarded.dogMood, .walking, "reward should trigger walk mood")

        let duplicate = rewarded.rewardIfNeeded(taskId: "p0", today: "2026-06-23")
        assertEqual(duplicate.fedTodayCount, 1, "same task should not reward twice")
        assertEqual(duplicate.pendingKibbleCount, 1, "duplicate reward should not consume kibble twice")

        let overdueSnapshot = PetState.derive(
            tasks: tasks,
            preferences: LocalPreferences(priorityByTaskId: priority),
            previous: PetState(),
            today: "2026-06-24"
        )
        assertEqual(overdueSnapshot.overdueCount, 1, "past due open task should be overdue")
        assertEqual(overdueSnapshot.dogMood, .concerned, "overdue task should create concerned mood")

        print("PetStateTests passed")
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run:

```bash
swiftc native/AimeCompanion/AimeModels.swift native/AimeCompanion/PetState.swift native/AimeCompanion/PetStateTests.swift -o .build/pet-state-tests && ./.build/pet-state-tests
```

Expected: FAIL because `native/AimeCompanion/PetState.swift` does not exist.

- [ ] **Step 4: Create the pet-state implementation**

Create `native/AimeCompanion/PetState.swift` with:

```swift
import Foundation

enum DogMood: String, Codable, Equatable {
    case idle
    case foundTask
    case readyToWalk
    case walking
    case happyReturn
    case concerned
    case sniffing
}

struct PetState: Codable, Equatable {
    var pendingKibbleCount: Int = 0
    var fedTodayCount: Int = 0
    var intimacy: Int = 0
    var dogMood: DogMood = .idle
    var lastRewardedTaskIds: Set<String> = []
    var rewardDate: String = ""
    var p0Count: Int = 0
    var overdueCount: Int = 0
    var nextTaskId: String?

    static func derive(tasks: [AimeTask], preferences: LocalPreferences, previous: PetState, today: String) -> PetState {
        let actionable = tasks.filter { $0.status != "done" && $0.status != "ignored" && !preferences.hiddenTaskIds.contains($0.id) }
        let p0 = actionable.filter { preferences.priorityByTaskId[$0.id] == "P0" }
        let overdue = actionable.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return String(dueDate.prefix(10)) < today
        }
        let next = actionable.sorted { left, right in
            let leftPinned = preferences.pinnedTaskIds.contains(left.id)
            let rightPinned = preferences.pinnedTaskIds.contains(right.id)
            if leftPinned != rightPinned { return leftPinned }

            let leftPriority = priorityRank(preferences.priorityByTaskId[left.id] ?? "P2")
            let rightPriority = priorityRank(preferences.priorityByTaskId[right.id] ?? "P2")
            if leftPriority != rightPriority { return leftPriority < rightPriority }

            let leftDate = left.dueDate ?? "9999-12-31"
            let rightDate = right.dueDate ?? "9999-12-31"
            if leftDate == rightDate { return left.title < right.title }
            return leftDate < rightDate
        }.first

        var state = previous
        if state.rewardDate != today {
            state.rewardDate = today
            state.fedTodayCount = 0
        }
        state.pendingKibbleCount = actionable.filter { !state.lastRewardedTaskIds.contains($0.id) }.count
        state.p0Count = p0.count
        state.overdueCount = overdue.count
        state.nextTaskId = next?.id

        if state.dogMood == .walking || state.dogMood == .happyReturn {
            return state
        }
        if !overdue.isEmpty || !p0.isEmpty {
            state.dogMood = .concerned
        } else if state.pendingKibbleCount > 0 {
            state.dogMood = .foundTask
        } else {
            state.dogMood = .idle
        }
        return state
    }

    func rewardIfNeeded(taskId: String, today: String) -> PetState {
        var state = self
        if state.rewardDate != today {
            state.rewardDate = today
            state.fedTodayCount = 0
        }
        guard !state.lastRewardedTaskIds.contains(taskId) else { return state }
        state.lastRewardedTaskIds.insert(taskId)
        state.pendingKibbleCount = max(0, state.pendingKibbleCount - 1)
        state.fedTodayCount += 1
        state.intimacy = min(100, state.intimacy + 1)
        state.dogMood = .walking
        return state
    }
}

private func priorityRank(_ priority: String) -> Int {
    switch priority {
    case "P0": return 0
    case "P1": return 1
    default: return 2
    }
}
```

- [ ] **Step 5: Add a native test script**

Modify `package.json` scripts so `native:build` compiles both Swift files and `native:test` runs the Swift assertions:

```json
"native:build": "mkdir -p .build/module-cache && CLANG_MODULE_CACHE_PATH=\"$PWD/.build/module-cache\" swiftc -target arm64-apple-macosx15.0 native/AimeCompanion/AimeModels.swift native/AimeCompanion/PetState.swift native/AimeCompanion/main.swift -framework AppKit -framework Vision -o .build/aime-companion",
"native:test": "mkdir -p .build/module-cache && CLANG_MODULE_CACHE_PATH=\"$PWD/.build/module-cache\" swiftc -target arm64-apple-macosx15.0 native/AimeCompanion/AimeModels.swift native/AimeCompanion/PetState.swift native/AimeCompanion/PetStateTests.swift -o .build/pet-state-tests && ./.build/pet-state-tests",
"test": "vitest run && npm run native:test",
```

- [ ] **Step 6: Run tests**

Run:

```bash
npm test
```

Expected: Vitest passes and output includes `PetStateTests passed`.

- [ ] **Step 7: Commit**

```bash
git add package.json native/AimeCompanion/AimeModels.swift native/AimeCompanion/PetState.swift native/AimeCompanion/PetStateTests.swift native/AimeCompanion/main.swift
git commit -m "feat: add pet state rules"
```

---

### Task 2: Persist Pet State and Reward Completion

**Files:**
- Modify: `native/AimeCompanion/main.swift`
- Test: `native/AimeCompanion/PetStateTests.swift`

- [ ] **Step 1: Add a test for reward reset by date**

Append this block inside `PetStateTestRunner.main()` in `native/AimeCompanion/PetStateTests.swift`, immediately before `print("PetStateTests passed")`:

```swift
let yesterdayReward = PetState(pendingKibbleCount: 1, fedTodayCount: 4, intimacy: 7, dogMood: .idle, lastRewardedTaskIds: [], rewardDate: "2026-06-22", p0Count: 0, overdueCount: 0, nextTaskId: nil)
let todayReward = yesterdayReward.rewardIfNeeded(taskId: "new-task", today: "2026-06-23")
assertEqual(todayReward.fedTodayCount, 1, "fed count should reset before first reward on a new day")
assertEqual(todayReward.intimacy, 8, "intimacy should survive daily reset")
```

- [ ] **Step 2: Run native test**

Run:

```bash
npm run native:test
```

Expected: PASS after Task 1; this locks daily reset behavior before UI wiring.

- [ ] **Step 3: Add pet state properties and persistence to `main.swift`**

Add properties near the other `AppDelegate` state:

```swift
private var petState = PetState()
private var walkReturnTimer: Timer?
```

Update `applicationDidFinishLaunching` after preferences load:

```swift
petState = loadPetState()
```

Add persistence helpers near `preferencesURL()`:

```swift
private func petStateURL() -> URL {
    preferencesURL()
        .deletingLastPathComponent()
        .appendingPathComponent("pet-state.json")
}

private func loadPetState() -> PetState {
    let url = petStateURL()
    do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PetState.self, from: data)
    } catch {
        return PetState()
    }
}

private func savePetState() {
    let url = petStateURL()
    do {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(petState)
        try data.write(to: url, options: .atomic)
    } catch {
        print("Aime pet state could not be saved: \(error.localizedDescription)")
    }
}
```

- [ ] **Step 4: Derive pet state during reload**

In `reloadTasks()`, after computing `sortedTasks`, add:

```swift
petState = PetState.derive(tasks: tasks, preferences: preferences, previous: petState, today: todayKey())
savePetState()
```

Use `petState` for compact and expanded rendering in later tasks.

- [ ] **Step 5: Reward only after successful completion**

Change `runSyncCommand` to return `Bool`:

```swift
@discardableResult
private func runSyncCommand(_ arguments: [String]) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    process.arguments = ["node", "scripts/aime-lark-sync.mjs"] + arguments
    process.standardOutput = Pipe()
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            print("Aime sync command failed: \(arguments.joined(separator: " "))")
            return false
        }
        return true
    } catch {
        print("Aime sync command could not run: \(error.localizedDescription)")
        return false
    }
}
```

Update `completeTask(_:)`:

```swift
@objc private func completeTask(_ sender: NSButton) {
    guard let recordId = (sender as? AimeActionButton)?.payload else { return }
    let succeeded = runSyncCommand(["complete", "--record-id", recordId])
    if succeeded {
        petState = petState.rewardIfNeeded(taskId: recordId, today: todayKey())
        savePetState()
        scheduleWalkReturn()
    } else {
        showMessage("写回失败，先别遛狗", detail: "完成状态没有成功写回飞书 Base，请稍后重试。")
    }
    pullLatestTasks()
    reloadTasks()
}
```

Add:

```swift
private func scheduleWalkReturn() {
    walkReturnTimer?.invalidate()
    walkReturnTimer = Timer.scheduledTimer(withTimeInterval: 2.2, repeats: false) { [weak self] _ in
        guard let self else { return }
        self.petState.dogMood = .happyReturn
        self.savePetState()
        self.reloadTasks()
        self.walkReturnTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.petState.dogMood = .idle
            self.savePetState()
            self.reloadTasks()
        }
    }
}
```

- [ ] **Step 6: Run tests and build**

Run:

```bash
npm test && npm run build
```

Expected: Tests pass and Swift build succeeds.

- [ ] **Step 7: Commit**

```bash
git add native/AimeCompanion/main.swift native/AimeCompanion/PetStateTests.swift
git commit -m "feat: reward completed tasks with pet state"
```

---

### Task 3: Render the Dog Den UI

**Files:**
- Modify: `native/AimeCompanion/main.swift`
- Test: manual build and visual check

- [ ] **Step 1: Add pet copy helpers**

Add helper methods near existing style helpers:

```swift
private func dogFace() -> String {
    switch petState.dogMood {
    case .concerned: return "🐶!"
    case .walking: return "🐕"
    case .happyReturn: return "🐶✓"
    case .sniffing: return "🐶?"
    case .foundTask, .readyToWalk: return "🐶"
    case .idle: return "🐶"
    }
}

private func dogStateLine() -> String {
    switch petState.dogMood {
    case .walking: return "完成得好，带小狗出门散步中"
    case .happyReturn: return "散步回来啦，今天已投喂 \(petState.fedTodayCount) 次"
    case .concerned:
        if petState.p0Count > 0 { return "小狗叼着牵引绳：还有 \(petState.p0Count) 件 P0 在等你" }
        return "小狗坐在门口：有 \(petState.overdueCount) 件事过期了"
    case .sniffing: return "小狗正在闻闻当前窗口有没有待办"
    case .foundTask, .readyToWalk:
        return "\(petState.pendingKibbleCount) 粒狗粮在碗边，完成后再喂"
    case .idle:
        return petState.fedTodayCount > 0 ? "今天已遛狗 \(petState.fedTodayCount) 次" : "今天从一件小事开始"
    }
}

private func nextTaskTitle(from tasks: [AimeTask]) -> String {
    guard let id = petState.nextTaskId, let task = tasks.first(where: { $0.id == id }) else {
        return "当前没有紧急待办"
    }
    let priority = preferences.priorityByTaskId[task.id] ?? "P2"
    return "\(priority) · \(task.title)"
}
```

- [ ] **Step 2: Replace collapsed cute widget with dog den**

Update `compactWidget(openCount:overdueCount:)` so cute style renders dog face and kibble count:

```swift
let orb = label(preferences.displayStyle == "cute" ? dogFace() : avatarText(), size: preferences.displayStyle == "cute" ? 18 : 16, weight: .bold, color: avatarTextColor())
```

Update `compactSummaryText(openCount:overdueCount:)`:

```swift
if preferences.displayStyle == "cute" {
    if petState.p0Count > 0 { return "P0 · \(petState.p0Count)" }
    if overdueCount > 0 { return "逾期 · \(overdueCount)" }
    return "\(petState.pendingKibbleCount) 粒狗粮"
}
```

- [ ] **Step 3: Add expanded den summary above filters**

Change the expanded render block in `reloadTasks()`:

```swift
rootStack.addArrangedSubview(headerRow(openCount: actionableTasks.count, overdueCount: overdueTasks.count))
if preferences.displayStyle == "cute" {
    rootStack.addArrangedSubview(dogDenSummary(tasks: tasks))
} else if let statusView = styleStatusView(openCount: actionableTasks.count, overdueCount: overdueTasks.count) {
    rootStack.addArrangedSubview(statusView)
}
rootStack.addArrangedSubview(filterView(tasks: tasks))
```

Add:

```swift
private func dogDenSummary(tasks: [AimeTask]) -> NSView {
    let stack = NSStackView()
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 7

    stack.addArrangedSubview(label("下一件最重要的事", size: 11, weight: .medium, color: mutedColor()))
    stack.addArrangedSubview(label(nextTaskTitle(from: tasks), size: 14, weight: .bold, color: NSColor(calibratedRed: 0.34, green: 0.22, blue: 0.12, alpha: 1)))

    let metrics = NSStackView()
    metrics.orientation = .horizontal
    metrics.spacing = 6
    metrics.addArrangedSubview(metricPill("P0", value: "\(petState.p0Count)"))
    metrics.addArrangedSubview(metricPill("逾期", value: "\(petState.overdueCount)"))
    metrics.addArrangedSubview(metricPill("狗粮", value: "\(petState.pendingKibbleCount)"))
    metrics.addArrangedSubview(metricPill("遛狗", value: "\(petState.fedTodayCount)"))
    stack.addArrangedSubview(metrics)

    stack.addArrangedSubview(label(dogStateLine(), size: 12, weight: .medium, color: styleStatusTextColor()))
    return card(stack, width: contentWidth(), priority: petState.p0Count > 0 ? "P0" : "P2", isPinned: false)
}

private func metricPill(_ title: String, value: String) -> NSView {
    let text = label("\(value) \(title)", size: 11, weight: .semibold, color: styleStatusTextColor())
    text.alignment = .center
    text.wantsLayer = true
    text.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.62).cgColor
    text.layer?.cornerRadius = 10
    return padded(text, width: max(54, (contentWidth() - 24) / 4), vertical: 5)
}
```

- [ ] **Step 4: Rename cute style from Aime companion to dog den**

Update `styleTitle()` cute case:

```swift
case "cute": return "Aime 小狗"
```

Update cute notification copy:

```swift
title: preferences.displayStyle == "cute" ? "小狗闻到新待办" : "Aime 有新待办"
body: "新增 \(lastKnownTaskCount - previousTaskCount) 个待办，狗粮先放在碗边。"
```

and overdue copy:

```swift
title: preferences.displayStyle == "cute" ? "小狗叼着牵引绳" : "有任务已逾期"
body: "现在有 \(lastKnownOverdueCount) 个逾期待办。"
```

- [ ] **Step 5: Build and launch for visual check**

Run:

```bash
npm run build
npm run native:run
```

Expected: Cute style shows dog den copy and still allows complete, reschedule, filter, create, and screen recognition.

- [ ] **Step 6: Commit**

```bash
git add native/AimeCompanion/main.swift
git commit -m "feat: render dog den companion"
```

---

### Task 4: Add Drag-to-Lark Sniff Trigger

**Files:**
- Modify: `native/AimeCompanion/main.swift`
- Test: manual visual and OCR flow

- [ ] **Step 1: Create a draggable dog button class**

Add near other custom view classes:

```swift
final class PetDragButton: NSButton {
    var onDragEnded: ((NSPoint) -> Void)?
    private var didDrag = false

    override func mouseDown(with event: NSEvent) {
        didDrag = false
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        didDrag = true
        window?.performDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            onDragEnded?(NSEvent.mouseLocation)
        } else {
            super.mouseUp(with: event)
        }
    }
}
```

- [ ] **Step 2: Use it for the collapsed widget**

In `compactWidget(openCount:overdueCount:)`, replace the button declaration with:

```swift
let button = PetDragButton(title: "", target: self, action: #selector(expandWidget))
button.onDragEnded = { [weak self] location in
    self?.handlePetDragEnded(at: location)
}
```

- [ ] **Step 3: Add sniff handling**

Add:

```swift
private func handlePetDragEnded(at location: NSPoint) {
    guard preferences.displayStyle == "cute" else { return }
    petState.dogMood = .sniffing
    savePetState()
    reloadTasks()

    if isLikelyLarkWindow(at: location) {
        scanScreenForTasks(dialogTitle: "小狗从飞书窗口闻到可能待办", skipDuplicate: false)
    } else {
        showMessage("小狗准备好了", detail: "把小狗拖到飞书聊天或会议纪要窗口附近，可以触发当前屏幕识别。")
    }
}

private func isLikelyLarkWindow(at location: NSPoint) -> Bool {
    let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
    guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return false }
    return windows.contains { info in
        guard
            let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
            let owner = info[kCGWindowOwnerName as String] as? String
        else { return false }
        let rect = NSRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )
        let ownerLooksLikeLark = owner.localizedCaseInsensitiveContains("Lark")
            || owner.localizedCaseInsensitiveContains("Feishu")
            || owner.localizedCaseInsensitiveContains("飞书")
        return ownerLooksLikeLark && rect.contains(location)
    }
}
```

If macOS coordinate conversion makes this unreliable, keep the fallback message and add a "嗅探当前屏幕" menu item in the header more menu that calls `captureScreenClicked()`.

- [ ] **Step 4: Reset sniff mood after OCR**

At the end of `scanScreenForTasks(dialogTitle:skipDuplicate:)`, after `createTask(...)`, set:

```swift
petState.dogMood = .foundTask
savePetState()
reloadTasks()
```

In failure branches where no text is found, set:

```swift
petState.dogMood = .idle
savePetState()
reloadTasks()
```

- [ ] **Step 5: Build and manually verify**

Run:

```bash
npm run build
npm run native:run
```

Manual expected behavior:

- Dragging the small dog still moves the widget.
- Dropping it near a visible Lark/Feishu window triggers screen recognition.
- The app asks for confirmation before creating a task.
- Dropping elsewhere shows guidance and does not create a task.

- [ ] **Step 6: Commit**

```bash
git add native/AimeCompanion/main.swift
git commit -m "feat: let pet sniff lark windows"
```

---

### Task 5: Documentation and Final Verification

**Files:**
- Modify: `README.md`
- Test: `npm test`, `npm run build`, manual launch

- [ ] **Step 1: Update README behavior bullets**

Add these bullets under `## MVP Behavior`:

```markdown
- Cute style can run as a dog-den todo companion: new actionable tasks appear as pending kibble, and completed tasks feed the dog.
- Completion rewards trigger a short "walk the dog" state only after completion writes back to Lark Base.
- P0 and overdue tasks use gentle dog reminder copy instead of punitive alerts.
- Dragging the small dog onto a visible Lark/Feishu window can trigger screen sniffing; the app still asks for confirmation before creating tasks.
- The first companion skin is dog-based; future skins can use cats, birds, plants, or user-uploaded pet photos while reusing the same completion reward model.
```

- [ ] **Step 2: Add local-state note**

Add under `## Lark/Aime Connection Status`:

```markdown
Pet state is local to the Mac. Fed count, intimacy, dog mood, and rewarded-task ids are stored in Application Support next to the existing local preferences. Lark Base remains the source of truth for task status and due dates.
```

- [ ] **Step 3: Run full verification**

Run:

```bash
npm test
npm run build
```

Expected:

- Vitest passes.
- `PetStateTests passed`.
- Native Swift build succeeds.

- [ ] **Step 4: Manual verification**

Run:

```bash
npm run native:run
```

Verify:

- Cute style collapsed widget is small and dog-like.
- Expanded panel shows next important task, P0, overdue, kibble, and walk count.
- Completing a task writes back to Lark and triggers walk copy.
- Completion failure does not feed the dog.
- Drag-to-Lark sniff asks for confirmation before creating tasks.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: document pet todo companion"
```

---

## Self-Review

- Spec coverage: the plan covers pet-state rules, completion-only reward, dog-den UI, overdue/P0 gentle reminders, drag-to-Lark sniffing, local persistence, error handling for failed completion, and tests.
- Scope control: the plan intentionally avoids shops, outfits, complex levels, streak pressure, and rich animation assets.
- Type consistency: `DogMood`, `PetState`, `pendingKibbleCount`, `fedTodayCount`, `intimacy`, `lastRewardedTaskIds`, and `rewardIfNeeded(taskId:today:)` are introduced once and reused consistently.
- Verification: every implementation task includes build or test commands, and the final task includes manual checks for the desktop widget behavior.
