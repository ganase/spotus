import SwiftUI

struct RuleListView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            ForEach(appState.courses) { course in
                let courseRules = appState.rules.filter { $0.courseId == course.id }

                Section(course.name) {
                    ForEach(courseRules) { rule in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(rule.placeCategory.displayName, systemImage: rule.placeCategory.systemImage)
                                Spacer()
                                Text(rule.triggerType.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(rule.message)
                                .font(.subheadline)

                            HStack {
                                Text(rule.timeBlock.displayName)
                                Text(rule.weekdayType.displayName)
                                Text(rule.isEnabled ? "ON" : "OFF")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Rule")
    }
}
