import SwiftUI

@main
struct PikaTakeHomeApp: App {
    var body: some Scene {
        WindowGroup {
            PrototypeFlowView()
                .environment(\.designSystem, DesignSystem.default)
        }
    }
}
