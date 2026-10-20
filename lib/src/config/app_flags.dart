/// Compile-time product flags. Override with `--dart-define=NAME=true|false`.
class AppFlags {
  AppFlags._();

  static const _judgesBannerRaw = String.fromEnvironment('SHOW_JUDGES_BANNER');

  /// Hackathon judges banner on the login screen.
  ///
  /// Default: on in debug and profile, off in release. Set
  /// `--dart-define=SHOW_JUDGES_BANNER=true` to force it on in a release
  /// demo build, or `false` to hide it while developing.
  ///
  /// The one-tap demo still needs the gateway's `HACKATHON_MODE=true`.
  /// This flag only decides whether the banner is drawn.
  static bool get showJudgesBanner {
    if (_judgesBannerRaw == 'true') return true;
    if (_judgesBannerRaw == 'false') return false;
    return !const bool.fromEnvironment('dart.vm.product');
  }
}
