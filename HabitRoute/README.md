# HabitRoute MVP

HabitRouteは、時間ベースではなく「場所 x 状況 x 生活コース」を使って、その場で最適な行動を促すiOS向けMVPです。

## 1. ディレクトリ構成

```text
HabitRoute/
  HabitRoute.xcodeproj/
  HabitRoute/
    HabitRouteApp.swift
    Info.plist
    Assets.xcassets/
    Models/
    Services/
    Views/
```

## 2. Swiftファイル一覧と役割

| ファイル | 役割 |
| --- | --- |
| `HabitRouteApp.swift` | アプリのエントリーポイント。`AppState`を生成し全画面に共有する。 |
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
| `Views/HomeView.swift` | 権限状態、有効コース、登録地点、直近ログを表示。 |
| `Views/CourseListView.swift` | コース一覧とON/OFF。 |
| `Views/PlaceListView.swift` | 登録地点一覧、削除、ON/OFF、テスト通知。 |
| `Views/PlaceEditorView.swift` | 場所の新規登録/編集。 |
| `Views/RuleListView.swift` | プリセットルール一覧。 |
| `Views/LogListView.swift` | 通知ログ一覧。 |

## 3. 最小実装コードの要点

- モデルはすべて`Codable`で、JSON保存できる。
- `PresetData`に読書、ジム、節酒、早寝、浪費防止、通勤時間活用コースを定義。
- `RuleEngine.bestMatch(...)`が現在時刻の`TimeBlock`と平日/休日を判定し、最も具体的なルールを選ぶ。
- `LocationService.syncMonitoring(for:)`が有効な登録地点を最大20件まで`CLCircularRegion`として監視する。
- `LocationService.locationManager(_:didEnterRegion:)`から`AppState.handleRegionEvent(...)`に渡し、該当ルールがあれば通知とログを作る。
- `NotificationService.deliver(...)`が即時ローカル通知を出し、通知アクション「やった」やdismiss/openをログに反映する。

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

## 7. didEnterRegionから通知まで

```swift
func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    handle(region: region, triggerType: .enter)
}
```

`region.identifier`から`Place.id`を復元し、`RuleEngine.bestMatch(...)`で有効コースとルールを照合します。該当すれば`TriggerLog`を保存し、同じ`logId`を通知の`userInfo`に入れてローカル通知を出します。

## 8. ローカル保存

`LocalStore`がApplication Support内の`HabitRoute`フォルダに以下を保存します。

- `places.json`
- `courses.json`
- `rules.json`
- `logs.json`

## 9. 動作確認手順

1. Xcodeで`HabitRoute/HabitRoute.xcodeproj`を開く。
2. Signing & Capabilitiesで自分のTeamを設定する。
3. iPhone実機、またはシミュレータで起動する。
4. Home画面で通知許可と位置情報許可を付与する。実機でバックグラウンド動作を見る場合は「常に許可」を選ぶ。
5. Place画面で駅、自宅、ジム、飲み屋街などを追加する。
6. Course画面で使いたいコースをONにする。
7. すぐ確認したい場合はPlace画面で対象地点を左からスワイプし、「テスト」を押す。
8. 実際のRegion Monitoring確認は、登録地点から十分離れた状態から半径内に入る、またはXcodeのLocation Simulationを使う。
9. 通知が出たらLog画面で発火時刻、場所、コース、メッセージ、反応を確認する。

## 10. MVP以降の拡張余地

地図UI、Apple Maps/Google Maps連携、AIメッセージ生成、通知アクション拡張、習慣達成率、危険ゾーン自動検出、コース別スコアリング、共有機能、Android版は、`Models`と`Services`を保ったまま追加しやすい構成にしています。
