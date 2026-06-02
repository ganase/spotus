import Foundation

struct HabitCourse: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var description: String
    var isEnabled: Bool
    var targetCategories: [PlaceCategory]

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        isEnabled: Bool = false,
        targetCategories: [PlaceCategory]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isEnabled = isEnabled
        self.targetCategories = targetCategories
    }
}
