# karum-client

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/brand/social/readme-banner-1600x400-dark.png">
  <img alt="Karum" src="assets/brand/social/readme-banner-1600x400.png">
</picture>

The **Flutter client** for [Karum](https://github.com/karum-labs/karum-infra#readme) — the brand-operated expansion agent. Flutter **web** is the judge-facing target, and the same screens run on desktop.

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

The login screen's hackathon banner follows `SHOW_JUDGES_BANNER`. It is on in debug and profile, and off in a release build, unless you pass `--dart-define=SHOW_JUDGES_BANNER=true` or `false`. The banner's **Open demo** button needs the gateway running with `HACKATHON_MODE=true`.

**Previewing `build/web` without the stack:** the landing screen fetches `GET /health` on load, so served from a plain static file server there is no gateway behind it and `/health` answers 404 — the screen shows its gateway-unavailable state, which is expected rather than a bug. To preview the happy path, run `make local` in `karum-infra`, or serve `build/web` from something that answers `/health` with the mode you want to see.

The hosted demo is https://karum-512016.web.app. `make demo-refresh` in `karum-infra` builds this repo with `GATEWAY_URL=https://35.244.55.185.sslip.io` and deploys `build/web` to that Firebase Hosting site.

## What's in the app

The repo is the full judge journey, not a scaffold. Screen by screen:

- **Seed builder** (`landing_screen.dart`) — the three locked presets and free
  entry: brand seed, city, mode, radius, category tags, and SKUs. Ambiguous
  cities ask for a point instead of guessing, and a seed is confirmed against
  resolved entity ids before `POST /api/v1/scout`.
- **Live trace** (`workspace_screen.dart`) — Server-Sent Events stages as the
  pipeline runs, with a polling fallback when the stream drops.
- **Map** (`widgets/map_panel.dart`) — door pins, skip pins, and locality
  polygons from the same Qloo payload the board shows.
- **Door board** (`widgets/door_board.dart`) — the ranked doors, the skip list
  with the gateway's reason codes and reason detail, and the LLM-only baseline
  for comparison. The evidence drawer (`widgets/evidence_sheet.dart`) opens
  every score's inputs and cites the Qloo calls behind them.
- **Pitch** (`door_pitch_screen.dart`) — the shopkeeper script, battlecard,
  recommended SKU, and the mode-specific paragraph, plus the run-sheet and
  site-brief actions.
- **Provenance everywhere** — each number carries a source badge (Qloo fact,
  Google fact, model inference, ungrounded LLM), and the client renders the
  gateway's rank and reasons as-is: no client-side re-sorting, no re-derived
  scores.

It also carries the brand foundation (`lib/src/theme/brand_tokens.dart` and
`app_theme.dart`, from the official guide — see [BRAND.md](BRAND.md)), the
judge sign-in flow, and the documented keyboard path and contrast table in
[ACCESSIBILITY.md](ACCESSIBILITY.md).

## Health & mode banner

`GET /health` from the gateway reports the operational mode. The client renders it as a banner:

- **Live** — real upstream data
- **Fixture** — replaying recorded data
- **Degraded** — running the autopilot fallback

The banner colours are implementation-defined: live takes the brand teal, fixture the Investigate amber, and degraded the Avoid red — the lanes the guide already uses for caution and for a stated problem (see [BRAND.md](BRAND.md)).

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
