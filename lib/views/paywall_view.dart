import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:koto/services/iap_service.dart';
import 'package:koto/services/subscription_service.dart';

class PaywallView extends ConsumerWidget {
  const PaywallView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iap = ref.watch(iapProvider);
    final iapCtrl = ref.read(iapProvider.notifier);
    final tier = ref.watch(subscriptionProvider);

    final products = iap.products;
    ProductDetails? lifetime;
    if (products.isNotEmpty) {
      lifetime = products.firstWhere(
        (p) => p.id == 'koto_pro_lifetime',
        orElse: () => products.first,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('KOTO Pro')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Pro でできること', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    SizedBox(height: 12),
                    _Bullet(text: '検索（全文 / #タグ）'),
                    _Bullet(text: 'リマインダー上限なし'),
                    _Bullet(text: '将来の同期などの追加機能'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!iap.isAvailable)
              const Text('ストアへ接続できません。後でもう一度お試しください。')
            else if (tier == SubscriptionTier.pro)
              const _SuccessBanner()
            else ...[
              Text('購入', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _ProductTile(
                title: lifetime?.title ?? 'Pro Lifetime',
                subtitle: lifetime?.description ?? 'Unlock KOTO Pro',
                price: lifetime?.price ?? '購入',
                loading: iap.purchasePending,
                onPressed: lifetime != null ? () { final p = lifetime!; iapCtrl.buy(p); } : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () => iapCtrl.restorePurchases(),
                    child: const Text('購入を復元'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '再読み込み',
                    onPressed: () => iapCtrl.init(),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (iap.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(iap.errorMessage!, style: const TextStyle(color: Colors.red)),
              ]
            ],
            const Spacer(),
            const Text('注意: 実際の価格はストアに従います。サブスクリプションを導入する場合は月額/年額プランの製品IDを追加してください。',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final bool loading;
  final VoidCallback? onPressed;
  const _ProductTile({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(price.isEmpty ? '購入' : price),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Icon(Icons.verified, color: Colors.green),
          SizedBox(width: 8),
          Expanded(child: Text('Pro が有効になりました。ありがとうございます！')),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
