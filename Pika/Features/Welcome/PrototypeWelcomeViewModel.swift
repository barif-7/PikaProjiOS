//
//  PrototypeWelcomeViewModel.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import SwiftUI

/// View model for the sign-in/onboarding entry screen.
@MainActor
final class PrototypeWelcomeViewModel: ObservableObject {
    @Published var phoneNumber = ""
    @Published private(set) var isAuthenticating = false
    @Published private(set) var authErrorMessage: String?

    var onContinueRequested: (() -> Void)?
    var onGoogleRequested: (() -> Void)?

    let title = AppStrings.welcomeTitle
    let subtitle = AppStrings.welcomeSubtitle

    init(phoneNumber: String = "") {
        self.phoneNumber = phoneNumber
    }

    var canContinue: Bool {
        phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).count >= 7
    }

    func continueTapped() {
        guard canContinue else { return }
        onContinueRequested?()
    }

    func googleTapped() {
        onGoogleRequested?()
    }

    func reset(phoneNumber: String = "") {
        self.phoneNumber = phoneNumber
        authErrorMessage = nil
        isAuthenticating = false
    }

    func setAuthenticating(_ value: Bool) {
        isAuthenticating = value
        if value {
            authErrorMessage = nil
        }
    }

    func presentAuthError(_ message: String?) {
        authErrorMessage = message
        isAuthenticating = false
    }

    func clearAuthError() {
        authErrorMessage = nil
    }
}
