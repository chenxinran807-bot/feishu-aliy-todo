import Foundation

func assertEqual<T: Equatable>(_ lhs: T, _ rhs: T, _ message: String) {
    if lhs != rhs {
        fatalError("\(message) (expected \(rhs), got \(lhs))")
    }
}

@main
struct PetStateTests {
    static func main() {
        let today = "2026-06-23"
        let tasks = [
            AimeTask(id: "p0", title: "紧急任务", status: "open", dueDate: "2026-06-23", project: "AI", sourceUrl: nil),
            AimeTask(id: "normal", title: "普通任务", status: "open", dueDate: "2026-06-30", project: "AI", sourceUrl: nil),
            AimeTask(id: "done", title: "已完成", status: "done", dueDate: "2026-06-23", project: "AI", sourceUrl: nil),
            AimeTask(id: "ignored", title: "已忽略", status: "ignored", dueDate: "2026-06-23", project: "AI", sourceUrl: nil),
            AimeTask(id: "hidden", title: "隐藏任务", status: "open", dueDate: "2026-06-23", project: "AI", sourceUrl: nil),
            AimeTask(id: "pinned", title: "置顶任务", status: "open", dueDate: nil, project: "AI", sourceUrl: nil),
            AimeTask(id: "early", title: "优先级任务", status: "open", dueDate: "2026-06-21", project: "AI", sourceUrl: nil),
        ]

        let preferences = LocalPreferences(
            pinnedTaskIds: ["pinned"],
            hiddenTaskIds: ["hidden"],
            priorityByTaskId: ["p0": "P0", "pinned": "P1", "normal": "P2", "early": "P2"],
            priorityFilter: "all",
            projectFilter: "all",
            statusFilter: "open",
            expandedPanelWidth: 400,
            expandedPanelHeight: 560,
            displayStyle: "refined"
        )

        let defaultBrand = DesktopBranding(preferences: LocalPreferences())
        assertEqual(defaultBrand.displayName, "神仙待办", "default desktop brand should be 神仙待办")
        assertEqual(defaultBrand.icon, "", "default desktop brand should not render an identity icon")
        assertEqual(LocalPreferences().displayStyle, "refined", "default display style should be the native refined mode")
        assertEqual(LocalPreferences().expandedPanelWidth, 360, "default panel width should remain compact")
        assertEqual(LocalPreferences().expandedPanelHeight, 260, "default panel height should remain compact")
        assertEqual(LocalPreferences().panelDesignVersion, 2, "new preferences should use the lightweight panel design")
        assertEqual(TaskPanelVisualPolicy.usesFeishuNativeLayout(displayStyle: "refined"), true, "refined mode should use the Feishu-native layout")
        assertEqual(TaskPanelVisualPolicy.usesFeishuNativeLayout(displayStyle: "cute"), true, "legacy style values should not restore the old card layout")
        assertEqual(TaskPanelVisualPolicy.summary(openCount: 14, overdueCount: 3), "14 项待办 · 3 项逾期", "task summary should use concise Chinese copy")
        assertEqual(TaskPanelVisualPolicy.previewTaskLimit, 3, "the always-on panel should show only three priority tasks")
        assertEqual(TaskPanelVisualPolicy.headline, "今天", "the lightweight panel should use the approved native headline")
        let groupedPreview = TaskPanelVisualPolicy.groupedPreview(
            tasks: [
                AimeTask(id: "normal", title: "普通任务", status: "waiting", dueDate: "2026-06-30", project: "AI", sourceUrl: nil),
                AimeTask(id: "p0", title: "紧急任务", status: "open", dueDate: "2026-06-23", project: "AI", sourceUrl: nil),
                AimeTask(id: "early", title: "逾期任务", status: "open", dueDate: "2026-06-21 18:00:00", project: "AI", sourceUrl: nil),
                AimeTask(id: "extra", title: "超出预览限制", status: "open", dueDate: nil, project: "AI", sourceUrl: nil),
                AimeTask(id: "done", title: "已完成", status: "done", dueDate: "2026-06-20", project: "AI", sourceUrl: nil),
            ],
            priorities: ["p0": "P0", "normal": "P2", "early": "P2"],
            today: today
        )
        assertEqual(groupedPreview.priority.map(\.id), ["p0", "early"], "P0 and overdue tasks should be handled first")
        assertEqual(groupedPreview.next.map(\.id), ["normal"], "remaining preview tasks should appear next")
        assertEqual(TaskPanelVisualPolicy.subtitle(openCount: 4, syncSucceeded: true), "4 项待办 · 飞书已同步", "subtitle should combine count and sync state")
        assertEqual(TaskPanelVisualPolicy.subtitle(openCount: 4, syncSucceeded: false), "4 项待办 · 等待飞书同步", "subtitle should explain pending sync")
        assertEqual(TaskPanelVisualPolicy.showsDashboardStats, false, "reminders mode must not render dashboard cards")
        assertEqual(TaskPanelWindowPolicy.minimumSize(isExpanded: false), TaskPanelSize(width: 120, height: 104), "collapsed widgets must be allowed to shrink below expanded minimums")
        assertEqual(TaskPanelWindowPolicy.minimumSize(isExpanded: true), TaskPanelSize(width: 320, height: 220), "expanded panels should keep a usable minimum size")

        let customBrand = DesktopBranding(preferences: LocalPreferences(customDisplayName: "我的飞书雷达", customIcon: "✨"))
        assertEqual(customBrand.displayName, "我的飞书雷达", "users should be able to customize the desktop display name")
        assertEqual(customBrand.icon, "✨", "users should be able to customize the desktop icon")

        let emptyBrand = DesktopBranding(preferences: LocalPreferences(customDisplayName: "  ", customIcon: ""))
        assertEqual(emptyBrand.displayName, "神仙待办", "blank custom names should fall back to the default brand")
        assertEqual(emptyBrand.icon, "", "blank custom icons should not create an identity icon")

        assertEqual(ProactivePermissionPolicy.statusText(accessibilityTrusted: true), "主动捕捉已开启", "trusted accessibility should show proactive capture as enabled")
        assertEqual(ProactivePermissionPolicy.statusText(accessibilityTrusted: false), "主动捕捉需要辅助功能权限", "missing accessibility should explain why proactive capture may not work")

        assertEqual(
            RecentScenePolicy.record(openedTaskId: "a", existing: ["b", "c"], limit: 5),
            ["a", "b", "c"],
            "newly opened scenes should be placed first"
        )
        assertEqual(
            RecentScenePolicy.record(openedTaskId: "b", existing: ["a", "b", "c"], limit: 5),
            ["b", "a", "c"],
            "reopened scenes should move to the front without duplicates"
        )
        assertEqual(
            RecentScenePolicy.record(openedTaskId: "f", existing: ["a", "b", "c", "d", "e"], limit: 5),
            ["f", "a", "b", "c", "d"],
            "recent scenes should be capped"
        )

        let snapshot = PetState.derive(tasks: tasks, preferences: preferences, previous: PetState(), today: today)
        assertEqual(snapshot.pendingKibbleCount, 4, "pending kibble should include only actionable visible tasks")
        assertEqual(snapshot.p0Count, 1, "P0 count should come from actionable high-priority tasks")
        assertEqual(snapshot.nextTaskId, "pinned", "pinned tasks should be selected first for next task")
        assertEqual(snapshot.overdueCount, 1, "one overdue task should be derived")
        assertEqual(snapshot.dogMood, .concerned, "overdue should switch mood to concerned")

        let noPinSnapshot = PetState.derive(
            tasks: tasks,
            preferences: LocalPreferences(
                pinnedTaskIds: [],
                hiddenTaskIds: ["hidden"],
                priorityByTaskId: ["p0": "P0", "pinned": "P1", "normal": "P2", "early": "P2"],
                priorityFilter: "all",
                projectFilter: "all",
                statusFilter: "open",
                expandedPanelWidth: 400,
                expandedPanelHeight: 560,
                displayStyle: "refined"
            ),
            previous: PetState(),
            today: today
        )
        assertEqual(noPinSnapshot.nextTaskId, "p0", "P0 should beat normal tasks when sorting next task")

        let withReward = PetState(pendingKibbleCount: 4, fedTodayCount: 2, intimacy: 2, dogMood: .foundTask, lastRewardedTaskIds: ["done"], rewardDate: today, p0Count: 1, overdueCount: 0, nextTaskId: "p0")
        let rewarded = withReward.rewardIfNeeded(taskId: "p0", today: today)
        assertEqual(rewarded.pendingKibbleCount, 3, "reward should consume one kibble")
        assertEqual(rewarded.fedTodayCount, 3, "reward should increment today's feed count")
        assertEqual(rewarded.intimacy, 3, "reward should increment intimacy")
        assertEqual(rewarded.dogMood, .walking, "reward should set walking mood")

        let duplicate = rewarded.rewardIfNeeded(taskId: "p0", today: today)
        assertEqual(duplicate.pendingKibbleCount, 3, "same task should not reward twice")
        assertEqual(duplicate.fedTodayCount, 3, "same task should not double increment feed count")

        let nextDayDuplicate = rewarded.rewardIfNeeded(taskId: "p0", today: "2026-06-24")
        assertEqual(nextDayDuplicate.pendingKibbleCount, 3, "same task should not reward twice across days")
        assertEqual(nextDayDuplicate.fedTodayCount, 0, "new day should reset feed count without rewarding duplicate task")
        assertEqual(nextDayDuplicate.intimacy, 3, "duplicate task should not increase intimacy across days")

        let overdueSnapshot = PetState.derive(
            tasks: [
                AimeTask(id: "late", title: "逾期", status: "open", dueDate: "2026-06-22", project: "AI", sourceUrl: nil),
            ],
            preferences: LocalPreferences(),
            previous: PetState(),
            today: "2026-06-23"
        )
        assertEqual(overdueSnapshot.overdueCount, 1, "overdue count should include past-due actionable tasks")
        assertEqual(overdueSnapshot.dogMood, .concerned, "overdue task should trigger concerned mood")

        let yesterdayReward = PetState(
            pendingKibbleCount: 1,
            fedTodayCount: 4,
            intimacy: 7,
            dogMood: .idle,
            lastRewardedTaskIds: [],
            rewardDate: "2026-06-22",
            p0Count: 0,
            overdueCount: 0,
            nextTaskId: nil
        )
        let todayReward = yesterdayReward.rewardIfNeeded(taskId: "new-task", today: "2026-06-23")
        assertEqual(todayReward.fedTodayCount, 1, "fed count should reset before first reward on a new day")
        assertEqual(todayReward.intimacy, 8, "intimacy should survive daily reset")

        let persistedWalking = PetState(
            pendingKibbleCount: 0,
            fedTodayCount: 1,
            intimacy: 8,
            dogMood: .walking,
            lastRewardedTaskIds: ["new-task"],
            rewardDate: "2026-06-23",
            p0Count: 0,
            overdueCount: 0,
            nextTaskId: nil
        )
        assertEqual(persistedWalking.normalizedAfterLaunch().dogMood, .idle, "launch should recover from transient walking mood")
        let persistedHappyReturn = PetState(
            pendingKibbleCount: 0,
            fedTodayCount: 1,
            intimacy: 8,
            dogMood: .happyReturn,
            lastRewardedTaskIds: ["new-task"],
            rewardDate: "2026-06-23",
            p0Count: 0,
            overdueCount: 0,
            nextTaskId: nil
        )
        assertEqual(persistedHappyReturn.normalizedAfterLaunch().dogMood, .idle, "launch should recover from transient happy-return mood")
        let persistedSniffing = PetState(
            pendingKibbleCount: 0,
            fedTodayCount: 1,
            intimacy: 8,
            dogMood: .sniffing,
            lastRewardedTaskIds: ["new-task"],
            rewardDate: "2026-06-23",
            p0Count: 0,
            overdueCount: 0,
            nextTaskId: nil
        )
        assertEqual(persistedSniffing.normalizedAfterLaunch().dogMood, .idle, "launch should recover from transient sniffing mood")

        let sniffingSnapshot = PetState.derive(
            tasks: tasks,
            preferences: preferences,
            previous: PetState(dogMood: .sniffing),
            today: today
        )
        assertEqual(sniffingSnapshot.dogMood, .sniffing, "derive should not overwrite an active sniffing mood")

        let legacyTaskJSON = """
        {
          "tasks": [
            {
              "id": "legacy",
              "title": "旧任务",
              "status": "open",
              "dueDate": "2026-06-24",
              "project": "AI",
              "sourceUrl": null
            }
          ]
        }
        """.data(using: .utf8)!
        let legacyFeed = try! JSONDecoder().decode(TaskFeed.self, from: legacyTaskJSON)
        assertEqual(legacyFeed.tasks.first?.details, nil, "legacy task JSON without details should decode")

        let legacyPreferencesJSON = """
        {
          "pinnedTaskIds": ["pinned"],
          "hiddenTaskIds": ["hidden"],
          "priorityByTaskId": {"p0": "P0"},
          "priorityFilter": "all",
          "projectFilter": "AI",
          "statusFilter": "open",
          "expandedPanelWidth": 220,
          "expandedPanelHeight": 220,
          "displayStyle": "cute"
        }
        """.data(using: .utf8)!
        let legacyPreferences = try! JSONDecoder().decode(LocalPreferences.self, from: legacyPreferencesJSON)
        assertEqual(legacyPreferences.pinnedTaskIds, ["pinned"], "legacy preferences should preserve pinned tasks")
        assertEqual(legacyPreferences.projectFilter, "AI", "legacy preferences should preserve project filter")
        assertEqual(legacyPreferences.visibleNativeTaskGroups, ["p0"], "legacy preferences should get default visible filter groups")
        assertEqual(legacyPreferences.panelDesignVersion, 0, "legacy preferences should be marked for one-time panel size migration")

        let disconnectedActions = FeishuDesktopActions(connected: false, syncEnabled: false, assistantAvailable: false)
        assertEqual(disconnectedActions.primaryMenuTitles, ["连接飞书"], "disconnected users should only see Feishu connection as the primary action")
        assertEqual(disconnectedActions.supportMenuTitles, ["飞书连接体检", "升级飞书字段"], "support actions should be available without becoming the primary connection path")
        assertEqual(disconnectedActions.emptyStateTitle, "连接飞书，待办常驻桌面", "disconnected empty state should frame Feishu as the setup path")

        let connectedActions = FeishuDesktopActions(connected: true, syncEnabled: true, assistantAvailable: false)
        assertEqual(connectedActions.primaryMenuTitles, ["立即同步飞书", "暂停飞书自动同步", "打开飞书待办库"], "connected users should see sync and Base before fallback capture actions")
        assertEqual(connectedActions.supportMenuTitles, ["飞书连接体检", "升级飞书字段"], "connected users should still have lightweight troubleshooting and schema upgrade paths")
        assertEqual(connectedActions.fallbackMenuTitles, ["新增待办", "粘贴内容补充识别"], "manual capture should stay secondary to the Feishu context loop")
        assertEqual(connectedActions.emptyStateTitle, "飞书已连接", "connected empty state should emphasize the Feishu link")

        let assistantActions = FeishuDesktopActions(connected: true, syncEnabled: false, assistantAvailable: true)
        assertEqual(assistantActions.primaryMenuTitles, ["立即同步飞书", "开启飞书自动同步", "打开飞书待办库", "长内容发给助手"], "assistant should appear only as a connected Feishu companion action")

        let previewTasks = TaskListPolicy.visiblePreviewTasks(
            [
                AimeTask(id: "open-today", title: "今日待办", status: "open", dueDate: "2026-06-23 18:00:00", project: "AI", sourceUrl: nil),
                AimeTask(id: "done-today", title: "今日已办", status: "done", dueDate: "2026-06-23 18:00:00", project: "AI", sourceUrl: nil),
                AimeTask(id: "done-old", title: "历史已办", status: "done", dueDate: "2026-06-21 18:00:00", project: "AI", sourceUrl: nil),
            ],
            today: today,
            doneLimit: 1
        )
        assertEqual(previewTasks.map(\.id), ["open-today", "done-today"], "default preview should show active tasks first and a bounded set of today's completed tasks at the bottom")

        let completeContextTask = AimeTask(
            id: "complete-context",
            title: "上下文完整",
            status: "open",
            dueDate: "2026-06-24",
            project: "AI",
            details: "任务详情",
            sourceUrl: "https://bytedance.larkoffice.com/docx/example",
            sourceExcerpt: "来自飞书文档",
            blocker: nil,
            nextStep: "回到文档继续推进"
        )
        assertEqual(TaskListPolicy.missingContextLabels(completeContextTask), [], "complete context should not require any extra fields")
        assertEqual(TaskListPolicy.needsContext(completeContextTask), false, "complete context should not be in the needs-context filter")

        let missingContextTask = AimeTask(
            id: "missing-context",
            title: "缺上下文",
            status: "open",
            dueDate: "2026-06-24",
            project: "AI",
            sourceUrl: nil
        )
        assertEqual(TaskListPolicy.missingContextLabels(missingContextTask), ["飞书来源", "来源摘要", "下一步"], "needs-context should call out exactly the fields needed for resume")
        assertEqual(TaskListPolicy.needsContext(missingContextTask), true, "tasks without source and next step should be in the needs-context filter")

        let nonFeishuSourceTask = AimeTask(
            id: "non-feishu-source",
            title: "普通网页来源",
            status: "open",
            dueDate: "2026-06-24",
            project: "AI",
            sourceUrl: "https://example.com/context",
            sourceExcerpt: "普通网页",
            nextStep: nil
        )
        assertEqual(SourceURLPolicy.feishuURL(nonFeishuSourceTask.sourceUrl), nil, "non-Feishu links should not count as returnable Feishu scenes")
        assertEqual(TaskListPolicy.missingContextLabels(nonFeishuSourceTask), ["飞书来源", "下一步"], "non-Feishu links should still require a Feishu source")
        let searchableSourceCompleteTask = AimeTask(
            id: "searchable-source-complete",
            title: "可搜索飞书现场",
            sourceType: "聊天记录",
            status: "open",
            dueDate: "2026-06-24",
            project: "AI",
            sourceUrl: nil,
            sourceExcerpt: "飞书现场：飞书 · 男装项目群",
            nextStep: "回群里确认"
        )
        assertEqual(TaskListPolicy.missingContextLabels(searchableSourceCompleteTask), [], "searchable Feishu scenes should count as having a returnable source")
        assertEqual(TaskListPolicy.needsContext(searchableSourceCompleteTask), false, "searchable Feishu scenes with next steps should not appear in needs-context")
        assertEqual(
            TaskResumePolicy.context(for: searchableSourceCompleteTask).contains("飞书来源：可搜索飞书现场"),
            true,
            "resume context should explain that no-URL Feishu scenes can still be searched"
        )
        assertEqual(
            SourceURLPolicy.feishuURL(" https://bytedance.larkoffice.com/docx/source-test）。 "),
            "https://bytedance.larkoffice.com/docx/source-test",
            "Feishu source URLs should be trimmed before being saved or opened"
        )
        let feishuDesktopContext = TaskWindowContext(appName: "飞书", windowTitle: "男装项目群", sourceURL: nil)
        assertEqual(SourceContextPolicy.isFeishuContext(feishuDesktopContext), true, "Feishu desktop windows should count as returnable Feishu scenes")
        assertEqual(SourceContextPolicy.sourceType(from: feishuDesktopContext.displayText), "聊天记录", "Feishu chat windows should be classified as chat records")
        assertEqual(
            SourceContextPolicy.sourceExcerpt(context: feishuDesktopContext, sourceURL: nil),
            "飞书现场：飞书 · 男装项目群",
            "Feishu desktop windows should be saved as Feishu scenes even without a URL"
        )
        let docContext = TaskWindowContext(appName: "飞书", windowTitle: "男装复盘云文档", sourceURL: nil)
        assertEqual(SourceContextPolicy.sourceType(from: docContext.displayText), "会议纪要", "Feishu document contexts should be classified as meeting/document notes")
        let finderContext = TaskWindowContext(appName: "Finder", windowTitle: "Downloads", sourceURL: nil)
        assertEqual(SourceContextPolicy.isFeishuContext(finderContext), false, "ordinary desktop windows should not count as Feishu scenes")
        assertEqual(
            SourceContextPolicy.sourceExcerpt(context: finderContext, sourceURL: nil),
            "当前窗口：Finder · Downloads",
            "non-Feishu windows should be saved as ordinary current-window context"
        )

        let blockedButResumableTask = AimeTask(
            id: "blocked-resumable",
            title: "有卡点但可恢复",
            status: "open",
            dueDate: "2026-06-24",
            project: "AI",
            sourceUrl: "https://bytedance.larkoffice.com/docx/example",
            sourceExcerpt: "来自飞书文档",
            blocker: "等待确认口径",
            nextStep: "回群里确认"
        )
        assertEqual(TaskListPolicy.needsContext(blockedButResumableTask), false, "blocker is useful context but should not make a task incomplete by itself")

        let urlMatchedTask = AimeTask(
            id: "url-match",
            title: "男装搭配接入启动",
            status: "open",
            dueDate: "2026-06-24",
            project: "AI穿搭",
            sourceUrl: "https://bytedance.larkoffice.com/docx/abc123?refer_index=1",
            sourceExcerpt: "飞书文档说明",
            nextStep: "回到文档继续推进"
        )
        let matchingURLContext = TaskWindowContext(
            appName: "Google Chrome",
            windowTitle: "飞书文档",
            sourceURL: "https://bytedance.larkoffice.com/docx/abc123?psg_id=999"
        )
        assertEqual(TaskListPolicy.contextMatchScore(urlMatchedTask, context: matchingURLContext) > 0, true, "context matching should survive Feishu URL query parameter changes")
        assertEqual(TaskListPolicy.contextMatchReason(urlMatchedTask, context: matchingURLContext), "来源链接匹配", "URL matches should explain why the task surfaced")

        let titleMatchedContext = TaskWindowContext(
            appName: "飞书",
            windowTitle: "AI穿搭 项目群",
            sourceURL: nil
        )
        assertEqual(TaskListPolicy.contextMatchScore(urlMatchedTask, context: titleMatchedContext) > 0, true, "context matching should use useful window title tokens")
        assertEqual(TaskListPolicy.contextMatchReason(urlMatchedTask, context: titleMatchedContext), "窗口关键词匹配：AI穿搭", "title-token matches should explain the strongest matched token")

        let exactSceneSourceTask = AimeTask(
            id: "exact-scene-source",
            title: "价格带规则确认",
            status: "open",
            dueDate: "2026-06-24",
            project: "AI穿搭",
            sourceUrl: nil,
            sourceExcerpt: "飞书现场：飞书 · AI穿搭 项目群",
            nextStep: "回群里确认"
        )
        assertEqual(
            TaskListPolicy.contextMatchScore(exactSceneSourceTask, context: titleMatchedContext)
                > TaskListPolicy.contextMatchScore(urlMatchedTask, context: titleMatchedContext),
            true,
            "exact saved Feishu scene should outrank a generic project-token match"
        )
        assertEqual(
            TaskListPolicy.contextMatchReason(exactSceneSourceTask, context: titleMatchedContext),
            "来源现场匹配",
            "exact saved Feishu scene matches should explain the stronger reason"
        )

        let blockerMatchedTask = AimeTask(
            id: "blocker-match",
            title: "价格规则推进",
            status: "open",
            dueDate: "2026-06-24",
            project: "AI穿搭",
            sourceUrl: "https://bytedance.larkoffice.com/docx/blocker",
            sourceExcerpt: "评测方向文档",
            blocker: "卡在等待法务确认价格规则",
            nextStep: "回群里拉齐口径"
        )
        let blockerMatchedContext = TaskWindowContext(
            appName: "飞书",
            windowTitle: "法务确认价格规则",
            sourceURL: nil
        )
        assertEqual(TaskListPolicy.contextMatchScore(blockerMatchedTask, context: blockerMatchedContext) > 0, true, "current blocker text should help surface the task when switching to the blocker scene")
        assertEqual(TaskListPolicy.contextMatchReason(blockerMatchedTask, context: blockerMatchedContext), "窗口关键词匹配：法务确认价格规则", "blocker-token matches should explain why the task surfaced")

        let unrelatedContext = TaskWindowContext(
            appName: "Google Chrome",
            windowTitle: "无关网页",
            sourceURL: "https://example.com"
        )
        assertEqual(TaskListPolicy.contextMatchScore(urlMatchedTask, context: unrelatedContext), 0, "unrelated windows should not surface a task")
        assertEqual(TaskListPolicy.contextMatchReason(urlMatchedTask, context: unrelatedContext), nil, "unrelated windows should not produce a match reason")

        let brandOnlyContext = TaskWindowContext(
            appName: "神仙待办",
            windowTitle: "待办窗口",
            sourceURL: nil
        )
        assertEqual(TaskListPolicy.contextMatchScore(urlMatchedTask, context: brandOnlyContext), 0, "desktop brand words should not create false task matches")

        let enterMatchDecision = ProactiveCapturePolicy.decision(
            tasks: [urlMatchedTask],
            context: matchingURLContext,
            typedText: "确认这个接入方案可以继续推进"
        )
        assertEqual(enterMatchDecision.matchedTaskId, "url-match", "enter capture should attach intent to an existing matching task first")
        assertEqual(enterMatchDecision.sourceURL, matchingURLContext.sourceURL, "enter capture should preserve the current Feishu source URL")
        assertEqual(enterMatchDecision.sourceType, "会议纪要", "enter capture with a Feishu doc URL should classify the source as a document or meeting note")
        assertEqual(enterMatchDecision.nextStep?.contains("确认这个接入方案"), true, "enter capture should keep the user's latest expressed intent as next step")
        assertEqual(enterMatchDecision.sourceExcerpt?.contains("表达：确认这个接入方案可以继续推进"), true, "enter capture source excerpt should remember the user's expressed intent")

        let desktopChatDecision = ProactiveCapturePolicy.decision(
            tasks: [
                AimeTask(
                    id: "desktop-chat-task",
                    title: "男装项目群规则确认",
                    status: "open",
                    dueDate: "2026-06-24",
                    project: "AI穿搭",
                    sourceUrl: nil,
                    sourceExcerpt: nil
                ),
            ],
            context: feishuDesktopContext,
            typedText: "我去群里确认价格带细节"
        )
        assertEqual(desktopChatDecision.matchedTaskId, "desktop-chat-task", "desktop Feishu chat capture should attach to the matching task")
        assertEqual(desktopChatDecision.sourceType, "聊天记录", "desktop Feishu chat capture should keep the real source type instead of generic Enter capture")
        assertEqual(desktopChatDecision.nextStep, "我去群里确认价格带细节", "going back to the group to confirm details should be kept as the next step")

        let blockerDecision = ProactiveCapturePolicy.decision(
            tasks: [urlMatchedTask],
            context: matchingURLContext,
            typedText: "卡在等待法务确认价格规则"
        )
        assertEqual(blockerDecision.matchedTaskId, "url-match", "blocker capture should still attach to the matching task")
        assertEqual(blockerDecision.blocker, "卡在等待法务确认价格规则", "blocker-like enter text should update the current blocker")
        assertEqual(blockerDecision.nextStep, nil, "blocker-like enter text should not be mistaken for the next step")
        assertEqual(blockerDecision.sourceExcerpt?.contains("表达：卡在等待法务确认价格规则"), true, "blocker capture source excerpt should keep the blocker sentence")

        let blockerAndNextStepDecision = ProactiveCapturePolicy.decision(
            tasks: [urlMatchedTask],
            context: matchingURLContext,
            typedText: "卡在等待法务确认价格规则，下一步回群里拉齐上线口径"
        )
        assertEqual(blockerAndNextStepDecision.blocker, "卡在等待法务确认价格规则", "combined blocker and next-step text should keep the blocker field focused")
        assertEqual(blockerAndNextStepDecision.nextStep, "回群里拉齐上线口径", "combined blocker and next-step text should extract only the executable next-step action")
        assertEqual(
            blockerAndNextStepDecision.sourceExcerpt?.contains("表达：卡在等待法务确认价格规则，下一步回群里拉齐上线口径"),
            true,
            "combined blocker and next-step source excerpt should preserve the original full sentence for traceability"
        )

        let casualAckDecision = ProactiveCapturePolicy.decision(
            tasks: [urlMatchedTask],
            context: matchingURLContext,
            typedText: "嗯嗯 可以"
        )
        assertEqual(casualAckDecision.matchedTaskId, "url-match", "casual acknowledgements can still confirm the active task context")
        assertEqual(casualAckDecision.nextStep, nil, "casual acknowledgements should not overwrite the next step")
        assertEqual(casualAckDecision.blocker, nil, "casual acknowledgements should not create blockers")
        assertEqual(casualAckDecision.sourceExcerpt, nil, "casual acknowledgements should not overwrite an existing source excerpt")

        let vagueActionDecision = ProactiveCapturePolicy.decision(
            tasks: [urlMatchedTask],
            context: matchingURLContext,
            typedText: "确认一下"
        )
        assertEqual(vagueActionDecision.nextStep, nil, "short vague action phrases should not overwrite a useful next step")

        let missingExcerptTask = AimeTask(
            id: "missing-excerpt",
            title: "缺来源摘要",
            status: "open",
            dueDate: "2026-06-24",
            project: "AI穿搭",
            sourceUrl: "https://bytedance.larkoffice.com/docx/abc123?refer_index=1",
            sourceExcerpt: nil,
            nextStep: "继续确认"
        )
        let fillExcerptDecision = ProactiveCapturePolicy.decision(
            tasks: [missingExcerptTask],
            context: matchingURLContext,
            typedText: "嗯嗯 可以"
        )
        assertEqual(fillExcerptDecision.sourceExcerpt?.contains("Enter 捕捉："), true, "casual acknowledgements may still fill a missing source excerpt from the current scene")

        let explicitNextStepDecision = ProactiveCapturePolicy.decision(
            tasks: [urlMatchedTask],
            context: matchingURLContext,
            typedText: "下一步先回群里确认上线口径"
        )
        assertEqual(explicitNextStepDecision.nextStep, "先回群里确认上线口径", "explicit next-step text should update the next step without duplicating the label")

        assertEqual(
            TaskDetailActionPolicy.actions(for: blockedButResumableTask).map(\.title),
            ["打开来源链接", "修改来源链接", "编辑", "关闭"],
            "complete task context should prioritize opening the source link and allow editing it"
        )
        assertEqual(TaskSceneReturnPolicy.isReturnable(blockedButResumableTask), true, "tasks with Feishu URLs should be directly returnable")
        let surfaceSummary = TaskResumePolicy.surfaceSummary(for: blockedButResumableTask, maxLength: 80)
        assertEqual(surfaceSummary.contains("来源："), true, "context switching summary should expose where the task came from")
        assertEqual(surfaceSummary.contains("卡点：等待确认口径"), true, "context switching summary should expose the current blocker")
        assertEqual(surfaceSummary.contains("下一步：回群里确认"), true, "context switching summary should expose the next step")
        assertEqual(
            TaskDetailActionPolicy.actions(for: blockedButResumableTask).map(\.kind),
            ["open", "linkFeishuURL", "edit", "close"],
            "returnable Feishu tasks should invoke the open-scene action and allow editing the source URL"
        )
        assertEqual(
            TaskDetailActionPolicy.actions(for: missingContextTask).map(\.title),
            ["补来源链接", "编辑", "关闭"],
            "missing context should expose source link fill and edit actions"
        )
        assertEqual(
            TaskDetailActionPolicy.actions(for: missingContextTask).map(\.kind),
            ["linkFeishuURL", "edit", "close"],
            "the missing-source primary action should really try to fill a source URL"
        )
        assertEqual(
            TaskDetailActionPolicy.actions(for: nonFeishuSourceTask).map(\.title),
            ["补来源链接", "编辑", "关闭"],
            "non-Feishu sources should not expose a misleading return-to-scene action"
        )
        assertEqual(TaskSceneReturnPolicy.isReturnable(nonFeishuSourceTask), false, "ordinary links should not count as Feishu-returnable scenes")
        let desktopFeishuSourceTask = AimeTask(
            id: "desktop-feishu-source",
            title: "桌面飞书来源",
            status: "open",
            dueDate: "2026-06-24",
            project: "AI",
            sourceUrl: nil,
            sourceExcerpt: "飞书现场：飞书 · 男装项目群",
            nextStep: "搜索群聊继续推进"
        )
        assertEqual(
            TaskDetailActionPolicy.actions(for: desktopFeishuSourceTask).map(\.title),
            ["搜索来源", "补来源链接", "编辑", "关闭"],
            "desktop Feishu scenes without URLs should make searchable source the primary action"
        )
        assertEqual(TaskSceneReturnPolicy.isReturnable(desktopFeishuSourceTask), true, "desktop Feishu scenes without URLs should still count as returnable through search")
        assertEqual(
            TaskSceneReturnPolicy.primaryAction(for: desktopFeishuSourceTask),
            TaskDetailAction(title: "搜索来源", kind: "copySourceSearch"),
            "searchable desktop Feishu scenes should use the search handoff action"
        )
        let weakMatchedTask = AimeTask(
            id: "weak-match",
            title: "男装项目",
            status: "open",
            dueDate: "2026-06-24",
            project: "AI",
            sourceUrl: nil
        )
        let readyMatchedTask = AimeTask(
            id: "ready-match",
            title: "男装项目",
            status: "open",
            statusText: "进行中",
            dueDate: "2026-06-24",
            project: "AI",
            sourceUrl: nil,
            sourceExcerpt: "飞书现场：飞书 · 男装项目群",
            blocker: "等待价格规则确认",
            nextStep: "回群里拉齐规则"
        )
        let sharedContext = TaskWindowContext(appName: "飞书", windowTitle: "男装项目群", sourceURL: nil)
        assertEqual(
            ContextTaskRankingPolicy.score(task: readyMatchedTask, context: sharedContext, lastSceneTaskId: nil, isRecentSceneOpen: false)
                > ContextTaskRankingPolicy.score(task: weakMatchedTask, context: sharedContext, lastSceneTaskId: nil, isRecentSceneOpen: false),
            true,
            "when multiple tasks match the same window, returnable tasks with blocker and next step should surface first"
        )
        assertEqual(
            ContextTaskRankingPolicy.score(task: weakMatchedTask, context: sharedContext, lastSceneTaskId: "weak-match", isRecentSceneOpen: true)
                < ContextTaskRankingPolicy.score(task: readyMatchedTask, context: sharedContext, lastSceneTaskId: nil, isRecentSceneOpen: false),
            true,
            "a stronger current-window match should beat a weak recent scene"
        )
        assertEqual(
            ContextTaskRankingPolicy.score(task: weakMatchedTask, context: sharedContext, lastSceneTaskId: "weak-match", isRecentSceneOpen: true)
                > ContextTaskRankingPolicy.score(task: weakMatchedTask, context: sharedContext, lastSceneTaskId: nil, isRecentSceneOpen: false),
            true,
            "recently opened work scenes should still be sticky among otherwise equal matches"
        )
        let urgentSameSceneTask = AimeTask(
            id: "urgent-same-scene",
            title: "男装项目群",
            status: "open",
            dueDate: "2000-01-01",
            project: "AI",
            priority: "P0",
            sourceUrl: nil,
            sourceExcerpt: "飞书现场：飞书 · 男装项目群",
            nextStep: "先处理逾期风险"
        )
        let recentRoutineSameSceneTask = AimeTask(
            id: "recent-routine-same-scene",
            title: "男装项目群",
            status: "open",
            dueDate: "2999-01-01",
            project: "AI",
            priority: "P2",
            sourceUrl: nil,
            sourceExcerpt: "飞书现场：飞书 · 男装项目群",
            nextStep: "继续日常跟进"
        )
        assertEqual(
            ContextTaskRankingPolicy.score(task: urgentSameSceneTask, context: sharedContext, lastSceneTaskId: nil, isRecentSceneOpen: false)
                > ContextTaskRankingPolicy.score(task: recentRoutineSameSceneTask, context: sharedContext, lastSceneTaskId: "recent-routine-same-scene", isRecentSceneOpen: true),
            true,
            "when two tasks match the same scene, overdue P0 work should surface before a routine recent scene"
        )
        let desktopSourceSearch = SourceSearchPolicy.searchText(for: desktopFeishuSourceTask)
        assertEqual(desktopSourceSearch.contains("飞书 男装项目群"), true, "source search should keep the Feishu desktop scene name")
        assertEqual(desktopSourceSearch.contains("桌面飞书来源"), true, "source search should include the task title")
        assertEqual(desktopSourceSearch.contains("搜索群聊继续推进"), true, "source search should include the next step so users can find the right scene")
        let blockerSourceSearch = SourceSearchPolicy.searchText(for: blockedButResumableTask)
        assertEqual(blockerSourceSearch.contains("等待确认口径"), true, "source search should include blockers when available")
        assertEqual(blockerSourceSearch.count <= 120, true, "source search should stay compact enough for Feishu search")
        assertEqual(
            SourceSearchHandoffPolicy.detail(accessibilityTrusted: true, query: desktopSourceSearch).contains("尝试填入全局搜索"),
            true,
            "trusted source-search handoff should explain that the app will try to fill Feishu global search"
        )
        assertEqual(
            SourceSearchHandoffPolicy.detail(accessibilityTrusted: true, query: desktopSourceSearch).contains("任务上下文放回剪贴板"),
            true,
            "trusted source-search handoff should explain that resume context returns to the clipboard after search"
        )
        assertEqual(
            SourceSearchHandoffPolicy.detail(accessibilityTrusted: false, query: desktopSourceSearch).contains("关键词已复制"),
            true,
            "untrusted source-search handoff should fall back to copied keywords"
        )
        let searchableMissingNextStepTask = AimeTask(
            id: "searchable-missing-next",
            title: "搜索现场缺下一步",
            status: "open",
            dueDate: "2026-06-24",
            project: "AI",
            sourceUrl: nil,
            sourceExcerpt: "Enter 捕捉：飞书 · 男装项目群",
            nextStep: nil
        )
        assertEqual(
            TaskResumePolicy.nextStep(for: searchableMissingNextStepTask),
            "点击“搜索来源”，在飞书里搜索关键词并确认细节后继续推进。",
            "searchable Feishu scenes should suggest searching the source instead of forcing a URL first"
        )
        assertEqual(
            TaskResumePolicy.context(for: searchableMissingNextStepTask).contains("下一步：搜索来源关键词，先确认来源细节，再补充明确下一步。"),
            true,
            "copied resume context should also guide users back through Feishu search"
        )
        let detailsOnlyFeishuSourceTask = AimeTask(
            id: "details-only-feishu-source",
            title: "男装价格规则",
            sourceType: "聊天记录",
            status: "open",
            dueDate: "2026-06-24",
            project: "AI穿搭",
            details: "来自飞书男装项目群：需要确认价格带规则和上新口径。",
            sourceUrl: nil,
            sourceExcerpt: nil,
            blocker: "等待运营确认",
            nextStep: "回群里对齐"
        )
        assertEqual(
            TaskSceneReturnPolicy.isReturnable(detailsOnlyFeishuSourceTask),
            true,
            "tasks with Feishu source type and details should be searchable even before a URL is attached"
        )
        assertEqual(
            TaskSceneReturnPolicy.primaryAction(for: detailsOnlyFeishuSourceTask),
            TaskDetailAction(title: "搜索来源", kind: "copySourceSearch"),
            "details-only Feishu context should still offer a source-search action"
        )
        let detailsOnlySearch = SourceSearchPolicy.searchText(for: detailsOnlyFeishuSourceTask)
        assertEqual(detailsOnlySearch.contains("聊天记录"), true, "source search should include source type when source excerpt is missing")
        assertEqual(detailsOnlySearch.contains("飞书男装项目群"), true, "source search should include Feishu details when source excerpt is missing")

        let pendingLocalCreate = AimeTask(
            id: "local-1",
            title: "本地捕捉的新任务",
            sourceType: "Enter主动捕捉",
            status: "open",
            dueDate: "2026-06-24",
            project: "AI穿搭",
            priority: "P2",
            details: "从飞书群里捕捉",
            sourceUrl: "https://bytedance.larkoffice.com/docx/local",
            sourceExcerpt: "Enter 捕捉",
            blocker: nil,
            nextStep: "回群里确认"
        )
        assertEqual(
            Array(LocalPendingSyncPolicy.arguments(for: pendingLocalCreate).prefix(2)),
            ["create", "--title"],
            "brand-new local captures should be created in Feishu when sync recovers"
        )

        let pendingRemoteUpdate = AimeTask(
            id: "rec_existing",
            title: "已有飞书任务",
            sourceType: "飞书文档",
            status: "open",
            statusText: "进行中",
            dueDate: "2026-06-24",
            project: "AI穿搭",
            priority: "P1",
            details: "已有任务的本地补偿",
            sourceUrl: "https://bytedance.larkoffice.com/docx/existing",
            sourceExcerpt: "Enter 捕捉：飞书文档",
            blocker: "等待法务确认",
            nextStep: "回群里拉齐口径"
        )
        let pendingRemoteArgs = LocalPendingSyncPolicy.arguments(for: pendingRemoteUpdate)
        assertEqual(
            Array(pendingRemoteArgs.prefix(3)),
            ["update", "--record-id", "rec_existing"],
            "failed proactive captures for existing Feishu tasks should update the existing record instead of creating duplicates"
        )
        assertEqual(
            pendingRemoteArgs.contains("doing"),
            true,
            "local compensation for an in-progress Feishu task should restore the doing status"
        )
        let pendingDoneUpdate = AimeTask(
            id: "rec_done_existing",
            title: "已本地完成",
            status: "done",
            statusText: "已完成",
            dueDate: "2026-06-24",
            project: "AI穿搭",
            sourceUrl: "https://bytedance.larkoffice.com/docx/done",
            nextStep: "已处理"
        )
        let pendingDoneArgs = LocalPendingSyncPolicy.arguments(for: pendingDoneUpdate)
        assertEqual(pendingDoneArgs.contains("done"), true, "completed local compensation should still be written back to Feishu")
        let pendingIgnoredUpdate = AimeTask(
            id: "rec_ignored_existing",
            title: "已本地忽略",
            status: "ignored",
            statusText: "取消",
            dueDate: "2026-06-24",
            project: "AI穿搭",
            sourceUrl: nil
        )
        let pendingIgnoredArgs = LocalPendingSyncPolicy.arguments(for: pendingIgnoredUpdate)
        assertEqual(pendingIgnoredArgs.contains("ignored"), true, "ignored local compensation should still be written back to Feishu")

        let feishuCandidateDecision = ProactiveCapturePolicy.decision(
            tasks: [urlMatchedTask],
            context: TaskWindowContext(
                appName: "飞书",
                windowTitle: "AIGC 搭配评测方向群",
                sourceURL: "https://bytedance.larkoffice.com/docx/new-context"
            ),
            typedText: "明天拉齐男装价格带规则"
        )
        assertEqual(feishuCandidateDecision.candidateTitle, "明天拉齐男装价格带规则", "unmatched Feishu enter capture should create a reviewable candidate instead of staying silent")

        let quietDecision = ProactiveCapturePolicy.decision(
            tasks: [urlMatchedTask],
            context: TaskWindowContext(appName: "Finder", windowTitle: "Downloads", sourceURL: nil),
            typedText: "明天拉齐男装价格带规则"
        )
        assertEqual(quietDecision.isNone, true, "enter capture should stay quiet outside Feishu when no task matches")

        let capturePreferences = LocalPreferences(
            recentSceneTaskIds: ["old-scene"],
            lastProactiveTaskId: "url-match",
            lastProactiveCapturedAt: "2026-06-25T00:00:00Z",
            lastProactiveContext: "飞书文档 · 男装搭配"
        )
        let captureData = try! JSONEncoder().encode(capturePreferences)
        let decodedCapturePreferences = try! JSONDecoder().decode(LocalPreferences.self, from: captureData)
        assertEqual(decodedCapturePreferences.lastProactiveTaskId, "url-match", "preferences should persist the latest proactive task")
        assertEqual(decodedCapturePreferences.lastProactiveContext, "飞书文档 · 男装搭配", "preferences should persist why the task was surfaced")

        let contextScenePreferences = SceneMemoryPolicy.applyingContextMatch(
            recordId: "context-match",
            openedAt: "2026-06-25T00:30:00Z",
            preferences: capturePreferences,
            recentLimit: 5
        )
        assertEqual(contextScenePreferences.lastSceneTaskId, "context-match", "context switching should remember the matched task as the latest work scene")
        assertEqual(contextScenePreferences.lastSceneOpenedAt, "2026-06-25T00:30:00Z", "context switching should timestamp the scene memory")
        assertEqual(contextScenePreferences.recentSceneTaskIds, ["context-match", "old-scene"], "context switching should place the matched task into recent scenes")
        assertEqual(contextScenePreferences.lastProactiveTaskId, "url-match", "context switching should not overwrite the latest proactive capture marker")

        let proactiveScenePreferences = SceneMemoryPolicy.applyingCapture(
            recordId: "url-match",
            context: "飞书文档 · 男装搭配",
            capturedAt: "2026-06-25T01:00:00Z",
            preferences: capturePreferences,
            recentLimit: 5
        )
        assertEqual(proactiveScenePreferences.lastProactiveTaskId, "url-match", "proactive capture should remember the captured task")
        assertEqual(proactiveScenePreferences.lastSceneTaskId, "url-match", "proactive capture should also become the latest work scene")
        assertEqual(proactiveScenePreferences.lastSceneOpenedAt, "2026-06-25T01:00:00Z", "proactive capture should timestamp the scene memory")
        assertEqual(proactiveScenePreferences.recentSceneTaskIds, ["url-match", "old-scene"], "proactive capture should put the task into recent scenes for quick switching")

        let resumeText = TaskResumePolicy.context(for: blockedButResumableTask)
        assertEqual(resumeText.contains("待办：有卡点但可恢复"), true, "resume context should include the task title")
        assertEqual(resumeText.contains("状态：open"), true, "resume context should include the current status")
        assertEqual(resumeText.contains("分类：AI"), true, "resume context should include the task category")
        assertEqual(resumeText.contains("截止：2026-06-24"), true, "resume context should include the due date")
        assertEqual(resumeText.contains("来源摘要：来自飞书文档"), true, "resume context should include where the task came from")
        assertEqual(resumeText.contains("当前卡点：等待确认口径"), true, "resume context should include current blocker")
        assertEqual(resumeText.contains("下一步：回群里确认"), true, "resume context should include the next step")
        assertEqual(resumeText.contains("飞书来源：https://bytedance.larkoffice.com/docx/example"), true, "resume context should include the returnable Feishu scene")

        let noBlockerResumeText = TaskResumePolicy.context(for: completeContextTask)
        assertEqual(noBlockerResumeText.contains("任务详情：任务详情"), true, "resume context should include task details")
        assertEqual(noBlockerResumeText.contains("当前卡点：暂无"), true, "resume context should explicitly say when there is no blocker")
        let missingNextStepResumeTask = AimeTask(
            id: "missing-next-step-resume",
            title: "缺下一步但有现场",
            status: "open",
            dueDate: "2026-06-24",
            project: "AI",
            sourceUrl: "https://bytedance.larkoffice.com/docx/resume",
            sourceExcerpt: "来自飞书现场",
            nextStep: nil
        )
        let missingNextStepResumeText = TaskResumePolicy.context(for: missingNextStepResumeTask)
        assertEqual(missingNextStepResumeText.contains("点击“打开来源链接”"), false, "copied resume context should not contain desktop-only instructions")
        assertEqual(missingNextStepResumeText.contains("下一步：打开来源链接，先确认来源细节，再补充明确下一步。"), true, "copied resume context should give an actionable source fallback next step")
        let nonFeishuResumeText = TaskResumePolicy.context(for: nonFeishuSourceTask)
        assertEqual(nonFeishuResumeText.contains("飞书来源：暂无飞书来源"), true, "resume context should not present ordinary links as Feishu scenes")

        let staleContextTask = AimeTask(
            id: "stale-context",
            title: "旧上下文",
            status: "open",
            dueDate: "2026-06-24",
            project: "AI",
            details: "旧详情",
            sourceUrl: "https://bytedance.larkoffice.com/docx/old",
            sourceExcerpt: "旧来源摘要",
            blocker: "旧卡点",
            nextStep: "旧下一步"
        )
        let clearedContextTask = staleContextTask.applying(TaskPatch(
            details: "",
            sourceUrl: "",
            sourceExcerpt: "",
            blocker: "",
            nextStep: ""
        ))
        assertEqual(clearedContextTask.details, "", "patch should allow clearing stale task details")
        assertEqual(clearedContextTask.sourceUrl, "", "patch should allow clearing stale source links")
        assertEqual(clearedContextTask.sourceExcerpt, "", "patch should allow clearing stale source summaries")
        assertEqual(clearedContextTask.blocker, "", "patch should allow clearing stale blockers")
        assertEqual(clearedContextTask.nextStep, "", "patch should allow clearing stale next steps")
        assertEqual(clearedContextTask.title, "旧上下文", "patch should preserve fields omitted from the update")

        let chatText = """
        嗯嗯 明天也行
        看穿搭tab访问链路
        于仕杰: 我在拆评测链路，咱们本周对齐一下
        或者试下这个 library 里的方案
        """
        let extracted = TaskCandidateExtractor.extract(from: chatText)
        assertEqual(extracted.contains("看穿搭tab访问链路"), true, "candidate extraction should keep actionable lines beyond the first sentence")
        assertEqual(extracted.contains("我在拆评测链路，咱们本周对齐一下"), true, "candidate extraction should strip speaker names and keep full chat context")

        print("PetStateTests passed")
    }
}
