import Foundation
import Observation

struct ActiveTimer: Codable, Equatable {
    let habitID: UUID
    let habitName: String
    let symbol: String
    let kind: HabitKind
    let earningRequirement: Double
    let allowsDebt: Bool
    let debtRecoveryMultiplier: Double
    let startedAt: Date
    let spendLimit: TimeInterval?
    var accumulatedDuration: TimeInterval
    var resumedAt: Date?

    func elapsed(at date: Date = .now) -> TimeInterval {
        accumulatedDuration + max(0, resumedAt.map { date.timeIntervalSince($0) } ?? 0)
    }

    var isPaused: Bool { resumedAt == nil }
}
struct CompletedTimer {
    let active: ActiveTimer
    let endedAt: Date
    let duration: TimeInterval
}

@MainActor
@Observable
final class TimerCoordinator {
    private(set) var active: ActiveTimer?

    private let defaults: UserDefaults
    private let storageKey = "activeHabitTimer"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restore()
    }

    func begin(
        habit: Habit,
        allowsDebt: Bool,
        debtRecoveryMultiplier: Double,
        currentBalance: TimeInterval
    ) {
        guard active == nil else { return }

        let now = Date.now
        active = ActiveTimer(
            habitID: habit.id,
            habitName: habit.name,
            symbol: habit.symbol,
            kind: habit.kind,
            earningRequirement: habit.earningRequirement,
            allowsDebt: allowsDebt,
            debtRecoveryMultiplier: debtRecoveryMultiplier,
            startedAt: now,
            spendLimit: habit.kind == .spending && !allowsDebt ? max(0, currentBalance) : nil,
            accumulatedDuration: 0,
            resumedAt: now
        )
        persist()
    }

    func pause(at date: Date = .now) {
        guard var active, !active.isPaused else { return }
        active.accumulatedDuration = active.elapsed(at: date)
        active.resumedAt = nil
        self.active = active
        persist()
    }

    func resume(at date: Date = .now) {
        guard var active, active.isPaused else { return }
        active.resumedAt = date
        self.active = active
        persist()
    }

    func finish(at date: Date = .now) -> CompletedTimer? {
        guard let active else { return nil }
        let uncappedDuration = active.elapsed(at: date)
        let duration = min(uncappedDuration, active.spendLimit ?? uncappedDuration)
        let completed = CompletedTimer(active: active, endedAt: date, duration: duration)
        clear()
        return completed
    }

    func cancel() {
        clear()
    }

    func shouldAutoFinish(at date: Date = .now) -> Bool {
        guard let active, let limit = active.spendLimit else { return false }
        return active.elapsed(at: date) >= limit
    }

    private func restore() {
        guard
            let data = defaults.data(forKey: storageKey),
            let restored = try? JSONDecoder().decode(ActiveTimer.self, from: data)
        else { return }
        active = restored
    }

    private func persist() {
        guard let active, let data = try? JSONEncoder().encode(active) else {
            defaults.removeObject(forKey: storageKey)
            return
        }
        defaults.set(data, forKey: storageKey)
    }

    private func clear() {
        active = nil
        defaults.removeObject(forKey: storageKey)
    }
}
