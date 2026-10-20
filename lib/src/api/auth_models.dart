/// Account and session models returned by the gateway auth endpoints.
library;

/// One first-party account.
class AuthAccount {
  const AuthAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.isJudge,
  });

  final String id;
  final String email;
  final String displayName;
  final bool isJudge;

  /// Builds an account from a decoded `account` object.
  factory AuthAccount.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    if (id is! String || email is! String) {
      throw const FormatException('account payload missing id or email');
    }
    return AuthAccount(
      id: id,
      email: email,
      displayName: (json['display_name'] ?? '').toString(),
      isJudge: json['is_judge'] == true,
    );
  }
}

/// One successful sign-in: the opaque bearer token and its account.
class AuthSession {
  const AuthSession({
    required this.token,
    required this.account,
    this.expiresAt,
  });

  final String token;
  final AuthAccount account;
  final DateTime? expiresAt;

  /// Builds a session from login, judge sign-in, or registration.
  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('session payload missing token');
    }
    final rawAccount = json['account'];
    if (rawAccount is! Map) {
      throw const FormatException('session payload missing account');
    }
    return AuthSession(
      token: token,
      account: AuthAccount.fromJson(
        rawAccount.map((key, value) => MapEntry(key.toString(), value)),
      ),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
    );
  }
}
