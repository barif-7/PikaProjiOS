# PikaProjiOS

SwiftUI implementation of the Pika iOS prototype flow.

## What’s in here
- Phone sign-in landing screen
- Selfie capture screen
- Voice-clone prompt, recording, and review states
- Final AI self success card
- Open Messages voice-chat screen
- Bundled custom fonts from the handoff
- iOS-only app code, assets, and tests

## Architecture
- Single `PrototypeViewModel` drives the whole flow as a small state machine.
- UI is split into focused SwiftUI views, with a shared design system for fonts, colors, and controls.
- No backend assumptions are baked into the UI, the seams stay local and replaceable.

## Decisions
- Kept the flow simple and explicit instead of introducing navigation complexity.
- Used the provided fonts to match the prototype’s tone.
- Built the missing edge states as polished local states, rather than leaving dead ends.

## Open Messages backend
- The app now submits voice turns to `POST /voice-chat/jobs` and polls `GET /voice-chat/jobs/{jobId}` from `VoiceChatBaseURL` or `VOICE_CHAT_BASE_URL`.
- The app expects `POST /voice-profiles` and `GET /voice-profiles/{jobId}` from `VoiceTrainingBaseURL` or `VOICE_TRAINING_BASE_URL`.
- Google auth uses `AuthBaseURL` / `AUTH_BASE_URL` and supports either:
  - a custom callback scheme via `AuthRedirectScheme` / `AUTH_REDIRECT_SCHEME`
  - or a full redirect URL via `AuthRedirectURL` / `AUTH_REDIRECT_URL` for Universal Link migration
- The backend now lives in the separate `PikaProjBackend` repo.
- This iOS repo does not include backend source or local backend scripts.
- To run against a simulator or physical device, point the app at a reachable backend URL via:
  - `VoiceChatBaseURL`
  - `VoiceTrainingBaseURL`
  - `VOICE_CHAT_BASE_URL`
  - `VOICE_TRAINING_BASE_URL`

## Revisit with more time
- Stream partial transcripts and partial TTS audio instead of full-turn request/response.
- Persist generated avatars and message history across app relaunches.
- Add snapshot tests for the main screens and integration tests for the voice backend contract.

## Questions for design / backend
- Should the final card always say “SEMI”, or should that be user-generated?
- What’s the actual phone auth and voice-upload contract?
- Should the capture and recording screens be strictly guided, or can users skip ahead?

## Related repo
- Backend: `https://github.com/barif-7/PikaProjBackend`
