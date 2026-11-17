import SwiftData
import SwiftUI

@main
struct AmseryddArferionApp: App {
    @State private var timerCoordinator = TimerCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(timerCoordinator)
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [Habit.self, HabitSession.self])
    }
}
