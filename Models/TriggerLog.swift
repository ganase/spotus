import Foundation

struct TriggerLog: Identifiable, Codable, Equatable {
    var id: UUID
    var placeId: UUID
    var courseId: UUID?
    var triggeredAt: Date
    var triggerType: TriggerType
    var message: String
    var userAction: UserAction

    init(
        id: UUID = UUID(),
        placeId: UUID,
        courseId: UUID?,
        triggeredAt: Date = Date(),
        triggerType: TriggerType,
        message: String,
        userAction: UserAction = .ignored
    ) {
        self.id = id
        self.placeId = placeId
        self.courseId = courseId
        self.triggeredAt = triggeredAt
        self.triggerType = triggerType
        self.message = message
        self.userAction = userAction
    }
}

enum UserAction: String, Codable, CaseIterable, Identifiable {
    case ignored
    case opened
    case completed
    case dismissed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ignored:
            return "未反応"
        case .opened:
            return "開いた"
        case .completed:
            return "やった"
        case .dismissed:
            return "閉じた"
        }
    }
}
