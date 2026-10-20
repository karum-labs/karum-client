import 'package:web/web.dart' as web;

const _key = 'karum.session.token';

/// Reads the saved opaque session token from browser storage.
String? readSessionToken() {
  try {
    final value = web.window.localStorage.getItem(_key);
    return (value == null || value.isEmpty) ? null : value;
  } on Object {
    // Private mode or a storage policy can deny localStorage. The app still
    // works with an in-memory session for this page load.
    return null;
  }
}

/// Saves or clears the opaque session token in browser storage.
void writeSessionToken(String? token) {
  try {
    if (token == null || token.isEmpty) {
      web.window.localStorage.removeItem(_key);
    } else {
      web.window.localStorage.setItem(_key, token);
    }
  } on Object {
    // Ignore storage failures; the in-memory client token remains valid.
  }
}
