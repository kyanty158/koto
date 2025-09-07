KOTO 広告（AdMob）導入メモ

概要
- Freeでは広告表示、Pro（買い切り）で広告非表示。
- google_mobile_ads を使用。現状はバナーを View 画面の下部に1枚表示。

実装ファイル
- 依存: `pubspec.yaml` → `google_mobile_ads`
- 初期化: `lib/services/ads_service.dart`（MobileAds.initialize / テストID）
- バナーUI: `lib/widgets/ad_banner.dart`（Free時のみロード/表示）
- 設置: `lib/views/view_view.dart`（リスト下部に表示）
- iOS設定: `ios/Runner/Info.plist` → `GADApplicationIdentifier`
- Android設定: `android/app/src/main/AndroidManifest.xml` → APPLICATION_ID meta-data

テストID（現在の設定）
- Android App ID: `ca-app-pub-3940256099942544~3347511713`
- iOS App ID: `ca-app-pub-3940256099942544~1458002511`
- Android Banner Unit: `ca-app-pub-3940256099942544/6300978111`
- iOS Banner Unit: `ca-app-pub-3940256099942544/2934735716`

本番公開前に置き換えるもの
1) App ID（Info.plist / AndroidManifest.xml）
2) 広告ユニットID（`AdsService.bannerUnitId()`）
   - 例: `koto_banner_main` などをストアで作成して差し替え

ポリシー注意
- 政策違反を避けるため、
  - クリック誘導文言（例: 「押してね」）は禁止
  - コンテンツと誤認するレイアウトを避ける
  - 子供向け対象ではないため families ポリシー非該当（該当させる場合は別途対応）

将来拡張
- Viewの途中インライン広告（ネイティブAd）やインタースティシャルはUXに配慮して検討。
- Proでは `subscriptionProvider == pro` の間は全広告非表示（現状実装済み）。

