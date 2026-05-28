# Developer Setup

## Prerequisites

| Tool | Version |
|------|---------|
| macOS | 15 (Sequoia) or later |
| Xcode | Latest stable (the CI uses `latest-stable` on `macos-15`) |
| iOS Simulator | iPhone 15, iPhone 15 Pro, iPhone 16, or iPhone 16 Pro |

No additional tools are required (no Homebrew packages, no Ruby gems, no Node).

## Clone and open

```bash
git clone <repo-url>
cd PikaProjiOS
open PikaProjiOS.xcodeproj
```

Xcode will automatically resolve Swift Package Manager dependencies on first open.

## First build

Select the `PikaTakeHome` scheme and an iPhone simulator, then press `Cmd+R`.

The app ships with the production backend URL baked into `Info.plist`, so it will connect to the hosted Cloud Run service by default. No additional configuration is required for a basic run.

## Running against a local backend

Set the environment variable in the Xcode scheme:

1. Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables
2. Add: `PIKA_BACKEND_BASE_URL` = `http://127.0.0.1:8080` (or your local server address)

On the iOS Simulator, `127.0.0.1` refers to the Mac's loopback. If running on a physical device, use the Mac's LAN IP.

> The simulator fallback (`http://127.0.0.1:8080`) applies automatically when no backend URL is configured and the build target is the simulator.

## Enabling live backend features

By default, voice training and voice chat call local stubs. Enable the real services via scheme environment variables:

| What | Variable | Value |
|------|----------|-------|
| Voice training | `PIKA_FEATURE_ENABLE_VOICE_TRAINING` | `1` |
| Voice chat | `PIKA_FEATURE_ENABLE_VOICE_CHAT` | `1` |

Both flags can also be set as Info.plist keys (`PIKA_FEATURE_ENABLE_VOICE_TRAINING`, `PIKA_FEATURE_ENABLE_VOICE_CHAT`) using boolean values, but environment variables are preferred for local dev since they don't require a recompile.

## API key

If the backend requires authentication:

1. Scheme → Run → Arguments → Environment Variables
2. Add: `PIKA_API_KEY` = `<your key>`

The key is forwarded as the `X-API-Key` header on every backend request.

## Google OAuth

Google sign-in is driven through the backend OAuth flow (not the Google SDK). It requires:

- A running backend that handles `/auth/google/start` and `/auth/session`.
- The backend URL configured via `AUTH_BASE_URL` env var or `AuthBaseURL` Info.plist key.

The production `Info.plist` has `AuthBaseURL` set to the Cloud Run backend, so Google sign-in works out of the box against the hosted environment.

To test without Google sign-in, inject a synthetic session:

```
PIKA_TEST_SESSION_TOKEN=any-string-you-like
```

This creates a valid in-memory session without hitting the OAuth flow. The token is forwarded as `Bearer <token>` on authenticated requests.

## Injecting a test session token

```
PIKA_TEST_SESSION_TOKEN=<token>
PIKA_TEST_USER_ID=test-user            # optional
PIKA_TEST_USER_EMAIL=test@example.com  # optional
PIKA_TEST_USER_DISPLAY_NAME=Test User  # optional
```

## Feature flags reference

| Flag | Env var | Default | Notes |
|------|---------|---------|-------|
| Voice UI | `PIKA_FEATURE_VOICE_UI_FLOW` | on | Shows the voice screens. Set to `0` to skip straight to success. |
| Voice training backend | `PIKA_FEATURE_ENABLE_VOICE_TRAINING` | off | Sends audio to `/voice-profiles`. |
| Voice chat backend | `PIKA_FEATURE_ENABLE_VOICE_CHAT` | off | Sends turns to `/voice-chat/jobs` and enables conversation sync. |
| Base44 design | `PIKA_FEATURE_BASE44_DESIGN_UPGRADE` | on | Dark "Semi" theme in Messages. |

Accepted truthy values: `1`, `true`, `yes`, `y`, `on`, `enabled`.

## Running tests

From Xcode: `Cmd+U` with the `PikaTakeHome` scheme selected.

From the terminal:

```bash
xcodebuild test \
  -project PikaProjiOS.xcodeproj \
  -scheme PikaTakeHome \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -derivedDataPath /tmp/PikaTakeHome-DerivedData
```

Snapshot test failure diffs are written to `PikaTakeHomeTests/FailureDiffs/`.

## Updating snapshots

If a UI change intentionally changes the appearance of a snapshotted screen, delete the reference snapshots in `PikaTakeHomeTests/__Snapshots__/` and run the tests once to regenerate them. Commit the new snapshots.

## Custom fonts

The custom fonts (Telka, Space Mono, BPdotsVertical) are bundled in the `fonts/` directory and registered via `UIAppFonts` in `Info.plist`. They are available to all views through `AppFont` and `PikaFonts`.

## Xcode project files

There are two `.xcodeproj` files:

| File | Use |
|------|-----|
| `PikaProjiOS.xcodeproj` | Primary — use this for development and CI |
| `PikaTakeHome.xcodeproj` | Secondary — TODO: clarify purpose |

Always open and build `PikaProjiOS.xcodeproj`.
