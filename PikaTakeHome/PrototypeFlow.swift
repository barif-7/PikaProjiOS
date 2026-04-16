import SwiftUI

struct PrototypeFlowView: View {
    @StateObject private var coordinator = PrototypeCoordinator()

    var body: some View {
        PrototypeCoordinatorView(coordinator: coordinator)
    }
}

