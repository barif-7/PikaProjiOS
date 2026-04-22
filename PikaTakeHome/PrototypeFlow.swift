//
//  PrototypeFlow.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import SwiftUI

/// Root SwiftUI entry point for the prototype experience.
struct PrototypeFlowView: View {
    @StateObject private var coordinator = PrototypeCoordinator()

    var body: some View {
        PrototypeCoordinatorView(coordinator: coordinator)
    }
}
