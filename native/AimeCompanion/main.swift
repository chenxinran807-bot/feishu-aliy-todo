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

final class AimeActionButton: NSButton {
    var payload: String = ""
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var rootStack: NSStackView!
    private var taskFeedPath: String = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        taskFeedPath = resolveTaskFeedPath()

        let frame = initialWidgetFrame()
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
        window.title = "Aime"
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
        let overdueTasks = openTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < todayKey()
        }
        let todayTasks = openTasks.filter { $0.dueDate == todayKey() }
        let nextTask = overdueTasks.first ?? todayTasks.first ?? openTasks.first

        rootStack.addArrangedSubview(headerRow(openCount: openTasks.count, overdueCount: overdueTasks.count))
        rootStack.addArrangedSubview(nextTaskView(nextTask))
        rootStack.addArrangedSubview(projectProgressView(tasks: tasks, projectName: "AI试穿"))
        rootStack.addArrangedSubview(projectProgressView(tasks: tasks, projectName: "AI穿搭"))
        rootStack.addArrangedSubview(footerView(tasksCount: tasks.count))
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
        titleStack.addArrangedSubview(label("Aime 桌面端", size: 12, weight: .medium, color: mutedColor()))
        titleStack.addArrangedSubview(summary)

        row.addArrangedSubview(orb)
        row.addArrangedSubview(titleStack)
        return row
    }

    private func nextTaskView(_ task: AimeTask?) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.addArrangedSubview(label("下一件事", size: 12, weight: .medium, color: mutedColor()))

        if let task {
            stack.addArrangedSubview(label(task.title, size: 14, weight: .semibold))
            stack.addArrangedSubview(label("\(task.project ?? "未分类") · \(task.dueDate ?? "无截止日期")", size: 12, color: mutedColor()))
            stack.addArrangedSubview(actionRow(for: task))
        } else {
            stack.addArrangedSubview(label("目前没有未完成任务", size: 14, weight: .semibold))
        }
        return card(stack)
    }

    private func actionRow(for task: AimeTask) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        if let sourceUrl = task.sourceUrl, !sourceUrl.isEmpty {
            row.addArrangedSubview(actionButton("打开", representedObject: sourceUrl, action: #selector(openTaskSource(_:))))
        }
        row.addArrangedSubview(actionButton("明天", representedObject: task.id, action: #selector(moveTaskToTomorrow(_:))))
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
        progress.widthAnchor.constraint(equalToConstant: 320).isActive = true

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(progress)
        stack.addArrangedSubview(label("auto from \(doneCount)/\(projectTasks.count) tasks", size: 11, color: mutedColor()))
        return stack
    }

    private func footerView(tasksCount: Int) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        let refresh = NSButton(title: "刷新", target: self, action: #selector(refreshClicked))
        refresh.bezelStyle = .rounded
        refresh.controlSize = .small

        row.addArrangedSubview(label("\(tasksCount) tasks from Aime Base", size: 11, color: mutedColor()))
        row.addArrangedSubview(refresh)
        return row
    }

    private func card(_ content: NSView) -> NSView {
        let wrapper = NSView()
        wrapper.wantsLayer = true
        wrapper.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.72).cgColor
        wrapper.layer?.cornerRadius = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(content)

        NSLayoutConstraint.activate([
            wrapper.widthAnchor.constraint(equalToConstant: 340),
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
        statusItem.button?.title = "Aime"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Widget", action: #selector(showWidget), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(refreshClicked), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func showWidget() {
        window.setFrame(initialWidgetFrame(), display: true, animate: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func refreshClicked() {
        pullLatestTasks()
        reloadTasks()
        showWidget()
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

    @objc private func completeTask(_ sender: NSButton) {
        guard let recordId = (sender as? AimeActionButton)?.payload else { return }
        runSyncCommand(["complete", "--record-id", recordId])
        pullLatestTasks()
        reloadTasks()
    }

    @objc private func moveTaskToTomorrow(_ sender: NSButton) {
        guard let recordId = (sender as? AimeActionButton)?.payload else { return }
        runSyncCommand(["reschedule", "--record-id", recordId, "--due-date", tomorrowKey()])
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

    private func tomorrowKey() -> String {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: tomorrow)
    }

    private func initialWidgetFrame() -> NSRect {
        let size = NSSize(width: 420, height: 330)
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
