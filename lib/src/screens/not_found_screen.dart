import 'package:flutter/material.dart';

import '../theme/brand_tokens.dart';
import '../widgets/karum_chrome.dart';

/// The utility route for an unknown path.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, this.path});

  /// The path that did not match a route.
  final String? path;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Scaffold(
      body: Column(
        children: [
          const KarumHeader(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(KarumSpacing.page),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.explore_off_outlined,
                        size: 44,
                        color: palette.mute,
                      ),
                      const SizedBox(height: KarumSpacing.lg),
                      Text(
                        'This door is not on the route.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: KarumSpacing.sm),
                      Text(
                        path == null || path!.isEmpty
                            ? 'The page you asked for does not exist.'
                            : 'No Karum screen matches $path.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: palette.mute),
                      ),
                      const SizedBox(height: KarumSpacing.xl),
                      FilledButton.icon(
                        onPressed: () =>
                            Navigator.of(context)
                                .pushNamedAndRemoveUntil('/', (route) => false),
                        icon: const Icon(Icons.home_outlined, size: 18),
                        label: const Text('Back to the seed builder'),
                      ),
                    ],
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
