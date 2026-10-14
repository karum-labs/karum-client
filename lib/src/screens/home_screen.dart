import 'package:flutter/material.dart';

import '../api/gateway_client.dart';
import '../api/health_status.dart';
import '../theme/app_theme.dart';
import '../widgets/async_states.dart';

/// The judge-facing landing screen.
///
/// For this scaffold it fetches `GET /health` from the gateway and renders the
/// operational mode. It exercises the loading / empty / error state trio that
/// every Karum screen will reuse; the intake form and shortlist board land in a
/// later pass.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.client});

  /// Injectable client so widget tests can supply a fake.
  final GatewayClient? client;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final GatewayClient _client;
  late Future<HealthStatus> _health;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? GatewayClient();
    _health = _client.fetchHealth();
  }

  @override
  void dispose() {
    // Only close a client we own; an injected one belongs to the caller.
    if (widget.client == null) {
      _client.close();
    }
    super.dispose();
  }

  void _reload() {
    setState(() {
      _health = _client.fetchHealth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karum'),
        centerTitle: false,
      ),
      body: FutureBuilder<HealthStatus>(
        future: _health,
        builder: (context, snapshot) {
          // In-flight: loading state.
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingState(label: 'Contacting the gateway…');
          }

          // Failure: specific error copy with retry.
          if (snapshot.hasError) {
            final error = snapshot.error;
            return ErrorState(
              title: 'Gateway unavailable',
              message: error is GatewayException
                  ? error.message
                  : 'Something went wrong reaching the gateway.',
              onRetry: _reload,
            );
          }

          final status = snapshot.data;
          // Defensive: a completed future should carry data, but treat a
          // missing value as an empty state rather than crashing.
          if (status == null) {
            return const EmptyState(
              title: 'No status returned',
              message: 'The gateway responded without a health payload.',
            );
          }

          return _HealthView(status: status, onRefresh: _reload);
        },
      ),
    );
  }
}

/// Renders the health payload and the operational-mode banner.
class _HealthView extends StatelessWidget {
  const _HealthView({required this.status, required this.onRefresh});

  final HealthStatus status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Karum',
                style: theme.textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'A wrong tenant is a multi-year mistake.',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              _ModeBanner(mode: status.mode),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(label: 'Service', value: status.service),
                      _InfoRow(label: 'Status', value: status.status),
                      if (status.version != null)
                        _InfoRow(label: 'Version', value: status.version!),
                      if (status.uptimeSeconds != null)
                        _InfoRow(
                          label: 'Uptime',
                          value: '${status.uptimeSeconds}s',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh status'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A banner showing the operational mode, tinted so a fixture or degraded run
/// is unmissable — the same banner will sit above the live trace timeline.
class _ModeBanner extends StatelessWidget {
  const _ModeBanner({required this.mode});

  final GatewayMode mode;

  @override
  Widget build(BuildContext context) {
    final (Color color, String label, IconData icon) = switch (mode) {
      GatewayMode.live => (
          AppTheme.catchmentFit,
          'Live mode — real upstream data',
          Icons.bolt,
        ),
      GatewayMode.fixture => (
          AppTheme.coTenancy,
          'Fixture mode — replaying recorded data',
          Icons.science_outlined,
        ),
      GatewayMode.degraded => (
          AppTheme.cannibalisation,
          'Degraded — running the autopilot fallback',
          Icons.warning_amber_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple label/value row used inside the health card.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
