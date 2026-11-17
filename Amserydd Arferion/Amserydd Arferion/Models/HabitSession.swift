import Foundation
import SwiftData

@Model
final class HabitSession {
    @Attribute(.unique) var id: UUID
    var habitID: UUID
    var habitName: String
    var symbol: String
    var kindRawValue: String
    var startedAt: Date
    var endedAt: Date
    var duration: TimeInterval
    var earningRequirement: Double
    var allowsDebt: Bool
    var debtRecoveryMultiplier: Double

    init(
        id: UUID = UUID(),
        habitID: UUID,
        habitName: String,
        symbol: String,
        kind: HabitKind,
        startedAt: Date,
        endedAt: Date,
        duration: TimeInterval,
        earningRequirement: Double,
        allowsDebt: Bool,
        debtRecoveryMultiplier: Double
    ) {
        self.id = id
        self.habitID = habitID
        self.habitName = habitName
        self.symbol = symbol
        self.kindRawValue = kind.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = max(0, duration)
        self.earningRequirement = max(1, earningRequirement)
        self.allowsDebt = allowsDebt
        self.debtRecoveryMultiplier = max(1, debtRecoveryMultiplier)
    }

    var kind: HabitKind {
        HabitKind(rawValue: kindRawValue) ?? .earning
    }

    var ledgerRecord: LedgerRecord {
        LedgerRecord(
            id: id,
            startedAt: startedAt,
            kind: kind,
            duration: duration,
            earningRequirement: earningRequirement,
            allowsDebt: allowsDebt,
            debtRecoveryMultiplier: debtRecoveryMultiplier
        )
    }
}
