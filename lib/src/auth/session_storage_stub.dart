String? _token;

/// Reads the in-memory token used by desktop and VM test builds.
String? readSessionToken() => _token;

/// Writes the in-memory token used by desktop and VM test builds.
void writeSessionToken(String? token) {
  _token = (token == null || token.isEmpty) ? null : token;
}
