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
| `Models/TriggerLog.swift` | 通知発火履歴、一歩ガイド、ユーザー反応。 |
| `Services/PresetData.swift` | MVP用のプリセットコースとプリセットルール。 |
| `Services/LocalStore.swift` | Application Support配下へのJSON保存/読み込み。 |
| `Services/RuleEngine.swift` | 場所、トリガー、時刻、コースON/OFFから通知ルールを選ぶ。 |
| `Services/NotificationService.swift` | `UNUserNotificationCenter`の許可取得、ローカル通知、通知アクション処理。 |
| `Services/LocationService.swift` | `CLLocationManager`の許可取得、現在地取得、Region Monitoring、`didEnterRegion`/`didExitRegion`。 |
| `Services/AppState.swift` | 画面、保存、通知、位置情報サービスをつなぐアプリ状態。 |
| `Views/RootTabView.swift` | Home/一歩/Course/Place/Ruleのタブ。 |
| `Views/HomeView.swift` | 地図、有効コース、権限状態を表示。 |
| `Views/CourseListView.swift` | コース一覧とON/OFF。 |
| `Views/PlaceListView.swift` | 登録地点一覧、削除、ON/OFF、テスト通知。 |
| `Views/PlaceEditorView.swift` | 場所の新規登録/編集。 |
| `Views/RuleListView.swift` | ルール一覧と通知文編集。 |
| `Views/LogListView.swift` | 通知から開く「一歩」画面。一歩ガイド、完了操作、履歴一覧。 |

## 3. 最小実装コードの要点

- モデルはすべて`Codable`で、JSON保存できる。
- `PresetData`に読書、ジム、節酒、早寝、浪費防止、通勤時間活用コースを定義。
- `RuleEngine.bestMatch(...)`が現在時刻の`TimeBlock`と平日/休日を判定し、最も具体的なルールを選ぶ。
- `LocationService.syncMonitoring(for:)`が有効な登録地点を最大20件まで`CLCircularRegion`として監視する。
- `LocationService`は`didEnterRegion`に加えて`didDetermineState`でも監視状態を再確認し、入域イベントの取りこぼし回復を行う。
- `AppState.handleRegionEvent(...)`がルール照合、フォールバック通知、重複抑制、ログ保存をまとめて行う。
- `NotificationService.deliver(...)`が即時ローカル通知を出し、通知タップ時は「一歩」画面へ進み、通知アクション「地図で見る」やdismiss/openを履歴に反映する。

## 4. 権限実装

`Info.plist`に以下の位置情報利用目的を入れています。

- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`

通知許可は`NotificationService.requestAuthorization()`で`.alert`, `.sound`, `.badge`を要求します。

位置情報は、まず`LocationService.requestWhenInUseAuthorization()`で前景利用を案内し、その後`LocationService.requestAlwaysAuthorization()`でバックグラウンド通知に必要な「常に許可」へ進める構成にしています。

起動直後にいきなり権限ダイアログは出さず、Home画面の権限カードで以下を先に説明します。

1. 位置情報は登録地点への到着判定に使う
2. 「常に許可」でSpotusを閉じていても到着通知を出せる
3. 通知はサーバー送信ではなく端末内のローカル通知として表示する

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
6. `TriggerLog`を保存し、同じ`logId`と一歩ガイドを通知の`userInfo`と履歴に関連付けてローカル通知を出す。

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
4. Home画面の権限カードを読み、まず位置情報を許可する。
5. バックグラウンド動作を見る場合は、続けて位置情報を「常に許可」にする。
6. 通知を許可する。
7. Place画面で駅、自宅、ジム、飲み屋街などを追加する。
8. Course画面で使いたいコースをONにする。
9. すぐ確認したい場合はPlace画面で対象地点を左からスワイプし、「テスト」を押す。
10. 実際のRegion Monitoring確認は、登録地点から十分離れた状態から半径内に入る、またはXcodeのLocation Simulationを使う。
11. 通知をタップするとHomeではなく「一歩」画面が開き、やること / 控えること / 完了操作を確認できる。
12. 完了後は「一歩」画面で発火時刻、場所、コース、メッセージ、反応を履歴として確認する。

## 12. App Store提出前の補強点

- Home画面に、権限ダイアログの前に目的を説明する権限カードを配置。
- Home画面左上の「情報」から、権限の使い方、プライバシー、サポート案内を確認可能。
- Place画面の「テスト」で、実際の移動を待たずに通知経路を確認可能。
- 通知タイトルは絵文字付きの`「場所名で次の一歩」`形式にし、見つけやすさを強める。
- App Store ConnectのReview Notesには、`Place`画面で地点を左スワイプして`テスト`を押すと通知確認できる旨を記載する前提。

## 13. MVP以降の拡張余地

地図UI、Apple Maps/Google Maps連携、AIメッセージ生成、通知アクション拡張、習慣達成率、危険ゾーン自動検出、コース別スコアリング、共有機能、Android版は、`Models`と`Services`を保ったまま追加しやすい構成にしています。
