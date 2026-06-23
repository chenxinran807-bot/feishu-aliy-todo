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
        let actionable = tasks.filter {
            $0.status != "done" && $0.status != "ignored" && !preferences.hiddenTaskIds.contains($0.id)
        }
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
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }

            let leftDate = left.dueDate ?? "9999-12-31"
            let rightDate = right.dueDate ?? "9999-12-31"
            if leftDate == rightDate {
                return left.title < right.title
            }
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
