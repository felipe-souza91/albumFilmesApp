import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  static const _kInterstitialPerDayCap = kDebugMode ? 999 : 100;
  static const _kPrefsDayKey = 'ads_day_key';
  static const _kPrefsCountKey = 'ads_day_count';

  static const Duration _jsEngineCooldown = Duration(minutes: 30);

  bool _initialized = false;

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  bool _isInterstitialLoading = false;
  bool _isInterstitialShowing = false;

  Timer? _interstitialRetryTimer;
  DateTime? _lastJsEngineFailureAt;

  bool get hasInterstitialReady => _interstitial != null;

  Future<void> init() async {
    if (_initialized) return;
    if (!Config.adsEnabled) return;

    await MobileAds.instance.initialize();

    if (Config.admobTestDeviceIds.isNotEmpty) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: Config.admobTestDeviceIds),
      );
    }

    _initialized = true;
  }

  Future<bool> canShowInterstitial() async {
    if (!Config.adsEnabled) return false;

    final now = DateTime.now();
    final day = '${now.year}-${now.month}-${now.day}';
    final prefs = await SharedPreferences.getInstance();
    final savedDay = prefs.getString(_kPrefsDayKey);

    if (savedDay != day) {
      await prefs.setString(_kPrefsDayKey, day);
      await prefs.setInt(_kPrefsCountKey, 0);
      return true;
    }

    final count = prefs.getInt(_kPrefsCountKey) ?? 0;
    return count < _kInterstitialPerDayCap;
  }

  Future<void> _bumpInterstitialCount() async {
    final now = DateTime.now();
    final day = '${now.year}-${now.month}-${now.day}';
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_kPrefsCountKey) ?? 0) + 1;

    await prefs.setString(_kPrefsDayKey, day);
    await prefs.setInt(_kPrefsCountKey, count);
  }

  bool _isInJsCooldown() {
    final jsFailureAt = _lastJsEngineFailureAt;
    if (jsFailureAt == null) return false;
    return DateTime.now().difference(jsFailureAt) < _jsEngineCooldown;
  }

  void _scheduleInterstitialRetry({
    required String adUnitId,
    required int seconds,
    required int nextAttempt,
  }) {
    _interstitialRetryTimer?.cancel();
    _interstitialRetryTimer = Timer(Duration(seconds: seconds), () {
      unawaited(preloadInterstitial(adUnitId: adUnitId, attempt: nextAttempt));
    });
  }

  void _attachInterstitialCallbacks({
    required InterstitialAd ad,
    required String adUnitId,
  }) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isInterstitialShowing = true;
        debugPrint('[Ads] Interstitial exibido.');
        unawaited(_bumpInterstitialCount());
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[Ads] Interstitial fechado.');
        _isInterstitialShowing = false;
        ad.dispose();

        if (identical(_interstitial, ad)) {
          _interstitial = null;
        }

        unawaited(preloadInterstitial(adUnitId: adUnitId, force: true));
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[Ads] Falha ao exibir interstitial: $error');
        _isInterstitialShowing = false;
        ad.dispose();

        if (identical(_interstitial, ad)) {
          _interstitial = null;
        }

        unawaited(preloadInterstitial(adUnitId: adUnitId, force: true));
      },
    );
  }

  Future<void> preloadInterstitial({
    required String adUnitId,
    int attempt = 1,
    bool force = false,
  }) async {
    if (!Config.adsEnabled) return;
    if (adUnitId.isEmpty) return;
    if (_isInterstitialLoading) return;
    if (_isInterstitialShowing) return;
    if (_interstitial != null && !force) return;

    if (_isInJsCooldown()) {
      debugPrint('[Ads] Pulando preload durante cooldown de JS engine.');
      return;
    }

    _isInterstitialLoading = true;

    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial?.dispose();
          _interstitial = ad;
          _isInterstitialLoading = false;

          _attachInterstitialCallbacks(ad: ad, adUnitId: adUnitId);

          debugPrint('[Ads] Interstitial carregado (attempt=$attempt).');
        },
        onAdFailedToLoad: (err) {
          _isInterstitialLoading = false;
          _interstitial = null;

          final message = err.message.toLowerCase();
          final jsEngineFailure = message.contains('javascriptengine');
          final internalErrorCode = err.code == 0;
          final noFill = err.code == 3;
          final shouldCooldown = jsEngineFailure || internalErrorCode;

          if (shouldCooldown) {
            _lastJsEngineFailureAt = DateTime.now();
          }

          debugPrint(
            '[Ads] Falha ao carregar interstitial '
            '(code=${err.code}, message=${err.message}, attempt=$attempt, '
            'jsEngineFailure=$jsEngineFailure, internalErrorCode=$internalErrorCode, '
            'noFill=$noFill).',
          );

          if (shouldCooldown) return;

          if (noFill && attempt < 4) {
            _scheduleInterstitialRetry(
              adUnitId: adUnitId,
              seconds: 15 * attempt,
              nextAttempt: attempt + 1,
            );
            return;
          }

          if (attempt < 2) {
            _scheduleInterstitialRetry(
              adUnitId: adUnitId,
              seconds: 2,
              nextAttempt: attempt + 1,
            );
          }
        },
      ),
    );
  }

  Future<bool> showInterstitialIfAvailable({
    required String adUnitId,
  }) async {
    if (!Config.adsEnabled) return false;

    if (!await canShowInterstitial()) {
      debugPrint('[Ads] Interstitial bloqueado pelo cap diário.');
      return false;
    }

    if (_isInterstitialShowing) {
      debugPrint('[Ads] Já existe um interstitial sendo exibido.');
      return false;
    }

    final ad = _interstitial;
    if (ad == null) {
      debugPrint('[Ads] Interstitial não estava pronto.');
      unawaited(preloadInterstitial(adUnitId: adUnitId));
      return false;
    }

    _interstitial = null;

    try {
      await ad.show();
      return true;
    } catch (e) {
      debugPrint('[Ads] Exceção ao chamar show(): $e');
      _isInterstitialShowing = false;
      ad.dispose();
      unawaited(preloadInterstitial(adUnitId: adUnitId, force: true));
      return false;
    }
  }

  void disposeInterstitial() {
    _interstitialRetryTimer?.cancel();
    _interstitial?.dispose();
    _interstitial = null;
    _isInterstitialLoading = false;
    _isInterstitialShowing = false;
  }

  Future<void> loadRewarded({required String adUnitId}) async {
    if (!Config.adsEnabled) return;

    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (err) => _rewarded = null,
      ),
    );
  }

  Future<void> showRewarded({
    required void Function(RewardItem) onReward,
  }) async {
    final ad = _rewarded;
    if (ad == null) return;

    await ad.show(
      onUserEarnedReward: (adWithoutView, reward) {
        onReward(reward);
      },
    );

    _rewarded = null;
  }
}
