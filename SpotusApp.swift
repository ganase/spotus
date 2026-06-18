import SwiftUI

@main
struct SpotusApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
                .task {
                    appState.bootstrap()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        appState.refreshMonitoringState()
                    }
                }
        }
    }
}
