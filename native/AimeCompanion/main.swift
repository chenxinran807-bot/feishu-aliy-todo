import AppKit
import Foundation
import Vision
import CoreGraphics

final class AimeActionButton: NSButton {
    var payload: String = ""
}

final class AimeMenuItem: NSMenuItem {
    var payload: String = ""
}

final class AimeMenuButton: NSButton {
    var payload: String = ""
}

final class AimePayloadNSView: NSView {
    var payload: String = ""
}

private enum NativeTaskGroup: String {
    case p0
    case overdue
    case open
}

final class PetDragButton: NSButton {
    var onDragEnded: ((NSPoint) -> Void)?
    private var didDrag = false
    private var mouseDownLocation: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        didDrag = false
        mouseDownLocation = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        let location = event.locationInWindow
        let deltaX = location.x - mouseDownLocation.x
        let deltaY = location.y - mouseDownLocation.y
        guard didDrag || hypot(deltaX, deltaY) > 4 else { return }
        didDrag = true
        if isEnabled {
            window?.performDrag(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled else { return }
        if didDrag {
            onDragEnded?(NSEvent.mouseLocation)
        } else {
            guard let target, let action else { return }
            NSApp.sendAction(action, to: target, from: self)
        }
    }
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
        NSColor.secondaryLabelColor.withAlphaComponent(0.65).setStroke()
        let path = NSBezierPath()
        for offset in stride(from: 7, through: 23, by: 8) {
            path.move(to: NSPoint(x: bounds.maxX - CGFloat(offset), y: 5))
            path.line(to: NSPoint(x: bounds.maxX - 5, y: CGFloat(offset)))
        }
        path.lineWidth = 1.6
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = NSEvent.mouseLocation
        initialFrame = window?.frame ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let currentLocation = NSEvent.mouseLocation
        let deltaX = (currentLocation.x - initialMouseLocation.x) * 1.35
        let deltaY = (currentLocation.y - initialMouseLocation.y) * 1.35
        let width = min(max(initialFrame.width + deltaX, window.minSize.width), window.maxSize.width)
        let height = min(max(initialFrame.height - deltaY, window.minSize.height), window.maxSize.height)
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
    private var setupProcess: Process?
    private var setupOutputData = Data()
    private var setupStateLabel: NSTextField?
    private var setupBindFailed = false
    private var setupBaseUrl: String?
    private var setupActionButton: NSButton?
    private var assistantIdField: NSTextField?
    private var autoRefreshTimer: Timer?
    private var assistantSignalTimer: Timer?
    private var assistantSignalCheckRunning = false
    private var screenMonitorTimer: Timer?
    private var petState = PetState()
    private var walkReturnTimer: Timer?
    private var lastRecognizedScreenText = ""
    private var lastKnownTaskCount = 0
    private var lastKnownOverdueCount = 0
    private var activeTaskGroup: NativeTaskGroup?
    private var messageBanner: NSView?
    private var messageDismissWorkItem: DispatchWorkItem?
    private var lastSyncDate: Date?
    private var lastSyncSucceeded = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        taskFeedPath = resolveTaskFeedPath()
        preferences = loadPreferences()
        migrateLegacyCutePanelSizeIfNeeded()
        petState = loadPetState()
        isExpanded = true

        let frame = frameForCurrentMode()
        window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.sharingType = .readOnly
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = true
        window.delegate = self
        window.title = "Aime Task Companion"
        window.contentView = buildContentView(frame: frame)

        updateWindowResizeBounds()
        if configFileExists() {
            pullLatestTasks()
            reloadTasks()
            startAutoRefresh()
        } else {
            showSetupView()
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        createStatusItem()
    }

    private func buildContentView(frame: NSRect) -> NSView {
        let container = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        container.blendingMode = .withinWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.masksToBounds = true
        container.autoresizingMask = [.width, .height]
        containerView = container
        applyWindowStyle()

        rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 8
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            rootStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            rootStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            rootStack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -12),
        ])

        return container
    }

    private func showSetupView() {
        rootStack.arrangedSubviews.forEach { view in
            rootStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let title = label("欢迎使用神仙待办", size: 16, weight: .bold)
        title.alignment = .center
        rootStack.addArrangedSubview(title)

        let subtitle = label("点击下面按钮，一键完成飞书授权、创建多维表格并绑定 Aime 助手。", size: 11, weight: .regular, color: .secondaryLabelColor)
        subtitle.alignment = .center
        rootStack.addArrangedSubview(subtitle)

        let button = NSButton(title: "一键配置", target: self, action: #selector(startSetup))
        button.bezelStyle = .rounded
        rootStack.addArrangedSubview(button)
        setupActionButton = button

        let stateLabel = label("等待开始", size: 11, weight: .regular, color: .secondaryLabelColor)
        stateLabel.alignment = .center
        stateLabel.lineBreakMode = .byWordWrapping
        stateLabel.maximumNumberOfLines = 4
        stateLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stateLabel.translatesAutoresizingMaskIntoConstraints = false
        stateLabel.widthAnchor.constraint(equalToConstant: contentWidth()).isActive = true
        rootStack.addArrangedSubview(stateLabel)
        setupStateLabel = stateLabel

        rootStack.needsLayout = true
        rootStack.layoutSubtreeIfNeeded()

        if ProcessInfo.processInfo.environment["AIME_AUTO_SETUP"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startSetup()
            }
        }
    }

    @objc private func startSetup() {
        guard setupProcess == nil else { return }
        updateSetupState("正在启动飞书授权…")
        runSetupCommand()
    }

    @objc private func copySetupBaseUrl() {
        guard let url = setupBaseUrl, !url.isEmpty else { return }
        let message = """
        这是我的待办多维表格，请帮我读取任务、标记完成、更新截止时间。
        Base 链接：\(url)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message, forType: .string)
        updateSetupState("Base 链接和引导语已复制到剪贴板。\n直接粘贴给 Aime 助理即可。")
    }

    @objc private func openLarkOpenPlatformApps() {
        openURLString("https://open.larkoffice.com/app/")
    }

    @objc private func copyAimeConfigCommand() {
        updateSetupState("正在生成 Aime 配置指令…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let (output, success) = self?.runSyncCommandReturningOutput(["print-aime-config"]) ?? ("", false)
            guard success else {
                DispatchQueue.main.async {
                    self?.updateSetupState("生成配置指令失败，请稍后重试。")
                }
                return
            }
            guard let data = output.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let text = json["text"] as? String, !text.isEmpty else {
                DispatchQueue.main.async {
                    self?.updateSetupState("生成配置指令失败，请稍后重试。")
                }
                return
            }
            DispatchQueue.main.async {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                self?.updateSetupState("Aime 配置指令已复制到剪贴板。\n直接粘贴给 Aime 助理即可。")
            }
        }
    }

    private func showAssistantBindingView(baseUrl: String) {
        rootStack.arrangedSubviews.forEach { view in
            rootStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let title = label("Base 已创建完成", size: 16, weight: .bold)
        title.alignment = .center
        rootStack.addArrangedSubview(title)

        let subtitle = label("Aime 助手需要在 Aime 页面创建；创建后去飞书开放平台查看应用详情，复制以 cli_ 开头的应用 ID 粘贴到下方。", size: 11, weight: .regular, color: .secondaryLabelColor)
        subtitle.alignment = .center
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.maximumNumberOfLines = 3
        subtitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.widthAnchor.constraint(equalToConstant: contentWidth()).isActive = true
        rootStack.addArrangedSubview(subtitle)

        let createButton = NSButton(title: "1. 去 Aime 页面创建助理", target: self, action: #selector(openAimeAssistantConfigPage))
        createButton.bezelStyle = .rounded
        rootStack.addArrangedSubview(createButton)

        let idButton = NSButton(title: "2. 去飞书开放平台查看应用 ID", target: self, action: #selector(openLarkOpenPlatformApps))
        idButton.bezelStyle = .rounded
        rootStack.addArrangedSubview(idButton)

        let input = NSTextField(string: "")
        input.placeholderString = "粘贴 Aime 助手应用 ID（cli_xxx）"
        input.bezelStyle = .roundedBezel
        input.translatesAutoresizingMaskIntoConstraints = false
        input.widthAnchor.constraint(equalToConstant: contentWidth()).isActive = true
        rootStack.addArrangedSubview(input)
        assistantIdField = input

        let bindButton = NSButton(title: "绑定 Aime 助手", target: self, action: #selector(bindAssistantFromInput))
        bindButton.bezelStyle = .rounded
        rootStack.addArrangedSubview(bindButton)
        setupActionButton = bindButton

        let copyButton = NSButton(title: "复制 Base 链接", target: self, action: #selector(copySetupBaseUrl))
        copyButton.bezelStyle = .rounded
        rootStack.addArrangedSubview(copyButton)

        let aimeConfigButton = NSButton(title: "复制 Aime 配置指令", target: self, action: #selector(copyAimeConfigCommand))
        aimeConfigButton.bezelStyle = .rounded
        rootStack.addArrangedSubview(aimeConfigButton)

        let stateLabel = label("等待输入", size: 11, weight: .regular, color: .secondaryLabelColor)
        stateLabel.alignment = .center
        stateLabel.lineBreakMode = .byWordWrapping
        stateLabel.maximumNumberOfLines = 4
        stateLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stateLabel.translatesAutoresizingMaskIntoConstraints = false
        stateLabel.widthAnchor.constraint(equalToConstant: contentWidth()).isActive = true
        rootStack.addArrangedSubview(stateLabel)
        setupStateLabel = stateLabel

        rootStack.needsLayout = true
        rootStack.layoutSubtreeIfNeeded()
    }

    @objc private func openAimeAssistantConfigPage() {
        openURLString("https://aime.bytedance.net/assistant")
    }

    @objc private func bindAssistantFromInput() {
        guard let input = assistantIdField, !input.stringValue.isEmpty else {
            updateSetupState("请先输入 Aime 助手 ID")
            return
        }
        let value = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard value.hasPrefix("cli_") || value.hasPrefix("ou_") || value.hasPrefix("oc_") else {
            updateSetupState("ID 格式不正确。请输入以 cli_、ou_ 或 oc_ 开头的 Aime 助手 ID。")
            return
        }
        let args = ["bind-assistant", "--assistant-id", value]

        updateSetupState("正在绑定 Aime 助手…")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let (output, success) = self?.runSyncCommandReturningOutput(args) ?? ("", false)
            DispatchQueue.main.async {
                if success && output.localizedStandardContains("\"ok\":true") {
                    self?.updateSetupState("绑定成功，正在加载…")
                    self?.pullLatestTasks()
                    self?.reloadTasks()
                    self?.startAutoRefresh()
                } else if output.localizedStandardContains("\"scopeMissing\":true") || output.localizedStandardContains("docs:permission.member:create") {
                    self?.updateSetupState("需要额外的飞书权限才能绑定助手。\n请在终端运行：\nlark-cli auth login --scope \"docs:permission.member:create\"\n授权后重试。")
                } else {
                    let reason = self?.parseBindFailureReason(output) ?? "绑定失败，请确认 ID 正确且已在 Aime 页面创建助理。"
                    self?.updateSetupState(reason)
                }
            }
        }
    }

    private func parseBindFailureReason(_ output: String) -> String {
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return "绑定失败，请确认 ID 正确且已在 Aime 页面创建助理。"
        }
        if let reason = json["reason"] as? String, !reason.isEmpty {
            return "绑定失败：\(reason)"
        }
        return "绑定失败，请确认 ID 正确且已在 Aime 页面创建助理。"
    }

    private func updateSetupState(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.setupStateLabel?.stringValue = text
        }
    }

    private func runSetupCommand() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        let syncScriptPath: String
        if let bundledPath = ProcessInfo.processInfo.environment["AIME_SYNC_SCRIPT_PATH"], !bundledPath.isEmpty {
            syncScriptPath = bundledPath
        } else {
            let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            syncScriptPath = repoRoot.appendingPathComponent("scripts/aime-lark-sync.mjs").path
        }

        process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        process.arguments = ["node", syncScriptPath, "setup"]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        setupOutputData = Data()
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                self?.setupOutputData.append(data)
                self?.handleSetupOutput(data)
            }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                    print("Aime setup stderr: \(text)")
                }
            }
        }

        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.handleSetupTermination(process)
            }
        }

        do {
            try process.run()
            setupProcess = process
        } catch {
            updateSetupState("启动失败：\(error.localizedDescription)")
            setupProcess = nil
        }
    }

    private func handleSetupOutput(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        for line in text.components(separatedBy: .newlines) where !line.isEmpty {
            if let json = try? JSONSerialization.jsonObject(with: Data(line.utf8), options: []) as? [String: Any] {
                handleSetupEvent(json)
            }
        }
    }

    private func handleSetupEvent(_ json: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let step = json["step"] as? String {
                switch step {
                case "awaiting_auth":
                    if let url = json["verificationUrl"] as? String {
                        self.updateSetupState("请在浏览器中完成飞书授权\n\(url)")
                        self.openURLString(url)
                    }
                case "creating_base":
                    self.updateSetupState("授权成功，正在创建多维表格…")
                case "binding_assistant":
                    self.updateSetupState("正在绑定 Aime 助手…")
                case "complete":
                    if let bindResult = json["bindResult"] as? [String: Any],
                       let bound = bindResult["bound"] as? Bool, !bound {
                        self.setupBindFailed = true
                        let baseUrl = (json["config"] as? [String: Any])?["baseUrl"] as? String ?? ""
                        self.setupBaseUrl = baseUrl
                        self.showAssistantBindingView(baseUrl: baseUrl)
                    } else {
                        self.updateSetupState("配置完成，正在加载…")
                    }
                case "already_configured":
                    self.updateSetupState("已配置完成，正在加载…")
                default:
                    break
                }
            }
        }
    }

    private func handleSetupTermination(_ process: Process) {
        setupProcess = nil

        if process.terminationStatus == 0 {
            if setupBindFailed {
                return
            }
            updateSetupState("配置成功")
            pullLatestTasks()
            reloadTasks()
            startAutoRefresh()
        } else {
            let text = String(data: setupOutputData, encoding: .utf8) ?? ""
            let isAuthFailure = text.localizedStandardContains("auth") ||
                text.localizedStandardContains("authorization") ||
                text.localizedStandardContains("token_missing") ||
                text.localizedStandardContains("need_user_authorization")
            if isAuthFailure {
                updateSetupState("授权失败或未在浏览器中确认。\n请点击下方按钮重新发起飞书授权。")
            } else {
                let reason = text.isEmpty ? "未知错误" : String(text.prefix(200))
                updateSetupState("配置失败：\(reason)")
            }
            if let button = setupActionButton {
                button.title = "重新授权"
                button.action = #selector(startSetup)
            }
        }
    }

    private func applyWindowStyle() {
        guard let containerView else { return }
        containerView.material = windowMaterial()
        containerView.layer?.cornerRadius = panelCornerRadius()
        containerView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.78).cgColor
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
    }

    private func reloadTasks(derivePetState: Bool = true) {
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
        if derivePetState {
            petState = PetState.derive(tasks: tasks, preferences: preferences, previous: petState, today: todayKey())
            savePetState()
        }
        lastKnownTaskCount = tasks.count
        lastKnownOverdueCount = overdueTasks.count

        if !isExpanded {
            rootStack.addArrangedSubview(compactWidget(openCount: actionableTasks.count, overdueCount: overdueTasks.count))
            return
        }

        rootStack.addArrangedSubview(headerRow(openCount: actionableTasks.count, overdueCount: overdueTasks.count))
        if preferences.displayStyle == "cute" {
            rootStack.addArrangedSubview(syncStatusRow())
            rootStack.addArrangedSubview(nativeTaskFilterRow(tasks: sortedTasks))
            rootStack.addArrangedSubview(webAlignedTaskListPreview(groupedTasks(from: sortedTasks)))
            fitCuteExpandedWindowToContent()
            return
        } else if let statusView = styleStatusView(openCount: actionableTasks.count, overdueCount: overdueTasks.count) {
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
        spacer.widthAnchor.constraint(equalToConstant: max(0, contentWidth() - 46)).isActive = true

        let handle = ResizeHandleView(frame: NSRect(x: 0, y: 0, width: 42, height: 34))
        handle.translatesAutoresizingMaskIntoConstraints = false
        handle.widthAnchor.constraint(equalToConstant: 42).isActive = true
        handle.heightAnchor.constraint(equalToConstant: 34).isActive = true
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
        let button = PetDragButton(title: "", target: self, action: #selector(expandWidget))
        button.onDragEnded = { [weak self] point in
            self?.handlePetDragEnded(at: point)
        }
        button.isBordered = false
        button.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        let summaryText = compactSummaryText(openCount: openCount, overdueCount: overdueCount)
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
            if petState.p0Count > 0 {
                return "P0 · \(petState.p0Count)"
            }
            if petState.overdueCount > 0 {
                return "逾期 · \(petState.overdueCount)"
            }
            return "待办 · \(petState.pendingKibbleCount)"
        }
        return overdueCount > 0 ? "\(overdueCount) 逾期" : "\(openCount) 待办"
    }

    private func dogStateLine() -> String {
        switch petState.dogMood {
        case .walking:
            return "已完成 1 件，正在同步状态"
        case .happyReturn:
            return "今天已完成 \(petState.fedTodayCount) 件"
        case .concerned:
            if petState.p0Count > 0 {
                return "还有 \(petState.p0Count) 件 P0 待处理"
            }
            if petState.overdueCount > 0 {
                return "有 \(petState.overdueCount) 件事已逾期"
            }
            return "建议先处理风险任务"
        case .foundTask, .readyToWalk:
            return "\(petState.pendingKibbleCount) 件待办待处理"
        case .sniffing:
            return "正在识别屏幕里的待办线索"
        case .idle:
            if petState.fedTodayCount > 0 {
                return "今天已完成 \(petState.fedTodayCount) 件"
            }
            return "今天从一件小事开始"
        }
    }

    private func styleStatusView(openCount: Int, overdueCount: Int) -> NSView? {
        if preferences.displayStyle == "minimal" { return nil }

        let text: String
        if preferences.displayStyle == "cute" {
            text = overdueCount > 0
                ? "有 \(overdueCount) 件逾期待办"
                : "当前有 \(openCount) 件待办"
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

    private func groupedTasks(from tasks: [AimeTask]) -> [AimeTask] {
        let visibleOpenTasks = tasks.filter { isActionableStatus($0.status) }
        let filtered: [AimeTask]
        switch activeTaskGroup {
        case .p0:
            filtered = visibleOpenTasks.filter { preferences.priorityByTaskId[$0.id] == "P0" }
        case .overdue:
            filtered = visibleOpenTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return String(dueDate.prefix(10)) < todayKey()
            }
        case .open, .none:
            filtered = visibleOpenTasks
        }
        return sortTasks(filtered)
    }

    private func isActionableStatus(_ status: String) -> Bool {
        status != "done" && status != "ignored"
    }

    private func sortTasks(_ tasks: [AimeTask]) -> [AimeTask] {
        let result = tasks.sorted { left, right in
            let leftPinned = preferences.pinnedTaskIds.contains(left.id)
            let rightPinned = preferences.pinnedTaskIds.contains(right.id)
            if leftPinned != rightPinned {
                return leftPinned
            }

            let ascending = preferences.sortAscending
            switch preferences.sortKey {
            case "priority":
                let leftRank = priorityRank(preferences.priorityByTaskId[left.id] ?? left.priority ?? "P2")
                let rightRank = priorityRank(preferences.priorityByTaskId[right.id] ?? right.priority ?? "P2")
                if leftRank != rightRank {
                    return ascending ? leftRank < rightRank : leftRank > rightRank
                }
            case "dueDate":
                let leftHasDate = left.dueDate != nil && !left.dueDate!.isEmpty
                let rightHasDate = right.dueDate != nil && !right.dueDate!.isEmpty
                if leftHasDate != rightHasDate {
                    return leftHasDate
                }
                let leftDate = left.dueDate ?? "9999-12-31"
                let rightDate = right.dueDate ?? "9999-12-31"
                if leftDate != rightDate {
                    return ascending ? leftDate < rightDate : leftDate > rightDate
                }
            case "title":
                if left.title != right.title {
                    return ascending ? left.title < right.title : left.title > right.title
                }
            default:
                break
            }

            let leftPriority = priorityRank(preferences.priorityByTaskId[left.id] ?? left.priority ?? "P2")
            let rightPriority = priorityRank(preferences.priorityByTaskId[right.id] ?? right.priority ?? "P2")
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
        return result
    }

    private func priorityRank(_ priority: String) -> Int {
        switch priority {
        case "P0": return 3
        case "P1": return 2
        case "P2": return 1
        default: return 0
        }
    }

    private func headerRow(openCount: Int, overdueCount: Int) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = preferences.displayStyle == "cute" ? scaledCute(12) : 10

        let summaryText = preferences.displayStyle == "cute"
            ? "\(openCount) 件待办"
            : "\(openCount) open · \(overdueCount) overdue"
        let summarySize: CGFloat = preferences.displayStyle == "cute" ? scaledCute(24) : 17
        let summary = label(summaryText, size: summarySize, weight: .semibold)
        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.spacing = preferences.displayStyle == "cute" ? scaledCute(4) : 5
        titleStack.addArrangedSubview(label(styleTitle(), size: preferences.displayStyle == "cute" ? scaledCute(18) : 12, weight: .bold, color: mutedColor()))
        titleStack.addArrangedSubview(summary)
        let collapse = NSButton(title: preferences.displayStyle == "cute" ? "×" : "收起", target: self, action: #selector(collapseWidget))
        collapse.bezelStyle = .rounded
        collapse.controlSize = usesCompactExpandedLayout() ? .mini : (preferences.displayStyle == "cute" ? .regular : .small)

        row.addArrangedSubview(titleStack)
        if preferences.displayStyle == "cute" {
            row.addArrangedSubview(toolbarButton(title: "+", toolTip: "新增待办", action: #selector(addTaskClicked)))
        }
        if preferences.displayStyle != "cute" {
            let more = menuButton(title: "更多", action: #selector(showHeaderMoreMenu(_:)))
            row.addArrangedSubview(more)
        }
        row.addArrangedSubview(collapse)
        return row
    }

    private func toolbarButton(title: String, toolTip: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = usesCompactExpandedLayout() ? .mini : .small
        button.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        button.toolTip = toolTip
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    private func sortButtonLabel() -> String {
        let keyText: String
        switch preferences.sortKey {
        case "dueDate": keyText = "截止"
        case "title": keyText = "标题"
        default: keyText = "优先级"
        }
        let arrow = preferences.sortAscending ? "↑" : "↓"
        return "\(keyText)\(arrow)"
    }

    private func sortMenuItem(title: String, key: String, menu: NSMenu) {
        let item = NSMenuItem(title: title, action: #selector(sortKeySelected(_:)), keyEquivalent: "")
        item.representedObject = key
        item.state = preferences.sortKey == key ? .on : .off
        item.target = self
        menu.addItem(item)
    }

    @objc private func showSortMenu(_ sender: NSButton) {
        let menu = NSMenu()
        sortMenuItem(title: "按优先级", key: "priority", menu: menu)
        sortMenuItem(title: "按截止时间", key: "dueDate", menu: menu)
        sortMenuItem(title: "按标题", key: "title", menu: menu)
        menu.addItem(NSMenuItem.separator())
        let ascendingItem = NSMenuItem(title: "升序", action: #selector(toggleSortAscending(_:)), keyEquivalent: "")
        ascendingItem.state = preferences.sortAscending ? .on : .off
        ascendingItem.target = self
        menu.addItem(ascendingItem)
        let descendingItem = NSMenuItem(title: "降序", action: #selector(toggleSortAscending(_:)), keyEquivalent: "")
        descendingItem.state = preferences.sortAscending ? .off : .on
        descendingItem.target = self
        menu.addItem(descendingItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 2), in: sender)
    }

    @objc private func sortKeySelected(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        preferences.sortKey = key
        savePreferences()
        reloadTasks()
    }

    @objc private func toggleSortAscending(_ sender: NSMenuItem) {
        preferences.sortAscending.toggle()
        savePreferences()
        reloadTasks()
    }

    private func syncStatusRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6

        let status = label(syncStatusText(), size: 11, weight: .medium, color: mutedColor())
        status.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(status)

        row.addArrangedSubview(toolbarButton(title: "刷新", toolTip: "同步飞书 Base", action: #selector(refreshClicked)))
        row.addArrangedSubview(toolbarButton(title: "Base", toolTip: "打开飞书 Base", action: #selector(openAimeBase)))

        return padded(row, width: contentWidth(), vertical: 4)
    }

    private func syncStatusText() -> String {
        let monitorText = screenMonitorTimer == nil ? "实时识别关" : "实时识别开"
        let syncText: String
        if let lastSyncDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            syncText = "\(lastSyncSucceeded ? "已同步" : "同步失败") \(formatter.string(from: lastSyncDate))"
        } else {
            syncText = "等待同步"
        }
        return "飞书 Base · \(syncText) · \(monitorText)"
    }

    private func nativeTaskFilterRow(tasks: [AimeTask]) -> NSView {
        let openTasks = tasks.filter { isActionableStatus($0.status) }
        let p0Count = openTasks.filter { preferences.priorityByTaskId[$0.id] == "P0" }.count
        let overdueCount = openTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return String(dueDate.prefix(10)) < todayKey()
        }.count

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.addArrangedSubview(filterChip(title: "全部", count: openTasks.count, group: .open))
        if p0Count > 0 {
            row.addArrangedSubview(filterChip(title: "P0", count: p0Count, group: .p0))
        }
        if overdueCount > 0 {
            row.addArrangedSubview(filterChip(title: "逾期", count: overdueCount, group: .overdue))
        }
        row.addArrangedSubview(NSStackView())
        row.addArrangedSubview(toolbarButton(title: sortButtonLabel(), toolTip: "排序方式", action: #selector(showSortMenu(_:))))
        return row
    }

    private func filterChip(title: String, count: Int, group: NativeTaskGroup) -> NSView {
        let button = AimeActionButton(title: "\(title) \(count)", target: self, action: #selector(showNativeTaskGroup(_:)))
        button.payload = group.rawValue
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: 11, weight: activeTaskGroup == group || (activeTaskGroup == nil && group == .open) ? .semibold : .regular)
        button.toolTip = "筛选\(title)待办"
        if activeTaskGroup == group || (activeTaskGroup == nil && group == .open) {
            button.contentTintColor = NSColor.controlAccentColor
        }
        return button
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

    private func webAlignedTaskListPreview(_ tasks: [AimeTask]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = scaledCute(14)

        stack.addArrangedSubview(label("待办事项", size: scaledCute(18), weight: .bold, color: mutedColor()))

        let openTasks = tasks.filter { isActionableStatus($0.status) }
        if openTasks.isEmpty {
            stack.addArrangedSubview(emptyTaskStateView())
            return stack
        }

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        // 固定小窗口不显示滚动条，避免右侧留白；仍可用滚轮滑动
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay

        let taskStack = NSStackView()
        taskStack.translatesAutoresizingMaskIntoConstraints = false
        taskStack.orientation = .vertical
        taskStack.alignment = .leading
        taskStack.spacing = scaledCute(10)
        openTasks.forEach { task in
            taskStack.addArrangedSubview(webAlignedTaskRow(task))
        }

        scrollView.documentView = taskStack
        NSLayoutConstraint.activate([
            scrollView.widthAnchor.constraint(equalToConstant: contentWidth()),
            scrollView.heightAnchor.constraint(equalToConstant: visibleTaskListHeight(for: openTasks.count)),
            taskStack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])

        stack.addArrangedSubview(scrollView)
        // 底部 footer 已移除，避免留白
        return stack
    }

    private func emptyTaskStateView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        stack.addArrangedSubview(label("今天已经清空", size: scaledCute(16), weight: .semibold))
        stack.addArrangedSubview(label("可以手动新增，也可以从飞书聊天或会议纪要里识别。", size: scaledCute(12), weight: .medium, color: mutedColor()))

        let actions = NSStackView()
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = 8
        actions.addArrangedSubview(toolbarButton(title: "新增", toolTip: "新增待办", action: #selector(addTaskClicked)))
        stack.addArrangedSubview(actions)

        return card(stack, width: contentWidth())
    }

    private func visibleTaskListHeight(for count: Int) -> CGFloat {
        let visibleRows = CGFloat(min(max(count, 1), 3))
        let rowHeight = usesCompactExpandedLayout() ? CGFloat(52) : scaledCute(64)
        let gapHeight = CGFloat(max(0, Int(visibleRows) - 1)) * scaledCute(10)
        return visibleRows * rowHeight + gapHeight + scaledCute(2)
    }

    private func webAlignedTaskRow(_ task: AimeTask) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = usesCompactExpandedLayout() ? 10 : scaledCute(14)

        let check = AimeActionButton(title: "", target: self, action: #selector(completeTask(_:)))
        check.payload = task.id
        check.isBordered = false
        check.wantsLayer = true
        check.layer?.backgroundColor = NSColor.clear.cgColor
        check.layer?.borderWidth = usesCompactExpandedLayout() ? 1.6 : max(2, scaledCute(2.4))
        check.layer?.borderColor = NSColor(calibratedRed: 0.31, green: 0.28, blue: 0.27, alpha: 1).cgColor
        let checkSize = usesCompactExpandedLayout() ? CGFloat(18) : scaledCute(24)
        check.layer?.cornerRadius = checkSize / 2
        check.translatesAutoresizingMaskIntoConstraints = false
        check.widthAnchor.constraint(equalToConstant: checkSize).isActive = true
        check.heightAnchor.constraint(equalToConstant: checkSize).isActive = true

        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = scaledCute(3)
        titleStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let priority = preferences.priorityByTaskId[task.id] ?? task.priority ?? "P2"
        let isPinned = preferences.pinnedTaskIds.contains(task.id)
        titleStack.addArrangedSubview(label("\(priority) · \(task.title)", size: usesCompactExpandedLayout() ? 13 : scaledCute(18), weight: .semibold, color: titleColor(priority: priority, isPinned: isPinned)))
        titleStack.addArrangedSubview(label("\(task.project ?? "未分类") · \(task.dueDate ?? "无截止日期")", size: usesCompactExpandedLayout() ? 11 : scaledCute(13), weight: .medium, color: mutedColor()))

        let clickableTitle = clickableTaskTitle(task, content: titleStack)

        let more = menuButton(title: "•••", action: #selector(showTaskMoreMenu(_:)), payload: task.id)
        more.toolTip = "更多操作"
        more.setContentHuggingPriority(.required, for: .horizontal)

        row.addArrangedSubview(check)
        row.addArrangedSubview(clickableTitle)
        if let sourceUrl = task.sourceUrl, !sourceUrl.isEmpty {
            let source = AimeActionButton(title: "↗", target: self, action: #selector(openTaskSource(_:)))
            source.payload = sourceUrl
            source.bezelStyle = .rounded
            source.controlSize = .small
            source.toolTip = "打开来源"
            source.setContentHuggingPriority(.required, for: .horizontal)
            row.addArrangedSubview(source)
        }
        row.addArrangedSubview(more)
        return card(row, width: contentWidth(), priority: priority, isPinned: preferences.pinnedTaskIds.contains(task.id))
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

        let titleLabel = label(title, size: 13, weight: isPinned ? .bold : .semibold, color: titleColor(priority: priority, isPinned: isPinned))
        let clickableTitle = clickableTaskTitle(task, content: titleLabel)
        stack.addArrangedSubview(clickableTitle)
        stack.addArrangedSubview(label("\(task.project ?? "未分类") · \(task.dueDate ?? "无截止日期")", size: 11, color: mutedColor()))
        stack.addArrangedSubview(actionRow(for: task))
        return card(stack, width: contentWidth(), priority: priority, isPinned: isPinned)
    }

    private func contentWidth() -> CGFloat {
        guard isExpanded else { return 88 }
        return max(112, window.frame.width - 28)
    }

    private func cuteScale() -> CGFloat {
        guard preferences.displayStyle == "cute", isExpanded else { return 1 }
        return min(1, max(0.26, window.frame.width / 760))
    }

    private func scaledCute(_ value: CGFloat) -> CGFloat {
        preferences.displayStyle == "cute" ? value * cuteScale() : value
    }

    private func usesCompactExpandedLayout() -> Bool {
        preferences.displayStyle == "cute" && isExpanded && window.frame.width <= 460
    }

    private func fitCuteExpandedWindowToContent() {
        guard preferences.displayStyle == "cute", isExpanded else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.containerView.layoutSubtreeIfNeeded()
            let targetHeight = min(
                self.window.maxSize.height,
                max(self.window.minSize.height, ceil(self.rootStack.fittingSize.height + 26))
            )
            guard abs(self.window.frame.height - targetHeight) > 1 else { return }
            var frame = self.window.frame
            frame.origin.y = frame.maxY - targetHeight
            frame.size.height = targetHeight
            self.window.setFrame(frame, display: true, animate: false)
            self.preferences.expandedPanelHeight = Double(targetHeight)
            self.savePreferences()
        }
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

    private func clickableTaskTitle(_ task: AimeTask, content: NSView) -> NSView {
        let wrapper = AimePayloadNSView()
        wrapper.payload = task.id
        wrapper.wantsLayer = true
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            content.topAnchor.constraint(equalTo: wrapper.topAnchor),
            content.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
        ])
        let click = NSClickGestureRecognizer(target: self, action: #selector(taskTitleClicked(_:)))
        click.numberOfClicksRequired = 1
        wrapper.addGestureRecognizer(click)
        return wrapper
    }

    @objc private func taskTitleClicked(_ sender: NSClickGestureRecognizer) {
        guard let wrapper = sender.view as? AimePayloadNSView else { return }
        editTaskDetail(recordId: wrapper.payload)
    }

    private func card(_ content: NSView, width: CGFloat = 388, priority: String = "P2", isPinned: Bool = false) -> NSView {
        let wrapper = NSView()
        wrapper.wantsLayer = true
        wrapper.layer?.backgroundColor = cardColor(priority: priority, isPinned: isPinned).cgColor
        wrapper.layer?.cornerRadius = cardCornerRadius()
        wrapper.layer?.borderWidth = preferences.displayStyle == "cute" ? 1 : (isPinned || priority == "P0" ? 2 : 0)
        wrapper.layer?.borderColor = borderColor(priority: priority, isPinned: isPinned).cgColor
        content.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(content)
        let horizontalPadding: CGFloat = preferences.displayStyle == "cute" ? (usesCompactExpandedLayout() ? 12 : scaledCute(18)) : 10
        let verticalPadding: CGFloat = preferences.displayStyle == "cute" ? (usesCompactExpandedLayout() ? 10 : scaledCute(16)) : 8

        NSLayoutConstraint.activate([
            wrapper.widthAnchor.constraint(equalToConstant: width),
            content.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: horizontalPadding),
            content.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -horizontalPadding),
            content.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: verticalPadding),
            content.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -verticalPadding),
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
            if isPinned { return NSColor.controlAccentColor.withAlphaComponent(0.12) }
            switch priority {
            case "P0": return NSColor.systemRed.withAlphaComponent(0.12)
            case "P1": return NSColor.systemOrange.withAlphaComponent(0.12)
            case "P2": return NSColor.systemBlue.withAlphaComponent(0.10)
            default: return NSColor.windowBackgroundColor.withAlphaComponent(0.72)
            }
        }
        if preferences.displayStyle == "minimal" {
            if isPinned { return NSColor.white.withAlphaComponent(0.9) }
            switch priority {
            case "P0": return NSColor(calibratedWhite: 1, alpha: 0.88)
            case "P1": return NSColor.systemOrange.withAlphaComponent(0.08)
            case "P2": return NSColor.systemBlue.withAlphaComponent(0.08)
            default: return NSColor.white.withAlphaComponent(0.72)
            }
        }
        if isPinned { return NSColor(calibratedRed: 1, green: 0.96, blue: 0.76, alpha: 0.92) }
        switch priority {
        case "P0": return NSColor(calibratedRed: 1, green: 0.88, blue: 0.86, alpha: 0.9)
        case "P1": return NSColor(calibratedRed: 1, green: 0.94, blue: 0.86, alpha: 0.9)
        case "P2": return NSColor(calibratedRed: 0.86, green: 0.93, blue: 1, alpha: 0.9)
        default: return NSColor.white.withAlphaComponent(0.72)
        }
    }

    private func cardCornerRadius() -> CGFloat {
        switch preferences.displayStyle {
        case "minimal": return 5
        case "cute": return usesCompactExpandedLayout() ? 12 : scaledCute(26)
        default: return 9
        }
    }

    private func panelCornerRadius() -> CGFloat {
        switch preferences.displayStyle {
        case "minimal": return 10
        case "cute": return usesCompactExpandedLayout() ? 18 : scaledCute(30)
        default: return 18
        }
    }

    private func windowMaterial() -> NSVisualEffectView.Material {
        switch preferences.displayStyle {
        case "minimal": return .popover
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
        case "cute": return NSColor.controlAccentColor.withAlphaComponent(0.88)
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
        case "cute": return "Aime 待办"
        default: return "任务伴随"
        }
    }

    private func styleStatusBackgroundColor() -> NSColor {
        switch preferences.displayStyle {
        case "cute": return NSColor(calibratedRed: 1, green: 0.91, blue: 0.80, alpha: 0.92)
        default: return NSColor(calibratedRed: 0.82, green: 0.9, blue: 0.88, alpha: 0.52)
        }
    }

    private func styleStatusTextColor() -> NSColor {
        switch preferences.displayStyle {
        case "cute": return NSColor(calibratedRed: 0.45, green: 0.33, blue: 0.23, alpha: 1)
        default: return NSColor(calibratedRed: 0.12, green: 0.28, blue: 0.25, alpha: 1)
        }
    }

    private func borderColor(priority: String, isPinned: Bool) -> NSColor {
        if preferences.displayStyle == "cute" {
            if isPinned { return NSColor.controlAccentColor.withAlphaComponent(0.35) }
            if priority == "P0" { return NSColor.systemRed.withAlphaComponent(0.28) }
            return NSColor.separatorColor.withAlphaComponent(0.5)
        }
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
        switch priority {
        case "P0": return NSColor.systemRed
        case "P1": return NSColor.systemOrange
        case "P2": return NSColor.systemBlue
        default: return NSColor.secondaryLabelColor
        }
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
        statusItem.button?.title = "Aime"
        statusItem.button?.toolTip = "Aime 待办伴随"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示面板", action: #selector(showWidget), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "展开待办", action: #selector(expandWidget), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "重置位置并显示", action: #selector(resetWindowPositionAndShow), keyEquivalent: "0"))
        menu.addItem(NSMenuItem(title: "打开多维表格", action: #selector(openAimeBase), keyEquivalent: "b"))
        menu.addItem(NSMenuItem(title: "打开 Aime 助手", action: #selector(openAimeAssistant), keyEquivalent: "a"))
        menu.addItem(NSMenuItem(title: "刷新", action: #selector(refreshClicked), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func showWidget() {
        window.setFrame(frameForCurrentMode(), display: true, animate: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func resetWindowPositionAndShow() {
        isExpanded = true
        preferences.expandedPanelWidth = 360
        preferences.expandedPanelHeight = 260
        savePreferences()
        updateWindowResizeBounds()
        reloadTasks()
        showWidget()
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
        window.minSize = NSSize(width: 320, height: 220)
        window.maxSize = NSSize(width: 560, height: 520)
    }

    @objc private func refreshClicked() {
        pullLatestTasks()
        reloadTasks()
        showWidget()
    }

    @objc private func showHeaderMoreMenu(_ sender: AimeMenuButton) {
        let menu = NSMenu()
        addMenuItem("新增待办", to: menu, action: #selector(addTaskClicked))
        menu.addItem(NSMenuItem.separator())
        addMenuItem("打开多维表格", to: menu, action: #selector(openAimeBase))
        addMenuItem("打开 Aime 助手", to: menu, action: #selector(openAimeAssistant))
        menu.addItem(NSMenuItem.separator())
        addPayloadMenuItem("风格：简洁", payload: "minimal", to: menu, action: #selector(changeDisplayStyle(_:)))
        addPayloadMenuItem("风格：精致", payload: "refined", to: menu, action: #selector(changeDisplayStyle(_:)))
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
        addPayloadMenuItem("查看/编辑详情", payload: task.id, to: menu, action: #selector(editTaskFromMenu(_:)))
        menu.addItem(NSMenuItem.separator())
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
        addPayloadMenuItem("改截止时间", payload: task.id, to: menu, action: #selector(rescheduleTaskFromMenu(_:)))
        addPayloadMenuItem(preferences.hiddenTaskIds.contains(task.id) ? "取消隐藏" : "隐藏", payload: task.id, to: menu, action: #selector(toggleHideTaskFromMenu(_:)))
        addPayloadMenuItem("忽略", payload: task.id, to: menu, action: #selector(ignoreTaskFromMenu(_:)))
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 2), in: sender)
    }

    private func startAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.performAutoRefresh()
        }
        assistantSignalTimer?.invalidate()
        assistantSignalTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.performAssistantSignalCheck()
        }
        performAssistantSignalCheck()
    }

    private func performAssistantSignalCheck() {
        guard !assistantSignalCheckRunning else { return }
        assistantSignalCheckRunning = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let (output, succeeded) = self.runSyncCommandReturningOutput(["assistant-signal"])
            let changed = succeeded && self.assistantSignalChanged(output)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.assistantSignalCheckRunning = false
                if changed {
                    self.performAutoRefresh()
                }
            }
        }
    }

    private func assistantSignalChanged(_ output: String) -> Bool {
        guard
            let data = output.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        return json["changed"] as? Bool == true
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
            let deltaTasks = lastKnownTaskCount - previousTaskCount
            showStatusNotification(
                title: preferences.displayStyle == "cute" ? "有新待办" : "Aime 有新待办",
                body: preferences.displayStyle == "cute"
                    ? "新增 \(deltaTasks) 个待办，点开查看。"
                    : "新增 \(deltaTasks) 个待办，点开看看。"
            )
        } else if lastKnownOverdueCount > previousOverdueCount {
            showStatusNotification(
                title: preferences.displayStyle == "cute" ? "有任务已逾期" : "有任务已逾期",
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

    private func handlePetDragEnded(at point: NSPoint) {
        guard preferences.displayStyle == "cute" else { return }
        petState.dogMood = .sniffing
        savePetState()
        reloadTasks()
        showMessage(
            "屏幕识别已暂停",
            detail: "当前版本暂不自动截取屏幕，请手动新增待办或使用飞书 Base。"
        )
        finishSniffing(as: .idle)
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
        preferences.expandedPanelWidth = 360
        preferences.expandedPanelHeight = 260
        savePreferences()
        guard isExpanded else { return }
        window.setFrame(frameForCurrentMode(), display: true, animate: true)
        reloadTasks()
    }

    @objc private func showNativeTaskGroup(_ sender: AimeActionButton) {
        activeTaskGroup = NativeTaskGroup(rawValue: sender.payload)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            sender.animator().alphaValue = 0.55
        } completionHandler: { [weak self, weak sender] in
            guard let self else { return }
            sender?.alphaValue = 1
            self.reloadTasks(derivePetState: false)
        }
    }

    private func scanScreenForTasks(dialogTitle: String, skipDuplicate: Bool) {
        let screenshotURL = captureCurrentScreen()
        guard let screenshotURL else {
            finishSniffing(as: .idle)
            showMessage("无法截取屏幕", detail: "请确认系统已允许屏幕录制权限。")
            return
        }

        let recognizedText = recognizeText(in: screenshotURL)
        let compactText = compactTaskTitle(recognizedText)
        guard !compactText.isEmpty else {
            finishSniffing(as: .idle)
            return
        }
        if skipDuplicate {
            guard compactText != lastRecognizedScreenText else {
                finishSniffing(as: .idle)
                return
            }
        }
        lastRecognizedScreenText = compactText

        guard let draft = taskDraftDialog(title: dialogTitle, initialText: recognizedText) else {
            finishSniffing(as: .idle)
            return
        }
        if createTask(title: draft.title, dueDate: draft.dueDate, project: draft.project) {
            finishSniffing(as: .foundTask)
        } else {
            finishSniffing(as: .idle)
            showMessage("写入失败", detail: "识别到了待办，但没有成功写入飞书 Base。")
        }
    }

    private func finishSniffing(as mood: DogMood) {
        guard petState.dogMood == .sniffing else { return }
        petState.dogMood = mood
        savePetState()
        reloadTasks(derivePetState: false)
    }

    private func isLikelyLarkWindow(at point: NSPoint) -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        let keywordTargets = ["lark", "feishu", "飞书"]
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) else { return false }
        let windowListPoint = NSPoint(
            x: point.x,
            y: screen.frame.maxY - point.y + screen.frame.minY
        )

        func asCGFloat(_ any: Any?) -> CGFloat? {
            if let value = any as? NSNumber { return CGFloat(truncating: value) }
            if let value = any as? CGFloat { return value }
            if let value = any as? Double { return CGFloat(value) }
            if let value = any as? Int { return CGFloat(value) }
            return nil
        }

        for window in windows {
            let ownerName = window[kCGWindowOwnerName as String] as? String ?? ""
            let windowName = window[kCGWindowName as String] as? String ?? ""
            let searchSource = "\(ownerName) \(windowName)".lowercased()
            guard keywordTargets.contains(where: { searchSource.contains($0) }) else { continue }

            guard
                let frameValue = window[kCGWindowBounds as String],
                let frameDict = frameValue as? [String: Any],
                let x = asCGFloat(frameDict["X"]),
                let y = asCGFloat(frameDict["Y"]),
                let width = asCGFloat(frameDict["Width"]),
                let height = asCGFloat(frameDict["Height"])
            else {
                continue
            }

            let windowRect = CGRect(x: x, y: y, width: width, height: height)
            if windowRect.contains(CGPoint(x: windowListPoint.x, y: windowListPoint.y)) {
                return true
            }
        }
        return false
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

    @objc private func editTaskFromMenu(_ sender: AimeMenuItem) {
        editTaskDetail(recordId: sender.payload)
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
        if runSyncCommand(["complete", "--record-id", recordId]) {
            petState = petState.rewardIfNeeded(taskId: recordId, today: todayKey())
            savePetState()
            scheduleWalkReturn()
        } else {
            showMessage(
                "写回失败",
                detail: "完成状态没有成功写回飞书 Base，请稍后重试。"
            )
        }
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
        reschedule(recordId: recordId)
    }

    @objc private func rescheduleTaskFromMenu(_ sender: AimeMenuItem) {
        reschedule(recordId: sender.payload)
    }

    private func reschedule(recordId: String) {
        guard let dueDate = chooseDueDate() else { return }
        runSyncCommand(["reschedule", "--record-id", recordId, "--due-date", dueDate])
        pullLatestTasks()
        reloadTasks()
    }

    @objc private func quit() {
        autoRefreshTimer?.invalidate()
        assistantSignalTimer?.invalidate()
        screenMonitorTimer?.invalidate()
        walkReturnTimer?.invalidate()
        NSApp.terminate(nil)
    }

    private func resolveTaskFeedPath() -> String {
        if CommandLine.arguments.count > 1 {
            return CommandLine.arguments[1]
        }

        let currentDirectory = FileManager.default.currentDirectoryPath
        return "\(currentDirectory)/tmp/aime-tasks.json"
    }

    private func configFilePath() -> String {
        let currentDirectory = FileManager.default.currentDirectoryPath
        return "\(currentDirectory)/config/aime-base.local.json"
    }

    private func configFileExists() -> Bool {
        FileManager.default.fileExists(atPath: configFilePath())
    }

    @discardableResult
    private func pullLatestTasks() -> Bool {
        let succeeded = runSyncCommand(["pull", "--out", "tmp/aime-tasks.json"])
        lastSyncDate = Date()
        lastSyncSucceeded = succeeded
        if !succeeded, isExpanded {
            showMessage("同步失败", detail: "没有成功从飞书 Base 拉取最新待办。")
        }
        return succeeded
    }

    @discardableResult
    private func createTask(title: String, dueDate: String?, project: String?) -> Bool {
        var arguments = ["create", "--title", title]
        if let dueDate, !dueDate.isEmpty {
            arguments += ["--due-date", dueDate]
        }
        if let project, !project.isEmpty {
            arguments += ["--project", project]
        }
        let succeeded = runSyncCommand(arguments)
        if succeeded {
            pullLatestTasks()
            reloadTasks()
        }
        return succeeded
    }

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
                self.walkReturnTimer = nil
            }
        }
    }

    @discardableResult
    private func runSyncCommand(_ arguments: [String]) -> Bool {
        let (_, success) = runSyncCommandReturningOutput(arguments)
        return success
    }

    private func runSyncCommandWithOutput(_ arguments: [String]) -> String {
        let (output, _) = runSyncCommandReturningOutput(arguments)
        return output
    }

    private func runSyncCommandReturningOutput(_ arguments: [String]) -> (String, Bool) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        let syncScriptPath: String
        if let bundledPath = ProcessInfo.processInfo.environment["AIME_SYNC_SCRIPT_PATH"], !bundledPath.isEmpty {
            syncScriptPath = bundledPath
        } else {
            let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            syncScriptPath = repoRoot.appendingPathComponent("scripts/aime-lark-sync.mjs").path
        }

        process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        process.arguments = ["node", syncScriptPath] + arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var stdoutData = Data()
        var stderrData = Data()
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                stdoutData.append(data)
            }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                stderrData.append(data)
            }
        }

        do {
            try process.run()
            process.waitUntilExit()
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil

            let stdoutText = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
            let combined = [stdoutText, stderrText].filter { !$0.isEmpty }.joined(separator: "\n")
            if process.terminationStatus != 0 {
                print("Aime sync command failed: \(arguments.joined(separator: " "))")
                if !stdoutText.isEmpty { print("stdout: \(stdoutText)") }
                if !stderrText.isEmpty { print("stderr: \(stderrText)") }
                return (combined, false)
            }
            if !stdoutText.isEmpty { print("Aime sync stdout: \(stdoutText)") }
            return (combined, true)
        } catch {
            print("Aime sync command could not run: \(error.localizedDescription)")
            return (error.localizedDescription, false)
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
        let suggestedTitle = compactTaskTitle(initialText)
        let contextPreview = recognizedContextPreview(initialText)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: contextPreview.isEmpty ? 310 : 430),
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

        let note = label(contextPreview.isEmpty ? "保存后会写入飞书 Base。" : "已从当前飞书/屏幕上下文提取候选待办，保存前可以修改。", size: 12, color: mutedColor())
        note.translatesAutoresizingMaskIntoConstraints = false

        let titleField = NSTextField(string: suggestedTitle)
        titleField.placeholderString = "待办标题"
        titleField.translatesAutoresizingMaskIntoConstraints = false

        let duePicker = NSDatePicker()
        duePicker.datePickerStyle = .textFieldAndStepper
        duePicker.datePickerElements = [.yearMonthDay, .hourMinute]
        duePicker.dateValue = inferredDueDate(from: initialText) ?? Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        duePicker.translatesAutoresizingMaskIntoConstraints = false

        let projectField = NSTextField(string: inferredProject(from: initialText))
        projectField.placeholderString = "分类，可留空"
        projectField.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = label("标题", size: 11, color: mutedColor())
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let dueLabel = label("截止时间", size: 11, color: mutedColor())
        dueLabel.translatesAutoresizingMaskIntoConstraints = false
        let projectLabel = label("分类", size: 11, color: mutedColor())
        projectLabel.translatesAutoresizingMaskIntoConstraints = false
        let contextLabel = label("识别依据", size: 11, color: mutedColor())
        contextLabel.translatesAutoresizingMaskIntoConstraints = false

        let contextScroll = NSScrollView()
        contextScroll.translatesAutoresizingMaskIntoConstraints = false
        contextScroll.drawsBackground = false
        contextScroll.hasVerticalScroller = true
        contextScroll.borderType = .noBorder

        let contextText = NSTextView()
        contextText.isEditable = false
        contextText.isSelectable = true
        contextText.drawsBackground = true
        contextText.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.58)
        contextText.textColor = mutedColor()
        contextText.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        contextText.textContainerInset = NSSize(width: 8, height: 6)
        contextText.string = contextPreview
        contextScroll.documentView = contextText

        let cancelButton = NSButton(title: "取消", target: nil, action: nil)
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        let saveButton = NSButton(title: "保存", target: nil, action: nil)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        var views: [NSView] = [heading, note, titleLabel, titleField, dueLabel, duePicker, projectLabel, projectField, cancelButton, saveButton]
        if !contextPreview.isEmpty {
            views += [contextLabel, contextScroll]
        }
        views.forEach { content.addSubview($0) }

        var constraints: [NSLayoutConstraint] = [
            heading.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            heading.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),

            note.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            note.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
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
        ]

        if !contextPreview.isEmpty {
            constraints += [
                contextLabel.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
                contextLabel.topAnchor.constraint(equalTo: projectField.bottomAnchor, constant: 12),

                contextScroll.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
                contextScroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
                contextScroll.topAnchor.constraint(equalTo: contextLabel.bottomAnchor, constant: 4),
                contextScroll.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -14),
            ]
        }

        NSLayoutConstraint.activate(constraints)

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

    private struct TaskEditDraft {
        let title: String
        let dueDate: String?
        let project: String?
        let priority: String
        let sourceUrl: String?
        let details: String?
    }

    private func editTaskDetail(recordId: String) {
        let tasks = loadTasks()
        guard let task = tasks.first(where: { $0.id == recordId }) else { return }
        guard let draft = taskDetailEditDialog(task: task) else { return }

        var arguments: [String] = ["update", "--record-id", recordId, "--title", draft.title]
        if let dueDate = draft.dueDate, !dueDate.isEmpty {
            arguments += ["--due-date", dueDate]
        }
        if let project = draft.project, !project.isEmpty {
            arguments += ["--project", project]
        }
        arguments += ["--priority", draft.priority]
        if let sourceUrl = draft.sourceUrl, !sourceUrl.isEmpty {
            arguments += ["--source-url", sourceUrl]
        }
        if let details = draft.details, !details.isEmpty {
            arguments += ["--details", details]
        }

        let succeeded = runSyncCommand(arguments)
        if succeeded {
            preferences.priorityByTaskId[recordId] = draft.priority
            savePreferences()
            pullLatestTasks()
            reloadTasks()
        } else {
            showMessage("保存失败", detail: "未能将修改同步到飞书 Base。")
        }
    }

    private func taskDetailEditDialog(task: AimeTask) -> TaskEditDraft? {
        var result: TaskEditDraft?

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = "任务详情"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.center()

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = content

        let heading = label("查看/编辑任务", size: 17, weight: .semibold)
        heading.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = label("标题", size: 11, color: mutedColor())
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let titleField = NSTextField(string: task.title)
        titleField.placeholderString = "待办标题"
        titleField.translatesAutoresizingMaskIntoConstraints = false

        let dueLabel = label("截止时间", size: 11, color: mutedColor())
        dueLabel.translatesAutoresizingMaskIntoConstraints = false
        let duePicker = NSDatePicker()
        duePicker.datePickerStyle = .textFieldAndStepper
        duePicker.datePickerElements = [.yearMonthDay, .hourMinute]
        duePicker.dateValue = parsedDueDate(task.dueDate) ?? Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        duePicker.translatesAutoresizingMaskIntoConstraints = false

        let projectLabel = label("分类", size: 11, color: mutedColor())
        projectLabel.translatesAutoresizingMaskIntoConstraints = false
        let projectField = NSTextField(string: task.project ?? "")
        projectField.placeholderString = "分类，可留空"
        projectField.translatesAutoresizingMaskIntoConstraints = false

        let priorityLabel = label("优先级", size: 11, color: mutedColor())
        priorityLabel.translatesAutoresizingMaskIntoConstraints = false
        let priorityPopup = NSPopUpButton()
        priorityPopup.translatesAutoresizingMaskIntoConstraints = false
        [("P0", "P0"), ("P1", "P1"), ("P2", "P2"), ("无", "P3")].forEach { title, value in
            priorityPopup.addItem(withTitle: title)
            priorityPopup.lastItem?.representedObject = value
        }
        let currentPriority = preferences.priorityByTaskId[task.id] ?? task.priority ?? "P2"
        priorityPopup.selectItem(at: ["P0", "P1", "P2", "P3"].firstIndex(of: currentPriority) ?? 2)

        let sourceLabel = label("来源链接", size: 11, color: mutedColor())
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        let sourceField = NSTextField(string: task.sourceUrl ?? "")
        sourceField.placeholderString = "飞书文档/群聊链接，可留空"
        sourceField.translatesAutoresizingMaskIntoConstraints = false

        let detailsLabel = label("详情/备注", size: 11, color: mutedColor())
        detailsLabel.translatesAutoresizingMaskIntoConstraints = false
        let detailsScroll = NSScrollView()
        detailsScroll.translatesAutoresizingMaskIntoConstraints = false
        detailsScroll.drawsBackground = false
        detailsScroll.hasVerticalScroller = true
        detailsScroll.borderType = .bezelBorder
        let detailsText = NSTextView()
        detailsText.isEditable = true
        detailsText.isSelectable = true
        detailsText.drawsBackground = true
        detailsText.backgroundColor = NSColor.textBackgroundColor
        detailsText.textColor = NSColor.textColor
        detailsText.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        detailsText.textContainerInset = NSSize(width: 6, height: 6)
        detailsText.string = task.details ?? ""
        detailsScroll.documentView = detailsText

        let cancelButton = NSButton(title: "取消", target: nil, action: nil)
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        let saveButton = NSButton(title: "保存", target: nil, action: nil)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        let views: [NSView] = [
            heading,
            titleLabel, titleField,
            dueLabel, duePicker,
            projectLabel, projectField,
            priorityLabel, priorityPopup,
            sourceLabel, sourceField,
            detailsLabel, detailsScroll,
            cancelButton, saveButton
        ]
        views.forEach { content.addSubview($0) }

        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            heading.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 18),
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

            priorityLabel.leadingAnchor.constraint(equalTo: duePicker.trailingAnchor, constant: 16),
            priorityLabel.centerYAnchor.constraint(equalTo: dueLabel.centerYAnchor),
            priorityPopup.leadingAnchor.constraint(equalTo: priorityLabel.leadingAnchor),
            priorityPopup.topAnchor.constraint(equalTo: priorityLabel.bottomAnchor, constant: 4),
            priorityPopup.widthAnchor.constraint(equalToConstant: 90),
            priorityPopup.heightAnchor.constraint(equalToConstant: 28),

            projectLabel.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            projectLabel.topAnchor.constraint(equalTo: duePicker.bottomAnchor, constant: 12),
            projectField.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            projectField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            projectField.topAnchor.constraint(equalTo: projectLabel.bottomAnchor, constant: 4),
            projectField.heightAnchor.constraint(equalToConstant: 28),

            sourceLabel.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            sourceLabel.topAnchor.constraint(equalTo: projectField.bottomAnchor, constant: 12),
            sourceField.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            sourceField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            sourceField.topAnchor.constraint(equalTo: sourceLabel.bottomAnchor, constant: 4),
            sourceField.heightAnchor.constraint(equalToConstant: 28),

            detailsLabel.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            detailsLabel.topAnchor.constraint(equalTo: sourceField.bottomAnchor, constant: 12),
            detailsScroll.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            detailsScroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            detailsScroll.topAnchor.constraint(equalTo: detailsLabel.bottomAnchor, constant: 4),
            detailsScroll.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -16),

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
                result = TaskEditDraft(
                    title: taskTitle,
                    dueDate: formatter.string(from: duePicker.dateValue),
                    project: projectField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
                    priority: selectedPopupValue(priorityPopup),
                    sourceUrl: sourceField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
                    details: detailsText.string.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        }

        panel.close()
        return result
    }

    private func parsedDueDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: value) { return date }
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: value) { return date }
        return nil
    }

    private func recognizedContextPreview(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map(cleanRecognizedTaskLine)
            .filter { !$0.isEmpty && !isRecognitionChromeLine($0) }
            .prefix(8)
            .joined(separator: "\n")
    }

    private func inferredProject(from text: String) -> String {
        let lowered = text.lowercased()
        if lowered.contains("男装") || lowered.contains("穿搭") || lowered.contains("试穿") {
            return "AI穿搭"
        }
        if lowered.contains("aigc") || lowered.contains("选品") {
            return "AI选品"
        }
        if lowered.contains("评测") || lowered.contains("方案") {
            return "AI试穿"
        }
        if lowered.contains("会议") || lowered.contains("纪要") {
            return "会议纪要"
        }
        if lowered.contains("飞书") {
            return "飞书"
        }
        return ""
    }

    private func inferredDueDate(from text: String) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 18
        components.minute = 0

        if text.contains("今天") {
            return calendar.date(from: components)
        }
        if text.contains("明天") {
            return calendar.date(byAdding: .day, value: 1, to: calendar.date(from: components) ?? now)
        }
        if text.contains("后天") {
            return calendar.date(byAdding: .day, value: 2, to: calendar.date(from: components) ?? now)
        }

        let weekdayMap: [(String, Int)] = [
            ("周一", 2), ("星期一", 2),
            ("周二", 3), ("星期二", 3),
            ("周三", 4), ("星期三", 4),
            ("周四", 5), ("星期四", 5),
            ("周五", 6), ("星期五", 6),
            ("周六", 7), ("星期六", 7),
            ("周日", 1), ("星期日", 1), ("周天", 1), ("星期天", 1),
        ]
        if let target = weekdayMap.first(where: { text.contains($0.0) })?.1 {
            return nextWeekday(target, from: now)
        }
        return nil
    }

    private func nextWeekday(_ targetWeekday: Int, from date: Date) -> Date? {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)
        let daysUntilTarget = (targetWeekday - currentWeekday + 7) % 7
        let daysToAdd = daysUntilTarget == 0 ? 7 : daysUntilTarget
        guard let targetDay = calendar.date(byAdding: .day, value: daysToAdd, to: date) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: targetDay)
        components.hour = 18
        components.minute = 0
        return calendar.date(from: components)
    }

    private func compactTaskTitle(_ text: String) -> String {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let bestLine = lines
            .map(cleanRecognizedTaskLine)
            .filter({ !$0.isEmpty && !isRecognitionChromeLine($0) })
            .max(by: { taskLineScore($0) < taskLineScore($1) }),
           taskLineScore(bestLine) > 0 {
            return String(bestLine.prefix(120))
        }

        let collapsed = lines
            .map(cleanRecognizedTaskLine)
            .filter { !$0.isEmpty && !isRecognitionChromeLine($0) }
            .prefix(2)
            .joined(separator: " / ")
        return String(collapsed.prefix(120))
    }

    private func cleanRecognizedTaskLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: "（已编辑）", with: "")
            .replacingOccurrences(of: "(已编辑)", with: "")
            .replacingOccurrences(of: "回复 ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isRecognitionChromeLine(_ line: String) -> Bool {
        let lowered = line.lowercased()
        let chromeTokens = [
            "飞书", "编辑", "窗口", "历史记录", "mira", "author_products", "知识库数据采集说明",
            "yes", "ok", "get", "回复 于", "确认", "→"
        ]
        if chromeTokens.contains(where: { lowered.contains($0.lowercased()) }) && !looksLikeTaskLine(line) {
            return true
        }
        if line.count <= 2 { return true }
        if line.range(of: #"^[\W_]+$"#, options: .regularExpression) != nil { return true }
        return false
    }

    private func looksLikeTaskLine(_ line: String) -> Bool {
        let taskTokens = ["梳理", "跟进", "整理", "同步", "确认", "拉汪宇", "问题", "流程", "上线", "今天", "明天", "需要", "要不", "你把", "你要"]
        return taskTokens.contains { line.contains($0) }
    }

    private func taskLineScore(_ line: String) -> Int {
        var score = 0
        if looksLikeTaskLine(line) { score += 8 }
        if line.count >= 8 { score += 2 }
        if line.count >= 16 { score += 2 }
        if line.contains("飞书") || line.contains("窗口") || line.contains("历史记录") { score -= 12 }
        if line.contains("知识库") || line.contains("author_products") { score -= 8 }
        if line.count > 90 { score -= 2 }
        return score
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
            return lines.prefix(30).joined(separator: "\n")
        } catch {
            return ""
        }
    }

    private func showMessage(_ title: String, detail: String) {
        showInlineMessage(title, detail: detail)
    }

    private func showInlineMessage(_ title: String, detail: String) {
        guard let containerView else { return }

        messageDismissWorkItem?.cancel()
        messageBanner?.removeFromSuperview()

        let banner = NSVisualEffectView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.blendingMode = .withinWindow
        banner.material = .popover
        banner.state = .active
        banner.wantsLayer = true
        banner.layer?.cornerRadius = 14
        banner.layer?.borderWidth = 1
        banner.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        banner.alphaValue = 0

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 3
        stack.addArrangedSubview(label(title, size: 13, weight: .semibold))
        stack.addArrangedSubview(label(detail, size: 11, weight: .medium, color: mutedColor()))
        banner.addSubview(stack)
        containerView.addSubview(banner)

        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            banner.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            banner.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: banner.topAnchor, constant: 9),
            stack.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -9),
        ])

        messageBanner = banner
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            banner.animator().alphaValue = 1
        }

        let workItem = DispatchWorkItem { [weak self, weak banner] in
            guard let self, let banner else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                banner.animator().alphaValue = 0
            } completionHandler: {
                banner.removeFromSuperview()
                if self.messageBanner === banner {
                    self.messageBanner = nil
                }
            }
        }
        messageDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2, execute: workItem)
    }

    private func preferencesURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL
            .appendingPathComponent("AimeCompanion", isDirectory: true)
            .appendingPathComponent("local-preferences.json")
    }

    private func petStateURL() -> URL {
        return preferencesURL()
            .deletingLastPathComponent()
            .appendingPathComponent("pet-state.json")
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

    private func migrateLegacyCutePanelSizeIfNeeded() {
        var changed = false
        if preferences.displayStyle == "cute" {
            preferences.displayStyle = "refined"
            changed = true
        }
        let clampedWidth = min(560, max(320, preferences.expandedPanelWidth))
        let clampedHeight = min(520, max(220, preferences.expandedPanelHeight))
        if clampedWidth != preferences.expandedPanelWidth || clampedHeight != preferences.expandedPanelHeight {
            preferences.expandedPanelWidth = clampedWidth
            preferences.expandedPanelHeight = clampedHeight
            changed = true
        }
        if changed { savePreferences() }
    }

    private func loadPetState() -> PetState {
        let url = petStateURL()
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(PetState.self, from: data).normalizedAfterLaunch()
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
        let size: NSSize
        if isExpanded, preferences.displayStyle == "cute" {
            // cute 模式宽度固定 320，高度按内容自适应并限制在合理范围
            let height = min(max(preferences.expandedPanelHeight, 200), 600)
            size = NSSize(width: 320, height: height)
        } else if isExpanded {
            let expandedSide = min(max(min(preferences.expandedPanelWidth, preferences.expandedPanelHeight), 240), 640)
            size = NSSize(width: expandedSide, height: expandedSide)
        } else {
            size = NSSize(width: 120, height: 104)
        }
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
