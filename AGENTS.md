# AGENTS.md — Guidance for AI coding agents

This file helps AI coding assistants (Claude Code, Codex, Copilot, etc.) understand the conventions and constraints of this codebase so they can make correct, consistent changes.

## Project identity

- **Target**: `PikaTakeHome` in `PikaProjiOS.xcodeproj`
- **Bundle ID**: `com.openclaw.pikatakehome`
- **Language**: Swift 5.9+, SwiftUI, iOS 17+
- **No external dependencies** beyond the Swift Package Manager packages already present in the project.

## Navigation changes

All navigation is driven by `PrototypeCoordinator` in `Pika/App/PrototypeCoordinator.swift`. Do **not** add `NavigationStack` or `sheet` modifiers directly in leaf views. Instead:

1. Add a new case to `PrototypeRoute` in `Pika/App/PrototypeFlowModels.swift`.
2. Add a `show*()` private method to `PrototypeCoordinator`.
3. Wire a closure callback from the view model (e.g., `viewModel.onFooRequested = { [weak self] in self?.showFoo() }`).
4. Handle the new route in `PrototypeCoordinatorView`.

## Adding a screen

1. Create a `Features/<Name>/` directory.
2. Add a view file (`<Name>Screen.swift`) and a view model file (`Prototype<Name>ViewModel.swift`).
3. The view model must be `@MainActor final class : ObservableObject`.
4. Navigation intent goes through closure callbacks — the view model declares `var onXRequested: (() -> Void)?`; the coordinator assigns it.
5. Add a lazy cached property to `PrototypeCoordinator` following the existing `make*ViewModel` pattern.

## Feature flags

Wrap new backend-dependent behavior in a feature flag. Add the flag to `FeatureFlag` enum in `Pika/Core/Infrastructure/FeatureFlags.swift`. Provide an `environmentKey` and a `defaultValue`. The default for new flags touching live services should be `false` (off by default).

## Services

- HTTP services use `URLSession` directly. Do not introduce Alamofire or similar libraries.
- New services must expose a protocol (e.g., `protocol FooServicing`) so tests can inject mocks.
- Use `actor` isolation for services that make network calls.
- Decorate requests with `PikaBackendConfiguration.decorate(_:)` to forward the API key header.

## Persistence

- Non-sensitive onboarding state: `PrototypeSessionStore` (`UserDefaults`).
- Authenticated session token: `PrototypeAppSessionStore` (Keychain).
- Do not write new `UserDefaults` keys ad-hoc. Add a case to the `Keys` enum inside the relevant store.

## Design system

- Use tokens from `AppColor`, `AppFont`, `AppSpacing`, `AppRadius`, `AppControlSize` — never hardcode hex values or numeric sizes inline.
- The Messages screen uses `SemiTheme` and `SemiDesign` tokens (dark theme). Other screens use the cream/lavender light theme.
- Do not mix the two themes within a single screen.

## Testing

- Place unit tests in `PikaTakeHomeTests/`.
- Mock network responses using `MockURLProtocol` (already defined in `PikaKitTests.swift`).
- Snapshot tests use the existing snapshot framework already set up in `PrototypeSnapshotTests.swift`. Add a snapshot for any new screen.
- Run tests with:
  ```bash
  xcodebuild test \
    -project PikaProjiOS.xcodeproj \
    -scheme PikaTakeHome \
    -destination "platform=iOS Simulator,name=iPhone 16"
  ```

## Audio chunking

Audio recordings longer than **15 seconds** must be sent as chunked uploads. Call `AudioChunker.chunkedUploads(for:duration:)` and check whether the result is empty before deciding between `audioBase64` (single blob) and `audioChunks` (array). The existing training and chat services already do this — follow the same pattern for any new audio upload.

## Localization

All user-facing strings go through `AppStrings` in `Pika/App/PrototypeFlowModels.swift`. Add a new `static let` using `LocalizedStringResource("prototype.<screen>.<key>")` before referencing in a view.

## CI

GitHub Actions runs on push to `main` and on all PRs (`.github/workflows/ios-ci.yml`). The workflow:

1. Selects the latest stable Xcode on `macos-15`.
2. Resolves Swift packages.
3. Runs `xcodebuild test` against the best available simulator (iPhone 16 → 16 Pro → 15 → 15 Pro).
4. Uploads the `.xcresult` bundle and snapshot failure diffs as artifacts.

Ensure the project builds and all tests pass before merging.

## Things to avoid

- Do not call `UserDefaults` or `Keychain` APIs directly in views or view models. Go through the session stores.
- Do not hard-code the backend URL. All URL construction goes through `PikaBackendConfiguration`.
- Do not skip the feature flag check when adding backend calls. The app must run in UI-only mode with flags off.
- Do not add `NSAllowsArbitraryLoads` workarounds beyond what's already in `Info.plist` (it's already present).
- Do not add `@State` navigation variables in leaf views. Navigation state belongs in the coordinator.
