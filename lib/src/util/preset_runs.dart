/// Remembers the run an anonymous visitor last opened for each preset, so
/// reopening the preset shows that run instead of starting a new one.
///
/// The gateway only replays a stored run to the account that owns it
/// (PLAN.md §49); an anonymous visitor has no account, so the browser keeps
/// the job id. Web uses `localStorage`; other builds keep it in memory.
library;

export 'preset_runs_stub.dart'
    if (dart.library.js_interop) 'preset_runs_web.dart';
