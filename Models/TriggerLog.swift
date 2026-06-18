import Foundation

struct TriggerLog: Identifiable, Codable, Equatable {
    var id: UUID
    var placeId: UUID
    var courseId: UUID?
    var triggeredAt: Date
    var triggerType: TriggerType
    var message: String
    var actionGuide: ActionGuide?
    var userAction: UserAction

    init(
        id: UUID = UUID(),
        placeId: UUID,
        courseId: UUID?,
        triggeredAt: Date = Date(),
        triggerType: TriggerType,
        message: String,
        actionGuide: ActionGuide? = nil,
        userAction: UserAction = .ignored
    ) {
        self.id = id
        self.placeId = placeId
        self.courseId = courseId
        self.triggeredAt = triggeredAt
        self.triggerType = triggerType
        self.message = message
        self.actionGuide = actionGuide
        self.userAction = userAction
    }
}

struct ActionGuide: Codable, Equatable {
    var doText: String
    var avoidText: String
}

enum UserAction: String, Codable, CaseIterable, Identifiable {
    case ignored
    case opened
    case mapOpened
    case completed
    case didAction = "did_action"
    case avoidedAction = "avoided_action"
    case dismissed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ignored:
            return "未反応"
        case .opened:
            return "開いた"
        case .mapOpened:
            return "地図で開いた"
        case .completed:
            return "完了"
        case .didAction:
            return "実行できた"
        case .avoidedAction:
            return "見送れた"
        case .dismissed:
            return "閉じた"
        }
    }

    var isResolved: Bool {
        switch self {
        case .completed, .didAction, .avoidedAction:
            return true
        case .ignored, .opened, .mapOpened, .dismissed:
            return false
        }
    }

    var statusIcon: String {
        switch self {
        case .completed, .didAction, .avoidedAction:
            return "checkmark.seal.fill"
        case .opened, .mapOpened:
            return "hand.tap.fill"
        case .dismissed:
            return "bell.slash"
        case .ignored:
            return "clock"
        }
    }
}
