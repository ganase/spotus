import Foundation

struct Place: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var radius: Double
    var category: PlaceCategory
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double = 150,
        category: PlaceCategory,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.category = category
        self.isEnabled = isEnabled
    }
}

enum PlaceCategory: String, Codable, CaseIterable, Identifiable {
    case home
    case station
    case office
    case gym
    case library
    case barArea = "bar_area"
    case convenienceStore = "convenience_store"
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home:
            return "自宅"
        case .station:
            return "駅"
        case .office:
            return "職場"
        case .gym:
            return "ジム"
        case .library:
            return "図書館"
        case .barArea:
            return "飲み屋街"
        case .convenienceStore:
            return "コンビニ"
        case .other:
            return "その他"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house"
        case .station:
            return "tram"
        case .office:
            return "building.2"
        case .gym:
            return "figure.strengthtraining.traditional"
        case .library:
            return "books.vertical"
        case .barArea:
            return "wineglass"
        case .convenienceStore:
            return "cart"
        case .other:
            return "mappin"
        }
    }
}
