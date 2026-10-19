import 'package:flutter/material.dart';

import '../theme/brand_tokens.dart';
import '../widgets/karum_chrome.dart';
import '../widgets/karum_logo.dart';

/// The conditional judge entry.
///
/// The gateway has no auth or session endpoint in this build. When the client
/// hackathon flag is on, this page is a single, credential-free entry point to
/// the demo; when it is off, the route explains that judge entry is disabled.
/// It is never inserted into the preset → campaign path.
class JudgeEntryScreen extends StatelessWidget {
  const JudgeEntryScreen({super.key, required this.hackathonMode});

  /// Mirrors the client `HACKATHON_MODE` dart-define.
  final bool hackathonMode;

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    return Scaffold(
      body: Column(
        children: [
          const KarumHeader(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(KarumSpacing.page),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const KarumLogo(height: 34),
                          const SizedBox(height: KarumSpacing.xl),
                          if (hackathonMode)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: palette.brand.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  KarumRadius.pill,
                                ),
                              ),
                              child: Text(
                                'HACKATHON BUILD · NO CREDENTIALS',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: palette.brand,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                              ),
                            ),
                          const SizedBox(height: KarumSpacing.lg),
                          Text(
                            hackathonMode
                                ? 'Enter the demo workspace.'
                                : 'Judge entry is disabled in this build.',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: KarumSpacing.sm),
                          Text(
                            hackathonMode
                                ? 'The gateway in this build has no account or '
                                      'session endpoint. This entry opens the '
                                      'public demo without collecting an email '
                                      'or password. Campaigns are restored from '
                                      'their job and campaign ids.'
                                : 'The client was built without '
                                      'HACKATHON_MODE=true. The seed builder and '
                                      'campaign routes are still public, so the '
                                      'demo path never becomes a login wall.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: palette.mute),
                          ),
                          const SizedBox(height: KarumSpacing.xl),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => Navigator.of(
                                context,
                              ).pushNamedAndRemoveUntil('/', (route) => false),
                              icon: Icon(
                                hackathonMode
                                    ? Icons.arrow_forward_rounded
                                    : Icons.home_outlined,
                                size: 18,
                              ),
                              label: Text(
                                hackathonMode
                                    ? 'Open the demo'
                                    : 'Back to the seed builder',
                              ),
                            ),
                          ),
                          const SizedBox(height: KarumSpacing.md),
                          Text(
                            'No credentials are stored, checked, or sent by '
                            'this screen.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: palette.mute),
                          ),
                        ],
                      ),
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
