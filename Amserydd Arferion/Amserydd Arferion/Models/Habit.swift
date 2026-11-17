import Foundation
import SwiftData

@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRawValue: String
    var earningRequirement: Double
    var symbol: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        kind: HabitKind,
        earningRequirement: Double = 1.5,
        symbol: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.kindRawValue = kind.rawValue
        self.earningRequirement = max(1, earningRequirement)
        self.symbol = symbol
        self.createdAt = createdAt
    }

    var kind: HabitKind {
        get { HabitKind(rawValue: kindRawValue) ?? .earning }
        set { kindRawValue = newValue.rawValue }
    }
}
