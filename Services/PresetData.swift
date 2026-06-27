import Foundation

enum PresetData {
    static let todoListCourseId = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
    static let retiredPresetCourseIds: Set<UUID> = [
        UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
        UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    ]
    static let retiredPresetRuleIds: Set<UUID> = Set((1...8).compactMap {
        UUID(uuidString: "7000000\($0)-0000-0000-0000-00000000000\($0)")
    })

    static let todoListCourse = HabitCourse(
        id: todoListCourseId,
        name: "To do list",
        description: "思い出したい行動をActとして置いておく備忘録です。",
        isEnabled: true,
        targetCategories: PlaceCategory.allCases
    )

    static let places: [Place] = [
        Place(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "自宅",
            latitude: 35.681236,
            longitude: 139.767125,
            radius: 150,
            category: .home
        ),
        Place(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "最寄駅",
            latitude: 35.681382,
            longitude: 139.766084,
            radius: 150,
            category: .station
        ),
        Place(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "ジム",
            latitude: 35.682839,
            longitude: 139.759455,
            radius: 150,
            category: .gym
        )
    ]

    static let courses: [HabitCourse] = [
        todoListCourse
    ]

    static let rules: [HabitRule] = []

    static func rule(for ruleId: UUID) -> HabitRule? {
        rules.first { $0.id == ruleId }
    }

    static func tasks(for ruleId: UUID) -> [RuleTask]? {
        rule(for: ruleId)?.tasks
    }

    static func guide(for ruleId: UUID) -> ActionGuide? {
        ruleGuides[ruleId]
    }

    private static let ruleGuides: [UUID: ActionGuide] = [:]
}
