KOTO 課金（IAP）セットアップ手順

概要
- Flutter `in_app_purchase` を使用した最小実装（Pro解放）。
- まずは「買い切り(Lifetime)」で短期リリースを可能にし、将来サブスク拡張も可能な構成。

ストア製品ID
- Lifetime: `koto_pro_lifetime`（非消耗型）
- 任意（未使用でもOK）: `koto_pro_monthly` / `koto_pro_annual`

iOS（App Store Connect）
1) App → In‑App Purchases → `+` → Non‑Consumable を作成
   - Product ID: `koto_pro_lifetime`
   - Reference Name/Display Name/価格 を設定
2) App Information → In‑App Purchase を有効化
3) Xcode → Runner → Signing & Capabilities → `In‑App Purchase` を追加
4) 審査用メタデータ: アカウント・サインイン不要。アプリ内の「購入を復元」ボタンあり。

Android（Google Play Console）
1) Monetize → Products → In‑app products → `Create product`
   - Product ID: `koto_pro_lifetime`
   - Managed product（非消耗）を選択、価格を設定、アクティブ化
2) Billing ライブラリは `in_app_purchase_android` により自動導入

Flutter 実装概要
- `lib/services/iap_service.dart`: 購入/復元/状態管理（Riverpod）
- `lib/views/paywall_view.dart`: 購入UI（価格はストアから取得）
- `lib/views/view_view.dart`: Free時に「Proにする」アクションを表示
- `lib/main.dart`: 起動時に IAP を初期化＋復元
- Proの有効/無効は `subscriptionProvider`（free/pro）に反映

動作確認（Sandbox）
1) iOS: Sandbox テスターで TestFlight or Xcode 実機起動 → Paywall から購入 → 復元ボタン動作
2) Android: ライセンステスターを設定 → 内部テストトラックで購入 → 復元動作

注意点
- 本実装はクライアントのみ。サブスクの有効期限検証は行わず、購入/復元イベントで Pro を解放します。
- 将来サブスクを厳格運用する場合はサーバー検証（App Store/Play API）やレシート検証を追加してください。

