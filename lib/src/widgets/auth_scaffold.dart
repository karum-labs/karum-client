import 'package:flutter/material.dart';

import '../theme/brand_tokens.dart';
import 'karum_chrome.dart';

/// The centered card used by login and both registration screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const KarumHeader(),
          const JudgeBanner(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(KarumSpacing.page),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
