//
//  PikaTakeHomeApp.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import SwiftUI

/// Application entry point.
@main
struct PikaTakeHomeApp: App {
    var body: some Scene {
        WindowGroup {
            PrototypeFlowView()
                .environment(\.designSystem, DesignSystem.default)
        }
    }
}
