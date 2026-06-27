import Foundation

struct HabitRule: Identifiable, Codable, Equatable {
    var id: UUID
    var courseId: UUID
    var placeId: UUID?
    var placeCategory: PlaceCategory
    var triggerType: TriggerType
    var timeBlock: TimeBlock
    var weekdayType: WeekdayType
    var message: String
    var tasks: [RuleTask]
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        courseId: UUID,
        placeId: UUID? = nil,
        placeCategory: PlaceCategory,
        triggerType: TriggerType,
        timeBlock: TimeBlock = .any,
        weekdayType: WeekdayType = .any,
        message: String,
        tasks: [RuleTask]? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.courseId = courseId
        self.placeId = placeId
        self.placeCategory = placeCategory
        self.triggerType = triggerType
        self.timeBlock = timeBlock
        self.weekdayType = weekdayType
        self.message = message
        self.tasks = tasks ?? [RuleTask(title: message)]
        self.isEnabled = isEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case courseId
        case placeId
        case placeCategory
        case triggerType
        case timeBlock
        case weekdayType
        case message
        case tasks
        case isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        courseId = try container.decode(UUID.self, forKey: .courseId)
        placeId = try container.decodeIfPresent(UUID.self, forKey: .placeId)
        placeCategory = try container.decode(PlaceCategory.self, forKey: .placeCategory)
        triggerType = try container.decode(TriggerType.self, forKey: .triggerType)
        timeBlock = try container.decodeIfPresent(TimeBlock.self, forKey: .timeBlock) ?? .any
        weekdayType = try container.decodeIfPresent(WeekdayType.self, forKey: .weekdayType) ?? .any
        message = try container.decode(String.self, forKey: .message)
        tasks = try container.decodeIfPresent([RuleTask].self, forKey: .tasks) ?? [RuleTask(title: message)]
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(courseId, forKey: .courseId)
        try container.encodeIfPresent(placeId, forKey: .placeId)
        try container.encode(placeCategory, forKey: .placeCategory)
        try container.encode(triggerType, forKey: .triggerType)
        try container.encode(timeBlock, forKey: .timeBlock)
        try container.encode(weekdayType, forKey: .weekdayType)
        try container.encode(message, forKey: .message)
        try container.encode(tasks, forKey: .tasks)
        try container.encode(isEnabled, forKey: .isEnabled)
    }
}

struct RuleTask: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }
}

struct ActTemplate: Identifiable, Equatable {
    var title: String
    var usageCount: Int

    var id: String { title }
}

struct CourseStepDraft: Identifiable, Equatable {
    var id: UUID
    var placeId: UUID?
    var actTitle: String

    init(id: UUID = UUID(), placeId: UUID? = nil, actTitle: String = "") {
        self.id = id
        self.placeId = placeId
        self.actTitle = actTitle
    }
}

enum TriggerType: String, Codable, CaseIterable, Identifiable {
    case enter
    case exit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .enter:
            return "入ったとき"
        case .exit:
            return "離れたとき"
        }
    }
}

enum TimeBlock: String, Codable, CaseIterable, Identifiable {
    case morning
    case daytime
    case evening
    case night
    case any

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning:
            return "朝"
        case .daytime:
            return "昼"
        case .evening:
            return "夜"
        case .night:
            return "深夜"
        case .any:
            return "いつでも"
        }
    }

    static func current(for date: Date, calendar: Calendar = .current) -> TimeBlock {
        let hour = calendar.component(.hour, from: date)

        switch hour {
        case 5..<10:
            return .morning
        case 10..<17:
            return .daytime
        case 17..<23:
            return .evening
        default:
            return .night
        }
    }

    func matches(date: Date, calendar: Calendar = .current) -> Bool {
        self == .any || self == TimeBlock.current(for: date, calendar: calendar)
    }
}

enum WeekdayType: String, Codable, CaseIterable, Identifiable {
    case weekday
    case weekend
    case any

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekday:
            return "平日"
        case .weekend:
            return "休日"
        case .any:
            return "毎日"
        }
    }

    func matches(date: Date, calendar: Calendar = .current) -> Bool {
        guard self != .any else { return true }

        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        return self == .weekend ? isWeekend : !isWeekend
    }
}
