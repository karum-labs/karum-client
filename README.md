# karum-client

The **Flutter client** for [Karum](https://github.com/kaarum/karum-infra#readme) — the tenant-mix leasing agent. Flutter **web** is the judge-facing target, and the same screens run on desktop.

Part of the five-repo Karum layout:

| Repo | Role |
| --- | --- |
| [`karum-infra`](https://github.com/kaarum/karum-infra) | Shared protos, Docker Compose, Cloud Run manifests |
| **`karum-client`** (this repo) | Flutter UI (web / desktop) |
| [`karum-server`](https://github.com/kaarum/karum-server) | Go + Gin API gateway |
| [`karum-service-taste`](https://github.com/kaarum/karum-service-taste) | Qloo integration, caching, taste scoring |
| [`karum-service-ai`](https://github.com/kaarum/karum-service-ai) | Vertex AI, search grounding, pitch drafting |

## Run path

Requires the **Flutter SDK** (see the version pin in [`karum-infra`](https://github.com/kaarum/karum-infra)).

The gateway base URL is supplied with `--dart-define`, so pointing the app at local Compose or the production host is a build flag, not a code change.

```bash
# Run in Chrome against the local Compose gateway (default).
flutter run -d chrome --dart-define=GATEWAY_URL=http://localhost:8080

# Run on Windows desktop.
flutter run -d windows --dart-define=GATEWAY_URL=http://localhost:8080

# Run against a production gateway.
flutter run -d chrome --dart-define=GATEWAY_URL=https://your-gateway.example.com
```

If `GATEWAY_URL` is omitted, the app defaults to `http://localhost:8080`.

### Build for the web

```bash
flutter build web --dart-define=GATEWAY_URL=https://your-gateway.example.com
```

The release bundle is written to `build/web/`.

## What's in the scaffold

- **`lib/src/config/app_config.dart`** — reads `GATEWAY_URL` from `--dart-define`.
- **`lib/src/theme/app_theme.dart`** — Material 3 theme: type scale, colours, cards, chips, buttons. Semantic colours for the three sub-scores (catchment fit, co-tenancy, cannibalisation).
- **`lib/src/api/gateway_client.dart`** — HTTP client for the gateway, with typed `GatewayException`s that map non-200 responses to specific copy.
- **`lib/src/api/health_status.dart`** — parsed `GET /health` model, including the `live` / `fixture` / `degraded` mode.
- **`lib/src/screens/home_screen.dart`** — landing screen wired to `/health`, with a mode banner.
- **`lib/src/widgets/async_states.dart`** — reusable loading / empty / error state widgets every screen shares.

## Health & mode banner

`GET /health` from the gateway reports the operational mode. The client renders it as a banner:

- **Live** — real upstream data
- **Fixture** — replaying recorded data
- **Degraded** — running the autopilot fallback

## Development

```bash
flutter analyze   # static analysis (flutter_lints)
flutter test      # widget tests
flutter pub get   # fetch dependencies
```

## Licence

MIT. See [`LICENSE`](LICENSE).
