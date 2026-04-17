import SwiftUI

struct SuccessScreen: View {
    @ObservedObject var viewModel: PrototypeSuccessViewModel

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()

                    Button {
                        viewModel.closeTapped()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColor.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(AppColor.surfaceSecondary, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                Spacer(minLength: 14)

                VStack(spacing: 12) {
                    Text(viewModel.title)
                        .font(AppFont.telka(31, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)

                    Text(viewModel.subtitle)
                        .font(AppFont.telka(17))
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer(minLength: 20)

                IdentityCardView(card: viewModel.identityCard)
                    .padding(.horizontal, 20)

                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    PrimaryButton(title: AppStrings.successOpenMessages, enabled: true, action: {})
                    SecondaryButton(title: AppStrings.successShareIDCard, action: {})
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
    }
}
