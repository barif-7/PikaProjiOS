import SwiftUI

struct PrototypeTopBar: View {
    let foregroundStyle: Color
    let buttonBackground: Color
    let action: () -> Void

    var body: some View {
        HStack {
            Button(action: action) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(foregroundStyle)
                    .frame(width: 34, height: 34)
                    .background(buttonBackground, in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

struct PhoneField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                Text("🇺🇸")
                    .font(.system(size: 16))

                Text("+1")
                    .font(AppFont.telka(16, weight: .medium))
                    .foregroundStyle(AppColor.textPrimary)
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .frame(height: AppControlSize.inputHeight)
            .background(Color.white.opacity(0.58))

            TextField(String(localized: AppStrings.phoneNumberPlaceholder), text: $text)
#if os(iOS)
                .keyboardType(.phonePad)
#endif
                .font(AppFont.telka(16))
                .foregroundStyle(AppColor.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: AppControlSize.inputHeight)
                .background(Color.white.opacity(0.58))
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .stroke(AppColor.borderSubtle.opacity(0.95), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }
}

struct PrimaryButton: View {
    let title: LocalizedStringResource
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(PikaRoundedPrimaryButtonStyle(isEnabled: enabled))
        .disabled(!enabled)
    }
}

struct SecondaryButton: View {
    let title: LocalizedStringResource
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(PikaRoundedSecondaryButtonStyle())
    }
}

struct DividerRow: View {
    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(AppColor.borderSubtle)
                .frame(height: 1)

            Text(AppStrings.continueWith)
                .font(AppFont.telka(14))
                .foregroundStyle(AppColor.textSecondary)

            Rectangle()
                .fill(AppColor.borderSubtle)
                .frame(height: 1)
        }
    }
}

struct CircleIconButton: View {
    let systemName: String

    var body: some View {
        Button(action: {}) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.textPrimary)
        }
        .buttonStyle(PikaGlassCircleButtonStyle(diameter: 44))
    }
}

struct CaptureControls: View {
    let onGallery: () -> Void
    let onShutter: () -> Void
    let onFlip: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            CircleControl(systemName: "photo.on.rectangle", action: onGallery)
            Spacer()

            Button(action: onShutter) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 74, height: 74)

                    Circle()
                        .stroke(.white, lineWidth: 5)
                        .frame(width: 92, height: 92)
                        .opacity(0.9)
                }
            }
            .buttonStyle(.plain)

            Spacer()
            CircleControl(systemName: "arrow.triangle.2.circlepath", action: onFlip)
        }
        .padding(.horizontal, 34)
    }
}

struct CircleControl: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.white.opacity(0.14), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct QuoteCard: View {
    let text: LocalizedStringResource

    var body: some View {
        Text(text)
            .font(AppFont.telka(19, weight: .medium))
            .foregroundStyle(Color(red: 0.55, green: 0.27, blue: 0.78))
            .multilineTextAlignment(.center)
            .lineSpacing(6)
            .padding(.horizontal, 16)
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.38), lineWidth: 1)
            )
    }
}

struct VoiceButton: View {
    enum Style {
        case mic
        case stop
    }

    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AppColor.accentMuted)
                    .frame(width: 108, height: 108)

                Circle()
                    .fill(AppColor.accentSecondary)
                    .frame(width: 84, height: 84)

                switch style {
                case .mic:
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                case .stop:
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppColor.textPrimary)
                        .frame(width: 28, height: 28)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct VoiceCompleteControls: View {
    let onRestart: () -> Void
    let onConfirm: () -> Void
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 26) {
            Button(action: onRestart) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
            }
            .buttonStyle(PikaGlassCircleButtonStyle(diameter: 50))

            Button(action: onConfirm) {
                ZStack {
                    Circle().fill(AppColor.accentMuted).frame(width: 108, height: 108)
                    Circle().fill(AppColor.accentSecondary).frame(width: 84, height: 84)
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                }
            }
            .buttonStyle(.plain)

            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
            }
            .buttonStyle(PikaGlassCircleButtonStyle(diameter: 50))
        }
    }
}
