import Foundation

struct HabitCourse: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var description: String
    var isEnabled: Bool
    var targetCategories: [PlaceCategory]
    var timeBlock: TimeBlock
    var weekdayType: WeekdayType
    var disabledActTitles: [String]

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        isEnabled: Bool = false,
        targetCategories: [PlaceCategory],
        timeBlock: TimeBlock = .any,
        weekdayType: WeekdayType = .any,
        disabledActTitles: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isEnabled = isEnabled
        self.targetCategories = targetCategories
        self.timeBlock = timeBlock
        self.weekdayType = weekdayType
        self.disabledActTitles = disabledActTitles
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case isEnabled
        case targetCategories
        case timeBlock
        case weekdayType
        case disabledActTitles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        targetCategories = try container.decode([PlaceCategory].self, forKey: .targetCategories)
        timeBlock = try container.decodeIfPresent(TimeBlock.self, forKey: .timeBlock) ?? .any
        weekdayType = try container.decodeIfPresent(WeekdayType.self, forKey: .weekdayType) ?? .any
        disabledActTitles = try container.decodeIfPresent([String].self, forKey: .disabledActTitles) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(targetCategories, forKey: .targetCategories)
        try container.encode(timeBlock, forKey: .timeBlock)
        try container.encode(weekdayType, forKey: .weekdayType)
        try container.encode(disabledActTitles, forKey: .disabledActTitles)
    }
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case plain
    case gray
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .plain:
            return "プレーン"
        case .gray:
            return "メリハリ"
        case .dark:
            return "ダーク"
        }
    }

    var systemImage: String {
        switch self {
        case .plain:
            return "circle.lefthalf.filled"
        case .gray:
            return "square.on.square"
        case .dark:
            return "moon.fill"
        }
    }
}
