# Architecture

## Overview

PikaProjiOS is a SwiftUI iOS application. It uses the **coordinator pattern** for navigation and **MVVM** for screen-level state. There are no third-party reactive frameworks; the app relies entirely on `ObservableObject`, `@Published`, and Swift Concurrency (`async/await`, `actor`).

## Entry point

```
PikaTakeHomeApp  (App entry point)
  └── PrototypeFlowView
        └── PrototypeCoordinatorView
              └── PrototypeCoordinator (ObservableObject)
```

`PikaTakeHomeApp` constructs `PrototypeFlowView` and injects the `DesignSystem` environment value. `PrototypeFlowView` is a thin wrapper that holds the `@StateObject` coordinator. All navigation is driven by mutating `coordinator.route`.

## Navigation

`PrototypeCoordinator` owns an enum `PrototypeRoute`:

```swift
enum PrototypeRoute: Equatable {
    case welcome
    case camera
    case voice(PrototypeVoiceStage)   // .prompt | .recording | .complete
    case success
    case messages
    case providerSettings
}
```

`PrototypeCoordinatorView` reads `coordinator.route` and switches between screens. Route transitions are animated using `coordinator.animationValue` as the `withAnimation` identity.

The coordinator holds **lazy-cached** view model instances:

```
cameraViewModel         PrototypeCameraViewModel
voiceViewModel          PrototypeVoiceViewModel
successViewModel        PrototypeSuccessViewModel
messagesViewModel       PrototypeMessagesViewModel
providerSettingsViewModel PrototypeProviderSettingsViewModel
```

These are created on first access and cached in `stored*` backing vars. The cache is intentionally cleared for auth-dependent view models (`voice`, `messages`, `providerSettings`) on sign-out or account deletion so they are rebuilt with fresh session state.

## View models

Each screen has its own view model. View models are `@MainActor final class : ObservableObject`. They:

- Expose `@Published` state consumed by the SwiftUI view.
- Call into services (actors or structs) for I/O.
- Communicate navigation intent upward via closure callbacks (`onBackRequested`, `onContinueRequested`, etc.). The coordinator wires these closures.

This keeps views passive (they call view model methods and observe published state) and keeps coordinators free of UI code.

## Service layer

Services sit below view models and are protocol-backed so they can be swapped in tests.

| Protocol | Purpose |
|----------|---------|
| `VoiceProfileTraining` | Submit a voice sample and poll training status |
| `MessagesVoiceChatResponding` | Submit a recorded turn and return a response |
| `MessagesVoiceRecorder` | Record microphone audio |
| `MessagesAudioPlaying` | Play back audio data |
| `MessagesConversationPersisting` | Save / load conversation state from the backend |
| `SelfieAvatarPreparing` | Run Vision face detection and write a prepared JPEG |
| `FeatureFlagManaging` | Check feature flag state |
| `PrototypeGoogleAuthenticating` | Drive Google OAuth and session refresh |

All HTTP services are `actor`-isolated or plain `struct`s using `URLSession` directly. There is no networking library dependency.

## Factory pattern

Services are instantiated by `*Factory` types that inspect the environment to choose production or stub implementations:

- `VoiceTrainingServiceFactory.makeDefault()` — returns `HTTPVoiceProfileTrainingService` if backend is configured, otherwise `MockVoiceProfileTrainingService`.
- `MessagesVoiceChatServiceFactory.makeDefault()` — returns `HTTPMessagesVoiceChatService` if backend is configured, otherwise `UnconfiguredMessagesVoiceChatService`.
- `MessagesConversationServiceFactory.makeDefault()` — returns the HTTP store when voice chat is enabled.
- `PrototypeGoogleAuthServiceFactory.makeDefault()` — returns `PrototypeGoogleOAuthService` when auth backend is configured, or `nil` (disabling Google sign-in silently).

## Session / persistence

Two distinct session stores:

| Store | Backing | Contents |
|-------|---------|---------|
| `PrototypeSessionStore` | `UserDefaults` + Application Support directory | Phone number, voice profile ID, avatar JPEG |
| `PrototypeAppSessionStore` | iOS Keychain (`com.openclaw.pikatakehome.auth`) | Authenticated session token and user info |

State is read at coordinator init to decide the launch route. A voice profile ID in `UserDefaults` means the user completed onboarding and lands in Messages; otherwise they start at Welcome.

## Design system

`PikaDesignSystem` (aliased as `DesignSystem`) is passed via SwiftUI environment:

```swift
.environment(\.designSystem, DesignSystem.default)
```

Design tokens live in `AppColor`, `AppFont`, `AppSpacing`, `AppRadius`, `AppControlSize`. The `PikaKit` namespace provides injectable providers for fonts, colors, and images so tests can swap them out.

The Messages screen uses a separate set of dark-themed tokens (`SemiTheme`, `SemiDesign`) from the `base44DesignUpgrade` design pass. Themes (Midnight, Aurora, Ember, Sakura, Obsidian) unlock progressively based on conversation progress.

## Feature flags

`FeatureFlagManager.shared` reads flags from:
1. In-memory overrides (tests only)
2. Process environment variables
3. Info.plist keys
4. Hard-coded defaults

Flags control whether the UI shows, whether backend calls are made, or both. The app is designed to run fully offline in demo mode with all backend flags off.

## Concurrency model

- All `@MainActor`-marked types (view models, coordinator, session stores) run on the main actor.
- HTTP service actors (`HTTPVoiceProfileTrainingService`, etc.) run on their own actor to keep I/O off the main thread.
- Long background tasks are started with `Task { ... }` from the coordinator or view models and hold `[weak self]` to avoid retain cycles.
- `pendingTransitionTask` in the coordinator cancels in-flight work when the user navigates away.

## Audio pipeline

Voice recording (both training and chat) creates CAF or WAV files in the temporary directory. For recordings longer than 15 seconds, `AudioChunker` splits the file into 15-second PCM segments using `AVAudioFile` and base64-encodes each chunk. The backend receives either a single `audioBase64` field or an `audioChunks` array.

## Selfie pipeline

`SelfieAvatarService` (implements `SelfieAvatarPreparing`):

1. Normalizes UIImage orientation.
2. Runs `VNDetectFaceRectanglesRequest` on a background `DispatchQueue`.
3. `FaceSelection.largestFace` picks the primary face.
4. `FaceCropper` converts Vision bounding box (normalized, flipped Y) to UIKit coordinates and crops with padding.
5. The cropped source image is written to `Caches/PikaTakeHome/ImagePlaygroundSource/` as a JPEG.
6. Apple Image Playground API generates the stylized avatar from the prepared JPEG.

## Testing strategy

- **Snapshot tests** (`PrototypeSnapshotTests`) cover the major prototype surfaces. Snapshot failures produce diff images in `PikaTakeHomeTests/FailureDiffs/`, which CI uploads as an artifact.
- **Unit tests** (`PikaKitTests`, `AuthConfigurationTests`, `SelfieAvatarPipelineTests`) test service logic, serialization, audio chunking, and view model state transitions using mock protocols and `MockURLProtocol`.
- Service seams (all the `*Responding`, `*Persisting`, `*Preparing` protocols) exist specifically to enable injection in tests.
