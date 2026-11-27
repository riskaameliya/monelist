import SwiftUI

@main
struct MoneListApp: App {
    @StateObject private var store = TodoStore()
    @StateObject private var pomo = PomodoroTimer()

    var body: some Scene {
        Window("MoneList", id: "main") {
            ContentView()
                .environmentObject(store)
                .environmentObject(pomo)
        }
        .windowResizability(.contentSize)
    }
}
