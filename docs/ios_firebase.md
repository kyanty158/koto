KOTO iOS Firebase 設定（警告解消手順）

目的
- 起動時の FirebaseCore 警告（`Could not locate configuration file: 'GoogleService-Info.plist'`）を解消する

前提
- Firebase プロジェクトが作成済み
- iOS Bundle ID（例: `com.kantiva.koto`）が Firebase に登録済み

手順
1) Firebase コンソール → iOS アプリ設定から `GoogleService-Info.plist` をダウンロード
2) Xcode で `Runner` プロジェクトを開く
   - `ios/Runner/` フォルダへ `GoogleService-Info.plist` をコピー
   - Xcode 左ペインで Runner ターゲット内にドラッグ&ドロップ（必要なら “Copy items if needed” をオン）
3) Runner ターゲット → Build Phases → Copy Bundle Resources に `GoogleService-Info.plist` があることを確認
4) ビルド/実行

補足
- Dart 側では `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` を呼んでいるため、
  plist が無くても動作はします（ログ警告のみ）。警告を消したい場合は上記手順を適用してください。
- 別環境（Staging/Prod）を使い分ける場合は Xcode の Build Configuration かスクリプトで plist を切り替えてください。

