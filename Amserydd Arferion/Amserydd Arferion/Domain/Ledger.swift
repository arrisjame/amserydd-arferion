import Foundation

public enum HabitKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case earning
    case spending

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .earning: "Earn"
        case .spending: "Spend"
        }
    }
}
public struct LedgerRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let kind: HabitKind
    public let duration: TimeInterval
    public let earningRequirement: Double
    public let allowsDebt: Bool
    public let debtRecoveryMultiplier: Double

    public init(
        id: UUID,
        startedAt: Date,
        kind: HabitKind,
        duration: TimeInterval,
        earningRequirement: Double = 1,
        allowsDebt: Bool = false,
        debtRecoveryMultiplier: Double = 1
    ) {
        self.id = id
        self.startedAt = startedAt
        self.kind = kind
        self.duration = max(0, duration)
        self.earningRequirement = max(1, earningRequirement)
        self.allowsDebt = allowsDebt
        self.debtRecoveryMultiplier = max(1, debtRecoveryMultiplier)
    }
}

public struct LedgerEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let delta: TimeInterval
    public let balanceAfter: TimeInterval

    public init(id: UUID, delta: TimeInterval, balanceAfter: TimeInterval) {
        self.id = id
        self.delta = delta
        self.balanceAfter = balanceAfter
    }
}

public enum TimeLedger {
    public static func evaluate(_ records: [LedgerRecord]) -> [LedgerEntry] {
        var balance: TimeInterval = 0

        return records
            .sorted {
                if $0.startedAt == $1.startedAt {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.startedAt < $1.startedAt
            }
            .map { record in
                let delta: TimeInterval

                switch record.kind {
                case .spending:
                    delta = record.allowsDebt
                        ? -record.duration
                        : -min(record.duration, max(0, balance))

                case .earning:
                    let normalCredit = record.duration / record.earningRequirement
                    delta = earningCredit(
                        normalCredit: normalCredit,
                        startingBalance: balance,
                        debtRecoveryMultiplier: record.debtRecoveryMultiplier
                    )
                }

                balance += delta
                return LedgerEntry(id: record.id, delta: delta, balanceAfter: balance)
            }
    }

    public static func balance(for records: [LedgerRecord]) -> TimeInterval {
        evaluate(records).last?.balanceAfter ?? 0
    }

    private static func earningCredit(
        normalCredit: TimeInterval,
        startingBalance: TimeInterval,
        debtRecoveryMultiplier: Double
    ) -> TimeInterval {
        guard startingBalance < 0, debtRecoveryMultiplier > 1 else {
            return normalCredit
        }

        let debt = -startingBalance
        let normalCreditNeededToClearDebt = debt * debtRecoveryMultiplier

        if normalCredit <= normalCreditNeededToClearDebt {
            return normalCredit / debtRecoveryMultiplier
        }

        let creditBeyondDebt = normalCredit - normalCreditNeededToClearDebt
        return debt + creditBeyondDebt
    }
}
