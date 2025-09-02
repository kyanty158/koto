KOTO Codex Guardrails (for auto-runner)

Scope
- App: Flutter (Dart 3), Riverpod, Isar, flutter_local_notifications, Firebase Core/Auth/Firestore(準備のみ)
- Platforms: iOS 15+, Android (標準サポート範囲)

Hard Rules
- Secrets: 置かない。Firebase/DSN/鍵は .env や Xcode/Gradle で注入。リポジトリへ直書き禁止。
- DB: Isar のスキーマ互換を壊さない（フィールド/Index変更時は migration ポリシーをPRで明示）。
- Time: すべて UTC 保存・ローカル表示。`DateTime.now().toUtc()` を保存、一貫性を守る。
- Offline-first: Isar を SSOT。クラウド同期（Firestore）はPro機能、無効時もアプリが完全動作。
- Notifications: ローカル通知のみ。送受信は UI と DB の状態同期を担保。iOS/Androidの差異に注意。
- Gestures (Write): 左=破棄 / 右=リマインド / 下=保存 の3方向を必ず維持。誤作動閾値は軽めだが意図誤認は防ぐ。
- Basic/Pro: Basicの月5回制限（リマインダー）、Viewの50件制限/検索非表示を維持。
- Layout: 親 `Scaffold(resizeToAvoidBottomInset: true)` を前提。子での手動リフトは原則禁止。
- Performance: KPI（起動→入力可能）を退行させない。重い初期化はPostFrameに遅延。
- CI Green: `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` をGreenに。

Style & Quality
- Lints: 既存の flutter_lints を遵守。未使用 import/メソッドは削除する。
- Naming: 予約語や1文字変数は避け、UI/動作の意図が分かる命名。
- Files: 小さく保つ。複雑化し始めたら分割（views/widgets/services 層）。
- Comments: ビジネスロジックやハックにだけ要点コメント。冗長な説明は禁止。

Dependencies
- pubspec: バージョンは caret だが主要メジャーは保守的に。大規模アップグレードは別PRで。
- iOS Pod: 15.0 以上。Pod由来の警告は post_install で統一してよいが破壊的変更は不可。

Testing
- Unit: タグ抽出、月次カウント、リマインド時刻生成（今夜/明日朝）。
- Widget: 右レールのヒット判定、高速ドロップ、Undo、キーボード上にカードが見えること。
- Integration: 通知アクション（完了/スヌーズ/編集）→DB反映。

PR & Commit
- 小さく・意味のある単位で。メイン動作を壊す変更とUI微調整は分ける。
- 変更方針→差分→検証手順をPR本文に必ず記載。

