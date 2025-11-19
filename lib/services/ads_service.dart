import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

/// Serviço simples de anúncios com capping diário.
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  static const _kInterstitialPerDayCap = 3;
  static const _kPrefsDayKey = 'ads_day_key';
  static const _kPrefsCountKey = 'ads_day_count';

  bool _initialized = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  Future<void> init() async {
    if (_initialized) return;
    if (!Config.adsEnabled) return; // <- garante que não inicializa sem Ads
    await MobileAds.instance.initialize();
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

  Future<void> loadInterstitial({required String adUnitId}) async {
    if (!Config.adsEnabled) return;
    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (err) => _interstitial = null,
      ),
    );
  }

  Future<void> showInterstitial() async {
    if (_interstitial == null) return;
    if (!await canShowInterstitial()) return;
    await _interstitial!.show();
    await _bumpInterstitialCount();
    _interstitial = null;
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

  Future<void> showRewarded(
      {required void Function(RewardItem) onReward}) async {
    final ad = _rewarded;
    if (ad == null) return;

    await ad.show(
      onUserEarnedReward: (adWithoutView, reward) {
        onReward(reward); // aqui você chama o callback que só recebe RewardItem
      },
    );

    _rewarded = null; // opcional: descartar depois de usar
  }
}
