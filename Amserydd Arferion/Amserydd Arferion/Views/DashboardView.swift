import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerCoordinator.self) private var timerCoordinator
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query(sort: \HabitSession.startedAt) private var sessions: [HabitSession]

    @AppStorage("debtMode") private var debtMode = "stopAtZero"
    @AppStorage("debtRecoveryMultiplier") private var debtRecoveryMultiplier = 1.5
    @State private var expandedHabitID: UUID?
    @State private var zeroAlertedTimerStart: Date?
    @State private var showEarningExplanation = false
    @State private var showCancelConfirmation = false

    private var balance: TimeInterval {
        TimeLedger.balance(for: sessions.map(\.ledgerRecord))
    }

    private var allowsDebt: Bool { debtMode == "allowDebt" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Text("Time Bank")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .foregroundStyle(GorpcoreTheme.carbon)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityAddTraits(.isHeader)

                    bankRows

                    if timerCoordinator.active != nil {
                        activeTimerCard
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(GorpcoreTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .alert("How earning ratios work", isPresented: $showEarningExplanation) {
                Button("Got it", role: .cancel) { }
            } message: {
                Text("An earning ratio of 1.5× means 90 seconds of a good habit earns 60 seconds of spendable time.")
            }
            .alert("Cancel this timer?", isPresented: $showCancelConfirmation) {
                Button("Keep timer", role: .cancel) { }
                Button("Cancel timer", role: .destructive) {
                    timerCoordinator.cancel()
                    zeroAlertedTimerStart = nil
                }
            } message: {
                Text("Elapsed time will not be saved.")
            }
        }
    }

    private var bankRows: some View {
        VStack(spacing: 14) {
            habitShelf(kind: .earning)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let liveBalance = displayedBalance(at: context.date)

                availableTimeCard(balance: liveBalance)
                    .onChange(of: liveBalance) { previousBalance, currentBalance in
                        notifyIfBalanceCrossedZero(
                            from: previousBalance,
                            to: currentBalance
                        )
                    }
            }

            habitShelf(kind: .spending)
        }
    }

    private func habitShelf(kind: HabitKind) -> some View {
        let matchingHabits = habits.filter { $0.kind == kind }
        let rowColor = kind == .earning ? GorpcoreTheme.mossyOak : GorpcoreTheme.rust

        return VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind == .earning ? "EARN TIME" : "SPEND TIME")
                        .font(.caption.bold().monospaced())
                        .tracking(1.2)
                    Text(kind == .earning ? "Good habits build your balance" : "Browse how you want to use it")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if kind == .earning {
                    Button {
                        showEarningExplanation = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                    }
                    .accessibilityLabel("Explain earning ratios")
                }

                Spacer()

                Image(systemName: "arrow.left.and.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Scroll horizontally to browse habits")
            }
            .foregroundStyle(rowColor)

            if matchingHabits.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                    Text("Add a \(kind.title.lowercased()) habit in the Habits tab")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 108)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(matchingHabits) { habit in
                            expandableHabit(habit, color: rowColor)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            rowColor.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(rowColor.opacity(0.16), lineWidth: 1)
        }
    }

    private func expandableHabit(_ habit: Habit, color: Color) -> some View {
        let isExpanded = expandedHabitID == habit.id
        let isActive = timerCoordinator.active?.habitID == habit.id
        let unavailable = timerCoordinator.active != nil
            || (habit.kind == .spending && !allowsDebt && balance <= 0)

        return VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expandedHabitID = isExpanded ? nil : habit.id
                }
            } label: {
                Image(systemName: habit.symbol)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(color, in: Circle())
                    .scaleEffect(isExpanded ? 1.06 : 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(habit.name)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint("Shows the habit name and start button")

            if isExpanded {
                Text(habit.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GorpcoreTheme.carbon)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Button(isActive ? "Active" : "Start") {
                    startTimer(for: habit)
                }
                .font(.caption.bold())
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(color)
                .disabled(unavailable)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(width: isExpanded ? 118 : 82)
        .frame(minHeight: 112, alignment: isExpanded ? .top : .center)
        .background(
            GorpcoreTheme.surface,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(color.opacity(isExpanded ? 0.30 : 0.10), lineWidth: 1)
        }
    }

    private func availableTimeCard(balance liveBalance: TimeInterval) -> some View {
        let isDebt = liveBalance < 0
        let isEmpty = abs(liveBalance) < 0.5

        return HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text(isDebt ? "TIME DEBT" : "AVAILABLE TIME")
                    .font(.caption.bold().monospaced())
                    .tracking(1.3)
                    .foregroundStyle(GorpcoreTheme.desertSand)

                Text(TimeText.balance(liveBalance))
                    .font(.system(size: 51, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.70)
                    .lineLimit(1)

                if isEmpty {
                    Label("Time is up", systemImage: "bell.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(GorpcoreTheme.rust, in: Capsule())
                } else {
                    Text(bankStatus(balance: liveBalance))
                        .font(.caption)
                        .foregroundStyle(GorpcoreTheme.desertSand.opacity(0.78))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .stroke(GorpcoreTheme.desertSand.opacity(0.20), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: isEmpty || isDebt ? 0.08 : 0.72)
                    .stroke(
                        isDebt || isEmpty ? GorpcoreTheme.rust : GorpcoreTheme.desertSand,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Image(systemName: isEmpty ? "speaker.wave.3.fill" : isDebt ? "arrow.up.heart.fill" : "hourglass")
                    .font(.title2)
                    .foregroundStyle(isEmpty || isDebt ? GorpcoreTheme.rust : GorpcoreTheme.desertSand)
            }
            .frame(width: 78, height: 78)
            .accessibilityHidden(true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
        .background(
            GorpcoreTheme.carbon,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isDebt
                ? "Time debt \(TimeText.balance(liveBalance))"
                : "Available time \(TimeText.balance(liveBalance))"
        )
    }

    private var activeTimerCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let active = timerCoordinator.active {
                let elapsed = active.elapsed(at: context.date)

                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: active.symbol)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(
                                active.kind == .earning ? GorpcoreTheme.mossyOak : GorpcoreTheme.rust,
                                in: Circle()
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(active.kind == .earning ? "EARNING NOW" : "SPENDING NOW")
                                .font(.caption2.bold().monospaced())
                                .tracking(1.2)
                                .foregroundStyle(GorpcoreTheme.rust)
                            Text(active.habitName)
                                .font(.headline)
                        }

                        Spacer()

                        Text(TimeText.balance(elapsed))
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(GorpcoreTheme.carbon)
                            .onChange(of: Int(elapsed)) { _, _ in
                                if timerCoordinator.shouldAutoFinish(at: context.date) {
                                    saveFinishedTimer(at: context.date)
                                }
                            }
                    }

                    HStack(spacing: 10) {
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

    private func displayedBalance(at date: Date) -> TimeInterval {
        guard let active = timerCoordinator.active else { return balance }

        let liveRecord = LedgerRecord(
            id: active.habitID,
            startedAt: active.startedAt,
            kind: active.kind,
            duration: active.elapsed(at: date),
            earningRequirement: active.earningRequirement,
            allowsDebt: active.allowsDebt,
            debtRecoveryMultiplier: active.debtRecoveryMultiplier
        )

        return TimeLedger.balance(for: sessions.map(\.ledgerRecord) + [liveRecord])
    }

    private func bankStatus(balance liveBalance: TimeInterval) -> String {
        if liveBalance < 0 { return "Earn time to clear your debt" }
        if let active = timerCoordinator.active {
            return active.kind == .earning
                ? "Earning with \(active.habitName)"
                : "Spending on \(active.habitName)"
        }
        return "Ready to spend"
    }

    private func startTimer(for habit: Habit) {
        if habit.kind == .spending {
            TimeBankAlertService.shared.requestAuthorizationIfNeeded()
        }

        timerCoordinator.begin(
            habit: habit,
            allowsDebt: allowsDebt,
            debtRecoveryMultiplier: debtRecoveryMultiplier,
            currentBalance: balance
        )
        expandedHabitID = nil
        zeroAlertedTimerStart = nil

        if habit.kind == .spending, balance <= 0 {
            zeroAlertedTimerStart = timerCoordinator.active?.startedAt
            TimeBankAlertService.shared.notifyTimeExpired()
        }
    }

    private func notifyIfBalanceCrossedZero(
        from previousBalance: TimeInterval,
        to currentBalance: TimeInterval
    ) {
        guard
            TimeLedger.crossedZero(from: previousBalance, to: currentBalance),
            let active = timerCoordinator.active,
            active.kind == .spending,
            zeroAlertedTimerStart != active.startedAt
        else { return }

        zeroAlertedTimerStart = active.startedAt
        TimeBankAlertService.shared.notifyTimeExpired()
    }

    private func saveFinishedTimer(at date: Date = .now) {
        let endingBalance = displayedBalance(at: date)
        guard let completed = timerCoordinator.finish(at: date), completed.duration > 0 else { return }

        let active = completed.active

        if active.kind == .spending,
           endingBalance <= 0,
           zeroAlertedTimerStart != active.startedAt {
            zeroAlertedTimerStart = active.startedAt
            TimeBankAlertService.shared.notifyTimeExpired()
        }

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
