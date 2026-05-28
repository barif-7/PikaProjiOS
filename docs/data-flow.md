# Data Flow

This document describes the end-to-end data flows for the main features: onboarding, voice training, voice chat, and conversation persistence.

## Onboarding flow

```
User taps Continue (phone) or signs in with Google
         │
         ▼
PrototypeCoordinator → route = .camera
         │
         ▼
CameraScreen
  User takes selfie → SelfieAvatarService
    1. Normalize UIImage orientation
    2. VNDetectFaceRectanglesRequest (background thread)
    3. FaceSelection.largestFace → bounding box
    4. FaceCropper → padded crop rect
    5. Write JPEG to Caches/PikaTakeHome/ImagePlaygroundSource/
    6. Apple Image Playground → stylized avatar UIImage
         │
         ▼
coordinator.saveAvatarImage → PrototypeSessionStore
  avatar propagated to voiceViewModel, successViewModel, messagesViewModel
         │
         ▼
route = .voice(.prompt)
```

## Voice training flow

Feature flag `enableVoiceTraining` must be `true` for real backend calls. If `false`, `MockVoiceProfileTrainingService` is used and the flow completes with a synthetic profile ID.

```
VoiceScreen (prompt stage)
  User taps record → AVAudioRecorder → CAF file in tmp directory
  User taps stop → route = .voice(.complete)
         │
         ▼
User taps Confirm
  PrototypeVoiceViewModel.confirmTapped()
         │
         ▼
PrototypeVoiceTrainingService
  1. GET /voice-profiles/capabilities
     Response: { trainingCommandConfigured, trainingMode, supportsPersonalizedVoice }
         │
  2. Determine chunking:
     - duration > 15 s → AudioChunker.chunkedUploads → [AudioUploadChunk]
     - duration ≤ 15 s → Data(contentsOf: audioURL).base64EncodedString()
         │
  3. POST /voice-profiles
     Body: {
       transcript,
       durationSeconds,
       fileName,
       mimeType,
       audioBase64 | audioChunks,  ← mutually exclusive
       baseProfileID               ← set only during retraining
     }
     Headers: Authorization: Bearer <sessionToken>   (if signed in)
              X-API-Key: <apiKey>                     (if configured)
     Response: { jobId, profileId? }
         │
  4. Poll GET /voice-profiles/{jobId}   (every ~1 s)
     Response: { status, progress?, profileId?, message? }
     status values: queued | processing | running | training | ready | completed | succeeded | failed | error
         │
  5. When status == ready/completed/succeeded:
     profileId → voiceViewModel.trainedVoiceProfileID
         │
         ▼
coordinator.completeVoiceStep()
  sessionStore.saveVoiceProfileID(profileId)
  messagesViewModel.setVoiceProfileID(profileId)
  await messagesViewModel.saveConversationNow()
  route = .success (or .messages if retraining)
```

## Voice chat flow

Feature flag `enableVoiceChat` must be `true`. If `false`, local demo stubs are used and no network calls occur.

```
MessagesScreen
  User taps "Start Talking"
  → MessagesAudioRecorder.start() → AVAudioSession + AVAudioRecorder
  callState = .listening
         │
  User taps "Finish Turn"
  → recorder.stop() → MessagesRecordedTurn { fileURL, duration }
  callState = .responding
         │
HTTPMessagesVoiceChatService.respond(to:history:conversationSummary:voiceProfileID:)
         │
  1. Determine chunking (same 15 s threshold as training)
         │
  2. POST /voice-chat/jobs
     Body: {
       audioBase64 | audioChunks,
       durationSeconds,
       fileName,
       mimeType,
       voiceProfileID,
       conversationHistory: [{ speaker, text }],  ← last 8 messages
       conversationSummary                         ← compressed older history
     }
     Headers: Authorization: Bearer <sessionToken>
              X-API-Key: <apiKey>
     Response: { jobId, stage }
         │
  3. Poll GET /voice-chat/jobs/{jobId}
     Response: {
       jobId,
       stage,           ← queued | processing | ready | failed
       transcript?,
       responseText?,
       responseAudioBase64?,
       responseAudioMimeType?,
       error?
     }
         │
  4. When stage == ready:
     - Append user message (transcript) and SEMI message (responseText)
     - Decode responseAudioBase64 → Data → MessagesAudioPlayer.play()
     - If no audio: show "text only" alert
         │
  5. rebuildConversationSummary()
     - Keep last 8 messages as recent context
     - Compress older messages: truncate each to 140 chars, total ≤ 1200 chars
         │
  6. persistConversationIfPossible() → conversation store
         │
  callState = .idle
```

## Conversation persistence

Requires `enableVoiceChat = true` and a configured backend.

```
On showMessages():
  messagesViewModel.prepareConversation()
    GET /conversations/default
    Headers: Authorization: Bearer <sessionToken>
    Response: {
      messages: [{ speaker, text }],
      summary,
      voiceProfileID?,
      avatarImageBase64?
    }
    Merges with local state:
      - prefer local voiceProfileID if set, fall back to stored
      - prefer local avatar if set, fall back to stored

On each voice turn completion:
  PUT /conversations/default
    Body: { messages, summary, voiceProfileID, avatarImageBase64? }
    Headers: Authorization: Bearer <sessionToken>

On sign-out / account deletion:
  coordinator.handleSignOut() → sessionStore.saveAvatarImage(nil) + saveVoiceProfileID(nil)
  No explicit DELETE of the conversation on the backend.
```

## Google OAuth flow

```
User taps "Continue with Google"
         │
PrototypeGoogleOAuthService.signInWithGoogle()
  1. Build authStartURL = {AUTH_BASE_URL}/auth/google/start
       ?mobile_callback=pikatakehome://auth/google
  2. ASWebAuthenticationSession → present browser
  3. User signs in → backend redirects to pikatakehome://auth/google?session_token=<token>
  4. Extract session_token from callback URL
         │
  5. GET {AUTH_BASE_URL}/auth/session
     Headers: Authorization: Bearer <session_token>
     Response: { sessionToken, user: { userId, email, displayName, photoURL }, expiresAt }
         │
  6. PrototypeAppSessionStore.save(session) → Keychain

On app launch (session expiring within 3 days):
  PrototypeGoogleOAuthService.refreshSession(sessionToken:)
    POST {AUTH_BASE_URL}/auth/session/refresh
    Headers: Authorization: Bearer <sessionToken>
    Response: same as session response
```

## Session state and launch routing

```
PrototypeCoordinator.init()
  sessionStore.state.voiceProfileID != nil
    → route = .messages        (returning user: lands in Messages)
  else
    → route = .welcome         (new user: starts at Welcome)

refreshStoredSessionIfNeeded()
  if session.isExpiringSoon(within: 3 days)
    → refreshSession() → update Keychain
    if refresh fails → clear session → route = .welcome
```

## Local state diagram

```
PrototypeSessionStore (UserDefaults + Application Support)
  ├── hasPersistedAccount: Bool
  ├── phoneNumber: String
  ├── voiceProfileID: String?
  └── session-avatar.jpg (Application Support directory)

PrototypeAppSessionStore (Keychain service: com.openclaw.pikatakehome.auth)
  └── current-session: PrototypeAppSession (JSON-encoded)
        ├── sessionToken
        ├── user { userId, email, displayName, photoURL }
        └── expiresAt (ISO8601)
```

## Backend API surface

All endpoints relative to `PikaBackendBaseURL`.

| Method | Path | Used by |
|--------|------|---------|
| GET | `/voice-profiles/capabilities` | Voice training — check backend capabilities |
| POST | `/voice-profiles` | Voice training — submit audio sample |
| GET | `/voice-profiles/{jobId}` | Voice training — poll status |
| POST | `/voice-chat/jobs` | Voice chat — submit user turn |
| GET | `/voice-chat/jobs/{jobId}` | Voice chat — poll response |
| GET | `/conversations/default` | Messages — load persisted conversation |
| PUT | `/conversations/default` | Messages — save conversation after each turn |
| GET | `/api/tags` | Provider Settings — discover available Ollama models |

Auth endpoints (relative to `AuthBaseURL`, which defaults to the same host):

| Method | Path | Used by |
|--------|------|---------|
| GET | `/auth/google/start?mobile_callback=<url>` | Google OAuth initiation |
| GET | `/auth/session` | Exchange OAuth session_token for full session |
| POST | `/auth/session/refresh` | Refresh expiring session |
| DELETE | `/auth/session` | Sign out |
| DELETE | `/auth/account` | Delete account |
