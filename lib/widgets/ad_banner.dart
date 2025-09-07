import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:koto/services/ads_service.dart';
import 'package:koto/services/subscription_service.dart';

class AdBanner extends ConsumerStatefulWidget {
  const AdBanner({super.key});
  @override
  ConsumerState<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends ConsumerState<AdBanner> {
  BannerAd? _banner;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    // Initial load will be triggered from build via a post-frame callback
  }

  void _loadBanner() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    await ref.read(adsServiceProvider).initialize();
    if (_banner != null) return; // already loading/loaded
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: AdsService.bannerUnitId(),
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _banner = null;
            _isLoaded = false;
          });
        },
      ),
    );
    setState(() => _banner = ad);
    await ad.load();
  }

  void _disposeBanner() {
    _banner?.dispose();
    _banner = null;
    _isLoaded = false;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return const SizedBox.shrink();
    final tier = ref.watch(subscriptionProvider);
    if (tier == SubscriptionTier.pro) {
      // Ensure ad is disposed when upgrading to Pro
      if (_banner != null) _disposeBanner();
      return const SizedBox.shrink();
    }
    // Schedule load after build to avoid dependency issues
    if (_banner == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _banner == null) {
          _loadBanner();
        }
      });
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _isLoaded && _banner != null
          ? SizedBox(
              key: const ValueKey('ad'),
              width: _banner!.size.width.toDouble(),
              height: _banner!.size.height.toDouble(),
              child: AdWidget(ad: _banner!),
            )
          : const SizedBox(height: 0),
    );
  }
}
