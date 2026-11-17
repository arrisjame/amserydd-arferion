import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HabitSession.startedAt, order: .reverse) private var sessions: [HabitSession]
    @State private var editingSession: HabitSession?

    private var ledgerEntries: [UUID: LedgerEntry] {
        Dictionary(
            uniqueKeysWithValues: TimeLedger
                .evaluate(sessions.map(\.ledgerRecord))
                .map { ($0.id, $0) }
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "clock.badge.questionmark",
                        description: Text("Completed timers will appear here.")
                    )
                } else {
                    List {
                        ForEach(sessions) { session in
                            Button {
                                editingSession = session
                            } label: {
                                historyRow(session)
                            }
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    modelContext.delete(session)
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(GorpcoreTheme.background)
            .navigationTitle("History")
            .sheet(item: $editingSession) { session in
                SessionEditorView(session: session)
            }
        }
    }

    private func historyRow(_ session: HabitSession) -> some View {
        let delta = ledgerEntries[session.id]?.delta ?? 0

        return HStack(spacing: 14) {
            Image(systemName: session.symbol)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    session.kind == .earning ? GorpcoreTheme.mossyOak : GorpcoreTheme.rust,
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(session.habitName)
                    .font(.headline)
                    .foregroundStyle(GorpcoreTheme.carbon)
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(delta >= 0 ? "+" : "−")\(TimeText.compact(delta))")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(session.kind == .earning ? GorpcoreTheme.mossyOak : GorpcoreTheme.rust)
                Text("\(TimeText.compact(session.duration)) actual")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct SessionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let session: HabitSession
    @State private var startedAt: Date
    @State private var durationMinutes: Int

    init(session: HabitSession) {
        self.session = session
        _startedAt = State(initialValue: session.startedAt)
        _durationMinutes = State(initialValue: max(1, Int((session.duration / 60).rounded())))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    LabeledContent("Habit", value: session.habitName)
                    DatePicker("Started", selection: $startedAt)
                    Stepper(value: $durationMinutes, in: 1...(24 * 60)) {
                        LabeledContent("Actual duration", value: durationLabel)
                    }
                }

                Section {
                    Text("Changing this session recalculates the full time-bank history, including debt recovery.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(GorpcoreTheme.background)
            .navigationTitle("Correct session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        session.startedAt = startedAt
                        session.endedAt = startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
                        session.duration = TimeInterval(durationMinutes * 60)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }

    private var durationLabel: String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
