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
    var expandedPanelWidth: Double = 420
    var expandedPanelHeight: Double = 360
    var displayStyle: String = "cute"
}
