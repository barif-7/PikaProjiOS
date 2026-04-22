# Pika iOS Take-Home

SwiftUI implementation of the 6-step prototype flow from Figma.

## What’s in here
- Phone sign-in landing screen
- Selfie capture screen
- Voice-clone prompt, recording, and review states
- Final AI self success card
- Open Messages voice-chat screen
- Bundled custom fonts from the handoff
- `voice-backend/` for the self-hosted Whisper + Ollama + Piper integration used by Open Messages

## Architecture
- Single `PrototypeViewModel` drives the whole flow as a small state machine.
- UI is split into focused SwiftUI views, with a shared design system for fonts, colors, and controls.
- No backend assumptions are baked into the UI, the seams stay local and replaceable.

## Decisions
- Kept the flow simple and explicit instead of introducing navigation complexity.
- Used the provided fonts to match the prototype’s tone.
- Built the missing edge states as polished local states, rather than leaving dead ends.

## Open Messages backend
- The app expects `POST /voice-chat/turn` from `VoiceChatBaseURL` or `VOICE_CHAT_BASE_URL`.
- The app expects `POST /voice-profiles` and `GET /voice-profiles/{jobId}` from `VoiceTrainingBaseURL` or `VOICE_TRAINING_BASE_URL`.
- A reference backend lives in `voice-backend/` and is designed for:
  - Whisper CLI for speech-to-text
  - Ollama serving an open model such as `mistral`
  - Piper for optional text-to-speech audio
- Simulator example:
  - run `./voice-backend/run-local.sh`
  - the app defaults to `http://127.0.0.1:8080` for both chat and training in the simulator
- Physical device example:
  - run the backend on your Mac and use your Mac’s LAN IP, for example `http://192.168.1.20:8080`
  - set `VoiceChatBaseURL`, `VoiceTrainingBaseURL`, `VOICE_CHAT_BASE_URL`, or `VOICE_TRAINING_BASE_URL` to that LAN address

## Revisit with more time
- Stream partial transcripts and partial TTS audio instead of full-turn request/response.
- Persist generated avatars and message history across app relaunches.
- Add snapshot tests for the main screens and integration tests for the voice backend contract.

## Questions for design / backend
- Should the final card always say “SEMI”, or should that be user-generated?
- What’s the actual phone auth and voice-upload contract?
- Should the capture and recording screens be strictly guided, or can users skip ahead?
