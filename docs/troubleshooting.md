# Troubleshooting

## Build issues

### "No such module 'PikaTakeHome'" in tests

The test target imports `@testable import PikaTakeHome`. If the app target has not been built yet, this import fails.

**Fix**: Build the `PikaTakeHome` scheme (`Cmd+B`) before running tests, or run `Cmd+U` which builds first automatically.

### Swift Package resolution fails

**Fix**: File → Packages → Reset Package Caches, then resolve again.

If that doesn't help:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
xcodebuild -resolvePackageDependencies \
  -project PikaProjiOS.xcodeproj \
  -scheme PikaTakeHome
```

### "No signing certificate" error

This is a prototype; signing is only needed for physical device builds. For simulator runs, set the target's signing to "Sign to Run Locally" or disable signing entirely.

---

## Runtime issues

### App launches to Welcome even though I completed onboarding before

The launch route is determined by whether `prototype.session.voiceProfileID` exists in `UserDefaults`. If you deleted the app or cleared `UserDefaults`, the session is gone.

You can also force a clean state by launching the app in the debugger, pausing, and running:

```
expr UserDefaults.standard.removeObject(forKey: "prototype.session.voiceProfileID")
```

### Voice training spins forever

1. Confirm `PIKA_FEATURE_ENABLE_VOICE_TRAINING=1` is set in the scheme.
2. Check the backend URL — it defaults to the Cloud Run service in `Info.plist`. Verify it's reachable: `curl https://pika-voice-backend-jf7rk4l2gq-pd.a.run.app/voice-profiles/capabilities`.
3. If the capabilities endpoint returns `trainingCommandConfigured: false`, the backend is not set up for training.
4. Check the Xcode console for the HTTP response — the service logs status poll responses.

If training is not available, set `PIKA_FEATURE_ENABLE_VOICE_TRAINING=0`. The mock service completes in ~3 seconds with a synthetic profile ID.

### Voice chat says "Backend not configured"

`enableVoiceChat` is off by default. The alert appears when the flag is off and the user tries to start a call while voice chat backend is expected.

**Fix**: Enable the flag (`PIKA_FEATURE_ENABLE_VOICE_CHAT=1`) or run in demo mode (flag stays off — the UI works but uses local stubs).

### "Voice profile required" alert in Messages

A voice profile ID must be set before the chat backend can be called. Complete the voice training flow, or inject one programmatically for testing:

```swift
// In a test scheme run script or the debugger
UserDefaults.standard.set("your-profile-id", forKey: "prototype.session.voiceProfileID")
```

### Google sign-in sheet never dismisses / "cancelled" error

The OAuth callback URL must match what the backend redirects to. The default scheme is `pikatakehome`. If the backend redirects to a different scheme:

1. Add `AUTH_REDIRECT_SCHEME=<your-scheme>` to the scheme env vars.
2. Add the scheme to `CFBundleURLSchemes` in `Info.plist`.

If ASWebAuthenticationSession shows the browser but the app never receives the callback, the scheme is likely mismatched.

### Google sign-in fails with "Google authentication failed"

The backend returned an error in the OAuth callback query string. Check the callback URL for `error_description` or `error` query parameters. Common causes:

- The backend's Google OAuth credentials are expired or misconfigured.
- The `mobile_callback` URL the app sent doesn't match the backend's allowed redirect URIs.

### Session token rejected (401 on voice-chat or conversation endpoints)

The session in the Keychain may be expired.

**Fix**: Sign out from Provider Settings and sign back in. The coordinator refreshes expiring sessions automatically at launch (within a 3-day window), but a fully expired session is cleared and the user is sent to Welcome.

To test without a real session, set `PIKA_TEST_SESSION_TOKEN=<any-string>` in the scheme env vars.

---

## Snapshot test failures

### Snapshot diffs appear after a SwiftUI update

If a system update changes default font rendering or spacing, snapshot tests will fail. Review the diffs in `PikaTakeHomeTests/FailureDiffs/` (or download the CI artifact `PikaTakeHome-snapshot-failure-diffs`).

If the change is expected: delete the reference images in `PikaTakeHomeTests/__Snapshots__/` and run the tests once to regenerate.

### Snapshots look correct locally but fail on CI

Snapshot reference images are recorded on a specific simulator/OS combination. The CI uses `macos-15` with `latest-stable` Xcode and an iPhone 16 or equivalent. If your local environment differs, the pixel output may not match.

**Fix**: Record snapshots in the same environment as CI, or add a `@available` guard to skip the test on mismatched OS versions.

---

## Audio issues

### Microphone permission denied

The app requests microphone access when the user first taps the voice record button. If denied, a system settings alert is shown but iOS does not re-prompt.

**Fix in Simulator**: Reset privacy settings via Device → Privacy & Security → Microphone, or reinstall the app.

### Recording produces 0-byte files

This can happen if the AVAudioSession is not activated before recording starts. The `MessagesAudioRecorder` handles activation, but if another process holds the audio session (e.g., a background test), it may fail silently.

**Fix**: Stop any other audio-using processes and try again.

### Audio chunks cause a backend error

`AudioChunker` splits recordings longer than 15 seconds into 15-second CAF/WAV segments and base64-encodes them. If the backend rejects chunked audio, verify that:

1. The backend supports the `audioChunks` field (instead of `audioBase64`).
2. The `mimeType` in each chunk matches what the backend expects (`audio/wav` or `audio/x-caf`).

For recordings ≤ 15 seconds, chunking is bypassed and a single `audioBase64` string is sent.

---

## Camera / avatar issues

### "No face detected" alert

Vision's `VNDetectFaceRectanglesRequest` did not find a face in the selfie.

- The image needs a visible, forward-facing face that is large enough relative to the frame.
- The face crop uses 35% padding. Very small faces may not pass the minimum detection threshold.

In tests, `SelfieAvatarPipelineTests` uses synthetic images to verify the pipeline in isolation.

### Image Playground unavailable

`ImagePlayground` is an iOS 18.2+ feature and requires a device with the relevant Apple Intelligence capability. On unsupported devices or OS versions, `CameraScreen` shows a "not supported" alert and the avatar step is skipped (a placeholder is used).

### Avatar not persisted across launches

The avatar is saved to Application Support as `session-avatar.jpg` via `PrototypeSessionStore.saveAvatarImage`. If the app does not have write access to Application Support (unlikely on device, not possible on simulator), the save fails silently.

---

## Provider settings

### Ollama models not loading

The app calls `GET /api/tags` to discover models. This endpoint is part of the Ollama REST API. Ensure the Ollama endpoint in Provider Settings is correct and reachable from the device/simulator.

On Simulator, `http://127.0.0.1:11434` points to the Mac's loopback. On a physical device, use the Mac's LAN IP.

### 2FA enrollment fails / QR code not scannable

TOTP 2FA is implemented locally using the iOS Keychain. The secret is generated on-device and never sent to the backend. If the QR code is not scannable, try copying the manual key and entering it directly into an authenticator app.

The 2FA state resets on sign-out (the Keychain item is tied to the app, not the account). There is no server-side recovery path.

---

## CI failures

### "No supported iPhone simulator found"

The CI step tries iPhone 16 → 16 Pro → 15 → 15 Pro in that order. If none are available on the runner, the job fails.

This is a runner provisioning issue. Re-running the job usually resolves it as a new runner is selected. If it persists, update the candidate list in `.github/workflows/ios-ci.yml`.

### Xcode version mismatch

The workflow uses `maxim-lobanov/setup-xcode@v1` with `xcode-version: latest-stable`. If Apple releases a new Xcode that breaks the build, pin a specific version using the `xcode-version` input.
