//
//  SuccessScreen.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import SwiftUI

/// Completion screen that presents the generated AI-self card and next actions.
struct SuccessScreen: View {
    @ObservedObject var viewModel: PrototypeSuccessViewModel
    @Environment(\.designSystem) private var designSystem

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let horizontalPadding = max(designSystem.spacing.md, min(designSystem.spacing.xl, size.width * 0.05))
            let topPadding = max(12.0, proxy.safeAreaInsets.top + 8.0)
            let bottomPadding = max(20.0, proxy.safeAreaInsets.bottom + 12.0)
            let titleFontSize = min(31.0, max(26.0, size.width * 0.08))
            let subtitleFontSize = min(17.0, max(15.0, size.width * 0.044))
            let glowWidth = min(size.width * 1.9, 708.0)
            let glowHeight = glowWidth * (787.0 / 708.0)
            let cardMaxWidth = min(size.width - (horizontalPadding * 2.0), 420.0)

            ZStack(alignment: .top) {
                designSystem.colors.screenBackground.ignoresSafeArea()

                if ImportedAsset.successGlow.existsInBundle {
                    ImportedSVGView(asset: .successGlow)
                        .frame(width: glowWidth, height: glowHeight)
                        .offset(x: -size.width * 0.08, y: -glowHeight * 0.34)
                        .allowsHitTesting(false)
                }

                VStack(spacing: 0) {
                    HStack {
                        Spacer()

                        Button {
                            viewModel.closeTapped()
                        } label: {
                            Group {
                                if ImportedAsset.closeIcon.existsInBundle {
                                    ImportedSVGView(asset: .closeIcon)
                                        .padding(12)
                                } else {
                                    Image(systemName: "xmark")
                                        .font(designSystem.fonts.telka(13, weight: .medium))
                                        .foregroundStyle(designSystem.colors.textPrimary)
                                }
                            }
                            .frame(width: designSystem.controlSize.closeButton, height: designSystem.controlSize.closeButton)
                            .background(designSystem.colors.surfaceChrome, in: RoundedRectangle(cornerRadius: designSystem.radius.sm, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: designSystem.radius.sm, style: .continuous)
                                    .stroke(designSystem.colors.borderSubtle, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, topPadding)

                    Spacer(minLength: max(12.0, size.height * 0.02))

                    VStack(spacing: designSystem.spacing.sm) {
                        Text(viewModel.title)
                            .font(designSystem.fonts.telka(titleFontSize, weight: .bold))
                            .foregroundStyle(designSystem.colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.85)
                            .lineLimit(2)

                        Text(viewModel.subtitle)
                            .font(designSystem.fonts.telka(subtitleFontSize))
                            .foregroundStyle(designSystem.colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.9)
                            .lineLimit(3)
                    }
                    .padding(.horizontal, horizontalPadding)

                    Spacer(minLength: max(16.0, size.height * 0.025))

                    IdentityCardView(card: viewModel.identityCard)
                        .frame(maxWidth: cardMaxWidth)
                        .padding(.horizontal, horizontalPadding)

                    Spacer(minLength: max(20.0, size.height * 0.03))

                    VStack(spacing: 10) {
                        PrimaryButton(
                            title: AppStrings.successOpenMessages,
                            enabled: true,
                            trailingAsset: .arrowTopRight,
                            textColor: designSystem.colors.textInverse,
                            backgroundColor: designSystem.colors.successPrimaryButton,
                            fontSize: 15,
                            height: designSystem.controlSize.secondaryButtonHeight,
                            action: { viewModel.openMessagesTapped() }
                        )
                        // TODO: Wire up share-ID-card flow when the share sheet is implemented.
                        SecondaryButton(title: AppStrings.successShareIDCard, trailingAsset: .shareIcon, action: {})
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, bottomPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(width: size.width, height: size.height)
        }
    }
}
