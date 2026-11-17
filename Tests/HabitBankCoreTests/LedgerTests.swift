import XCTest
@testable import HabitBankCore

final class LedgerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    func testEarningRequirementConvertsNinetySecondsToSixty() {
        let record = LedgerRecord(
            id: UUID(),
            startedAt: start,
            kind: .earning,
            duration: 90,
            earningRequirement: 1.5
        )

        XCTAssertEqual(TimeLedger.balance(for: [record]), 60, accuracy: 0.001)
    }

    func testSpendingStopsAtZeroWhenDebtIsProhibited() {
        let earning = LedgerRecord(
            id: UUID(),
            startedAt: start,
            kind: .earning,
            duration: 60
        )
        let spending = LedgerRecord(
            id: UUID(),
            startedAt: start.addingTimeInterval(1),
            kind: .spending,
            duration: 90,
            allowsDebt: false
        )

        XCTAssertEqual(TimeLedger.balance(for: [earning, spending]), 0, accuracy: 0.001)
    }

    func testSpendingCanCreateDebt() {
        let spending = LedgerRecord(
            id: UUID(),
            startedAt: start,
            kind: .spending,
            duration: 60,
            allowsDebt: true
        )

        XCTAssertEqual(TimeLedger.balance(for: [spending]), -60, accuracy: 0.001)
    }

    func testDebtRecoveryMultiplierRequiresExtraEarning() {
        let spending = LedgerRecord(
            id: UUID(),
            startedAt: start,
            kind: .spending,
            duration: 60,
            allowsDebt: true
        )
        let earning = LedgerRecord(
            id: UUID(),
            startedAt: start.addingTimeInterval(1),
            kind: .earning,
            duration: 135,
            earningRequirement: 1.5,
            debtRecoveryMultiplier: 1.5
        )

        XCTAssertEqual(TimeLedger.balance(for: [spending, earning]), 0, accuracy: 0.001)
    }

    func testCreditBeyondDebtReturnsToNormalRate() {
        let spending = LedgerRecord(
            id: UUID(),
            startedAt: start,
            kind: .spending,
            duration: 60,
            allowsDebt: true
        )
        let earning = LedgerRecord(
            id: UUID(),
            startedAt: start.addingTimeInterval(1),
            kind: .earning,
            duration: 180,
            earningRequirement: 1.5,
            debtRecoveryMultiplier: 1.5
        )

        XCTAssertEqual(TimeLedger.balance(for: [spending, earning]), 30, accuracy: 0.001)
    }
}
