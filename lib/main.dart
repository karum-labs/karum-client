import 'package:flutter/material.dart';

import 'src/screens/home_screen.dart';
import 'src/theme/app_theme.dart';

/// Karum client entrypoint.
///
/// The app targets Flutter web for judging and keeps the same screens on
/// desktop. The gateway base URL comes from `--dart-define=GATEWAY_URL=...` —
/// see [AppConfig] — so switching between local Compose and production is a
/// build flag, not a code change.
void main() {
  runApp(const KarumApp());
}

/// Root widget: applies the shared theme and shows the home screen.
class KarumApp extends StatelessWidget {
  const KarumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Karum',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeScreen(),
    );
  }
}
