import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerCoordinator.self) private var timerCoordinator
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query(sort: \HabitSession.startedAt) private var sessions: [HabitSession]

    @AppStorage("debtMode") private var debtMode = "stopAtZero"
    @AppStorage("debtRecoveryMultiplier") private var debtRecoveryMultiplier = 1.5
    @State private var showEarningExplanation = false
    @State private var showCancelConfirmation = false

    private var balance: TimeInterval {
        TimeLedger.balance(for: sessions.map(\.ledgerRecord))
    }

    private var allowsDebt: Bool { debtMode == "allowDebt" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    balanceCard

                    if timerCoordinator.active != nil {
                        activeTimerCard
                    }

                    habitSection(kind: .earning)
                    habitSection(kind: .spending)
                }
                .padding(18)
                .padding(.bottom, 24)
            }
            .background(GorpcoreTheme.background.ignoresSafeArea())
            .navigationTitle("Time bank")
            .toolbarBackground(GorpcoreTheme.background, for: .navigationBar)
            .alert("How earning ratios work", isPresented: $showEarningExplanation) {
                Button("Got it", role: .cancel) { }
            } message: {
                Text("An earning ratio of 1.5× means 90 seconds of a good habit earns 60 seconds of spendable time.")
            }
            .alert("Cancel this timer?", isPresented: $showCancelConfirmation) {
                Button("Keep timer", role: .cancel) { }
                Button("Cancel timer", role: .destructive) { timerCoordinator.cancel() }
            } message: {
                Text("Elapsed time will not be saved.")
            }
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(
                    balance < 0 ? "TIME DEBT" : "AVAILABLE TIME",
                    systemImage: balance < 0 ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"
                )
                .font(.caption.bold().monospaced())
                .tracking(1.5)
                Spacer()
                Image(systemName: "mountain.2.fill")
                    .font(.title2)
            }
            .foregroundStyle(GorpcoreTheme.desertSand)

            Text(TimeText.balance(balance))
                .font(.system(size: 54, weight: .black, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)

            Text(balance < 0 ? "Earn time to return to zero." : "Good habits fund intentional downtime.")
                .font(.subheadline)
                .foregroundStyle(GorpcoreTheme.desertSand.opacity(0.86))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gorpcoreCard(background: GorpcoreTheme.carbon)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            balance < 0
                ? "Time debt \(TimeText.balance(balance))"
                : "Available time \(TimeText.balance(balance))"
        )
    }

    private var activeTimerCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let active = timerCoordinator.active {
                let elapsed = active.elapsed(at: context.date)

                VStack(spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: active.symbol)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(GorpcoreTheme.trailTan.opacity(0.55), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(active.kind == .earning ? "EARNING NOW" : "SPENDING NOW")
                                .font(.caption2.bold().monospaced())
                                .tracking(1.4)
                                .foregroundStyle(GorpcoreTheme.rust)
                            Text(active.habitName)
                                .font(.headline)
                        }
                        Spacer()
                    }

                    Text(TimeText.balance(elapsed))
                        .font(.system(size: 45, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(GorpcoreTheme.carbon)
                        .onChange(of: Int(elapsed)) { _, _ in
                            if timerCoordinator.shouldAutoFinish(at: context.date) {
                                saveFinishedTimer(at: context.date)
                            }
                        }

                    HStack(spacing: 12) {
                        Button {
                            if active.isPaused { timerCoordinator.resume() }
                            else { timerCoordinator.pause() }
                        } label: {
                            Label(
                                active.isPaused ? "Resume" : "Pause",
                                systemImage: active.isPaused ? "play.fill" : "pause.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(GorpcoreTheme.mossyOak)

                        Button {
                            saveFinishedTimer()
                        } label: {
                            Label("Finish", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(GorpcoreTheme.rust)
                    }

                    Button("Cancel timer", role: .destructive) {
                        showCancelConfirmation = true
                    }
                    .font(.footnote)
                }
                .gorpcoreCard(background: GorpcoreTheme.surface)
            }
        }
    }

    @ViewBuilder
    private func habitSection(kind: HabitKind) -> some View {
        let matchingHabits = habits.filter { $0.kind == kind }

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                GorpcoreSectionHeader(
                    eyebrow: kind == .earning ? "Build your balance" : "Use it deliberately",
                    title: kind == .earning ? "Earn time" : "Spend time"
                )

                if kind == .earning {
                    Button { showEarningExplanation = true } label: {
                        Image(systemName: "info.circle")
                            .font(.title3)
                    }
                    .foregroundStyle(GorpcoreTheme.rust)
                    .accessibilityLabel("Explain earning ratios")
                }
            }

            if matchingHabits.isEmpty {
                Text("Add a \(kind.title.lowercased()) habit from the Habits tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gorpcoreCard()
            } else {
                ForEach(matchingHabits) { habit in
                    habitRow(habit)
                }
            }
        }
    }

    private func habitRow(_ habit: Habit) -> some View {
        let unavailable = timerCoordinator.active != nil
            || (habit.kind == .spending && !allowsDebt && balance <= 0)

        return HStack(spacing: 14) {
            Image(systemName: habit.symbol)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(
                    habit.kind == .earning ? GorpcoreTheme.mossyOak : GorpcoreTheme.rust,
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(.headline)
                    .foregroundStyle(GorpcoreTheme.carbon)
                Text(
                    habit.kind == .earning
                        ? "\(habit.earningRequirement.formatted(.number.precision(.fractionLength(0...2))))× effort ratio"
                        : spendingSubtitle
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Start") {
                timerCoordinator.begin(
                    habit: habit,
                    allowsDebt: allowsDebt,
                    debtRecoveryMultiplier: debtRecoveryMultiplier,
                    currentBalance: balance
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(habit.kind == .earning ? GorpcoreTheme.mossyOak : GorpcoreTheme.rust)
            .disabled(unavailable)
        }
        .gorpcoreCard()
    }

    private var spendingSubtitle: String {
        if allowsDebt {
            return "Debt allowed · \(debtRecoveryMultiplier.formatted())× recovery"
        }
        return "Stops when your balance reaches zero"
    }

    private func saveFinishedTimer(at date: Date = .now) {
        guard let completed = timerCoordinator.finish(at: date), completed.duration > 0 else { return }

        let active = completed.active
        modelContext.insert(
            HabitSession(
                habitID: active.habitID,
                habitName: active.habitName,
                symbol: active.symbol,
                kind: active.kind,
                startedAt: active.startedAt,
                endedAt: completed.endedAt,
                duration: completed.duration,
                earningRequirement: active.earningRequirement,
                allowsDebt: active.allowsDebt,
                debtRecoveryMultiplier: active.debtRecoveryMultiplier
            )
        )
        try? modelContext.save()
    }
}
