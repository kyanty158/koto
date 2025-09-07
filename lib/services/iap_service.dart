import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koto/services/subscription_service.dart';

// Define your product identifiers in stores (create matching products later).
const Set<String> kIapProductIds = {
  // Non-consumable (lifetime unlock)
  'koto_pro_lifetime',
  // Optional subscriptions (create later if needed)
  'koto_pro_monthly',
  'koto_pro_annual',
};

class IapState {
  final bool isAvailable;
  final bool isPro;
  final bool purchasePending;
  final List<ProductDetails> products;
  final String? errorMessage;

  const IapState({
    required this.isAvailable,
    required this.isPro,
    required this.purchasePending,
    required this.products,
    this.errorMessage,
  });

  IapState copyWith({
    bool? isAvailable,
    bool? isPro,
    bool? purchasePending,
    List<ProductDetails>? products,
    String? errorMessage,
  }) => IapState(
        isAvailable: isAvailable ?? this.isAvailable,
        isPro: isPro ?? this.isPro,
        purchasePending: purchasePending ?? this.purchasePending,
        products: products ?? this.products,
        errorMessage: errorMessage,
      );

  static IapState initial() => const IapState(
        isAvailable: false,
        isPro: false,
        purchasePending: false,
        products: <ProductDetails>[],
      );
}

final iapProvider = StateNotifierProvider<IapNotifier, IapState>((ref) {
  final notifier = IapNotifier(ref);
  notifier.init();
  return notifier;
});

class IapNotifier extends StateNotifier<IapState> {
  IapNotifier(this._ref) : super(IapState.initial());

  final Ref _ref;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  Future<void> init() async {
    try {
      final isAvailable = await _iap.isAvailable();
      state = state.copyWith(isAvailable: isAvailable);
      if (!isAvailable) return;

      // Listen to purchase updates
      _purchaseSub ??= _iap.purchaseStream.listen(_onPurchases, onDone: () {
        _purchaseSub?.cancel();
      }, onError: (e) {
        state = state.copyWith(errorMessage: e.toString(), purchasePending: false);
      });

      // Load products
      final productResp = await _iap.queryProductDetails(kIapProductIds);
      if (productResp.error != null) {
        state = state.copyWith(errorMessage: productResp.error!.message);
      }
      state = state.copyWith(products: productResp.productDetails);

      // Try to restore/recognize existing entitlement on startup
      await restorePurchases(silent: true);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> buy(ProductDetails product) async {
    try {
      state = state.copyWith(purchasePending: true, errorMessage: null);
      final param = PurchaseParam(productDetails: product);
      if (product.id.contains('monthly') || product.id.contains('annual')) {
        await _iap.buyNonConsumable(purchaseParam: param); // Subscriptions are purchased via non-consumable API in plugin
      } else {
        await _iap.buyNonConsumable(purchaseParam: param);
      }
    } catch (e) {
      state = state.copyWith(purchasePending: false, errorMessage: e.toString());
    }
  }

  Future<void> restorePurchases({bool silent = false}) async {
    try {
      if (!state.isAvailable) return;
      // Note: Works for both platforms; iOS needs this for restoration UI requirement.
      await _iap.restorePurchases();
    } catch (e) {
      if (!silent) {
        state = state.copyWith(errorMessage: e.toString());
      }
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    bool becamePro = state.isPro;
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(purchasePending: true);
          break;
        case PurchaseStatus.error:
          state = state.copyWith(purchasePending: false, errorMessage: p.error?.message);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // MVP: trust the store result and unlock Pro immediately.
          becamePro = true;
          // Always complete/ack purchases to avoid refunds/chargebacks.
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          break;
        case PurchaseStatus.canceled:
          state = state.copyWith(purchasePending: false);
          break;
      }
    }

    // Update state after processing batch
    state = state.copyWith(purchasePending: false, isPro: becamePro);
    _ref.read(subscriptionProvider.notifier).state =
        becamePro ? SubscriptionTier.pro : SubscriptionTier.free;
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
