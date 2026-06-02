import Foundation

struct HabitRule: Identifiable, Codable, Equatable {
    var id: UUID
    var courseId: UUID
    var placeCategory: PlaceCategory
    var triggerType: TriggerType
    var timeBlock: TimeBlock
    var weekdayType: WeekdayType
    var message: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        courseId: UUID,
        placeCategory: PlaceCategory,
        triggerType: TriggerType,
        timeBlock: TimeBlock = .any,
        weekdayType: WeekdayType = .any,
        message: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.courseId = courseId
        self.placeCategory = placeCategory
        self.triggerType = triggerType
        self.timeBlock = timeBlock
        self.weekdayType = weekdayType
        self.message = message
        self.isEnabled = isEnabled
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
