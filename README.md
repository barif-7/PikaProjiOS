# Pika iOS Take-Home

SwiftUI implementation of the 6-step prototype flow from Figma.

## What’s in here
- Phone sign-in landing screen
- Selfie capture screen
- Voice-clone prompt, recording, and review states
- Final AI self success card
- Bundled custom fonts from the handoff

## Architecture
- Single `PrototypeViewModel` drives the whole flow as a small state machine.
- UI is split into focused SwiftUI views, with a shared design system for fonts, colors, and controls.
- No backend assumptions are baked into the UI, the seams stay local and replaceable.

## Decisions
- Kept the flow simple and explicit instead of introducing navigation complexity.
- Used the provided fonts to match the prototype’s tone.
- Built the missing edge states as polished local states, rather than leaving dead ends.

## Revisit with more time
- Swap the stylized camera / portrait placeholders for real capture and media assets.
- Add real message-sharing and voice-recording integrations.
- Add snapshot tests for the main screens.

## Questions for design / backend
- Should the final card always say “SEMI”, or should that be user-generated?
- What’s the actual phone auth and voice-upload contract?
- Should the capture and recording screens be strictly guided, or can users skip ahead?
