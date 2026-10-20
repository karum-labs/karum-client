/// Token persistence for the judge session.
///
/// Web uses `localStorage`; everything else keeps the token in memory so a
/// desktop test run never writes a credential to disk. The conditional export
/// keeps `package:web` out of non-web builds.
library;

export 'session_storage_stub.dart'
    if (dart.library.js_interop) 'session_storage_web.dart';
