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

        let sniffingSnapshot = PetState.derive(
            tasks: tasks,
            preferences: preferences,
            previous: PetState(dogMood: .sniffing),
            today: today
        )
        assertEqual(sniffingSnapshot.dogMood, .sniffing, "derive should not overwrite an active sniffing mood")

        print("PetStateTests passed")
    }
}
