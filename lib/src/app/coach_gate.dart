/// Tracks whether the sixty-second coach has been shown in this app session.
///
/// The coach belongs on the first preset run, not on every restored campaign.
abstract final class CoachGate {
  static bool _shown = false;

  /// Returns true once; later calls return false.
  static bool consume() {
    if (_shown) return false;
    _shown = true;
    return true;
  }

  /// Test hook for a fresh app session.
  static void reset() => _shown = false;
}
