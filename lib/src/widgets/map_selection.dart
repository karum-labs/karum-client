import '../api/scout_models.dart';

/// The selection id for the skipped venue at [index] in `Campaign.skipList`.
///
/// A skipped venue has no id of its own that is guaranteed unique (an
/// unresolved row can carry an empty one), and a duplicate would collide the
/// per-row scroll keys. The list position makes it unique, and the same
/// helper names a row on the board and a pin on the map, so a tap on either
/// finds the other. The map filters its skips to those with a point, so it
/// must pass the position in the full list, not in its own filtered one.
String skipSelectionId(int index, SkipItem skip) => 'skip-$index-${skip.id}';
