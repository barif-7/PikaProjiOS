import SwiftUI

struct SuccessScreen: View {
    @ObservedObject var viewModel: PrototypeSuccessViewModel

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let horizontalPadding = max(16.0, min(24.0, size.width * 0.05))
            let topPadding = max(12.0, proxy.safeAreaInsets.top + 8.0)
            let bottomPadding = max(20.0, proxy.safeAreaInsets.bottom + 12.0)
            let titleFontSize = min(31.0, max(26.0, size.width * 0.08))
            let subtitleFontSize = min(17.0, max(15.0, size.width * 0.044))
            let glowWidth = min(size.width * 1.9, 708.0)
            let glowHeight = glowWidth * (787.0 / 708.0)
            let cardMaxWidth = min(size.width - (horizontalPadding * 2.0), 420.0)

            ZStack(alignment: .top) {
                AppColor.screenBackground.ignoresSafeArea()

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
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppColor.textPrimary)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(AppColor.borderSubtle.opacity(0.35), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, topPadding)

                    Spacer(minLength: max(12.0, size.height * 0.02))

                    VStack(spacing: 12) {
                        Text(viewModel.title)
                            .font(AppFont.telka(titleFontSize, weight: .bold))
                            .foregroundStyle(AppColor.textPrimary)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.85)
                            .lineLimit(2)

                        Text(viewModel.subtitle)
                            .font(AppFont.telka(subtitleFontSize))
                            .foregroundStyle(AppColor.textSecondary)
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

                    VStack(spacing: 12) {
                        PrimaryButton(title: AppStrings.successOpenMessages, enabled: true, trailingAsset: .arrowTopRight, action: {})
                        SecondaryButton(title: AppStrings.successShareIDCard, trailingAsset: .shareIcon, action: {})
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, bottomPadding)
                }
                .frame(width: size.width, height: size.height, alignment: .top)
            }
            .frame(width: size.width, height: size.height)
        }
    }
}
