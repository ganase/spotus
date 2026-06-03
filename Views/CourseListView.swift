import SwiftUI

struct CourseListView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            ForEach(appState.courses) { course in
                Toggle(isOn: binding(for: course)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(course.name)
                            .font(.headline)
                        Text(course.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(course.targetCategories.map(\.displayName).joined(separator: " / "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Course")
    }

    private func binding(for course: HabitCourse) -> Binding<Bool> {
        Binding(
            get: {
                appState.courses.first(where: { $0.id == course.id })?.isEnabled ?? false
            },
            set: { isEnabled in
                appState.setCourseEnabled(course.id, isEnabled: isEnabled)
            }
        )
    }
}
