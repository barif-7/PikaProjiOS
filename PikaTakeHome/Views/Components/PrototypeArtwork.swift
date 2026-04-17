import SwiftUI

struct HeroFace: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.99, green: 0.97, blue: 0.95),
                            Color(red: 0.95, green: 0.93, blue: 0.98),
                            Color(red: 0.90, green: 0.88, blue: 0.99)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Circle()
                        .fill(Color.white.opacity(0.40))
                        .frame(width: 220, height: 220)
                        .blur(radius: 18)
                        .offset(x: -84, y: -16)
                }
                .overlay {
                    ZStack {
                        Ellipse()
                            .fill(Color(red: 0.88, green: 0.84, blue: 0.98).opacity(0.45))
                            .frame(width: 280, height: 178)
                            .blur(radius: 12)
                            .offset(y: 55)

                        Ellipse()
                            .fill(Color.black.opacity(0.04))
                            .frame(width: 164, height: 220)
                            .offset(x: 6, y: 26)

                        Circle()
                            .fill(Color(red: 0.98, green: 0.80, blue: 0.74).opacity(0.95))
                            .frame(width: 116, height: 116)
                            .offset(y: 2)

                        Circle()
                            .fill(Color(red: 0.96, green: 0.89, blue: 0.84))
                            .frame(width: 100, height: 100)
                            .offset(y: 8)

                        RoundedRectangle(cornerRadius: 40, style: .continuous)
                            .fill(Color(red: 0.45, green: 0.30, blue: 0.40).opacity(0.88))
                            .frame(width: 148, height: 196)
                            .offset(y: 56)

                        Ellipse()
                            .fill(Color(red: 0.99, green: 0.94, blue: 0.90))
                            .frame(width: 62, height: 22)
                            .offset(y: 120)
                    }
                    .blur(radius: 1.1)
                    .opacity(0.95)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .softShadow()
    }
}

struct CameraPreviewCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.10, blue: 0.13),
                            Color(red: 0.18, green: 0.13, blue: 0.12),
                            Color(red: 0.10, green: 0.10, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack {
                Spacer(minLength: 28)

                PortraitSilhouette()
                    .frame(width: 320, height: 520)

                Spacer(minLength: 20)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .softShadow()
    }
}

struct PortraitSilhouette: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 290, height: 290)
                .blur(radius: 20)
                .offset(x: 20, y: 10)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.82, green: 0.58, blue: 0.52),
                            Color(red: 0.68, green: 0.33, blue: 0.25)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 180, height: 250)
                .offset(y: 42)

            Circle()
                .fill(Color(red: 0.93, green: 0.75, blue: 0.66))
                .frame(width: 118, height: 118)
                .offset(y: -54)

            Circle()
                .fill(Color(red: 0.97, green: 0.84, blue: 0.73))
                .frame(width: 104, height: 104)
                .offset(y: -48)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color(red: 0.35, green: 0.12, blue: 0.17))
                .frame(width: 160, height: 210)
                .offset(y: 58)

            Ellipse()
                .fill(Color(red: 0.24, green: 0.18, blue: 0.20).opacity(0.88))
                .frame(width: 248, height: 110)
                .offset(y: 128)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.95, green: 0.83, blue: 0.74).opacity(0.88))
                .frame(width: 92, height: 18)
                .offset(y: 116)

            Circle()
                .fill(Color.black.opacity(0.10))
                .frame(width: 18, height: 18)
                .offset(x: -24, y: -44)

            Circle()
                .fill(Color.black.opacity(0.10))
                .frame(width: 18, height: 18)
                .offset(x: 24, y: -44)
        }
        .blur(radius: 0.8)
    }
}

struct IdentityCardView: View {
    let card: PrototypeIdentityCard

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.95, blue: 0.89),
                        Color(red: 0.94, green: 0.93, blue: 0.99)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 440)

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(card.name)
                                .font(AppFont.telka(42, weight: .bold))
                                .foregroundStyle(AppColor.textPrimary)

                            Text(card.birthLabel)
                                .font(AppFont.mono(12))
                                .foregroundStyle(AppColor.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColor.textPrimary)

                            Text(card.birthDate)
                                .font(AppFont.mono(12))
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }

                    HStack(alignment: .bottom, spacing: 16) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.82, green: 0.62, blue: 0.83))
                                    .frame(width: 112, height: 112)

                                Circle()
                                    .fill(Color.white.opacity(0.34))
                                    .frame(width: 94, height: 94)

                                VStack(spacing: 3) {
                                    Circle()
                                        .fill(AppColor.textPrimary.opacity(0.12))
                                        .frame(width: 34, height: 34)

                                    Capsule()
                                        .fill(AppColor.textPrimary.opacity(0.12))
                                        .frame(width: 48, height: 12)
                                }
                            }

                            Text(AppStrings.identityProfile)
                                .font(AppFont.mono(10))
                                .foregroundStyle(AppColor.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 14) {
                            cardDetail(title: AppStrings.identityLocation, value: card.location)
                            cardDetail(title: AppStrings.identityStatus, value: card.status)
                            cardDetail(title: AppStrings.identityFindMeOn, value: card.profileLink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack {
                        Text(AppStrings.identityIdentifierLabel)
                            .font(AppFont.dots(16))
                            .foregroundStyle(AppColor.textPrimary.opacity(0.72))

                        Spacer()

                        Text(card.identifier)
                            .font(AppFont.mono(11, weight: .bold))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
                .padding(18)
            }
        }
        .frame(maxWidth: .infinity)
        .background(AppColor.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .softShadow()
    }

    private func cardDetail(title: LocalizedStringResource, value: LocalizedStringResource) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppFont.mono(10))
                .foregroundStyle(AppColor.textSecondary)

            Text(value)
                .font(AppFont.telka(14, weight: .medium))
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}
