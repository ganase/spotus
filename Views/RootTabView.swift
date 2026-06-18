import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tag(AppTab.home)
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                LogListView()
            }
            .tag(AppTab.actionCenter)
            .tabItem {
                Label("一歩", systemImage: "figure.walk.arrival")
            }
            .modifier(PendingBadgeModifier(count: appState.pendingActionCount))

            NavigationStack {
                CourseListView()
            }
            .tag(AppTab.course)
            .tabItem {
                Label("Course", systemImage: "figure.walk.motion")
            }

            NavigationStack {
                PlaceListView()
            }
            .tag(AppTab.place)
            .tabItem {
                Label("Place", systemImage: "mappin.and.ellipse")
            }

            NavigationStack {
                RuleListView()
            }
            .tag(AppTab.rule)
            .tabItem {
                Label("Rule", systemImage: "list.bullet.rectangle")
            }
        }
        .sheet(item: $appState.mapSelection) { selection in
            if let place = appState.place(for: selection.placeId) {
                PlaceMapDetailView(place: place)
                    .environmentObject(appState)
            } else {
                ContentUnavailableView("場所が見つかりません", systemImage: "mappin.slash")
            }
        }
    }
}

private struct PendingBadgeModifier: ViewModifier {
    let count: Int

    @ViewBuilder
    func body(content: Content) -> some View {
        if count > 0 {
            content.badge(count)
        } else {
            content
        }
    }
}
