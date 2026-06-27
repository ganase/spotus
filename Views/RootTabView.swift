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
                PlaceListView()
            }
            .tag(AppTab.place)
            .tabItem {
                Label("Place", systemImage: "mappin.and.ellipse")
            }

            NavigationStack {
                ActListView()
            }
            .tag(AppTab.act)
            .tabItem {
                Label("Act", systemImage: "list.bullet.rectangle")
            }

            NavigationStack {
                StepsRegistryView()
            }
            .tag(AppTab.steps)
            .tabItem {
                Label("Steps", systemImage: "checklist")
            }

            NavigationStack {
                LogListView()
            }
            .tag(AppTab.log)
            .tabItem {
                Label("Log", systemImage: "list.bullet.clipboard")
            }
            .modifier(PendingBadgeModifier(count: appState.pendingActionCount))
        }
        .sheet(item: $appState.mapSelection) { selection in
            if let place = appState.place(for: selection.placeId) {
                PlaceMapDetailView(place: place)
                    .environmentObject(appState)
            } else {
                ContentUnavailableView("場所が見つかりません", systemImage: "mappin.slash")
            }
        }
        .tint(appState.appTheme.tintColor)
        .preferredColorScheme(appState.appTheme.colorScheme)
        .toolbarBackground(appState.appTheme.barBackground, for: .navigationBar, .tabBar)
        .toolbarBackground(appState.appTheme.barVisibility, for: .navigationBar, .tabBar)
        .toolbarColorScheme(appState.appTheme.barColorScheme, for: .navigationBar, .tabBar)
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

extension AppTheme {
    var tintColor: Color {
        switch self {
        case .plain:
            return .blue
        case .gray:
            return Color(red: 0.08, green: 0.18, blue: 0.34)
        case .dark:
            return .cyan
        }
    }

    var screenBackground: Color {
        switch self {
        case .plain:
            return Color(.systemGroupedBackground)
        case .gray:
            return Color(red: 0.78, green: 0.81, blue: 0.86)
        case .dark:
            return Color(.systemBackground)
        }
    }

    var cardBackground: Color {
        switch self {
        case .plain, .dark:
            return Color(.systemBackground)
        case .gray:
            return Color(red: 0.98, green: 0.99, blue: 1.00)
        }
    }

    var subtleBackground: Color {
        switch self {
        case .plain, .dark:
            return Color.accentColor.opacity(0.08)
        case .gray:
            return Color.white.opacity(0.86)
        }
    }

    var barBackground: Color {
        switch self {
        case .plain:
            return Color(.systemBackground)
        case .gray:
            return Color(red: 0.09, green: 0.12, blue: 0.17)
        case .dark:
            return Color(.systemBackground)
        }
    }

    var barVisibility: Visibility {
        switch self {
        case .plain:
            return .automatic
        case .gray, .dark:
            return .visible
        }
    }

    var barColorScheme: ColorScheme? {
        switch self {
        case .plain:
            return nil
        case .gray, .dark:
            return .dark
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .plain, .gray:
            return nil
        case .dark:
            return .dark
        }
    }

    var elementBorderColor: Color {
        switch self {
        case .plain:
            return Color.secondary.opacity(0.20)
        case .gray:
            return .clear
        case .dark:
            return Color.white.opacity(0.18)
        }
    }

    var elementBorderWidth: CGFloat {
        switch self {
        case .plain, .dark:
            return 1
        case .gray:
            return 0
        }
    }
}

struct ThemedScreenBackground: ViewModifier {
    @EnvironmentObject private var appState: AppState

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(appState.appTheme == .plain ? .automatic : .hidden)
            .background(appState.appTheme.screenBackground.ignoresSafeArea())
    }
}

extension View {
    func themedScreenBackground() -> some View {
        modifier(ThemedScreenBackground())
    }
}
