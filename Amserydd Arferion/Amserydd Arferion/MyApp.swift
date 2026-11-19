import SwiftData
import SwiftUI

@main
struct AmseryddArferionApp: App {
    @State private var timerCoordinator = TimerCoordinator()

    init() {
        TimeBankAlertService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(timerCoordinator)
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [Habit.self, HabitSession.self])
    }
}
