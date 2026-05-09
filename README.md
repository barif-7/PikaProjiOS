# PikaProjiOS

SwiftUI iOS prototype for the Pika onboarding and "future self" voice-chat experience.

## What’s in here
- Welcome flow with phone-entry continuation and optional Google sign-in.
- Selfie capture that generates the avatar used throughout the app.
- Voice onboarding with prompt, recording, review, backend training, and retraining flows.
- Success card and transition into the Open Messages voice-chat experience.
- Messages screen with backend voice turns, persisted conversation state, avatar updates, and voice-profile reuse.
- Provider settings for Ollama connection management, model discovery, sign-out, account deletion, and local TOTP-based two-factor enrollment.
- Imported handoff assets, custom fonts, snapshot tests, and focused unit tests.

## Architecture
- `PrototypeCoordinator` owns navigation and launch routing. Returning users with a saved voice profile land in Messages; everyone else starts at Welcome.
- Screen-specific view models keep concerns separated:
  - `PrototypeWelcomeViewModel`
  - `PrototypeCameraViewModel`
  - `PrototypeVoiceViewModel`
  - `PrototypeSuccessViewModel`
  - `PrototypeMessagesViewModel`
  - `PrototypeProviderSettingsViewModel`
- Shared UI styling lives in the design system and imported asset helpers rather than inside the flow logic.
- Feature flags gate voice UI, backend voice training, and backend voice chat so the app can run in UI-only mode or against live services.
- Session-backed state persists the phone number, generated avatar, and trained voice profile selection across launches.

## Backend Integration
- Voice services resolve from a unified backend config:
  - `PIKA_BACKEND_BASE_URL`
  - `PikaBackendBaseURL`
  - legacy `VOICE_CHAT_BASE_URL`
  - legacy `VOICE_TRAINING_BASE_URL`
- Optional service auth is forwarded via `X-API-Key` from:
  - `PIKA_API_KEY`
  - `PikaAPIKey`
- Voice training calls:
  - `GET /voice-profiles/capabilities`
  - `POST /voice-profiles`
  - `GET /voice-profiles/{jobId}`
- Voice chat currently submits async jobs to:
  - `POST /voice-chat/jobs`
  - `GET /voice-chat/jobs/{jobId}`
- Large audio payloads can be sent as chunked uploads instead of a single base64 blob.
- When auth is configured and the user has a session, the app also persists the default conversation at:
  - `PUT /conversations/default`
  - `GET /conversations/default`
- This repo is iOS-only. Backend source and local model runtime scripts live outside this repository.

## Authentication And Provider Settings
- Google sign-in is optional and refreshes expiring sessions on launch when available.
- Provider settings are only meaningful for signed-in users and allow editing the stored Ollama endpoint, model, label, and API token.
- The app can fetch available Ollama models from `GET /api/tags`.
- Two-factor is currently a local TOTP implementation backed by the iOS keychain, including QR enrollment and verification UI.

## Testing
- Snapshot coverage exists for the major prototype surfaces, including Welcome, Voice, Messages, Success, and Provider Settings states.
- Unit coverage includes backend/auth configuration, avatar processing, and `PikaKit` helpers.
- The project is structured so service seams can be swapped for mocks in UI and snapshot tests.

## Revisit With More Time
- Stream partial transcripts and partial synthesized audio instead of full-turn polling.
- Add stronger end-to-end coverage for the live backend contracts.
- Replace local-only two-factor state with a server-backed implementation if this moves beyond prototype scope.
- Tighten the split between demo-mode services and production integrations as the backend stabilizes.
