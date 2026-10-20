import 'package:flutter/material.dart';

import '../theme/brand_tokens.dart';

/// The first-run coach. It explains the judge path without blocking the run;
/// the campaign streams behind the dialog.
Future<void> showCoach(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final palette = KarumPalette.of(context);
      const steps = [
        (
          'Watch the trace',
          'Nine stages stream in as the gateway resolves the seed, ranks '
              'doors, grounds menus, and drafts pitches.',
        ),
        (
          'Read the first door',
          'Scores show their source. The evidence button opens every '
              'recorded call behind the card.',
        ),
        (
          'Turn on the baseline',
          'The generic-LLM answer sits beside the Qloo board and is labelled '
              'ungrounded.',
        ),
        (
          'Download the run-sheet',
          'The PDF carries the stops, the pitches, and the citations. The '
              'Brooklyn flagship downloads a site brief instead.',
        ),
      ];
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.flag_outlined, color: palette.brand),
            const SizedBox(width: KarumSpacing.sm),
            const Expanded(child: Text('The three-minute path')),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.brand.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.brand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: KarumSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].$1,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: palette.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            steps[i].$2,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: palette.mute),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (i < steps.length - 1)
                  const SizedBox(height: KarumSpacing.lg),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      );
    },
  );
}
