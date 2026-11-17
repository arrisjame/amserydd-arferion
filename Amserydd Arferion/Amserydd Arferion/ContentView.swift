import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("didSeedHabits") private var didSeedHabits = false

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Bank", systemImage: "hourglass") }

            HabitsView()
                .tabItem { Label("Habits", systemImage: "leaf") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
        .tint(GorpcoreTheme.rust)
        .task { seedHabitsIfNeeded() }
    }

    private func seedHabitsIfNeeded() {
        guard !didSeedHabits else { return }

        [
            Habit(name: "Walk", kind: .earning, earningRequirement: 1.5, symbol: "figure.walk"),
            Habit(name: "Read", kind: .earning, earningRequirement: 1.5, symbol: "book.closed.fill"),
            Habit(name: "Social media", kind: .spending, symbol: "apps.iphone"),
            Habit(name: "Gaming", kind: .spending, symbol: "gamecontroller.fill")
        ].forEach(modelContext.insert)

        didSeedHabits = true
        try? modelContext.save()
    }
}
