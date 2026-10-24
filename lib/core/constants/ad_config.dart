/// Advertising settings.
///
/// By default Google's TEST ad units are used (they show "Test Ad" and earn
/// nothing). The real ids are supplied by the build (see build-apk.yml):
///   secrets ADMOB_APP_ID and ADMOB_BANNER_ID.
class AdConfig {
  /// Master switch.
  static const bool enabled = true;

  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _banner = String.fromEnvironment('ADMOB_BANNER_ID');

  static String get bannerUnitId => _banner.isEmpty ? _testBanner : _banner;

  /// Tabs that may show a banner. The Quran, Azkar and tasbeeh tabs never
  /// show ads out of respect for their content.
  static const Set<int> tabsWithAds = {0, 1, 4};
}
