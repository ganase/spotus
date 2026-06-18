import Foundation

enum PresetData {
    static let readingCourseId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let gymCourseId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let soberCourseId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let sleepCourseId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    static let spendingCourseId = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    static let commuteCourseId = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!

    static let places: [Place] = [
        Place(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "自宅",
            latitude: 35.681236,
            longitude: 139.767125,
            radius: 150,
            category: .home
        ),
        Place(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "最寄駅",
            latitude: 35.681382,
            longitude: 139.766084,
            radius: 150,
            category: .station
        ),
        Place(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "ジム",
            latitude: 35.682839,
            longitude: 139.759455,
            radius: 150,
            category: .gym
        )
    ]

    static let courses: [HabitCourse] = [
        HabitCourse(
            id: readingCourseId,
            name: "読書習慣コース",
            description: "駅や図書館をきっかけに、短い読書時間を作ります。",
            isEnabled: true,
            targetCategories: [.station, .library, .home]
        ),
        HabitCourse(
            id: gymCourseId,
            name: "ジム継続コース",
            description: "帰宅前やジム到着時に、軽い運動の実行を後押しします。",
            isEnabled: true,
            targetCategories: [.station, .gym, .home]
        ),
        HabitCourse(
            id: soberCourseId,
            name: "節酒コース",
            description: "飲み屋街に近づいたとき、帰宅を選びやすくします。",
            isEnabled: true,
            targetCategories: [.barArea, .station, .home]
        ),
        HabitCourse(
            id: sleepCourseId,
            name: "早寝コース",
            description: "夜の帰宅後に、早く休むための小さな行動を促します。",
            isEnabled: false,
            targetCategories: [.home, .convenienceStore, .barArea]
        ),
        HabitCourse(
            id: spendingCourseId,
            name: "浪費防止コース",
            description: "コンビニや寄り道の前に、買う理由を見直します。",
            isEnabled: false,
            targetCategories: [.convenienceStore, .barArea, .station]
        ),
        HabitCourse(
            id: commuteCourseId,
            name: "通勤時間活用コース",
            description: "通勤の移動時間を、学習や準備の時間に変えます。",
            isEnabled: false,
            targetCategories: [.station, .office]
        )
    ]

    static let rules: [HabitRule] = [
        HabitRule(
            id: UUID(uuidString: "A0000001-0000-0000-0000-000000000001")!,
            courseId: readingCourseId,
            placeCategory: .station,
            triggerType: .enter,
            timeBlock: .morning,
            weekdayType: .any,
            message: "{place}に着きました。電車の中で10ページだけ読んでみましょう。"
        ),
        HabitRule(
            id: UUID(uuidString: "A0000002-0000-0000-0000-000000000002")!,
            courseId: readingCourseId,
            placeCategory: .library,
            triggerType: .enter,
            timeBlock: .daytime,
            weekdayType: .any,
            message: "図書館に着きました。まず15分だけ、静かな読書時間を作りましょう。"
        ),
        HabitRule(
            id: UUID(uuidString: "A0000003-0000-0000-0000-000000000003")!,
            courseId: readingCourseId,
            placeCategory: .home,
            triggerType: .enter,
            timeBlock: .evening,
            weekdayType: .any,
            message: "帰宅しました。スマホを見る前に、1ページだけ本を開いてみましょう。"
        ),
        HabitRule(
            id: UUID(uuidString: "B0000001-0000-0000-0000-000000000001")!,
            courseId: gymCourseId,
            placeCategory: .station,
            triggerType: .enter,
            timeBlock: .evening,
            weekdayType: .weekday,
            message: "帰宅前にジムへ寄れるタイミングです。今日は軽めでもOKです。"
        ),
        HabitRule(
            id: UUID(uuidString: "B0000002-0000-0000-0000-000000000002")!,
            courseId: gymCourseId,
            placeCategory: .gym,
            triggerType: .enter,
            timeBlock: .any,
            weekdayType: .any,
            message: "ジムに着きました。まずは5分だけ体を動かしましょう。"
        ),
        HabitRule(
            id: UUID(uuidString: "B0000003-0000-0000-0000-000000000003")!,
            courseId: gymCourseId,
            placeCategory: .home,
            triggerType: .enter,
            timeBlock: .evening,
            weekdayType: .weekday,
            message: "帰宅しました。今日は家でスクワット10回だけやっておきましょう。"
        ),
        HabitRule(
            id: UUID(uuidString: "C0000001-0000-0000-0000-000000000001")!,
            courseId: soberCourseId,
            placeCategory: .barArea,
            triggerType: .enter,
            timeBlock: .evening,
            weekdayType: .any,
            message: "今日は節酒コース中です。ここで曲がらず、まっすぐ帰る選択をしましょう。"
        ),
        HabitRule(
            id: UUID(uuidString: "C0000002-0000-0000-0000-000000000002")!,
            courseId: soberCourseId,
            placeCategory: .barArea,
            triggerType: .enter,
            timeBlock: .night,
            weekdayType: .any,
            message: "深夜の寄り道は明日の負担になります。水を買って帰るだけにしましょう。"
        ),
        HabitRule(
            id: UUID(uuidString: "C0000003-0000-0000-0000-000000000003")!,
            courseId: soberCourseId,
            placeCategory: .station,
            triggerType: .enter,
            timeBlock: .night,
            weekdayType: .any,
            message: "駅に着きました。今日はそのまま帰宅して、明日の朝を軽くしましょう。"
        ),
        HabitRule(
            id: UUID(uuidString: "D0000001-0000-0000-0000-000000000001")!,
            courseId: sleepCourseId,
            placeCategory: .home,
            triggerType: .enter,
            timeBlock: .evening,
            weekdayType: .any,
            message: "帰宅しました。ストレッチを3分だけやって、寝る準備を始めましょう。"
        ),
        HabitRule(
            id: UUID(uuidString: "D0000002-0000-0000-0000-000000000002")!,
            courseId: sleepCourseId,
            placeCategory: .convenienceStore,
            triggerType: .enter,
            timeBlock: .night,
            weekdayType: .any,
            message: "深夜の買い物は睡眠を遅らせがちです。必要なものだけに絞りましょう。"
        ),
        HabitRule(
            id: UUID(uuidString: "E0000001-0000-0000-0000-000000000001")!,
            courseId: spendingCourseId,
            placeCategory: .convenienceStore,
            triggerType: .enter,
            timeBlock: .evening,
            weekdayType: .any,
            message: "買う前に一度だけ確認しましょう。今日必要なものだけで十分です。"
        ),
        HabitRule(
            id: UUID(uuidString: "E0000002-0000-0000-0000-000000000002")!,
            courseId: spendingCourseId,
            placeCategory: .barArea,
            triggerType: .enter,
            timeBlock: .evening,
            weekdayType: .any,
            message: "浪費防止コース中です。寄り道せず、未来の自分に残す選択をしましょう。"
        ),
        HabitRule(
            id: UUID(uuidString: "F0000001-0000-0000-0000-000000000001")!,
            courseId: commuteCourseId,
            placeCategory: .station,
            triggerType: .enter,
            timeBlock: .morning,
            weekdayType: .weekday,
            message: "駅に着きました。移動中に今日のタスクを3つだけ整理しましょう。"
        ),
        HabitRule(
            id: UUID(uuidString: "F0000002-0000-0000-0000-000000000002")!,
            courseId: commuteCourseId,
            placeCategory: .office,
            triggerType: .enter,
            timeBlock: .morning,
            weekdayType: .weekday,
            message: "職場に着きました。最初の25分で一番大事な作業に着手しましょう。"
        )
    ]

    static func guide(for ruleId: UUID) -> ActionGuide? {
        ruleGuides[ruleId]
    }

    private static let ruleGuides: [UUID: ActionGuide] = [
        UUID(uuidString: "A0000001-0000-0000-0000-000000000001")!: ActionGuide(
            doText: "電車に乗ったら10ページだけ読む",
            avoidText: "移動時間を何となくスマホで埋める"
        ),
        UUID(uuidString: "A0000002-0000-0000-0000-000000000002")!: ActionGuide(
            doText: "最初の15分は静かに読書する",
            avoidText: "席に着いてから別の用事を始める"
        ),
        UUID(uuidString: "A0000003-0000-0000-0000-000000000003")!: ActionGuide(
            doText: "本を1ページだけ開く",
            avoidText: "先にスマホを見る"
        ),
        UUID(uuidString: "B0000001-0000-0000-0000-000000000001")!: ActionGuide(
            doText: "帰宅前にジムへ向かう",
            avoidText: "そのまま駅から帰ってしまう"
        ),
        UUID(uuidString: "B0000002-0000-0000-0000-000000000002")!: ActionGuide(
            doText: "まず5分だけ体を動かし始める",
            avoidText: "着いてすぐ休憩モードに入る"
        ),
        UUID(uuidString: "B0000003-0000-0000-0000-000000000003")!: ActionGuide(
            doText: "家でスクワット10回だけやる",
            avoidText: "ソファに座ってそのまま終える"
        ),
        UUID(uuidString: "C0000001-0000-0000-0000-000000000001")!: ActionGuide(
            doText: "ここで曲がらず、そのまま帰る",
            avoidText: "勢いで店に入る"
        ),
        UUID(uuidString: "C0000002-0000-0000-0000-000000000002")!: ActionGuide(
            doText: "水だけ買って帰る",
            avoidText: "深夜の一杯に流れる"
        ),
        UUID(uuidString: "C0000003-0000-0000-0000-000000000003")!: ActionGuide(
            doText: "そのまま帰宅する",
            avoidText: "別の店や寄り道に向かう"
        ),
        UUID(uuidString: "D0000001-0000-0000-0000-000000000001")!: ActionGuide(
            doText: "3分だけストレッチして寝る準備を始める",
            avoidText: "帰宅後にだらだら画面を見る"
        ),
        UUID(uuidString: "D0000002-0000-0000-0000-000000000002")!: ActionGuide(
            doText: "必要なものだけ買って切り上げる",
            avoidText: "夜食や余計な買い足しをする"
        ),
        UUID(uuidString: "E0000001-0000-0000-0000-000000000001")!: ActionGuide(
            doText: "必要なものだけ確認して買う",
            avoidText: "ついで買いを増やす"
        ),
        UUID(uuidString: "E0000002-0000-0000-0000-000000000002")!: ActionGuide(
            doText: "寄り道せず帰る",
            avoidText: "気分で出費を増やす"
        ),
        UUID(uuidString: "F0000001-0000-0000-0000-000000000001")!: ActionGuide(
            doText: "移動中に今日のタスクを3つだけ整理する",
            avoidText: "乗車時間を漫然と流す"
        ),
        UUID(uuidString: "F0000002-0000-0000-0000-000000000002")!: ActionGuide(
            doText: "最優先の作業を最初の25分で始める",
            avoidText: "メールや雑務から入る"
        )
    ]
}
