import Foundation

struct TriggerLog: Identifiable, Codable, Equatable {
    var id: UUID
    var placeId: UUID
    var courseId: UUID?
    var triggeredAt: Date
    var triggerType: TriggerType
    var message: String
    var actionGuide: ActionGuide?
    var tasks: [StepTask]
    var userAction: UserAction
    var snoozedUntil: Date?

    init(
        id: UUID = UUID(),
        placeId: UUID,
        courseId: UUID?,
        triggeredAt: Date = Date(),
        triggerType: TriggerType,
        message: String,
        actionGuide: ActionGuide? = nil,
        tasks: [StepTask] = [],
        userAction: UserAction = .ignored,
        snoozedUntil: Date? = nil
    ) {
        self.id = id
        self.placeId = placeId
        self.courseId = courseId
        self.triggeredAt = triggeredAt
        self.triggerType = triggerType
        self.message = message
        self.actionGuide = actionGuide
        self.tasks = tasks
        self.userAction = userAction
        self.snoozedUntil = snoozedUntil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case placeId
        case courseId
        case triggeredAt
        case triggerType
        case message
        case actionGuide
        case tasks
        case userAction
        case snoozedUntil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        placeId = try container.decode(UUID.self, forKey: .placeId)
        courseId = try container.decodeIfPresent(UUID.self, forKey: .courseId)
        triggeredAt = try container.decode(Date.self, forKey: .triggeredAt)
        triggerType = try container.decode(TriggerType.self, forKey: .triggerType)
        message = try container.decode(String.self, forKey: .message)
        actionGuide = try container.decodeIfPresent(ActionGuide.self, forKey: .actionGuide)
        tasks = try container.decodeIfPresent([StepTask].self, forKey: .tasks) ?? []
        userAction = try container.decodeIfPresent(UserAction.self, forKey: .userAction) ?? .ignored
        snoozedUntil = try container.decodeIfPresent(Date.self, forKey: .snoozedUntil)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(placeId, forKey: .placeId)
        try container.encodeIfPresent(courseId, forKey: .courseId)
        try container.encode(triggeredAt, forKey: .triggeredAt)
        try container.encode(triggerType, forKey: .triggerType)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(actionGuide, forKey: .actionGuide)
        try container.encode(tasks, forKey: .tasks)
        try container.encode(userAction, forKey: .userAction)
        try container.encodeIfPresent(snoozedUntil, forKey: .snoozedUntil)
    }
}

struct StepTask: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }

    init(ruleTask: RuleTask) {
        id = ruleTask.id
        title = ruleTask.title
        isCompleted = false
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
    case snoozed

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
        case .snoozed:
            return "スヌーズ"
        }
    }

    var isResolved: Bool {
        switch self {
        case .completed, .didAction, .avoidedAction:
            return true
        case .ignored, .opened, .mapOpened, .dismissed, .snoozed:
            return false
        }
    }

    var outcomeScore: Int {
        switch self {
        case .completed, .didAction:
            return 1
        case .avoidedAction:
            return -1
        case .ignored, .opened, .mapOpened, .dismissed, .snoozed:
            return 0
        }
    }

    var statusIcon: String {
        switch self {
        case .completed, .didAction:
            return "checkmark.seal.fill"
        case .avoidedAction:
            return "minus.circle.fill"
        case .opened, .mapOpened:
            return "hand.tap.fill"
        case .dismissed:
            return "bell.slash"
        case .snoozed:
            return "alarm"
        case .ignored:
            return "clock"
        }
    }
}
