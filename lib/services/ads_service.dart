import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:koto/services/subscription_service.dart';

final adsInitializedProvider = StateProvider<bool>((_) => false);

class AdsService {
  AdsService(this._ref);
  final Ref _ref;

  Future<void> initialize() async {
    if (_ref.read(adsInitializedProvider)) return;
    if (kIsWeb) return; // Ads not supported on web in this app
    await MobileAds.instance.initialize();
    _ref.read(adsInitializedProvider.notifier).state = true;
  }

  static String bannerUnitId() {
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/6300978111'; // Android test until prod ID provided
    if (Platform.isIOS) return 'ca-app-pub-8080791667786913/9737143110'; // iOS prod
    return '';
  }
}

final adsServiceProvider = Provider<AdsService>((ref) => AdsService(ref));
