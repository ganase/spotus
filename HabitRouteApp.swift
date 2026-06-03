import SwiftUI

@main
struct HabitRouteApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
                .task {
                    appState.bootstrap()
                }
        }
    }
}
