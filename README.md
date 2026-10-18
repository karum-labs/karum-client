# karum-client

The **Flutter client** for [Karum](https://github.com/karum-labs/karum-infra#readme) — the tenant-mix leasing agent. Flutter **web** is the judge-facing target, and the same screens run on desktop.

Part of the five-repo Karum layout:

| Repo | Role |
| --- | --- |
| [`karum-infra`](https://github.com/karum-labs/karum-infra) | Shared protos, the laptop run path, and the demo VM |
| **`karum-client`** (this repo) | Flutter UI (web / desktop) |
| [`karum-server`](https://github.com/karum-labs/karum-server) | Go + Gin API gateway |
| [`karum-service-taste`](https://github.com/karum-labs/karum-service-taste) | Qloo integration, caching, taste scoring |
| [`karum-service-ai`](https://github.com/karum-labs/karum-service-ai) | Vertex AI, search grounding, pitch drafting |

## Run path

Requires the **Flutter SDK** (see the version pin in [`karum-infra`](https://github.com/karum-labs/karum-infra)).

The gateway base URL is supplied with `--dart-define`. On the laptop, start the stack from `karum-infra` with `make local`. That opens this app against the local gateway. To start the client on its own once the gateway is already up:

```bash
flutter run -d chrome --dart-define=GATEWAY_URL=http://127.0.0.1:8080
```

If `GATEWAY_URL` is omitted, the app defaults to `http://localhost:8080`.

The hosted demo is https://karum-512016.web.app. `make demo-refresh` in `karum-infra` builds this repo with `GATEWAY_URL=https://35.244.55.185.sslip.io` and deploys `build/web` to that Firebase Hosting site.

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

## Ownership

Karum is a two-person build (record: [`DECISIONS.md`](https://github.com/karum-labs/karum-infra/blob/main/DECISIONS.md)). **Side A** owns taste, score, agent, and eval; **side B** owns UI, map, drafts, deploy, and Devpost. This repo is **side B** — UI, map, and the deliverable actions. It renders the server's rank and reason codes as-is: no client-side re-sorting, no re-derived scores.

## Licence

MIT. See [`LICENSE`](LICENSE).
