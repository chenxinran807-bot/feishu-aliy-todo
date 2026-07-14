import Foundation

struct TaskFeed: Codable {
    let tasks: [AimeTask]
}

struct AimeTask: Codable, Equatable {
    let id: String
    let title: String
    let sourceType: String?
    let sourceTypes: [String]?
    let status: String
    let statusText: String?
    let dueDate: String?
    let project: String?
    let priority: String?
    let details: String?
    let sourceUrl: String?
    let sourceExcerpt: String?
    let result: String?
    let updateRecord: String?
    let larkTaskGuid: String?
    let larkTaskUrl: String?
    let syncStatus: String?
    let sourceId: String?
    let parentRecordId: String?
    let blocker: String?
    let nextStep: String?

    init(
        id: String,
        title: String,
        sourceType: String? = nil,
        sourceTypes: [String]? = nil,
        status: String,
        statusText: String? = nil,
        dueDate: String?,
        project: String?,
        priority: String? = nil,
        details: String? = nil,
        sourceUrl: String?,
        sourceExcerpt: String? = nil,
        result: String? = nil,
        updateRecord: String? = nil,
        larkTaskGuid: String? = nil,
        larkTaskUrl: String? = nil,
        syncStatus: String? = nil,
        sourceId: String? = nil,
        parentRecordId: String? = nil,
        blocker: String? = nil,
        nextStep: String? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceType = sourceType
        self.sourceTypes = sourceTypes
        self.status = status
        self.statusText = statusText
        self.dueDate = dueDate
        self.project = project
        self.priority = priority
        self.details = details
        self.sourceUrl = sourceUrl
        self.sourceExcerpt = sourceExcerpt
        self.result = result
        self.updateRecord = updateRecord
        self.larkTaskGuid = larkTaskGuid
        self.larkTaskUrl = larkTaskUrl
        self.syncStatus = syncStatus
        self.sourceId = sourceId
        self.parentRecordId = parentRecordId
        self.blocker = blocker
        self.nextStep = nextStep
    }
}

struct TaskPatch: Equatable {
    var title: String?
    var sourceType: String?
    var sourceTypes: [String]?
    var status: String?
    var statusText: String?
    var dueDate: String?
    var project: String?
    var priority: String?
    var details: String?
    var sourceUrl: String?
    var sourceExcerpt: String?
    var result: String?
    var updateRecord: String?
    var larkTaskGuid: String?
    var larkTaskUrl: String?
    var syncStatus: String?
    var sourceId: String?
    var parentRecordId: String?
    var blocker: String?
    var nextStep: String?
}

extension AimeTask {
    func applying(_ patch: TaskPatch) -> AimeTask {
        AimeTask(
            id: id,
            title: patch.title ?? title,
            sourceType: patch.sourceType ?? sourceType,
            sourceTypes: patch.sourceTypes ?? sourceTypes,
            status: patch.status ?? status,
            statusText: patch.statusText ?? statusText,
            dueDate: patch.dueDate ?? dueDate,
            project: patch.project ?? project,
            priority: patch.priority ?? priority,
            details: patch.details ?? details,
            sourceUrl: patch.sourceUrl ?? sourceUrl,
            sourceExcerpt: patch.sourceExcerpt ?? sourceExcerpt,
            result: patch.result ?? result,
            updateRecord: patch.updateRecord ?? updateRecord,
            larkTaskGuid: patch.larkTaskGuid ?? larkTaskGuid,
            larkTaskUrl: patch.larkTaskUrl ?? larkTaskUrl,
            syncStatus: patch.syncStatus ?? syncStatus,
            sourceId: patch.sourceId ?? sourceId,
            parentRecordId: patch.parentRecordId ?? parentRecordId,
            blocker: patch.blocker ?? blocker,
            nextStep: patch.nextStep ?? nextStep
        )
    }
}

struct LocalPreferences: Codable, Equatable {
    var pinnedTaskIds: Set<String> = []
    var hiddenTaskIds: Set<String> = []
    var priorityByTaskId: [String: String] = [:]
    var priorityFilter: String = "all"
    var projectFilter: String = "all"
    var statusFilter: String = "open"
    var visibleNativeTaskGroups: Set<String> = ["p0"]
    var feishuSyncEnabled: Bool = false
    var expandedPanelWidth: Double = 360
    var expandedPanelHeight: Double = 260
    var panelDesignVersion: Int = 2
    var displayStyle: String = "refined"
    var sortKey: String = "priority"
    var sortAscending: Bool = false
    var customDisplayName: String?
    var customIcon: String?
    var lastSceneTaskId: String?
    var lastSceneOpenedAt: String?
    var recentSceneTaskIds: [String] = []
    var lastProactiveTaskId: String?
    var lastProactiveCapturedAt: String?
    var lastProactiveContext: String?

    init(
        pinnedTaskIds: Set<String> = [],
        hiddenTaskIds: Set<String> = [],
        priorityByTaskId: [String: String] = [:],
        priorityFilter: String = "all",
        projectFilter: String = "all",
        statusFilter: String = "open",
        visibleNativeTaskGroups: Set<String> = ["p0"],
        feishuSyncEnabled: Bool = false,
        expandedPanelWidth: Double = 360,
        expandedPanelHeight: Double = 260,
        panelDesignVersion: Int = 2,
        displayStyle: String = "refined",
        sortKey: String = "priority",
        sortAscending: Bool = false,
        customDisplayName: String? = nil,
        customIcon: String? = nil,
        lastSceneTaskId: String? = nil,
        lastSceneOpenedAt: String? = nil,
        recentSceneTaskIds: [String] = [],
        lastProactiveTaskId: String? = nil,
        lastProactiveCapturedAt: String? = nil,
        lastProactiveContext: String? = nil
    ) {
        self.pinnedTaskIds = pinnedTaskIds
        self.hiddenTaskIds = hiddenTaskIds
        self.priorityByTaskId = priorityByTaskId
        self.priorityFilter = priorityFilter
        self.projectFilter = projectFilter
        self.statusFilter = statusFilter
        self.visibleNativeTaskGroups = visibleNativeTaskGroups
        self.feishuSyncEnabled = feishuSyncEnabled
        self.expandedPanelWidth = expandedPanelWidth
        self.expandedPanelHeight = expandedPanelHeight
        self.panelDesignVersion = panelDesignVersion
        self.displayStyle = displayStyle
        self.sortKey = sortKey
        self.sortAscending = sortAscending
        self.customDisplayName = customDisplayName
        self.customIcon = customIcon
        self.lastSceneTaskId = lastSceneTaskId
        self.lastSceneOpenedAt = lastSceneOpenedAt
        self.recentSceneTaskIds = recentSceneTaskIds
        self.lastProactiveTaskId = lastProactiveTaskId
        self.lastProactiveCapturedAt = lastProactiveCapturedAt
        self.lastProactiveContext = lastProactiveContext
    }

    private enum CodingKeys: String, CodingKey {
        case pinnedTaskIds
        case hiddenTaskIds
        case priorityByTaskId
        case priorityFilter
        case projectFilter
        case statusFilter
        case visibleNativeTaskGroups
        case feishuSyncEnabled
        case expandedPanelWidth
        case expandedPanelHeight
        case panelDesignVersion
        case displayStyle
        case sortKey
        case sortAscending
        case customDisplayName
        case customIcon
        case lastSceneTaskId
        case lastSceneOpenedAt
        case recentSceneTaskIds
        case lastProactiveTaskId
        case lastProactiveCapturedAt
        case lastProactiveContext
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pinnedTaskIds = try container.decodeIfPresent(Set<String>.self, forKey: .pinnedTaskIds) ?? []
        self.hiddenTaskIds = try container.decodeIfPresent(Set<String>.self, forKey: .hiddenTaskIds) ?? []
        self.priorityByTaskId = try container.decodeIfPresent([String: String].self, forKey: .priorityByTaskId) ?? [:]
        self.priorityFilter = try container.decodeIfPresent(String.self, forKey: .priorityFilter) ?? "all"
        self.projectFilter = try container.decodeIfPresent(String.self, forKey: .projectFilter) ?? "all"
        self.statusFilter = try container.decodeIfPresent(String.self, forKey: .statusFilter) ?? "open"
        self.visibleNativeTaskGroups = try container.decodeIfPresent(Set<String>.self, forKey: .visibleNativeTaskGroups) ?? ["p0"]
        self.feishuSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .feishuSyncEnabled) ?? false
        self.expandedPanelWidth = try container.decodeIfPresent(Double.self, forKey: .expandedPanelWidth) ?? 360
        self.expandedPanelHeight = try container.decodeIfPresent(Double.self, forKey: .expandedPanelHeight) ?? 260
        self.panelDesignVersion = try container.decodeIfPresent(Int.self, forKey: .panelDesignVersion) ?? 0
        self.displayStyle = try container.decodeIfPresent(String.self, forKey: .displayStyle) ?? "refined"
        self.sortKey = try container.decodeIfPresent(String.self, forKey: .sortKey) ?? "priority"
        self.sortAscending = try container.decodeIfPresent(Bool.self, forKey: .sortAscending) ?? false
        self.customDisplayName = try container.decodeIfPresent(String.self, forKey: .customDisplayName)
        self.customIcon = try container.decodeIfPresent(String.self, forKey: .customIcon)
        self.lastSceneTaskId = try container.decodeIfPresent(String.self, forKey: .lastSceneTaskId)
        self.lastSceneOpenedAt = try container.decodeIfPresent(String.self, forKey: .lastSceneOpenedAt)
        self.recentSceneTaskIds = try container.decodeIfPresent([String].self, forKey: .recentSceneTaskIds) ?? []
        self.lastProactiveTaskId = try container.decodeIfPresent(String.self, forKey: .lastProactiveTaskId)
        self.lastProactiveCapturedAt = try container.decodeIfPresent(String.self, forKey: .lastProactiveCapturedAt)
        self.lastProactiveContext = try container.decodeIfPresent(String.self, forKey: .lastProactiveContext)
    }
}

struct TaskPanelVisualPolicy {
    static let previewTaskLimit = 3
    static let headline = "今天"

    static func usesFeishuNativeLayout(displayStyle: String) -> Bool {
        true
    }

    static func summary(openCount: Int, overdueCount: Int) -> String {
        overdueCount > 0
            ? "\(openCount) 项待办 · \(overdueCount) 项逾期"
            : "\(openCount) 项待办"
    }
}

struct TaskPanelSize: Equatable {
    let width: Double
    let height: Double
}

struct TaskPanelWindowPolicy {
    static func minimumSize(isExpanded: Bool) -> TaskPanelSize {
        isExpanded
            ? TaskPanelSize(width: 320, height: 220)
            : TaskPanelSize(width: 120, height: 104)
    }

    static func maximumSize(isExpanded: Bool) -> TaskPanelSize {
        isExpanded
            ? TaskPanelSize(width: 560, height: 520)
            : TaskPanelSize(width: 120, height: 104)
    }
}

struct RecentScenePolicy {
    static func record(openedTaskId: String, existing: [String], limit: Int) -> [String] {
        let cleanId = openedTaskId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty, limit > 0 else { return Array(existing.prefix(max(0, limit))) }
        var result = [cleanId]
        for taskId in existing where taskId != cleanId {
            result.append(taskId)
            if result.count >= limit { break }
        }
        return result
    }
}

struct SceneMemoryPolicy {
    static func applyingContextMatch(recordId: String, openedAt: String, preferences: LocalPreferences, recentLimit: Int) -> LocalPreferences {
        let cleanId = recordId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return preferences }
        var updated = preferences
        updated.lastSceneTaskId = cleanId
        updated.lastSceneOpenedAt = openedAt
        updated.recentSceneTaskIds = RecentScenePolicy.record(openedTaskId: cleanId, existing: preferences.recentSceneTaskIds, limit: recentLimit)
        return updated
    }

    static func applyingCapture(recordId: String, context: String, capturedAt: String, preferences: LocalPreferences, recentLimit: Int) -> LocalPreferences {
        let cleanId = recordId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return preferences }
        var updated = applyingContextMatch(recordId: cleanId, openedAt: capturedAt, preferences: preferences, recentLimit: recentLimit)
        updated.lastProactiveTaskId = cleanId
        updated.lastProactiveCapturedAt = capturedAt
        updated.lastProactiveContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
        return updated
    }
}

struct DesktopBranding: Equatable {
    static let defaultDisplayName = "神仙待办"
    static let defaultIcon = ""

    let displayName: String
    let icon: String

    init(preferences: LocalPreferences) {
        self.displayName = Self.clean(preferences.customDisplayName) ?? Self.defaultDisplayName
        self.icon = Self.clean(preferences.customIcon) ?? Self.defaultIcon
    }

    private static func clean(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? value?.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
    }
}

struct ProactivePermissionPolicy {
    static func statusText(accessibilityTrusted: Bool) -> String {
        accessibilityTrusted ? "主动捕捉已开启" : "主动捕捉需要辅助功能权限"
    }
}

struct FeishuDesktopActions: Equatable {
    let connected: Bool
    let syncEnabled: Bool
    let assistantAvailable: Bool

    var emptyStateTitle: String {
        connected ? "飞书已连接" : "连接飞书，待办常驻桌面"
    }

    var emptyStateDetail: String {
        connected ? "待办会自动同步到桌面，重要事项主动浮出。" : "点击后自动创建待办库，并绑定助手整理入口。"
    }

    var primaryMenuTitles: [String] {
        guard connected else { return ["连接飞书"] }
        var titles = [
            "立即同步飞书",
            syncEnabled ? "暂停飞书自动同步" : "开启飞书自动同步",
            "打开飞书待办库",
        ]
        if assistantAvailable {
            titles.append("长内容发给助手")
        }
        return titles
    }

    var fallbackMenuTitles: [String] {
        ["新增待办", "粘贴内容补充识别"]
    }

    var supportMenuTitles: [String] {
        ["飞书连接体检", "升级飞书字段"]
    }
}

struct TaskWindowContext: Equatable {
    let appName: String
    let windowTitle: String
    let sourceURL: String?

    var displayText: String {
        [appName, windowTitle].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var searchText: String {
        [displayText, sourceURL ?? ""].filter { !$0.isEmpty }.joined(separator: " ").lowercased()
    }
}

struct SourceURLPolicy {
    static func clean(_ value: String?) -> String? {
        guard var text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "，。；、）)]}>\"'"))
        return text.isEmpty ? nil : text
    }

    static func feishuURL(_ value: String?) -> String? {
        guard let cleanValue = clean(value), let host = URL(string: cleanValue)?.host?.lowercased() else {
            return nil
        }
        guard host.contains("larkoffice.com")
            || host.contains("feishu.cn")
            || host.contains("larksuite.com")
        else {
            return nil
        }
        return cleanValue
    }
}

struct SourceContextPolicy {
    static func sourceType(from text: String) -> String {
        let lowered = text.lowercased()
        if lowered.contains("会议纪要")
            || lowered.contains("妙记")
            || lowered.contains("minutes")
            || lowered.contains("/minutes/")
            || lowered.contains("docx")
            || lowered.contains("文档")
            || lowered.contains("云文档") {
            return "会议纪要"
        }
        return "聊天记录"
    }

    static func isFeishuContext(_ context: TaskWindowContext) -> Bool {
        let text = context.searchText
        return text.contains("飞书")
            || text.contains("lark")
            || text.contains("larkoffice.com")
            || text.contains("feishu.cn")
            || text.contains("larksuite.com")
    }

    static func sourceExcerpt(context: TaskWindowContext, sourceURL: String?) -> String {
        let prefix = sourceURL == nil && !isFeishuContext(context) ? "当前窗口" : "飞书现场"
        return "\(prefix)：\(context.displayText)"
    }
}

struct TaskListPolicy {
    static func isActionable(_ status: String) -> Bool {
        status != "done" && status != "ignored"
    }

    static func isDueToday(_ task: AimeTask, today: String) -> Bool {
        guard let dueDate = task.dueDate else { return false }
        return String(dueDate.prefix(10)) == today
    }

    static func visiblePreviewTasks(_ tasks: [AimeTask], today: String, doneLimit: Int = 3) -> [AimeTask] {
        let active = tasks.filter { isActionable($0.status) }
        let doneToday = tasks.filter { $0.status == "done" && isDueToday($0, today: today) }
        let otherDone = tasks.filter { $0.status == "done" && !isDueToday($0, today: today) }
        return active + Array(doneToday.prefix(doneLimit)) + Array(otherDone.prefix(max(0, doneLimit - doneToday.count)))
    }

    static func missingContextLabels(_ task: AimeTask) -> [String] {
        let hasReturnableSource = SourceURLPolicy.feishuURL(task.sourceUrl) != nil
            || TaskDetailActionPolicy.hasSearchableSource(task)
        return [
            hasReturnableSource ? nil : "飞书来源",
            hasText(task.sourceExcerpt) ? nil : "来源摘要",
            hasText(task.nextStep) ? nil : "下一步",
        ].compactMap { $0 }
    }

    static func needsContext(_ task: AimeTask) -> Bool {
        !missingContextLabels(task).isEmpty
    }

    static func contextMatchScore(_ task: AimeTask, context: TaskWindowContext) -> Int {
        let contextText = context.searchText
        guard !contextText.isEmpty else { return 0 }
        let taskText = [
            task.title,
            task.project ?? "",
            task.sourceType ?? "",
            task.sourceUrl ?? "",
            task.sourceExcerpt ?? "",
            task.details ?? "",
            task.blocker ?? "",
            task.nextStep ?? "",
        ].map { $0.lowercased() }.joined(separator: " ")

        var score = 0
        if sourceSceneMatches(task.sourceExcerpt, context: context) {
            score += 6
        }
        for token in contextTokens(from: context.displayText) where taskText.contains(token.lowercased()) {
            score += token.count >= 4 ? 3 : 2
        }
        if let sourceUrl = task.sourceUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !sourceUrl.isEmpty {
            let normalized = normalizedURLForMatch(sourceUrl)
            if contextText.contains(sourceUrl.lowercased()) || contextText.contains(normalized) {
                score += 8
            }
        }
        return score
    }

    static func contextMatchReason(_ task: AimeTask, context: TaskWindowContext) -> String? {
        let contextText = context.searchText
        guard !contextText.isEmpty else { return nil }
        if let sourceUrl = task.sourceUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !sourceUrl.isEmpty {
            let normalized = normalizedURLForMatch(sourceUrl)
            if contextText.contains(sourceUrl.lowercased()) || contextText.contains(normalized) {
                return "来源链接匹配"
            }
        }
        if sourceSceneMatches(task.sourceExcerpt, context: context) {
            return "来源现场匹配"
        }

        let taskText = [
            task.title,
            task.project ?? "",
            task.sourceType ?? "",
            task.sourceUrl ?? "",
            task.sourceExcerpt ?? "",
            task.details ?? "",
            task.blocker ?? "",
            task.nextStep ?? "",
        ].map { $0.lowercased() }.joined(separator: " ")

        let matchedToken = contextTokens(from: context.displayText)
            .sorted { left, right in left.count > right.count }
            .first { taskText.contains($0.lowercased()) }
        guard let matchedToken else { return nil }
        return "窗口关键词匹配：\(matchedToken)"
    }

    private static func hasText(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private static func contextTokens(from text: String) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)
        let rawTokens = text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
        let stopWords: Set<String> = ["飞书", "lark", "chrome", "google", "codex", "小狗", "神仙", "待办", "窗口", "编辑"]
        var seen = Set<String>()
        let uniqueTokens = rawTokens.filter { token in
            let normalized = token.lowercased()
            guard !stopWords.contains(normalized), !seen.contains(normalized) else { return false }
            seen.insert(normalized)
            return true
        }
        return Array(uniqueTokens.prefix(8))
    }

    private static func normalizedURLForMatch(_ value: String) -> String {
        guard var components = URLComponents(string: value) else {
            return value.lowercased()
        }
        components.query = nil
        components.fragment = nil
        return (components.string ?? value).lowercased()
    }

    private static func sourceSceneMatches(_ value: String?, context: TaskWindowContext) -> Bool {
        guard let source = normalizedSceneText(value), let display = normalizedSceneText(context.displayText) else {
            return false
        }
        return source.contains(display)
    }

    private static func normalizedSceneText(_ value: String?) -> String? {
        let normalized = value?
            .lowercased()
            .replacingOccurrences(of: "飞书现场：", with: "")
            .replacingOccurrences(of: "当前窗口：", with: "")
            .replacingOccurrences(of: "enter 捕捉：", with: "")
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "·", with: "")
            .replacingOccurrences(of: "|", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized?.isEmpty == false ? normalized : nil
    }
}

struct ProactiveCaptureDecision {
    let matchedTaskId: String?
    let candidateTitle: String?
    let sourceURL: String?
    let sourceType: String?
    let sourceExcerpt: String?
    let blocker: String?
    let nextStep: String?

    var isNone: Bool {
        matchedTaskId == nil && candidateTitle == nil
    }
}

struct ProactiveCapturePolicy {
    private static let explicitNextStepMarkers = ["下一步", "下步", "然后", "接着", "继续", "follow", "next", "先"]

    static func decision(tasks: [AimeTask], context: TaskWindowContext, typedText: String?) -> ProactiveCaptureDecision {
        let cleanText = typedText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawBlocker = blockerIntent(from: cleanText)
        let nextStep = rawBlocker == nil ? nextStepIntent(from: cleanText) : explicitNextStepInsideBlocker(from: cleanText)
        let blocker = rawBlocker == nil ? nil : blockerWithoutExplicitNextStep(from: rawBlocker) ?? rawBlocker
        let isFeishuScene = isFeishuContext(context)
        let sourceType = inferredSourceType(context: context, isFeishuScene: isFeishuScene)
        let sourceExcerpt = captureSourceExcerpt(context: context, typedText: cleanText, shouldIncludeText: blocker != nil || nextStep != nil)
        let matchedTask = tasks
            .filter { TaskListPolicy.isActionable($0.status) }
            .max { left, right in
                TaskListPolicy.contextMatchScore(left, context: context) < TaskListPolicy.contextMatchScore(right, context: context)
            }
        if let matchedTask, TaskListPolicy.contextMatchScore(matchedTask, context: context) > 0 {
            let shouldUpdateSourceExcerpt = blocker != nil || nextStep != nil || !hasText(matchedTask.sourceExcerpt)
            return ProactiveCaptureDecision(
                matchedTaskId: matchedTask.id,
                candidateTitle: nil,
                sourceURL: context.sourceURL,
                sourceType: sourceType,
                sourceExcerpt: shouldUpdateSourceExcerpt ? sourceExcerpt : nil,
                blocker: blocker,
                nextStep: nextStep
            )
        }

        guard isFeishuScene else {
            return ProactiveCaptureDecision(matchedTaskId: nil, candidateTitle: nil, sourceURL: nil, sourceType: nil, sourceExcerpt: nil, blocker: nil, nextStep: nil)
        }

        let candidates = TaskCandidateExtractor.extract(from: cleanText ?? "")
        guard let candidateTitle = candidates.first else {
            return ProactiveCaptureDecision(matchedTaskId: nil, candidateTitle: nil, sourceURL: nil, sourceType: nil, sourceExcerpt: nil, blocker: nil, nextStep: nil)
        }
        return ProactiveCaptureDecision(
            matchedTaskId: nil,
            candidateTitle: candidateTitle,
            sourceURL: context.sourceURL,
            sourceType: sourceType,
            sourceExcerpt: sourceExcerpt,
            blocker: nil,
            nextStep: candidateTitle
        )
    }

    private static func captureSourceExcerpt(context: TaskWindowContext, typedText: String?, shouldIncludeText: Bool) -> String {
        guard shouldIncludeText, let typedText, !typedText.isEmpty else {
            return "Enter 捕捉：\(context.displayText)"
        }
        return "Enter 捕捉：\(context.displayText)\n表达：\(String(typedText.prefix(300)))"
    }

    private static func blockerIntent(from text: String?) -> String? {
        guard let cleanText = text?.trimmingCharacters(in: .whitespacesAndNewlines), !cleanText.isEmpty else {
            return nil
        }
        let lowered = cleanText.lowercased()
        let markers = ["卡在", "卡点", "卡住", "阻塞", "blocked", "blocker", "等待", "等确认", "等回复", "风险", "问题是", "问题在"]
        guard markers.contains(where: { lowered.contains($0.lowercased()) }) else {
            return nil
        }
        return cleanText
    }

    private static func nextStepIntent(from text: String?) -> String? {
        guard let cleanText = text?.trimmingCharacters(in: .whitespacesAndNewlines), !cleanText.isEmpty else {
            return nil
        }
        let compact = cleanText.replacingOccurrences(of: " ", with: "")
        if compact.count <= 8 && ["嗯", "嗯嗯", "ok", "okk", "可以", "好的", "收到"].contains(where: { compact.lowercased().hasPrefix($0) }) {
            return nil
        }
        let lowered = cleanText.lowercased()
        let explicitMarkers = ["下一步", "下步", "先", "然后", "接着", "继续", "follow", "next"]
        if explicitMarkers.contains(where: { lowered.contains($0.lowercased()) }) {
            return actionAfterExplicitMarker(from: cleanText) ?? cleanText
        }
        let actionMarkers = ["确认", "推进", "整理", "同步", "补", "发", "写", "改", "看", "回复", "拉齐", "对齐", "输出"]
        guard compact.count >= 10, actionMarkers.contains(where: { lowered.contains($0.lowercased()) }) else {
            return nil
        }
        return cleanText
    }

    private static func explicitNextStepInsideBlocker(from text: String?) -> String? {
        guard let cleanText = text?.trimmingCharacters(in: .whitespacesAndNewlines), !cleanText.isEmpty else {
            return nil
        }
        guard let range = firstExplicitNextStepMarkerRange(in: cleanText) else { return nil }
        return cleanActionSuffix(cleanText[range.upperBound...])
    }

    private static func blockerWithoutExplicitNextStep(from text: String?) -> String? {
        guard let cleanText = text?.trimmingCharacters(in: .whitespacesAndNewlines), !cleanText.isEmpty else {
            return nil
        }
        guard let range = firstExplicitNextStepMarkerRange(in: cleanText) else {
            return cleanText
        }
        let prefix = cleanText[..<range.lowerBound]
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "，,。；;：:")))
        return prefix.isEmpty ? cleanText : String(prefix)
    }

    private static func actionAfterExplicitMarker(from text: String) -> String? {
        guard let range = firstExplicitNextStepMarkerRange(in: text) else { return nil }
        return cleanActionSuffix(text[range.upperBound...])
    }

    private static func firstExplicitNextStepMarkerRange(in text: String) -> Range<String.Index>? {
        explicitNextStepMarkers
            .compactMap { marker in text.range(of: marker, options: .caseInsensitive) }
            .filter { isExplicitMarkerBoundary(range: $0, in: text) }
            .sorted { $0.lowerBound < $1.lowerBound }
            .first
    }

    private static func isExplicitMarkerBoundary(range: Range<String.Index>, in text: String) -> Bool {
        if range.lowerBound == text.startIndex { return true }
        let previous = text[text.index(before: range.lowerBound)]
        return previous.isWhitespace || "，,。；;：:、".contains(previous)
    }

    private static func cleanActionSuffix(_ value: Substring) -> String? {
        let suffix = value.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "，,。；;：:"))
        )
        guard suffix.count >= 2 else { return nil }
        return String(suffix)
    }

    private static func isFeishuContext(_ context: TaskWindowContext) -> Bool {
        let text = context.searchText
        return text.contains("飞书")
            || text.contains("larkoffice.com")
            || text.contains("feishu.cn")
            || text.contains("larksuite.com")
    }

    private static func inferredSourceType(context: TaskWindowContext, isFeishuScene: Bool) -> String? {
        if let sourceURL = context.sourceURL {
            return SourceContextPolicy.sourceType(from: sourceURL)
        }
        guard isFeishuScene else { return nil }
        return SourceContextPolicy.sourceType(from: context.displayText)
    }

    private static func hasText(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

struct TaskResumePolicy {
    static func context(for task: AimeTask) -> String {
        let sourceExcerpt = clean(task.sourceExcerpt) ?? "暂无"
        let blocker = clean(task.blocker) ?? "暂无"
        let details = clean(task.details) ?? "暂无"
        let status = clean(task.statusText) ?? task.status
        let priority = clean(task.priority) ?? "未标记"
        let project = clean(task.project) ?? "未分类"
        let dueDate = clean(task.dueDate) ?? "无截止日期"
        let sourceUrl = sourceLine(for: task)
        return """
        待办：\(task.title)
        状态：\(status)
        优先级：\(priority)
        分类：\(project)
        截止：\(dueDate)
        任务详情：\(details)
        来源摘要：\(sourceExcerpt)
        当前卡点：\(blocker)
        下一步：\(resumeNextStep(for: task))
        飞书来源：\(sourceUrl)
        """
    }

    static func hint(for task: AimeTask, maxLength: Int) -> String {
        var parts: [String] = []
        if let blocker = clean(task.blocker) {
            parts.append("卡点：\(blocker)")
        }
        parts.append("下一步：\(nextStep(for: task))")
        return parts
            .map { String($0.prefix(maxLength)) }
            .joined(separator: "\n")
    }

    static func surfaceSummary(for task: AimeTask, maxLength: Int) -> String {
        let source = clean(task.sourceType) ?? (SourceURLPolicy.feishuURL(task.sourceUrl) == nil ? "未标注来源" : "飞书")
        var parts = ["来源：\(source)"]
        if let blocker = clean(task.blocker) {
            parts.append("卡点：\(blocker)")
        }
        parts.append("下一步：\(nextStep(for: task))")
        return parts
            .map { compact($0, maxLength: maxLength) }
            .joined(separator: "\n")
    }

    static func nextStep(for task: AimeTask) -> String {
        if let nextStep = clean(task.nextStep) {
            return nextStep
        }
        if SourceURLPolicy.feishuURL(task.sourceUrl) != nil {
            return "点击“打开来源链接”，查看来源内容并确认细节后继续推进。"
        }
        if TaskDetailActionPolicy.hasSearchableSource(task) {
            return "点击“搜索来源”，在飞书里搜索关键词并确认细节后继续推进。"
        }
        return "先补充来源链接或任务详情，之后才能从桌面快速打开来源。"
    }

    static func resumeNextStep(for task: AimeTask) -> String {
        if let nextStep = clean(task.nextStep) {
            return nextStep
        }
        if SourceURLPolicy.feishuURL(task.sourceUrl) != nil {
            return "打开来源链接，先确认来源细节，再补充明确下一步。"
        }
        if TaskDetailActionPolicy.hasSearchableSource(task) {
            return "搜索来源关键词，先确认来源细节，再补充明确下一步。"
        }
        return "先补充来源链接或任务详情。"
    }

    private static func clean(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? value?.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
    }

    private static func sourceLine(for task: AimeTask) -> String {
        if let sourceUrl = SourceURLPolicy.feishuURL(task.sourceUrl) {
            return sourceUrl
        }
        if TaskDetailActionPolicy.hasSearchableSource(task) {
            return "可搜索飞书现场：\(SourceSearchPolicy.searchText(for: task, maxLength: 80))"
        }
        return "暂无飞书来源"
    }

    private static func compact(_ value: String, maxLength: Int) -> String {
        guard maxLength > 0, value.count > maxLength else { return value }
        return "\(value.prefix(maxLength))..."
    }
}

struct TaskDetailAction: Equatable {
    let title: String
    let kind: String
}

struct TaskDetailActionPolicy {
    static func hasSearchableSource(_ task: AimeTask) -> Bool {
        SourceURLPolicy.feishuURL(task.sourceUrl) == nil && [
            task.sourceExcerpt,
            task.sourceType,
            task.details,
        ].contains(where: hasSearchableSource)
    }

    static func actions(for task: AimeTask) -> [TaskDetailAction] {
        var actions: [TaskDetailAction] = []
        actions.append(TaskSceneReturnPolicy.primaryAction(for: task))
        if SourceURLPolicy.feishuURL(task.sourceUrl) != nil {
            actions.append(TaskDetailAction(title: "修改来源链接", kind: "linkFeishuURL"))
        } else if hasSearchableSource(task) {
            actions.append(TaskDetailAction(title: "补来源链接", kind: "linkFeishuURL"))
        }
        actions.append(TaskDetailAction(title: "编辑", kind: "edit"))
        actions.append(TaskDetailAction(title: "关闭", kind: "close"))
        return actions
    }

    private static func hasText(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private static func hasSearchableSource(_ value: String?) -> Bool {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return false
        }
        return text.contains("飞书现场")
            || text.contains("当前窗口")
            || text.contains("Enter 捕捉")
            || text.contains("主动捕捉")
            || text.contains("飞书")
            || text.contains("聊天记录")
            || text.contains("群聊")
            || text.contains("私聊")
            || text.contains("会议纪要")
            || text.contains("文档")
    }
}

struct SourceSearchPolicy {
    static func searchText(for task: AimeTask, maxLength: Int = 120) -> String {
        let source = cleanedSource(task.sourceExcerpt)
        let values = [
            source,
            task.sourceType,
            task.title,
            task.project,
            task.details,
            task.blocker,
            task.nextStep,
        ]
        return compactUnique(values, maxLength: maxLength)
    }

    private static func cleanedSource(_ value: String?) -> String? {
        guard let raw = clean(value) else { return nil }
        let firstLine = raw
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? raw
        let prefixes = ["飞书现场：", "当前窗口：", "Enter 捕捉："]
        let withoutPrefix = prefixes.reduce(firstLine) { current, prefix in
            current.hasPrefix(prefix) ? String(current.dropFirst(prefix.count)) : current
        }
        return clean(withoutPrefix.replacingOccurrences(of: " · ", with: " "))
    }

    private static func compactUnique(_ values: [String?], maxLength: Int) -> String {
        var seen = Set<String>()
        var parts: [String] = []
        for value in values {
            guard let cleaned = clean(value) else { continue }
            let normalized = cleaned
                .lowercased()
                .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
            guard !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            parts.append(cleaned)
        }
        let joined = parts.joined(separator: " ")
        guard maxLength > 0, joined.count > maxLength else { return joined }
        return String(joined.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func clean(_ value: String?) -> String? {
        let cleaned = value?
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned?.isEmpty == false ? cleaned : nil
    }
}

struct SourceSearchHandoffPolicy {
    static func detail(accessibilityTrusted: Bool, query: String) -> String {
        let preview = String(query.prefix(60))
        if accessibilityTrusted {
            return "已打开飞书并尝试填入全局搜索：\(preview)。随后会把任务上下文放回剪贴板。"
        }
        return "已打开飞书，关键词已复制，可直接搜索：\(preview)"
    }
}

struct TaskSceneReturnPolicy {
    static func isReturnable(_ task: AimeTask) -> Bool {
        SourceURLPolicy.feishuURL(task.sourceUrl) != nil || TaskDetailActionPolicy.hasSearchableSource(task)
    }

    static func primaryAction(for task: AimeTask) -> TaskDetailAction {
        if SourceURLPolicy.feishuURL(task.sourceUrl) != nil {
            return TaskDetailAction(title: "打开来源链接", kind: "open")
        }
        if TaskDetailActionPolicy.hasSearchableSource(task) {
            return TaskDetailAction(title: "搜索来源", kind: "copySourceSearch")
        }
        return TaskDetailAction(title: "补来源链接", kind: "linkFeishuURL")
    }
}

struct ContextTaskRankingPolicy {
    static func score(task: AimeTask, context: TaskWindowContext?, lastSceneTaskId: String?, isRecentSceneOpen: Bool) -> Int {
        var score = 0
        let matchScore = context.map { TaskListPolicy.contextMatchScore(task, context: $0) } ?? 0
        score += matchScore
        if matchScore > 0 {
            if TaskSceneReturnPolicy.isReturnable(task) {
                score += 2
            }
            if hasText(task.nextStep) {
                score += 1
            }
            if hasText(task.blocker) {
                score += 1
            }
            if task.status == "doing" || task.statusText == "进行中" {
                score += 2
            }
            if priorityRank(task.priority) == 0 {
                score += 4
            } else if priorityRank(task.priority) == 1 {
                score += 1
            }
            if isOverdue(task) {
                score += 4
            } else if isDueToday(task) {
                score += 1
            }
        }
        if task.id == lastSceneTaskId && isRecentSceneOpen {
            score += 6
        }
        return score
    }

    private static func hasText(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private static func priorityRank(_ value: String?) -> Int {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "P0": return 0
        case "P1": return 1
        case "P2": return 2
        case "P3": return 3
        default: return 2
        }
    }

    private static func isOverdue(_ task: AimeTask) -> Bool {
        guard let date = normalizedDate(task.dueDate) else { return false }
        return date < currentDateKey()
    }

    private static func isDueToday(_ task: AimeTask) -> Bool {
        normalizedDate(task.dueDate) == currentDateKey()
    }

    private static func normalizedDate(_ value: String?) -> String? {
        guard let value, value.count >= 10 else { return nil }
        return String(value.prefix(10))
    }

    private static func currentDateKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

struct LocalPendingSyncPolicy {
    static func arguments(for task: AimeTask, localTaskPrefix: String = "local-") -> [String] {
        let isLocalCreate = task.id.hasPrefix(localTaskPrefix)
        var arguments = isLocalCreate
            ? ["create", "--title", task.title]
            : ["update", "--record-id", task.id]

        if !isLocalCreate {
            arguments += ["--title", task.title]
        }
        if let dueDate = clean(task.dueDate) {
            arguments += ["--due-date", dueDate]
        }
        if let project = clean(task.project) {
            arguments += ["--project", project]
        }
        if let priority = clean(task.priority) {
            arguments += ["--priority", priority]
        }
        if let status = syncStatus(task) {
            arguments += ["--status", status]
        }
        if let sourceType = clean(task.sourceType) {
            arguments += ["--source-type", sourceType]
        }
        if let sourceUrl = SourceURLPolicy.feishuURL(task.sourceUrl) {
            arguments += ["--source-url", sourceUrl]
        }
        if let details = clean(task.details) {
            arguments += ["--details", details]
        }
        if let sourceExcerpt = clean(task.sourceExcerpt) {
            arguments += ["--source-excerpt", sourceExcerpt]
        }
        if let result = clean(task.result) {
            arguments += ["--result", result]
        }
        return arguments
    }

    private static func syncStatus(_ task: AimeTask) -> String? {
        if task.status == "open", clean(task.statusText) == "进行中" {
            return "doing"
        }
        return clean(task.status)
    }

    private static func clean(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? value?.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
    }
}

struct TaskCandidateExtractor {
    static func extract(from text: String) -> [String] {
        let lines = text
            .components(separatedBy: .newlines)
            .map(cleanLine)
            .filter { !$0.isEmpty && !isChromeLine($0) }

        let actionKeywords = ["跟进", "确认", "整理", "同步", "发", "写", "改", "补", "看", "处理", "推进", "对齐", "回复", "约", "评估", "输出", "拉", "拆", "试下"]
        let candidates = lines.filter { line in
            guard !isCasualAck(line) else { return false }
            return actionKeywords.contains { line.contains($0) } || line.contains("明天") || line.contains("今天") || line.contains("本周") || line.contains("下周")
        }
        return candidates.prefix(8).map { String($0.prefix(80)) }
    }

    private static func cleanLine(_ value: String) -> String {
        var line = value.trimmingCharacters(in: .whitespacesAndNewlines)
        line = line.replacingOccurrences(of: #"^\s*(回复\s+)?[^:：]{1,12}[:：]\s*"#, with: "", options: .regularExpression)
        line = line.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isChromeLine(_ line: String) -> Bool {
        let lowered = line.lowercased()
        if lowered.contains("codex / file") || lowered.contains("analyse airjelly") { return true }
        if ["打开位置", "截屏总结待办", "从剪贴板识别待办"].contains(line) { return true }
        return false
    }

    private static func isCasualAck(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        if compact.count <= 8 && ["嗯", "嗯嗯", "ok", "okk", "可以", "好的"].contains(where: { compact.lowercased().hasPrefix($0) }) {
            return true
        }
        return false
    }
}
