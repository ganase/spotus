import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                CourseListView()
            }
            .tabItem {
                Label("Course", systemImage: "figure.walk.motion")
            }

            NavigationStack {
                PlaceListView()
            }
            .tabItem {
                Label("Place", systemImage: "mappin.and.ellipse")
            }

            NavigationStack {
                RuleListView()
            }
            .tabItem {
                Label("Rule", systemImage: "list.bullet.rectangle")
            }

            NavigationStack {
                LogListView()
            }
            .tabItem {
                Label("Log", systemImage: "clock.arrow.circlepath")
            }
        }
    }
}
