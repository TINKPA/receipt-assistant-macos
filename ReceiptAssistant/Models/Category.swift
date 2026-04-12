import SwiftUI

enum Category: String, Codable, CaseIterable, Identifiable, Hashable {
    case food, groceries, transport, shopping, utilities
    case entertainment, health, education, travel, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food: return "Dining"
        case .groceries: return "Groceries"
        case .transport: return "Transport"
        case .shopping: return "Shopping"
        case .utilities: return "Utilities"
        case .entertainment: return "Entertainment"
        case .health: return "Health"
        case .education: return "Education"
        case .travel: return "Travel"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .food: return "fork.knife"
        case .groceries: return "cart"
        case .transport: return "car"
        case .shopping: return "bag"
        case .utilities: return "bolt"
        case .entertainment: return "film"
        case .health: return "heart"
        case .education: return "book"
        case .travel: return "airplane"
        case .other: return "square.grid.2x2"
        }
    }

    var tint: Color {
        switch self {
        case .food: return .orange
        case .groceries: return .green
        case .transport: return .blue
        case .shopping: return .pink
        case .utilities: return .yellow
        case .entertainment: return .purple
        case .health: return .red
        case .education: return .teal
        case .travel: return .cyan
        case .other: return .gray
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Category(rawValue: raw.lowercased()) ?? .other
    }
}
