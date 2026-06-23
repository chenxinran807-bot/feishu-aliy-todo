import AppKit
import Foundation

struct TaskFeed: Decodable {
    let tasks: [AimeTask]
}

struct AimeTask: Decodable {
    let id: String
    let title: String
    let status: String
    let dueDate: String?
    let project: String?
    let sourceUrl: String?
}

struct LocalPreferences: Codable {
    var pinnedTaskIds: Set<String> = []
    var hiddenTaskIds: Set<String> = []
}

final class AimeActionButton: NSButton {
    var payload: String = ""
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let defaultBaseURL = "https://bytedance.larkoffice.com/base/F4k1bKUkRaIafPsKxP2cVAyEnwJ?table=tblllGcOFXODLI5I&view=vewBgeF8ZA"
    private let defaultAimeAssistantURL = "lark://client"

    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var rootStack: NSStackView!
    private var taskFeedPath: String = ""
    private var preferences = LocalPreferences()
    private var showingHiddenTasks = false
    private var isExpanded = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        taskFeedPath = resolveTaskFeedPath()

        let frame = frameForCurrentMode()
        window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = true
        window.title = "Aime Task Companion"
        window.contentView = buildContentView(frame: frame)

        reloadTasks()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        createStatusItem()
    }

    private func buildContentView(frame: NSRect) -> NSView {
        let container = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        container.material = .hudWindow
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 18
        container.layer?.masksToBounds = true
        container.autoresizingMask = [.width, .height]

        rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 10
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            rootStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            rootStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            rootStack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -14),
        ])

        return container
    }

    private func reloadTasks() {
        let tasks = loadTasks()
        rootStack.arrangedSubviews.forEach { view in
            rootStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let openTasks = tasks.filter { $0.status != "done" }
        let visibleOpenTasks = openTasks.filter { task in
            showingHiddenTasks || !preferences.hiddenTaskIds.contains(task.id)
        }
        let overdueTasks = openTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < todayKey()
        }
        let sortedOpenTasks = sortOpenTasks(visibleOpenTasks)

        if !isExpanded {
            rootStack.addArrangedSubview(compactWidget(openCount: openTasks.count, overdueCount: overdueTasks.count))
            return
        }

        rootStack.addArrangedSubview(headerRow(openCount: openTasks.count, overdueCount: overdueTasks.count))
        rootStack.addArrangedSubview(projectProgressView(tasks: tasks, projectName: "AI试穿"))
        rootStack.addArrangedSubview(projectProgressView(tasks: tasks, projectName: "AI穿搭"))
        rootStack.addArrangedSubview(taskListView(sortedOpenTasks))
        rootStack.addArrangedSubview(footerView(tasksCount: tasks.count, hiddenCount: preferences.hiddenTaskIds.count))
    }

    private func compactWidget(openCount: Int, overdueCount: Int) -> NSView {
        let button = NSButton(title: "", target: self, action: #selector(expandWidget))
        button.isBordered = false
        button.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        let orb = label("Ai", size: 16, weight: .bold, color: .white)
        orb.alignment = .center
        orb.wantsLayer = true
        orb.layer?.backgroundColor = NSColor(calibratedRed: 0.14, green: 0.36, blue: 0.32, alpha: 1).cgColor
        orb.layer?.cornerRadius = 20
        orb.widthAnchor.constraint(equalToConstant: 40).isActive = true
        orb.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let summaryText = overdueCount > 0 ? "\(overdueCount) 逾期" : "\(openCount) 待办"
        stack.addArrangedSubview(orb)
        stack.addArrangedSubview(label(summaryText, size: 11, weight: .semibold))
        button.addSubview(stack)

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 88),
            button.heightAnchor.constraint(equalToConstant: 76),
            stack.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])

        return button
    }

    private func sortOpenTasks(_ tasks: [AimeTask]) -> [AimeTask] {
        tasks.sorted { left, right in
            let leftPinned = preferences.pinnedTaskIds.contains(left.id)
            let rightPinned = preferences.pinnedTaskIds.contains(right.id)
            if leftPinned != rightPinned {
                return leftPinned
            }

            let leftDate = left.dueDate ?? "9999-12-31"
            let rightDate = right.dueDate ?? "9999-12-31"
            if leftDate == rightDate {
                return left.title < right.title
            }
            return leftDate < rightDate
        }
    }

    private func headerRow(openCount: Int, overdueCount: Int) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10

        let orb = label("Ai", size: 17, weight: .bold, color: .white)
        orb.alignment = .center
        orb.wantsLayer = true
        orb.layer?.backgroundColor = NSColor(calibratedRed: 0.14, green: 0.36, blue: 0.32, alpha: 1).cgColor
        orb.layer?.cornerRadius = 22
        orb.widthAnchor.constraint(equalToConstant: 44).isActive = true
        orb.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let summary = label("\(openCount) open · \(overdueCount) overdue", size: 17, weight: .semibold)
        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.spacing = 2
        titleStack.addArrangedSubview(label("任务伴随", size: 12, weight: .medium, color: mutedColor()))
        titleStack.addArrangedSubview(summary)

        let collapse = NSButton(title: "收起", target: self, action: #selector(collapseWidget))
        collapse.bezelStyle = .rounded
        collapse.controlSize = .small

        row.addArrangedSubview(orb)
        row.addArrangedSubview(titleStack)
        row.addArrangedSubview(collapse)
        return row
    }

    private func taskListView(_ tasks: [AimeTask]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.addArrangedSubview(label("全部待办（上下滚动）", size: 12, weight: .medium, color: mutedColor()))

        if tasks.isEmpty {
            stack.addArrangedSubview(card(label("目前没有未完成任务", size: 14, weight: .semibold), width: 388))
        } else {
            stack.addArrangedSubview(scrollableTaskList(tasks))
        }
        return stack
    }

    private func scrollableTaskList(_ tasks: [AimeTask]) -> NSView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let documentStack = NSStackView()
        documentStack.orientation = .vertical
        documentStack.alignment = .leading
        documentStack.spacing = 8
        documentStack.translatesAutoresizingMaskIntoConstraints = false

        tasks.forEach { task in
            documentStack.addArrangedSubview(taskCardView(task))
        }

        scrollView.documentView = documentStack
        NSLayoutConstraint.activate([
            scrollView.widthAnchor.constraint(equalToConstant: 402),
            scrollView.heightAnchor.constraint(equalToConstant: 330),
            documentStack.widthAnchor.constraint(equalToConstant: 388),
        ])

        return scrollView
    }

    private func taskCardView(_ task: AimeTask) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        let isPinned = preferences.pinnedTaskIds.contains(task.id)
        let isHidden = preferences.hiddenTaskIds.contains(task.id)
        let statePrefix = [
            isPinned ? "置顶" : nil,
            isHidden ? "隐藏" : nil,
        ].compactMap { $0 }.joined(separator: " · ")
        let title = statePrefix.isEmpty ? task.title : "\(statePrefix) · \(task.title)"

        stack.addArrangedSubview(label(title, size: 13, weight: .semibold))
        stack.addArrangedSubview(label("\(task.project ?? "未分类") · \(task.dueDate ?? "无截止日期")", size: 11, color: mutedColor()))
        stack.addArrangedSubview(actionRow(for: task))
        return card(stack, width: 388)
    }

    private func actionRow(for task: AimeTask) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        if let sourceUrl = task.sourceUrl, !sourceUrl.isEmpty {
            row.addArrangedSubview(actionButton("打开", representedObject: sourceUrl, action: #selector(openTaskSource(_:))))
        }
        row.addArrangedSubview(actionButton("改时间", representedObject: task.id, action: #selector(rescheduleTask(_:))))
        row.addArrangedSubview(actionButton(preferences.pinnedTaskIds.contains(task.id) ? "取消置顶" : "置顶", representedObject: task.id, action: #selector(togglePinTask(_:))))
        row.addArrangedSubview(actionButton(preferences.hiddenTaskIds.contains(task.id) ? "取消隐藏" : "隐藏", representedObject: task.id, action: #selector(toggleHideTask(_:))))
        row.addArrangedSubview(actionButton("完成", representedObject: task.id, action: #selector(completeTask(_:))))
        return row
    }

    private func actionButton(_ title: String, representedObject: String, action: Selector) -> NSButton {
        let button = AimeActionButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.payload = representedObject
        return button
    }

    private func projectProgressView(tasks: [AimeTask], projectName: String) -> NSView {
        let projectTasks = tasks.filter { $0.project == projectName }
        let doneCount = projectTasks.filter { $0.status == "done" }.count
        let totalCount = max(projectTasks.count, 1)
        let percent = Double(doneCount) / Double(totalCount)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        let title = label("\(projectName) \(Int(percent * 100))%", size: 13, weight: .semibold)
        let progress = NSProgressIndicator()
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 1
        progress.doubleValue = percent
        progress.controlSize = .small
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.widthAnchor.constraint(equalToConstant: 388).isActive = true

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(progress)
        stack.addArrangedSubview(label("auto from \(doneCount)/\(projectTasks.count) tasks", size: 11, color: mutedColor()))
        return stack
    }

    private func footerView(tasksCount: Int, hiddenCount: Int) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        let base = NSButton(title: "多维表格", target: self, action: #selector(openAimeBase))
        base.bezelStyle = .rounded
        base.controlSize = .small

        let assistant = NSButton(title: "Aime助手", target: self, action: #selector(openAimeAssistant))
        assistant.bezelStyle = .rounded
        assistant.controlSize = .small

        let refresh = NSButton(title: "刷新", target: self, action: #selector(refreshClicked))
        refresh.bezelStyle = .rounded
        refresh.controlSize = .small

        let hiddenToggle = NSButton(title: showingHiddenTasks ? "隐藏收起" : "显示隐藏", target: self, action: #selector(toggleShowHiddenTasks))
        hiddenToggle.bezelStyle = .rounded
        hiddenToggle.controlSize = .small
        hiddenToggle.isEnabled = hiddenCount > 0

        row.addArrangedSubview(label("\(tasksCount) tasks from Aime Base", size: 11, color: mutedColor()))
        row.addArrangedSubview(label("\(hiddenCount) hidden", size: 11, color: mutedColor()))
        row.addArrangedSubview(base)
        row.addArrangedSubview(assistant)
        row.addArrangedSubview(hiddenToggle)
        row.addArrangedSubview(refresh)
        return row
    }

    private func card(_ content: NSView, width: CGFloat = 388) -> NSView {
        let wrapper = NSView()
        wrapper.wantsLayer = true
        wrapper.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.72).cgColor
        wrapper.layer?.cornerRadius = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(content)

        NSLayoutConstraint.activate([
            wrapper.widthAnchor.constraint(equalToConstant: width),
            content.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 10),
            content.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -10),
            content.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 8),
            content.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -8),
        ])

        return wrapper
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = NSColor.labelColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = NSFont.systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.lineBreakMode = .byTruncatingTail
        field.maximumNumberOfLines = 2
        return field
    }

    private func mutedColor() -> NSColor {
        NSColor.secondaryLabelColor
    }

    private func loadTasks() -> [AimeTask] {
        preferences = loadPreferences()

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: taskFeedPath))
            let feed = try JSONDecoder().decode(TaskFeed.self, from: data)
            return feed.tasks
        } catch {
            print("Aime task feed unavailable at \(taskFeedPath): \(error.localizedDescription)")
            return [
                AimeTask(id: "sample-1", title: "运行 npm run lark:pull 同步 Aime Base", status: "open", dueDate: todayKey(), project: "AI探索", sourceUrl: nil),
                AimeTask(id: "sample-2", title: "确认桌面小组件可见", status: "done", dueDate: todayKey(), project: "AI探索", sourceUrl: nil),
            ]
        }
    }

    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Ai"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示任务伴随", action: #selector(showWidget), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "展开任务列表", action: #selector(expandWidget), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "打开多维表格", action: #selector(openAimeBase), keyEquivalent: "b"))
        menu.addItem(NSMenuItem(title: "打开 Aime 助手", action: #selector(openAimeAssistant), keyEquivalent: "a"))
        menu.addItem(NSMenuItem(title: "刷新", action: #selector(refreshClicked), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func showWidget() {
        window.setFrame(frameForCurrentMode(), display: true, animate: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func expandWidget() {
        isExpanded = true
        window.setFrame(frameForCurrentMode(), display: true, animate: true)
        reloadTasks()
        showWidget()
    }

    @objc private func collapseWidget() {
        isExpanded = false
        window.setFrame(frameForCurrentMode(), display: true, animate: true)
        reloadTasks()
        showWidget()
    }

    @objc private func refreshClicked() {
        pullLatestTasks()
        reloadTasks()
        showWidget()
    }

    @objc private func openAimeBase() {
        openURLString(ProcessInfo.processInfo.environment["AIME_BASE_URL"] ?? defaultBaseURL)
    }

    @objc private func openAimeAssistant() {
        openURLString(ProcessInfo.processInfo.environment["AIME_ASSISTANT_URL"] ?? defaultAimeAssistantURL)
    }

    @objc private func openTaskSource(_ sender: NSButton) {
        guard
            let urlString = (sender as? AimeActionButton)?.payload,
            let url = URL(string: urlString)
        else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func openURLString(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func togglePinTask(_ sender: NSButton) {
        guard let recordId = (sender as? AimeActionButton)?.payload else { return }
        if preferences.pinnedTaskIds.contains(recordId) {
            preferences.pinnedTaskIds.remove(recordId)
        } else {
            preferences.pinnedTaskIds.insert(recordId)
        }
        savePreferences()
        reloadTasks()
    }

    @objc private func toggleHideTask(_ sender: NSButton) {
        guard let recordId = (sender as? AimeActionButton)?.payload else { return }
        if preferences.hiddenTaskIds.contains(recordId) {
            preferences.hiddenTaskIds.remove(recordId)
        } else {
            preferences.hiddenTaskIds.insert(recordId)
        }
        savePreferences()
        reloadTasks()
    }

    @objc private func toggleShowHiddenTasks() {
        showingHiddenTasks.toggle()
        reloadTasks()
    }

    @objc private func completeTask(_ sender: NSButton) {
        guard let recordId = (sender as? AimeActionButton)?.payload else { return }
        runSyncCommand(["complete", "--record-id", recordId])
        pullLatestTasks()
        reloadTasks()
    }

    @objc private func rescheduleTask(_ sender: NSButton) {
        guard let recordId = (sender as? AimeActionButton)?.payload else { return }
        guard let dueDate = chooseDueDate() else { return }
        runSyncCommand(["reschedule", "--record-id", recordId, "--due-date", dueDate])
        pullLatestTasks()
        reloadTasks()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func resolveTaskFeedPath() -> String {
        if CommandLine.arguments.count > 1 {
            return CommandLine.arguments[1]
        }

        let currentDirectory = FileManager.default.currentDirectoryPath
        return "\(currentDirectory)/tmp/aime-tasks.json"
    }

    private func pullLatestTasks() {
        runSyncCommand(["pull", "--out", "tmp/aime-tasks.json"])
    }

    private func runSyncCommand(_ arguments: [String]) {
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
            }
        } catch {
            print("Aime sync command could not run: \(error.localizedDescription)")
        }
    }

    private func preferencesURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL
            .appendingPathComponent("AimeCompanion", isDirectory: true)
            .appendingPathComponent("local-preferences.json")
    }

    private func loadPreferences() -> LocalPreferences {
        let url = preferencesURL()
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(LocalPreferences.self, from: data)
        } catch {
            return LocalPreferences()
        }
    }

    private func savePreferences() {
        let url = preferencesURL()
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(preferences)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Aime local preferences could not be saved: \(error.localizedDescription)")
        }
    }

    private func chooseDueDate() -> String? {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = [.yearMonthDay, .hourMinute]
        picker.dateValue = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.widthAnchor.constraint(equalToConstant: 240).isActive = true

        let alert = NSAlert()
        alert.messageText = "选择新的截止时间"
        alert.informativeText = "会写回飞书 Base 的截止时间字段。"
        alert.accessoryView = picker
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: picker.dateValue)
    }

    private func frameForCurrentMode() -> NSRect {
        let size = isExpanded ? NSSize(width: 460, height: 650) : NSSize(width: 120, height: 104)
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(
            x: visibleFrame.maxX - size.width - 32,
            y: visibleFrame.maxY - size.height - 48,
            width: size.width,
            height: size.height
        )
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
