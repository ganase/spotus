# lifeloop MVP

lifeloopは、Place、Act、Course内Stepを組み合わせ、登録地点に着いたときに必要な行動だけを通知するiOS向けMVPです。

## 1. ディレクトリ構成

```text
lifeloop/
  lifeloop.xcodeproj/
  LifeloopApp.swift
  Info.plist
  Assets.xcassets/
  Models/
  Services/
  Views/
```

## 2. Swiftファイル一覧と役割

| ファイル | 役割 |
| --- | --- |
| `LifeloopApp.swift` | アプリのエントリーポイント。`AppState`を生成し全画面に共有する。 |
| `Models/Place.swift` | 登録地点と場所カテゴリ。 |
| `Models/HabitCourse.swift` | Course名、ON/OFF、曜日、時間帯、表示用の対象カテゴリを保持する。 |
| `Models/HabitRule.swift` | Course内Step。PlaceまたはPlaceカテゴリ、時間帯、平日/休日、Actの対応を保持する。 |
| `Models/TriggerLog.swift` | 通知発火履歴、Log上のAct、ユーザー反応、スヌーズ時刻。 |
| `Services/PresetData.swift` | MVP用のTo do listプリセットとAct。 |
| `Services/LocalStore.swift` | Application Support配下へのJSON保存/読み込み。 |
| `Services/RuleEngine.swift` | 場所、トリガー、時刻、Course条件から通知対象のStepを抽出する。 |
| `Services/NotificationService.swift` | `UNUserNotificationCenter`の許可取得、ローカル通知、通知アクション処理。 |
| `Services/LocationService.swift` | `CLLocationManager`の許可取得、現在地取得、Region Monitoring、`didEnterRegion`/`didExitRegion`。 |
| `Services/AppState.swift` | 画面、保存、通知、位置情報サービスをつなぐアプリ状態。 |
| `Views/RootTabView.swift` | Home/Place/Act/Steps/Logのタブ。 |
| `Views/HomeView.swift` | 日次グラフ、地図、Courseを表示。 |
| `Views/CourseListView.swift` | コース一覧、作成、ON/OFF、曜日、時間帯、Course内Stepの設定。 |
| `Views/PlaceListView.swift` | 登録地点一覧、削除、ON/OFF、テスト通知。 |
| `Views/PlaceEditorView.swift` | 場所の新規登録/編集。 |
| `Views/ActListView.swift` | Act一覧、追加、編集、削除。 |
| `Views/LogListView.swift` | Steps登録画面、通知から開くLog画面、日次グラフ部品、共通編集ボタン。Stepsは場所ごと/Actごとの表示に対応し、Logでは実施/非実施、再編集、スヌーズを扱う。 |

## 3. 最小実装コードの要点

- モデルはすべて`Codable`で、JSON保存できる。
- `PresetData`にTo do listコースだけを定義。
- `RuleEngine.matchingRules(...)`が現在時刻の`TimeBlock`と平日/休日を判定し、通知対象になるStepを抽出する。
- `LocationService.syncMonitoring(for:)`が有効な登録地点を最大20件まで`CLCircularRegion`として監視する。
- `LocationService`は`didEnterRegion`に加えて`didDetermineState`でも監視状態を再確認し、入域イベントの取りこぼし回復を行う。
- `AppState.handleRegionEvent(...)`が登録済みStepの照合、重複抑制、Log保存をまとめて行う。Courseに登録されていないStepは通知しない。
- `NotificationService.deliver(...)`が即時またはスヌーズ指定時刻のローカル通知を出し、通知タップ時はLog画面へ進み、実施/非実施、通知アクション「地図で見る」やdismiss/openを履歴に反映する。

## 4. 権限実装

`Info.plist`に以下の位置情報利用目的を入れています。

- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`

通知許可は`NotificationService.requestAuthorization()`で`.alert`, `.sound`, `.badge`を要求します。

位置情報は、まず`LocationService.requestWhenInUseAuthorization()`で前景利用を案内し、その後`LocationService.requestAlwaysAuthorization()`でバックグラウンド通知に必要な「常に許可」へ進める構成にしています。

起動直後にいきなり権限ダイアログは出さず、Home画面の権限カードで以下を先に説明します。

1. 位置情報は登録地点への到着判定に使う
2. 「常に許可」でlifeloopを閉じていても到着通知を出せる
3. 通知はサーバー送信ではなく端末内のローカル通知として表示する

## 5. Place / Act / Steps / Course

画面上の基本構成は以下です。

- `Place`: 場所だけを登録、編集、ON/OFF、テスト通知する。
- `Act`: 行動だけを追加、編集、削除する。
- `Steps`: `Place + Act`を組み合わせた登録単位。場所ごと/Actごとに表示し、追加、編集、削除ができる。
- `Log`: 通知から開く記録画面。ヘッダー帯でCourse、Step、Place、Actを明示し、Actごとに実施/非実施を反応する。反応済みはグレーアウトする。再編集と時刻指定スヌーズに対応する。
- `Course`: Home画面から設定する。平日/土日/全日、朝/昼/夜/深夜/いつでも、Course内Stepを調整する。Step追加はSteps登録にも反映される。
- `Course内Step`: `Place + 複数Act`の組み合わせ。例: `自宅 + クレアチンを飲む + シダキュア`、`レストラン + 入らずに通過する`。

## 6. Region Monitoring

`LocationService`は有効な`Place`を`CLCircularRegion`に変換します。

- `identifier`: `Place.id.uuidString`
- `center`: 緯度/経度
- `radius`: 最小50m、端末の`maximumRegionMonitoringDistance`以内
- `notifyOnEntry`: `true`
- `notifyOnExit`: `true`

MVPではenterを主に使いますが、exitもモデルとサービスで受け取れる状態にしています。

## 7. 通知ロジックの判定表

通知は、単に「スポットに着いたか」だけではなく、監視状態、重複、CourseのON/OFF、時間帯、Course内Stepまで含めて判定します。

| 段階 | 条件 | 結果 |
| --- | --- | --- |
| 監視登録 | 位置情報許可が`authorizedAlways`、かつ`Place.isEnabled == true` | 有効な先頭20地点をRegion Monitoringへ登録 |
| 入域イベント | `didEnterRegion`を受信 | `enter`トリガーとして処理候補にする |
| 取りこぼし回復 | `didDetermineState(.inside)`で前回状態が`outside` | `enter`トリガーを補完して処理候補にする |
| 退域イベント | `didExitRegion`、または`didDetermineState(.outside)`で前回状態が`inside` | `exit`トリガーとして処理候補にする |
| 重複抑制 | 同じ`placeId`かつ同じ`triggerType`の通知ログが120秒以内にある | 通知しない |
| Step一致 | 有効Step、有効Course、StepのPlace、トリガー、時間帯、曜日がすべて一致 | 同じPlaceで一致したStepのActをまとめて1件の通知にする |
| 通知なし | Placeが無効、監視外、または一致する登録済みStepがない | 通知しない |

## 8. Step選択マトリクス

`RuleEngine.matchingRules(...)`は、次の条件をすべて満たしたStep候補を通知対象として残します。

| 判定軸 | 一致条件 | 例 |
| --- | --- | --- |
| コースON/OFF | `HabitCourse.isEnabled == true` | To do listがOFFなら、そのActは使わない |
| Step ON/OFF | `HabitRule.isEnabled == true` | 無効化したStepは使わない |
| StepのPlace | `rule.placeId == place.id`、または旧データでは`rule.placeCategory == place.category` | 自宅Stepは自宅だけで通知する |
| トリガー | `rule.triggerType == enter/exit` | 到着通知は`enter`のStepのみ対象 |
| 時間帯 | `rule.timeBlock.matches(date:)` | 朝/昼/夜/深夜/いつでも |
| 曜日 | `rule.weekdayType.matches(date:)` | 平日/休日/毎日 |
| コース時間帯 | `course.timeBlock.matches(date:)` | 夜だけONにしたコースは昼に通知しない |
| コース曜日 | `course.weekdayType.matches(date:)` | 平日だけONにしたコースは土日に通知しない |

通知内の表示順は、次の具体性が高いStepを先にします。

| Stepの具体性 | 優先度 |
| --- | --- |
| 登録Place指定あり | 最優先 |
| 時間帯あり + 曜日あり | 次点 |
| 時間帯あり + 曜日なし | その次 |
| 時間帯なし + 曜日あり | その次 |
| 時間帯なし + 曜日なし | 最後 |

同じPlaceに複数Stepがある場合、以前のように1件だけ選ばず、該当するActをまとめて通知します。

## 9. didEnterRegionから通知まで

```swift
func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    handle(region: region, triggerType: .enter)
}
```

実際の流れは次の通りです。

1. `region.identifier`から`Place.id`を復元する。
2. `RuleEngine.matchingRules(...)`で有効CourseとCourse内Stepを照合する。
3. 一致Stepがあれば、それらのStepのActを重複排除してまとめる。
4. 一致Stepがなければ通知しない。
5. 直近120秒以内の同一通知なら落とす。
6. `TriggerLog`を保存し、同じ`logId`とAct一覧を通知の`userInfo`と履歴に関連付けてローカル通知を出す。

## 10. ローカル保存

`LocalStore`がApplication Support内の`lifeloop`フォルダに以下を保存します。

- `places.json`
- `courses.json`
- `rules.json`
- `acts.json`
- `logs.json`
- `region_states.json`

`region_states.json`は、各監視地点が前回`inside`/`outside`のどちらだったかを保持し、`didDetermineState`で入域/退域を補完するときに使います。

## 11. 動作確認手順

1. Xcodeで`lifeloop.xcodeproj`を開く。
2. Signing & Capabilitiesで自分のTeamを設定する。
3. iPhone実機、またはシミュレータで起動する。
4. Home画面の権限カードを読み、まず位置情報を許可する。
5. バックグラウンド動作を見る場合は、続けて位置情報を「常に許可」にする。
6. 通知を許可する。
7. Place画面で駅、自宅、ジム、飲み屋街などを追加する。
8. Act画面で行動を確認し、必要なら追加・編集する。
9. Home画面のCourseから、コースのON/OFF、曜日、時間帯、Course内Stepを確認する。
10. Steps画面で、`Place + Act`の組み合わせを作る。
11. すぐ確認したい場合はPlace画面で対象地点を左からスワイプし、「テスト」を押す。
12. 実際のRegion Monitoring確認は、登録地点から十分離れた状態から半径内に入る、またはXcodeのLocation Simulationを使う。
13. 通知をタップするとHomeではなくLog画面が開き、ヘッダー帯でCourse、Step、Place、Actを確認できる。
14. 各Actは左側のサムズダウンで非実施、右側のサムズアップで実施にできる。
15. すべてのActが完了すると、そのLogは反応済みとして記録される。

## 12. App Store提出前の補強点

- Home画面に、権限ダイアログの前に目的を説明する権限カードを配置。
- Home画面左上の「情報」から、権限の使い方、プライバシー、サポート案内を確認可能。
- Place画面の「テスト」で、実際の移動を待たずに通知経路を確認可能。
- 通知タイトルは黒猫アイコン付きの`「🐈‍⬛ 場所名」`形式にし、本文は到着フレーズではなく、やることをそのまま出す。
- App Store ConnectのReview Notesには、`Place`画面で地点を左スワイプして`テスト`を押すと通知確認できる旨を記載する前提。

## 13. MVP以降の拡張余地

地図UI、Apple Maps/Google Maps連携、AIメッセージ生成、通知アクション拡張、習慣達成率、危険ゾーン自動検出、コース別スコアリング、共有機能、Android版は、`Models`と`Services`を保ったまま追加しやすい構成にしています。
