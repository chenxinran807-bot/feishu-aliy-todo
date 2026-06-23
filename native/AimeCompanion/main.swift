import AppKit
import Foundation
import Vision

final class AimeActionButton: NSButton {
    var payload: String = ""
}

final class AimeMenuItem: NSMenuItem {
    var payload: String = ""
}

final class AimeMenuButton: NSButton {
    var payload: String = ""
}

final class ResizeHandleView: NSView {
    var onResizeEnded: (() -> Void)?
    private var initialMouseLocation: NSPoint = .zero
    private var initialFrame: NSRect = .zero

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.secondaryLabelColor.withAlphaComponent(0.5).setStroke()
        let path = NSBezierPath()
        for offset in stride(from: 5, through: 15, by: 5) {
            path.move(to: NSPoint(x: bounds.maxX - CGFloat(offset), y: 4))
            path.line(to: NSPoint(x: bounds.maxX - 4, y: CGFloat(offset)))
        }
        path.lineWidth = 1.2
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = NSEvent.mouseLocation
        initialFrame = window?.frame ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let currentLocation = NSEvent.mouseLocation
        let deltaX = currentLocation.x - initialMouseLocation.x
        let deltaY = currentLocation.y - initialMouseLocation.y
        let minSize = window.minSize
        let maxSize = window.maxSize
        let width = min(max(initialFrame.width + deltaX, minSize.width), maxSize.width)
        let height = min(max(initialFrame.height - deltaY, minSize.height), maxSize.height)
        let frame = NSRect(
            x: initialFrame.minX,
            y: initialFrame.maxY - height,
            width: width,
            height: height
        )
        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        onResizeEnded?()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let defaultBaseURL = "https://bytedance.larkoffice.com/base/F4k1bKUkRaIafPsKxP2cVAyEnwJ?table=tblllGcOFXODLI5I&view=vewBgeF8ZA"
    private let defaultAimeAssistantURL = "https://applink.feishu.cn/client/chat/open?openChatId=oc_31661171e477fd90c1d62de8e2f1a84d"

    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var containerView: NSVisualEffectView!
    private var rootStack: NSStackView!
    private var taskFeedPath: String = ""
    private var preferences = LocalPreferences()
    private var showingHiddenTasks = false
    private var isExpanded = false
    private var autoRefreshTimer: Timer?
    private var screenMonitorTimer: Timer?
    private var lastRecognizedScreenText = ""
    private var lastKnownTaskCount = 0
    private var lastKnownOverdueCount = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        taskFeedPath = resolveTaskFeedPath()
        preferences = loadPreferences()

        let frame = frameForCurrentMode()
        window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = true
        window.delegate = self
        window.title = "Aime Task Companion"
        window.contentView = buildContentView(frame: frame)

        updateWindowResizeBounds()
        reloadTasks()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        createStatusItem()
        startAutoRefresh()
    }

    private func buildContentView(frame: NSRect) -> NSView {
        let container = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.masksToBounds = true
        container.autoresizingMask = [.width, .height]
        containerView = container
        applyWindowStyle()

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

    private func applyWindowStyle() {
        guard let containerView else { return }
        containerView.material = windowMaterial()
        containerView.layer?.cornerRadius = panelCornerRadius()
    }

    private func reloadTasks() {
        let tasks = loadTasks()
        rootStack.arrangedSubviews.forEach { view in
            rootStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let actionableTasks = tasks.filter { isActionableStatus($0.status) }
        let filteredTasks = applyFilters(tasks)
        let visibleTasks = filteredTasks.filter { task in
            showingHiddenTasks || !preferences.hiddenTaskIds.contains(task.id)
        }
        let overdueTasks = actionableTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < todayKey()
        }
        let sortedTasks = sortTasks(visibleTasks)
        lastKnownTaskCount = tasks.count
        lastKnownOverdueCount = overdueTasks.count

        if !isExpanded {
            rootStack.addArrangedSubview(compactWidget(openCount: actionableTasks.count, overdueCount: overdueTasks.count))
            return
        }

        rootStack.addArrangedSubview(headerRow(openCount: actionableTasks.count, overdueCount: overdueTasks.count))
        if let statusView = styleStatusView(openCount: actionableTasks.count, overdueCount: overdueTasks.count) {
            rootStack.addArrangedSubview(statusView)
        }
        rootStack.addArrangedSubview(filterView(tasks: tasks))
        rootStack.addArrangedSubview(taskListView(sortedTasks))
        rootStack.addArrangedSubview(resizeHandle())
    }

    private func resizeHandle() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 0

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.widthAnchor.constraint(equalToConstant: max(0, contentWidth() - 26)).isActive = true

        let handle = ResizeHandleView(frame: NSRect(x: 0, y: 0, width: 22, height: 18))
        handle.translatesAutoresizingMaskIntoConstraints = false
        handle.widthAnchor.constraint(equalToConstant: 22).isActive = true
        handle.heightAnchor.constraint(equalToConstant: 18).isActive = true
        handle.onResizeEnded = { [weak self] in
            guard let self else { return }
            self.saveExpandedPanelSize()
            self.reloadTasks()
        }

        row.addArrangedSubview(spacer)
        row.addArrangedSubview(handle)
        return row
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

        let orb = label(avatarText(), size: 16, weight: .bold, color: avatarTextColor())
        orb.alignment = .center
        orb.wantsLayer = true
        orb.layer?.backgroundColor = avatarColor().cgColor
        orb.layer?.cornerRadius = avatarCornerRadius(size: 40)
        orb.widthAnchor.constraint(equalToConstant: 40).isActive = true
        orb.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let summaryText = compactSummaryText(openCount: openCount, overdueCount: overdueCount)
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

    private func compactSummaryText(openCount: Int, overdueCount: Int) -> String {
        if preferences.displayStyle == "cute" {
            return overdueCount > 0 ? "催你啦 \(overdueCount)" : "陪你做 \(openCount)"
        }
        return overdueCount > 0 ? "\(overdueCount) 逾期" : "\(openCount) 待办"
    }

    private func styleStatusView(openCount: Int, overdueCount: Int) -> NSView? {
        if preferences.displayStyle == "minimal" { return nil }

        let text: String
        if preferences.displayStyle == "cute" {
            text = overdueCount > 0
                ? "Aime 正在轻轻提醒你：有 \(overdueCount) 件快来处理"
                : "Aime 陪你盯着 \(openCount) 件事，慢慢来"
        } else {
            text = overdueCount > 0
                ? "Focus: \(overdueCount) overdue needs attention"
                : "Focus: \(openCount) active tasks"
        }

        let pill = label(text, size: 11, weight: .medium, color: styleStatusTextColor())
        pill.wantsLayer = true
        pill.layer?.backgroundColor = styleStatusBackgroundColor().cgColor
        pill.layer?.cornerRadius = preferences.displayStyle == "cute" ? 12 : 7
        return padded(pill, width: contentWidth(), vertical: preferences.displayStyle == "cute" ? 7 : 5)
    }

    private func applyFilters(_ tasks: [AimeTask]) -> [AimeTask] {
        tasks.filter { task in
            let priority = preferences.priorityByTaskId[task.id] ?? "P2"
            let project = task.project ?? "未分类"
            let statusMatches = preferences.statusFilter == "all"
                || (preferences.statusFilter == "open" && isActionableStatus(task.status))
                || task.status == preferences.statusFilter
            let priorityMatches = preferences.priorityFilter == "all" || priority == preferences.priorityFilter
            let projectMatches = preferences.projectFilter == "all" || project == preferences.projectFilter
            return statusMatches && priorityMatches && projectMatches
        }
    }

    private func isActionableStatus(_ status: String) -> Bool {
        status != "done" && status != "ignored"
    }

    private func sortTasks(_ tasks: [AimeTask]) -> [AimeTask] {
        tasks.sorted { left, right in
            let leftPinned = preferences.pinnedTaskIds.contains(left.id)
            let rightPinned = preferences.pinnedTaskIds.contains(right.id)
            if leftPinned != rightPinned {
                return leftPinned
            }

            let leftPriority = priorityRank(preferences.priorityByTaskId[left.id] ?? "P2")
            let rightPriority = priorityRank(preferences.priorityByTaskId[right.id] ?? "P2")
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }

            let leftDate = left.dueDate ?? "9999-12-31"
            let rightDate = right.dueDate ?? "9999-12-31"
            if leftDate == rightDate {
                return left.title < right.title
            }
            return leftDate < rightDate
        }
    }

    private func priorityRank(_ priority: String) -> Int {
        switch priority {
        case "P0": return 0
        case "P1": return 1
        default: return 2
        }
    }

    private func headerRow(openCount: Int, overdueCount: Int) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10

        let orb = label(avatarText(), size: 17, weight: .bold, color: avatarTextColor())
        orb.alignment = .center
        orb.wantsLayer = true
        orb.layer?.backgroundColor = avatarColor().cgColor
        orb.layer?.cornerRadius = avatarCornerRadius(size: 44)
        orb.widthAnchor.constraint(equalToConstant: 44).isActive = true
        orb.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let summary = label("\(openCount) open · \(overdueCount) overdue", size: 17, weight: .semibold)
        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.spacing = 2
        titleStack.addArrangedSubview(label(styleTitle(), size: 12, weight: .medium, color: mutedColor()))
        titleStack.addArrangedSubview(summary)

        let collapse = NSButton(title: "收起", target: self, action: #selector(collapseWidget))
        collapse.bezelStyle = .rounded
        collapse.controlSize = .small

        let more = menuButton(title: "更多", action: #selector(showHeaderMoreMenu(_:)))

        row.addArrangedSubview(orb)
        row.addArrangedSubview(titleStack)
        row.addArrangedSubview(more)
        row.addArrangedSubview(collapse)
        return row
    }

    private func menuButton(title: String, action: Selector, payload: String = "") -> AimeMenuButton {
        let button = AimeMenuButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.payload = payload
        return button
    }

    private func addMenuItem(_ title: String, to menu: NSMenu, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    private func filterView(tasks: [AimeTask]) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        row.addArrangedSubview(label("筛选", size: 11, weight: .medium, color: mutedColor()))
        row.addArrangedSubview(popup(
            items: [("全部优先级", "all"), ("P0", "P0"), ("P1", "P1"), ("P2", "P2")],
            selected: preferences.priorityFilter,
            action: #selector(priorityFilterChanged(_:))
        ))

        let projects = Array(Set(tasks.map { $0.project ?? "未分类" })).sorted()
        let projectItems = [("全部分类", "all")] + projects.map { ($0, $0) }
        row.addArrangedSubview(popup(
            items: projectItems,
            selected: preferences.projectFilter,
            action: #selector(projectFilterChanged(_:))
        ))

        row.addArrangedSubview(popup(
            items: [("未完成", "open"), ("已完成", "done"), ("已忽略", "ignored"), ("全部状态", "all")],
            selected: preferences.statusFilter,
            action: #selector(statusFilterChanged(_:))
        ))

        return row
    }

    private func popup(items: [(String, String)], selected: String, action: Selector) -> NSPopUpButton {
        let popup = NSPopUpButton()
        popup.controlSize = .small
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.widthAnchor.constraint(equalToConstant: filterWidth()).isActive = true
        popup.target = self
        popup.action = action
        items.forEach { title, value in
            popup.addItem(withTitle: title)
            popup.lastItem?.representedObject = value
        }
        if let index = items.firstIndex(where: { $0.1 == selected }) {
            popup.selectItem(at: index)
        }
        return popup
    }

    private func taskListView(_ tasks: [AimeTask]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.addArrangedSubview(label("待办", size: 12, weight: .medium, color: mutedColor()))

        if tasks.isEmpty {
            stack.addArrangedSubview(card(label("当前筛选下没有任务", size: 14, weight: .semibold), width: contentWidth()))
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
            scrollView.widthAnchor.constraint(equalToConstant: scrollWidth()),
            scrollView.heightAnchor.constraint(equalToConstant: scrollHeight()),
            documentStack.widthAnchor.constraint(equalToConstant: contentWidth()),
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
        let priority = preferences.priorityByTaskId[task.id] ?? "P2"
        let statePrefix = [
            isPinned ? "★置顶" : nil,
            priority,
            isHidden ? "隐藏" : nil,
        ].compactMap { $0 }.joined(separator: " · ")
        let title = statePrefix.isEmpty ? task.title : "\(statePrefix) · \(task.title)"

        stack.addArrangedSubview(label(title, size: 13, weight: isPinned ? .bold : .semibold, color: titleColor(priority: priority, isPinned: isPinned)))
        stack.addArrangedSubview(label("\(task.project ?? "未分类") · \(task.dueDate ?? "无截止日期")", size: 11, color: mutedColor()))
        stack.addArrangedSubview(actionRow(for: task))
        return card(stack, width: contentWidth(), priority: priority, isPinned: isPinned)
    }

    private func contentWidth() -> CGFloat {
        guard isExpanded else { return 88 }
        return max(220, window.frame.width - 62)
    }

    private func scrollWidth() -> CGFloat {
        contentWidth() + 14
    }

    private func scrollHeight() -> CGFloat {
        guard isExpanded else { return 0 }
        return max(96, window.frame.height - 200)
    }

    private func filterWidth() -> CGFloat {
        guard isExpanded else { return 96 }
        return window.frame.width < 330 ? 74 : 106
    }

    private func actionRow(for task: AimeTask) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        row.addArrangedSubview(actionButton("完成", representedObject: task.id, action: #selector(completeTask(_:))))
        row.addArrangedSubview(actionButton("改时间", representedObject: task.id, action: #selector(rescheduleTask(_:))))
        row.addArrangedSubview(menuButton(title: "更多", action: #selector(showTaskMoreMenu(_:)), payload: task.id))
        return row
    }

    private func addPayloadMenuItem(_ title: String, payload: String, to menu: NSMenu, action: Selector) {
        let item = AimeMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.payload = payload
        menu.addItem(item)
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

    private func card(_ content: NSView, width: CGFloat = 388, priority: String = "P2", isPinned: Bool = false) -> NSView {
        let wrapper = NSView()
        wrapper.wantsLayer = true
        wrapper.layer?.backgroundColor = cardColor(priority: priority, isPinned: isPinned).cgColor
        wrapper.layer?.cornerRadius = cardCornerRadius()
        wrapper.layer?.borderWidth = isPinned || priority == "P0" ? 2 : 0
        wrapper.layer?.borderColor = borderColor(priority: priority, isPinned: isPinned).cgColor
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

    private func padded(_ content: NSView, width: CGFloat, vertical: CGFloat) -> NSView {
        let wrapper = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(content)
        NSLayoutConstraint.activate([
            wrapper.widthAnchor.constraint(equalToConstant: width),
            content.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 10),
            content.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -10),
            content.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: vertical),
            content.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -vertical),
        ])
        return wrapper
    }

    private func cardColor(priority: String, isPinned: Bool) -> NSColor {
        if preferences.displayStyle == "cute" {
            if isPinned { return NSColor(calibratedRed: 1, green: 0.92, blue: 0.72, alpha: 0.95) }
            if priority == "P0" { return NSColor(calibratedRed: 1, green: 0.84, blue: 0.88, alpha: 0.94) }
            if priority == "P1" { return NSColor(calibratedRed: 0.86, green: 0.95, blue: 1, alpha: 0.92) }
            return NSColor(calibratedRed: 0.98, green: 0.95, blue: 1, alpha: 0.82)
        }
        if preferences.displayStyle == "minimal" {
            if isPinned { return NSColor.white.withAlphaComponent(0.9) }
            if priority == "P0" { return NSColor(calibratedWhite: 1, alpha: 0.88) }
            return NSColor.white.withAlphaComponent(0.72)
        }
        if isPinned { return NSColor(calibratedRed: 1, green: 0.96, blue: 0.76, alpha: 0.92) }
        if priority == "P0" { return NSColor(calibratedRed: 1, green: 0.88, blue: 0.86, alpha: 0.9) }
        if priority == "P1" { return NSColor(calibratedRed: 0.9, green: 0.95, blue: 1, alpha: 0.85) }
        return NSColor.white.withAlphaComponent(0.72)
    }

    private func cardCornerRadius() -> CGFloat {
        switch preferences.displayStyle {
        case "minimal": return 5
        case "cute": return 16
        default: return 9
        }
    }

    private func panelCornerRadius() -> CGFloat {
        switch preferences.displayStyle {
        case "minimal": return 10
        case "cute": return 24
        default: return 18
        }
    }

    private func windowMaterial() -> NSVisualEffectView.Material {
        switch preferences.displayStyle {
        case "minimal": return .underWindowBackground
        case "cute": return .popover
        default: return .hudWindow
        }
    }

    private func avatarText() -> String {
        switch preferences.displayStyle {
        case "minimal": return "A"
        case "cute": return "Ai"
        default: return "Ai"
        }
    }

    private func avatarColor() -> NSColor {
        switch preferences.displayStyle {
        case "minimal": return NSColor(calibratedWhite: 0.16, alpha: 1)
        case "cute": return NSColor(calibratedRed: 0.95, green: 0.45, blue: 0.68, alpha: 1)
        default: return NSColor(calibratedRed: 0.14, green: 0.36, blue: 0.32, alpha: 1)
        }
    }

    private func avatarTextColor() -> NSColor {
        preferences.displayStyle == "cute" ? NSColor.white : NSColor.white
    }

    private func avatarCornerRadius(size: CGFloat) -> CGFloat {
        switch preferences.displayStyle {
        case "minimal": return 8
        case "cute": return size / 2
        default: return size / 2
        }
    }

    private func styleTitle() -> String {
        switch preferences.displayStyle {
        case "minimal": return "Aime"
        case "cute": return "Aime 陪伴"
        default: return "任务伴随"
        }
    }

    private func styleStatusBackgroundColor() -> NSColor {
        switch preferences.displayStyle {
        case "cute": return NSColor(calibratedRed: 1, green: 0.88, blue: 0.94, alpha: 0.88)
        default: return NSColor(calibratedRed: 0.82, green: 0.9, blue: 0.88, alpha: 0.52)
        }
    }

    private func styleStatusTextColor() -> NSColor {
        switch preferences.displayStyle {
        case "cute": return NSColor(calibratedRed: 0.52, green: 0.16, blue: 0.32, alpha: 1)
        default: return NSColor(calibratedRed: 0.12, green: 0.28, blue: 0.25, alpha: 1)
        }
    }

    private func borderColor(priority: String, isPinned: Bool) -> NSColor {
        if preferences.displayStyle == "minimal" {
            if isPinned { return NSColor.secondaryLabelColor }
            if priority == "P0" { return NSColor.systemRed.withAlphaComponent(0.7) }
            return NSColor.clear
        }
        if isPinned { return NSColor(calibratedRed: 0.9, green: 0.62, blue: 0.05, alpha: 1) }
        if priority == "P0" { return NSColor.systemRed }
        return NSColor.clear
    }

    private func titleColor(priority: String, isPinned: Bool) -> NSColor {
        if isPinned { return NSColor(calibratedRed: 0.38, green: 0.25, blue: 0.02, alpha: 1) }
        if priority == "P0" { return NSColor.systemRed }
        return NSColor.labelColor
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
        updateWindowResizeBounds()
        window.setFrame(frameForCurrentMode(), display: true, animate: true)
        reloadTasks()
        showWidget()
    }

    @objc private func collapseWidget() {
        saveExpandedPanelSize()
        isExpanded = false
        updateWindowResizeBounds()
        window.setFrame(frameForCurrentMode(), display: true, animate: true)
        reloadTasks()
        showWidget()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard isExpanded else { return }
        saveExpandedPanelSize()
        reloadTasks()
    }

    private func saveExpandedPanelSize() {
        guard isExpanded else { return }
        preferences.expandedPanelWidth = Double(window.frame.width)
        preferences.expandedPanelHeight = Double(window.frame.height)
        savePreferences()
    }

    private func updateWindowResizeBounds() {
        if isExpanded {
            window.minSize = NSSize(width: 280, height: 280)
            window.maxSize = NSSize(width: 760, height: 900)
        } else {
            window.minSize = NSSize(width: 120, height: 104)
            window.maxSize = NSSize(width: 120, height: 104)
        }
    }

    @objc private func refreshClicked() {
        pullLatestTasks()
        reloadTasks()
        showWidget()
    }

    @objc private func showHeaderMoreMenu(_ sender: AimeMenuButton) {
        let menu = NSMenu()
        addMenuItem("新增待办", to: menu, action: #selector(addTaskClicked))
        addMenuItem("识别屏幕", to: menu, action: #selector(captureScreenClicked))
        addMenuItem(screenMonitorTimer == nil ? "开始实时识别" : "停止实时识别", to: menu, action: #selector(toggleScreenMonitor))
        menu.addItem(NSMenuItem.separator())
        addMenuItem("打开多维表格", to: menu, action: #selector(openAimeBase))
        addMenuItem("打开 Aime 助手", to: menu, action: #selector(openAimeAssistant))
        menu.addItem(NSMenuItem.separator())
        addPayloadMenuItem("风格：简洁", payload: "minimal", to: menu, action: #selector(changeDisplayStyle(_:)))
        addPayloadMenuItem("风格：精致", payload: "refined", to: menu, action: #selector(changeDisplayStyle(_:)))
        addPayloadMenuItem("风格：可爱", payload: "cute", to: menu, action: #selector(changeDisplayStyle(_:)))
        menu.addItem(NSMenuItem.separator())
        addMenuItem(showingHiddenTasks ? "收起隐藏任务" : "显示隐藏任务", to: menu, action: #selector(toggleShowHiddenTasks))
        addMenuItem("重置面板尺寸", to: menu, action: #selector(resetExpandedPanelSize))
        addMenuItem("刷新", to: menu, action: #selector(refreshClicked))
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 2), in: sender)
    }

    @objc private func showTaskMoreMenu(_ sender: AimeMenuButton) {
        let tasks = loadTasks()
        guard let task = tasks.first(where: { $0.id == sender.payload }) else { return }

        let menu = NSMenu()
        if let sourceUrl = task.sourceUrl, !sourceUrl.isEmpty {
            addPayloadMenuItem("打开来源", payload: sourceUrl, to: menu, action: #selector(openTaskSourceFromMenu(_:)))
            menu.addItem(NSMenuItem.separator())
        }

        addPayloadMenuItem(preferences.pinnedTaskIds.contains(task.id) ? "取消置顶" : "置顶", payload: task.id, to: menu, action: #selector(togglePinTaskFromMenu(_:)))
        menu.addItem(NSMenuItem.separator())
        ["P0", "P1", "P2"].forEach { priority in
            addPayloadMenuItem("标记 \(priority)", payload: "\(task.id)|\(priority)", to: menu, action: #selector(priorityChangedFromMenu(_:)))
        }
        menu.addItem(NSMenuItem.separator())
        addPayloadMenuItem(preferences.hiddenTaskIds.contains(task.id) ? "取消隐藏" : "隐藏", payload: task.id, to: menu, action: #selector(toggleHideTaskFromMenu(_:)))
        addPayloadMenuItem("忽略", payload: task.id, to: menu, action: #selector(ignoreTaskFromMenu(_:)))
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 2), in: sender)
    }

    private func startAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.performAutoRefresh()
        }
    }

    private func performAutoRefresh() {
        let previousTaskCount = lastKnownTaskCount
        let previousOverdueCount = lastKnownOverdueCount
        pullLatestTasks()
        reloadTasks()
        notifyIfTaskStateChanged(previousTaskCount: previousTaskCount, previousOverdueCount: previousOverdueCount)
    }

    private func notifyIfTaskStateChanged(previousTaskCount: Int, previousOverdueCount: Int) {
        if lastKnownTaskCount > previousTaskCount {
            showStatusNotification(
                title: preferences.displayStyle == "cute" ? "Aime 捡到新待办啦" : "Aime 有新待办",
                body: "新增 \(lastKnownTaskCount - previousTaskCount) 个待办，点开看看。"
            )
        } else if lastKnownOverdueCount > previousOverdueCount {
            showStatusNotification(
                title: preferences.displayStyle == "cute" ? "有任务在轻轻催你" : "有任务已逾期",
                body: "现在有 \(lastKnownOverdueCount) 个逾期待办。"
            )
        }
    }

    private func showStatusNotification(title: String, body: String) {
        NSSound(named: NSSound.Name("Glass"))?.play()
        if isExpanded {
            showMessage(title, detail: body)
        }
    }

    @objc private func addTaskClicked() {
        guard let draft = taskDraftDialog(title: "新增待办", initialText: "") else { return }
        createTask(title: draft.title, dueDate: draft.dueDate, project: draft.project)
    }

    @objc private func captureScreenClicked() {
        scanScreenForTasks(dialogTitle: "从屏幕识别待办", skipDuplicate: false)
    }

    @objc private func toggleScreenMonitor() {
        if screenMonitorTimer == nil {
            lastRecognizedScreenText = ""
            screenMonitorTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in
                self?.scanScreenForTasks(dialogTitle: "实时识别到可能待办", skipDuplicate: true)
            }
            scanScreenForTasks(dialogTitle: "实时识别到可能待办", skipDuplicate: true)
        } else {
            screenMonitorTimer?.invalidate()
            screenMonitorTimer = nil
        }
        reloadTasks()
    }

    @objc private func resetExpandedPanelSize() {
        preferences.expandedPanelWidth = 320
        preferences.expandedPanelHeight = 420
        savePreferences()
        guard isExpanded else { return }
        window.setFrame(frameForCurrentMode(), display: true, animate: true)
        reloadTasks()
    }

    private func scanScreenForTasks(dialogTitle: String, skipDuplicate: Bool) {
        let screenshotURL = captureCurrentScreen()
        guard let screenshotURL else {
            showMessage("无法截取屏幕", detail: "请确认系统已允许屏幕录制权限。")
            return
        }

        let recognizedText = recognizeText(in: screenshotURL)
        let compactText = compactTaskTitle(recognizedText)
        guard !compactText.isEmpty else { return }
        if skipDuplicate {
            guard compactText != lastRecognizedScreenText else { return }
        }
        lastRecognizedScreenText = compactText

        guard let draft = taskDraftDialog(title: dialogTitle, initialText: recognizedText) else { return }
        createTask(title: draft.title, dueDate: draft.dueDate, project: draft.project)
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

    @objc private func openTaskSourceFromMenu(_ sender: AimeMenuItem) {
        openURLString(sender.payload)
    }

    private func openURLString(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func togglePinTask(_ sender: NSButton) {
        guard let recordId = (sender as? AimeActionButton)?.payload else { return }
        togglePin(recordId: recordId)
    }

    @objc private func togglePinTaskFromMenu(_ sender: AimeMenuItem) {
        togglePin(recordId: sender.payload)
    }

    @objc private func toggleHideTask(_ sender: NSButton) {
        guard let recordId = (sender as? AimeActionButton)?.payload else { return }
        toggleHide(recordId: recordId)
    }

    @objc private func toggleHideTaskFromMenu(_ sender: AimeMenuItem) {
        toggleHide(recordId: sender.payload)
    }

    private func togglePin(recordId: String) {
        if preferences.pinnedTaskIds.contains(recordId) {
            preferences.pinnedTaskIds.remove(recordId)
        } else {
            preferences.pinnedTaskIds.insert(recordId)
        }
        savePreferences()
        reloadTasks()
    }

    private func toggleHide(recordId: String) {
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

    @objc private func changeDisplayStyle(_ sender: AimeMenuItem) {
        preferences.displayStyle = sender.payload
        savePreferences()
        applyWindowStyle()
        reloadTasks()
    }

    @objc private func priorityChangedFromMenu(_ sender: AimeMenuItem) {
        guard let separator = sender.payload.firstIndex(of: "|") else { return }
        let recordId = String(sender.payload[..<separator])
        let priority = String(sender.payload[sender.payload.index(after: separator)...])
        preferences.priorityByTaskId[recordId] = priority
        savePreferences()
        reloadTasks()
    }

    @objc private func priorityFilterChanged(_ sender: NSPopUpButton) {
        preferences.priorityFilter = selectedPopupValue(sender)
        savePreferences()
        reloadTasks()
    }

    @objc private func projectFilterChanged(_ sender: NSPopUpButton) {
        preferences.projectFilter = selectedPopupValue(sender)
        savePreferences()
        reloadTasks()
    }

    @objc private func statusFilterChanged(_ sender: NSPopUpButton) {
        preferences.statusFilter = selectedPopupValue(sender)
        savePreferences()
        reloadTasks()
    }

    @objc private func completeTask(_ sender: NSButton) {
        guard let recordId = (sender as? AimeActionButton)?.payload else { return }
        runSyncCommand(["complete", "--record-id", recordId])
        pullLatestTasks()
        reloadTasks()
    }

    @objc private func ignoreTask(_ sender: NSButton) {
        guard let recordId = (sender as? AimeActionButton)?.payload else { return }
        ignore(recordId: recordId)
    }

    @objc private func ignoreTaskFromMenu(_ sender: AimeMenuItem) {
        ignore(recordId: sender.payload)
    }

    private func ignore(recordId: String) {
        runSyncCommand(["ignore", "--record-id", recordId])
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
        autoRefreshTimer?.invalidate()
        screenMonitorTimer?.invalidate()
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

    private func createTask(title: String, dueDate: String?, project: String?) {
        var arguments = ["create", "--title", title]
        if let dueDate, !dueDate.isEmpty {
            arguments += ["--due-date", dueDate]
        }
        if let project, !project.isEmpty {
            arguments += ["--project", project]
        }
        runSyncCommand(arguments)
        pullLatestTasks()
        reloadTasks()
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

    private func selectedPopupValue(_ sender: NSPopUpButton) -> String {
        sender.selectedItem?.representedObject as? String ?? "all"
    }

    private struct TaskDraft {
        let title: String
        let dueDate: String?
        let project: String?
    }

    private func taskDraftDialog(title: String, initialText: String) -> TaskDraft? {
        var result: TaskDraft?

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 285),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.center()

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = content

        let heading = label(title, size: 17, weight: .semibold)
        heading.translatesAutoresizingMaskIntoConstraints = false

        let note = label("保存后会写入飞书 Base。", size: 12, color: mutedColor())
        note.translatesAutoresizingMaskIntoConstraints = false

        let titleField = NSTextField(string: compactTaskTitle(initialText))
        titleField.placeholderString = "待办标题"
        titleField.translatesAutoresizingMaskIntoConstraints = false

        let duePicker = NSDatePicker()
        duePicker.datePickerStyle = .textFieldAndStepper
        duePicker.datePickerElements = [.yearMonthDay, .hourMinute]
        duePicker.dateValue = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        duePicker.translatesAutoresizingMaskIntoConstraints = false

        let projectField = NSTextField(string: "")
        projectField.placeholderString = "分类，可留空"
        projectField.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = label("标题", size: 11, color: mutedColor())
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let dueLabel = label("截止时间", size: 11, color: mutedColor())
        dueLabel.translatesAutoresizingMaskIntoConstraints = false
        let projectLabel = label("分类", size: 11, color: mutedColor())
        projectLabel.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = NSButton(title: "取消", target: nil, action: nil)
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        let saveButton = NSButton(title: "保存", target: nil, action: nil)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        [heading, note, titleLabel, titleField, dueLabel, duePicker, projectLabel, projectField, cancelButton, saveButton].forEach {
            content.addSubview($0)
        }

        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            heading.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),

            note.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            note.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 6),

            titleLabel.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: note.bottomAnchor, constant: 18),

            titleField.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            titleField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            titleField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            titleField.heightAnchor.constraint(equalToConstant: 28),

            dueLabel.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            dueLabel.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 12),

            duePicker.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            duePicker.topAnchor.constraint(equalTo: dueLabel.bottomAnchor, constant: 4),
            duePicker.widthAnchor.constraint(equalToConstant: 240),
            duePicker.heightAnchor.constraint(equalToConstant: 28),

            projectLabel.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            projectLabel.topAnchor.constraint(equalTo: duePicker.bottomAnchor, constant: 12),

            projectField.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            projectField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            projectField.topAnchor.constraint(equalTo: projectLabel.bottomAnchor, constant: 4),
            projectField.heightAnchor.constraint(equalToConstant: 28),

            saveButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            saveButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),
            saveButton.widthAnchor.constraint(equalToConstant: 96),

            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -10),
            cancelButton.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 96),
        ])

        cancelButton.target = self
        cancelButton.action = #selector(closeModalPanel(_:))
        cancelButton.tag = 0

        saveButton.target = self
        saveButton.action = #selector(closeModalPanel(_:))
        saveButton.tag = 1

        panel.makeFirstResponder(titleField)
        let response = NSApp.runModal(for: panel)

        if response == .OK {
            let taskTitle = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !taskTitle.isEmpty {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                result = TaskDraft(
                    title: taskTitle,
                    dueDate: formatter.string(from: duePicker.dateValue),
                    project: projectField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        }

        panel.close()
        return result
    }

    @objc private func closeModalPanel(_ sender: NSButton) {
        NSApp.stopModal(withCode: sender.tag == 1 ? .OK : .cancel)
    }

    private func compactTaskTitle(_ text: String) -> String {
        let collapsed = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: " / ")
        return String(collapsed.prefix(160))
    }

    private func captureCurrentScreen() -> URL? {
        let url = preferencesURL()
            .deletingLastPathComponent()
            .appendingPathComponent("screen-capture-\(Int(Date().timeIntervalSince1970)).png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", url.path]

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? url : nil
        } catch {
            return nil
        }
    }

    private func recognizeText(in imageURL: URL) -> String {
        guard
            let image = NSImage(contentsOf: imageURL),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return ""
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            let lines = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            return lines.prefix(8).joined(separator: "\n")
        } catch {
            return ""
        }
    }

    private func showMessage(_ title: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "知道了")
        alert.runModal()
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
        let expandedWidth = min(max(preferences.expandedPanelWidth, 280), 760)
        let expandedHeight = min(max(preferences.expandedPanelHeight, 280), 900)
        let size = isExpanded ? NSSize(width: expandedWidth, height: expandedHeight) : NSSize(width: 120, height: 104)
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
