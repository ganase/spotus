# Spotus MVP

Spotusは、時間ベースではなく「場所 x 状況 x 生活コース」を使って、その場で最適な行動を促すiOS向けMVPです。

## 1. ディレクトリ構成

```text
spotus/
  Spotus.xcodeproj/
  SpotusApp.swift
  Info.plist
  Assets.xcassets/
  Models/
  Services/
  Views/
```

## 2. Swiftファイル一覧と役割

| ファイル | 役割 |
| --- | --- |
| `SpotusApp.swift` | アプリのエントリーポイント。`AppState`を生成し全画面に共有する。 |
| `Models/Place.swift` | 登録地点と場所カテゴリ。 |
| `Models/HabitCourse.swift` | 生活改善コース。 |
| `Models/HabitRule.swift` | コース、場所カテゴリ、時間帯、平日/休日、通知文の対応ルール。 |
| `Models/TriggerLog.swift` | 通知発火ログとユーザー反応。 |
| `Services/PresetData.swift` | MVP用のプリセットコースとプリセットルール。 |
| `Services/LocalStore.swift` | Application Support配下へのJSON保存/読み込み。 |
| `Services/RuleEngine.swift` | 場所、トリガー、時刻、コースON/OFFから通知ルールを選ぶ。 |
| `Services/NotificationService.swift` | `UNUserNotificationCenter`の許可取得、ローカル通知、通知アクション処理。 |
| `Services/LocationService.swift` | `CLLocationManager`の許可取得、現在地取得、Region Monitoring、`didEnterRegion`/`didExitRegion`。 |
| `Services/AppState.swift` | 画面、保存、通知、位置情報サービスをつなぐアプリ状態。 |
| `Views/RootTabView.swift` | Home/Course/Place/Rule/Logのタブ。 |
| `Views/HomeView.swift` | 地図、有効コース、権限状態を表示。 |
| `Views/CourseListView.swift` | コース一覧とON/OFF。 |
| `Views/PlaceListView.swift` | 登録地点一覧、削除、ON/OFF、テスト通知。 |
| `Views/PlaceEditorView.swift` | 場所の新規登録/編集。 |
| `Views/RuleListView.swift` | ルール一覧と通知文編集。 |
| `Views/LogListView.swift` | 通知ログ一覧。 |

## 3. 最小実装コードの要点

- モデルはすべて`Codable`で、JSON保存できる。
- `PresetData`に読書、ジム、節酒、早寝、浪費防止、通勤時間活用コースを定義。
- `RuleEngine.bestMatch(...)`が現在時刻の`TimeBlock`と平日/休日を判定し、最も具体的なルールを選ぶ。
- `LocationService.syncMonitoring(for:)`が有効な登録地点を最大20件まで`CLCircularRegion`として監視する。
- `LocationService`は`didEnterRegion`に加えて`didDetermineState`でも監視状態を再確認し、入域イベントの取りこぼし回復を行う。
- `AppState.handleRegionEvent(...)`がルール照合、フォールバック通知、重複抑制、ログ保存をまとめて行う。
- `NotificationService.deliver(...)`が即時ローカル通知を出し、通知アクション「やった」「地図で見る」やdismiss/openをログに反映する。

## 4. 権限実装

`Info.plist`に以下の位置情報利用目的を入れています。

- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`

通知許可は`NotificationService.requestAuthorization()`で`.alert`, `.sound`, `.badge`を要求します。

位置情報許可は`LocationService.requestAlwaysAuthorization()`で要求します。バックグラウンドでRegion Monitoringを使うには、ユーザーが「常に許可」を選ぶ必要があります。

## 5. プリセットコースとルール

初期状態では以下の6コースを持ちます。

- 読書習慣コース
- ジム継続コース
- 節酒コース
- 早寝コース
- 浪費防止コース
- 通勤時間活用コース

例として、駅 x 朝 x 読書、駅 x 夜 x ジム、飲み屋街 x 夜 x 節酒、自宅 x 夜 x 早寝などのルールを定義しています。

## 6. Region Monitoring

`LocationService`は有効な`Place`を`CLCircularRegion`に変換します。

- `identifier`: `Place.id.uuidString`
- `center`: 緯度/経度
- `radius`: 最小50m、端末の`maximumRegionMonitoringDistance`以内
- `notifyOnEntry`: `true`
- `notifyOnExit`: `true`

MVPではenterを主に使いますが、exitもモデルとサービスで受け取れる状態にしています。

## 7. 通知ロジックの判定表

通知は、単に「スポットに着いたか」だけではなく、監視状態、重複、コースON/OFF、時間帯ルールまで含めて判定します。

| 段階 | 条件 | 結果 |
| --- | --- | --- |
| 監視登録 | 位置情報許可が`authorizedAlways`または`authorizedWhenInUse`、かつ`Place.isEnabled == true` | 有効な先頭20地点をRegion Monitoringへ登録 |
| 入域イベント | `didEnterRegion`を受信 | `enter`トリガーとして処理候補にする |
| 取りこぼし回復 | `didDetermineState(.inside)`で前回状態が`outside` | `enter`トリガーを補完して処理候補にする |
| 退域イベント | `didExitRegion`、または`didDetermineState(.outside)`で前回状態が`inside` | `exit`トリガーとして処理候補にする |
| 重複抑制 | 同じ`placeId`かつ同じ`triggerType`の通知ログが120秒以内にある | 通知しない |
| ルール一致 | 有効ルール、有効コース、場所カテゴリ、トリガー、時間帯、曜日がすべて一致 | コース名をタイトルにして通知する |
| フォールバック | `enter`だが一致するルールがない、ただしその場所カテゴリを対象にする有効コースが1つ以上ある | `Spotus`タイトルで共通メッセージを通知する |
| 通知なし | 場所が無効、監視外、`exit`で一致ルールなし、対象カテゴリの有効コースがない | 通知しない |

## 8. ルール選択マトリクス

`RuleEngine.bestMatch(...)`は、次の条件をすべて満たしたルール候補だけを残し、その中で「より具体的なルール」を優先します。

| 判定軸 | 一致条件 | 例 |
| --- | --- | --- |
| コースON/OFF | `HabitCourse.isEnabled == true` | ジム継続コースがOFFなら、そのルールは使わない |
| ルールON/OFF | `HabitRule.isEnabled == true` | 無効化したルールは使わない |
| 場所カテゴリ | `rule.placeCategory == place.category` | 駅ルールは駅にだけ適用 |
| トリガー | `rule.triggerType == enter/exit` | 到着通知は`enter`ルールのみ対象 |
| 時間帯 | `rule.timeBlock.matches(date:)` | 朝/昼/夜/深夜/いつでも |
| 曜日 | `rule.weekdayType.matches(date:)` | 平日/休日/毎日 |
| コース対象カテゴリ | `course.targetCategories.contains(place.category)` | 読書習慣コースは駅・図書館・自宅に適用 |

具体性の優先順位は次の通りです。

| ルールの具体性 | 優先度 |
| --- | --- |
| 時間帯あり + 曜日あり | 最優先 |
| 時間帯あり + 曜日なし | 次点 |
| 時間帯なし + 曜日あり | その次 |
| 時間帯なし + 曜日なし | 最後 |

そのため、同じ場所カテゴリとトリガーに複数ルールがあっても、`夜 x 平日`のような具体ルールが`いつでも x 毎日`より優先されます。

## 9. didEnterRegionから通知まで

```swift
func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    handle(region: region, triggerType: .enter)
}
```

実際の流れは次の通りです。

1. `region.identifier`から`Place.id`を復元する。
2. `RuleEngine.bestMatch(...)`で有効コースとルールを照合する。
3. 一致ルールがあればその文言を使う。
4. 一致しなくても、`enter`かつ対象カテゴリの有効コースがあれば共通メッセージへフォールバックする。
5. 直近120秒以内の同一通知なら落とす。
6. `TriggerLog`を保存し、同じ`logId`を通知の`userInfo`に入れてローカル通知を出す。

## 10. ローカル保存

`LocalStore`がApplication Support内の`Spotus`フォルダに以下を保存します。

- `places.json`
- `courses.json`
- `rules.json`
- `logs.json`
- `region_states.json`

`region_states.json`は、各監視地点が前回`inside`/`outside`のどちらだったかを保持し、`didDetermineState`で入域/退域を補完するときに使います。

## 11. 動作確認手順

1. Xcodeで`Spotus.xcodeproj`を開く。
2. Signing & Capabilitiesで自分のTeamを設定する。
3. iPhone実機、またはシミュレータで起動する。
4. Home画面で通知許可と位置情報許可を付与する。実機でバックグラウンド動作を見る場合は「常に許可」を選ぶ。
5. Place画面で駅、自宅、ジム、飲み屋街などを追加する。
6. Course画面で使いたいコースをONにする。
7. すぐ確認したい場合はPlace画面で対象地点を左からスワイプし、「テスト」を押す。
8. 実際のRegion Monitoring確認は、登録地点から十分離れた状態から半径内に入る、またはXcodeのLocation Simulationを使う。
9. 通知が出たらLog画面で発火時刻、場所、コース、メッセージ、反応を確認する。

## 12. MVP以降の拡張余地

地図UI、Apple Maps/Google Maps連携、AIメッセージ生成、通知アクション拡張、習慣達成率、危険ゾーン自動検出、コース別スコアリング、共有機能、Android版は、`Models`と`Services`を保ったまま追加しやすい構成にしています。
