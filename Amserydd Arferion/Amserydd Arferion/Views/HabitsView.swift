import SwiftData
import SwiftUI

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @State private var editorTarget: HabitEditorTarget?

    var body: some View {
        NavigationStack {
            List {
                habitSection(kind: .earning)
                habitSection(kind: .spending)
            }
            .scrollContentBackground(.hidden)
            .background(GorpcoreTheme.background)
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorTarget = HabitEditorTarget(habit: nil)
                    } label: {
                        Label("Add habit", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editorTarget) { target in
                HabitEditorView(habit: target.habit)
            }
        }
    }

    @ViewBuilder
    private func habitSection(kind: HabitKind) -> some View {
        Section {
            let matchingHabits = habits.filter { $0.kind == kind }

            if matchingHabits.isEmpty {
                Text("No \(kind.title.lowercased()) habits yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(matchingHabits) { habit in
                    Button {
                        editorTarget = HabitEditorTarget(habit: habit)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: habit.symbol)
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(
                                    kind == .earning ? GorpcoreTheme.mossyOak : GorpcoreTheme.rust,
                                    in: Circle()
                                )
                            VStack(alignment: .leading, spacing: 3) {
                                Text(habit.name)
                                    .font(.headline)
                                    .foregroundStyle(GorpcoreTheme.carbon)
                                Text(
                                    kind == .earning
                                        ? "\(habit.earningRequirement.formatted(.number.precision(.fractionLength(0...2))))× effort ratio"
                                        : "Uses your available balance"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            modelContext.delete(habit)
                            try? modelContext.save()
                        }
                    }
                }
            }
        } header: {
            Text(kind == .earning ? "Earn time" : "Spend time")
                .font(.caption.bold().monospaced())
                .foregroundStyle(GorpcoreTheme.rust)
        }
    }
}

private struct HabitEditorTarget: Identifiable {
    let id = UUID()
    let habit: Habit?
}

private struct HabitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let habit: Habit?

    @State private var name: String
    @State private var kind: HabitKind
    @State private var earningRequirement: Double
    @State private var symbol: String
    @State private var showRatioExplanation = false

    private let earningSymbols = ["figure.walk", "book.closed.fill", "dumbbell.fill", "brain.head.profile", "leaf.fill", "paintbrush.fill"]
    private let spendingSymbols = ["apps.iphone", "gamecontroller.fill", "tv.fill", "cup.and.saucer.fill", "music.note", "cart.fill"]

    init(habit: Habit?) {
        self.habit = habit
        _name = State(initialValue: habit?.name ?? "")
        _kind = State(initialValue: habit?.kind ?? .earning)
        _earningRequirement = State(initialValue: habit?.earningRequirement ?? 1.5)
        _symbol = State(initialValue: habit?.symbol ?? "figure.walk")
    }

    private var symbols: [String] {
        kind == .earning ? earningSymbols : spendingSymbols
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $kind) {
                        ForEach(HabitKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, newKind in
                        if !symbols.contains(symbol) {
                            symbol = newKind == .earning ? earningSymbols[0] : spendingSymbols[0]
                        }
                    }
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                        ForEach(symbols, id: \.self) { option in
                            Button {
                                symbol = option
                            } label: {
                                Image(systemName: option)
                                    .font(.title3)
                                    .foregroundStyle(symbol == option ? .white : GorpcoreTheme.carbon)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        symbol == option ? GorpcoreTheme.mossyOak : GorpcoreTheme.sandstone.opacity(0.45),
                                        in: Circle()
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option)
                            .accessibilityAddTraits(symbol == option ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }

                if kind == .earning {
                    Section {
                        Stepper(value: $earningRequirement, in: 1...3, step: 0.25) {
                            HStack {
                                Text("Effort ratio")
                                Spacer()
                                Text("\(earningRequirement.formatted(.number.precision(.fractionLength(0...2))))×")
                                    .font(.headline.monospacedDigit())
                            }
                        }

                        Button {
                            showRatioExplanation = true
                        } label: {
                            Label("What does this mean?", systemImage: "info.circle")
                        }
                    } footer: {
                        Text(exampleText)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GorpcoreTheme.background)
            .navigationTitle(habit == nil ? "New habit" : "Edit habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Earning ratio", isPresented: $showRatioExplanation) {
                Button("Got it", role: .cancel) { }
            } message: {
                Text("The ratio is the good-habit effort required to earn one unit of spendable time. At 1.5×, 90 seconds earns 60 seconds.")
            }
        }
    }

    private var exampleText: String {
        let goodMinutes = Int((earningRequirement * 10).rounded())
        return "About \(goodMinutes) minutes of this habit earns 10 minutes of spendable time."
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let habit {
            habit.name = cleanName
            habit.kind = kind
            habit.earningRequirement = earningRequirement
            habit.symbol = symbol
        } else {
            modelContext.insert(
                Habit(
                    name: cleanName,
                    kind: kind,
                    earningRequirement: earningRequirement,
                    symbol: symbol
                )
            )
        }

        try? modelContext.save()
        dismiss()
    }
}
