final Map<String, String> _runs = {};

/// The job id last opened for [presetId], or null.
String? readPresetRun(String presetId) => _runs[presetId];

/// Remembers [jobId] for [presetId]; null forgets it.
void writePresetRun(String presetId, String? jobId) {
  if (jobId == null || jobId.isEmpty) {
    _runs.remove(presetId);
  } else {
    _runs[presetId] = jobId;
  }
}
