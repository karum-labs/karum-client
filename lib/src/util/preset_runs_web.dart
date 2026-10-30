import 'package:web/web.dart' as web;

String _key(String presetId) => 'karum.preset.run.$presetId';

/// The job id last opened for [presetId], or null.
String? readPresetRun(String presetId) {
  try {
    final value = web.window.localStorage.getItem(_key(presetId));
    return (value == null || value.isEmpty) ? null : value;
  } on Object {
    // Storage can be denied in private mode; the preset then starts a run.
    return null;
  }
}

/// Remembers [jobId] for [presetId]; null forgets it.
void writePresetRun(String presetId, String? jobId) {
  try {
    if (jobId == null || jobId.isEmpty) {
      web.window.localStorage.removeItem(_key(presetId));
    } else {
      web.window.localStorage.setItem(_key(presetId), jobId);
    }
  } on Object {
    // Ignore storage failures; the next open starts a run.
  }
}
