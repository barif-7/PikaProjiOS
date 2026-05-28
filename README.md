# PikaProjiOS

SwiftUI iOS prototype for the Pika onboarding and "future self" voice-chat experience.

## What the app does

Users take a selfie, record a voice sample, and are introduced to **SEMI** — an AI future-self persona that can converse using a voice clone. The onboarding flow is:

```
Welcome → Camera (selfie + avatar) → Voice training → Success card → Messages (voice chat with SEMI)
```

Returning users with a saved voice profile land directly in Messages.

## Quick start

**Requirements**

- macOS 15+, Xcode (latest stable)
- iOS Simulator — iPhone 15 or iPhone 16 series

**Build and run**

```bash
# Open the project
open PikaProjiOS.xcodeproj

# Or build from the command line
xcodebuild build \
  -project PikaProjiOS.xcodeproj \
  -scheme PikaTakeHome \
  -destination "platform=iOS Simulator,name=iPhone 16"
```

There are no external package managers (no CocoaPods, no Carthage). Swift Package Manager dependencies are resolved automatically by Xcode.

**Run tests**

```bash
xcodebuild test \
  -project PikaProjiOS.xcodeproj \
  -scheme PikaTakeHome \
  -destination "platform=iOS Simulator,name=iPhone 16"
```

## Environment and configuration

The app resolves its backend URL from the following sources in priority order:

| Priority | Source | Key |
|----------|--------|-----|
| 1 | Process env var | `PIKA_BACKEND_BASE_URL` |
| 2 | Info.plist | `PikaBackendBaseURL` |
| 3 | Legacy env var | `VOICE_CHAT_BASE_URL` |
| 4 | Legacy env var | `VOICE_TRAINING_BASE_URL` |
| 5 | Simulator fallback | `http://127.0.0.1:8080` |

The `Info.plist` ships with the production Cloud Run URL (`https://pika-voice-backend-jf7rk4l2gq-pd.a.run.app`) baked in, so no local `.env` is required for simulator runs against the hosted backend.

Optional API key (forwarded as `X-API-Key`):

| Priority | Source | Key |
|----------|--------|-----|
| 1 | Process env var | `PIKA_API_KEY` |
| 2 | Info.plist | `PikaAPIKey` |

Auth backend can be overridden separately:

| Env var | Purpose |
|---------|---------|
| `AUTH_BASE_URL` | OAuth backend base URL |
| `AUTH_REDIRECT_URL` | OAuth callback URL |
| `AUTH_REDIRECT_SCHEME` | OAuth callback scheme (default: `pikatakehome`) |

### Feature flags

All flags default to their noted value. Override via env var or Info.plist key.

| Flag | Env var | Default | Effect when enabled |
|------|---------|---------|---------------------|
| `voiceUIFlow` | `PIKA_FEATURE_VOICE_UI_FLOW` | **on** | Shows the voice recording/training screens |
| `enableVoiceTraining` | `PIKA_FEATURE_ENABLE_VOICE_TRAINING` | off | Sends audio to the real training backend instead of the mock |
| `enableVoiceChat` | `PIKA_FEATURE_ENABLE_VOICE_CHAT` | off | Sends turns to the real voice-chat backend; enables conversation persistence and provider settings |
| `base44DesignUpgrade` | `PIKA_FEATURE_BASE44_DESIGN_UPGRADE` | **on** | Uses the "Semi" dark-themed design in Messages |

Set a flag in Xcode scheme environment variables or as a boolean in `Info.plist`.

### Test session injection

To inject an authenticated session without going through Google OAuth (useful for CI or test schemes):

```
PIKA_TEST_SESSION_TOKEN=<token>
PIKA_TEST_USER_ID=<id>          # optional
PIKA_TEST_USER_EMAIL=<email>    # optional
PIKA_TEST_USER_DISPLAY_NAME=<name> # optional
```

## Project layout

```
PikaProjiOS/
├── Pika/
│   ├── App/                    # Entry point, coordinator, routes, session stores
│   ├── Core/
│   │   ├── DesignSystem/       # Design tokens, themes, component styles
│   │   ├── Components/         # Shared reusable SwiftUI components
│   │   └── Infrastructure/     # Backend config, feature flags, audio chunking, 2FA
│   ├── Features/
│   │   ├── Welcome/            # Phone entry + Google OAuth
│   │   ├── Camera/             # Selfie capture, Vision face detection, avatar pipeline
│   │   ├── VoiceTraining/      # Prompt, record, review, submit, poll for profile
│   │   ├── Success/            # Identity card reveal
│   │   ├── Messages/           # Voice-chat conversation with SEMI
│   │   └── ProviderSettings/   # Ollama endpoint, model, 2FA, sign-out, delete account
│   ├── PikaKit/                # Design system abstraction (fonts, colors, images)
│   └── Info.plist
├── PikaTakeHomeTests/          # Unit and snapshot tests
├── PikaProjiOS.xcodeproj       # Primary project file
├── PikaTakeHome.xcodeproj      # Secondary project file
├── fonts/                      # Bundled custom font files
└── .github/workflows/ios-ci.yml
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for a full breakdown of the coordinator pattern, view model conventions, service seams, and design system.

## Data flow

See [docs/data-flow.md](docs/data-flow.md) for request/response sequences across the voice training and voice chat pipelines.

## Setup

See [docs/setup.md](docs/setup.md) for first-time developer setup, Xcode scheme configuration, and connecting to a local backend.

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for common errors and how to fix them.

## Backend

This repo is iOS-only. The backend source lives in a separate repository. The production service runs on Google Cloud Run.

## Known limitations / future work

- Voice turns are full-turn polled, not streamed. Partial transcript and streaming audio are not yet implemented.
- Two-factor auth state is device-local (iOS Keychain + TOTP). There is no server-backed 2FA enrollment.
- The live backend contract has limited end-to-end test coverage; mock services cover the seams.
- Demo mode (feature flags off) routes all voice turns through local stubs and never calls the backend.
