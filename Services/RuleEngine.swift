import Foundation

struct RuleMatch {
    let course: HabitCourse
    let rule: HabitRule
    let message: String
}

enum RuleEngine {
    static func matchingRules(
        for place: Place,
        triggerType: TriggerType,
        date: Date,
        courses: [HabitCourse],
        rules: [HabitRule]
    ) -> [RuleMatch] {
        candidates(
            for: place,
            triggerType: triggerType,
            date: date,
            courses: courses,
            rules: rules
        )
        .map(\.match)
    }

    static func bestMatch(
        for place: Place,
        triggerType: TriggerType,
        date: Date,
        courses: [HabitCourse],
        rules: [HabitRule]
    ) -> RuleMatch? {
        matchingRules(
            for: place,
            triggerType: triggerType,
            date: date,
            courses: courses,
            rules: rules
        )
        .first
    }

    private static func candidates(
        for place: Place,
        triggerType: TriggerType,
        date: Date,
        courses: [HabitCourse],
        rules: [HabitRule]
    ) -> [(match: RuleMatch, score: Int)] {
        let enabledCourses = Dictionary(
            uniqueKeysWithValues: courses
                .filter {
                    $0.isEnabled &&
                    $0.timeBlock.matches(date: date) &&
                    $0.weekdayType.matches(date: date)
                }
                .map { ($0.id, $0) }
        )

        let candidates = rules.compactMap { rule -> (match: RuleMatch, score: Int)? in
            guard rule.isEnabled,
                  matches(place: place, rule: rule),
                  rule.triggerType == triggerType,
                  rule.timeBlock.matches(date: date),
                  rule.weekdayType.matches(date: date),
                  let course = enabledCourses[rule.courseId],
                  !rule.tasks.isEmpty
            else {
                return nil
            }

            let message = render(rule.message, place: place)
            return (RuleMatch(course: course, rule: rule, message: message), score(rule))
        }

        return candidates
            .sorted { left, right in
                if left.score != right.score {
                    return left.score > right.score
                }

                if left.match.course.name != right.match.course.name {
                    return left.match.course.name.localizedCompare(right.match.course.name) == .orderedAscending
                }

                return left.match.message.localizedCompare(right.match.message) == .orderedAscending
            }
    }

    private static func render(_ template: String, place: Place) -> String {
        template
            .replacingOccurrences(of: "{place}", with: place.name)
            .replacingOccurrences(of: "{category}", with: place.category.displayName)
    }

    private static func matches(place: Place, rule: HabitRule) -> Bool {
        if let placeId = rule.placeId {
            return placeId == place.id
        }

        return rule.placeCategory == place.category
    }

    private static func score(_ rule: HabitRule) -> Int {
        var value = 0

        if rule.placeId != nil {
            value += 20
        }

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
