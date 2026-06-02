import Foundation

struct RuleMatch {
    let course: HabitCourse
    let rule: HabitRule
    let message: String
}

enum RuleEngine {
    static func bestMatch(
        for place: Place,
        triggerType: TriggerType,
        date: Date,
        courses: [HabitCourse],
        rules: [HabitRule]
    ) -> RuleMatch? {
        let enabledCourses = Dictionary(
            uniqueKeysWithValues: courses
                .filter { $0.isEnabled }
                .map { ($0.id, $0) }
        )

        let candidates = rules.compactMap { rule -> (RuleMatch, Int)? in
            guard rule.isEnabled,
                  rule.placeCategory == place.category,
                  rule.triggerType == triggerType,
                  rule.timeBlock.matches(date: date),
                  rule.weekdayType.matches(date: date),
                  let course = enabledCourses[rule.courseId],
                  course.targetCategories.contains(place.category)
            else {
                return nil
            }

            let message = render(rule.message, place: place)
            return (RuleMatch(course: course, rule: rule, message: message), score(rule))
        }

        return candidates
            .sorted { left, right in left.1 > right.1 }
            .first?
            .0
    }

    private static func render(_ template: String, place: Place) -> String {
        template
            .replacingOccurrences(of: "{place}", with: place.name)
            .replacingOccurrences(of: "{category}", with: place.category.displayName)
    }

    private static func score(_ rule: HabitRule) -> Int {
        var value = 0

        // Exact time and weekday rules should win over broader fallback rules.
        if rule.timeBlock != .any {
            value += 10
        }

        if rule.weekdayType != .any {
            value += 3
        }

        return value
    }
}
