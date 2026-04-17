import SwiftUI

struct WelcomeScreen: View {
    @ObservedObject var viewModel: PrototypeWelcomeViewModel

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 34)

                HeroFace()
                    .frame(height: 266)
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                Spacer(minLength: 20)

                VStack(spacing: 18) {
                    VStack(spacing: 7) {
                        Text(viewModel.title)
                            .font(AppFont.telka(29, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(AppColor.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        Text(viewModel.subtitle)
                            .font(AppFont.telka(17))
                            .foregroundStyle(AppColor.textSecondary)
                    }

                    PhoneField(text: $viewModel.phoneNumber)

                    PrimaryButton(title: AppStrings.welcomeContinue, enabled: viewModel.canContinue) {
                        viewModel.continueTapped()
                    }
                    .padding(.top, 2)

                    DividerRow()

                    HStack(spacing: 14) {
                        CircleIconButton(systemName: "g.circle.fill")
                        CircleIconButton(systemName: "envelope.fill")
                    }

                    Text(AppStrings.welcomeTerms)
                        .font(AppFont.mono(11))
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(.top, 2)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, 26)
            }
        }
    }
}
