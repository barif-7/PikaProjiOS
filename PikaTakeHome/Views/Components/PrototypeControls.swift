import SwiftUI

struct PrototypeTopBar: View {
    let foregroundStyle: Color
    let buttonBackground: Color
    let action: () -> Void

    var body: some View {
        HStack {
            Button(action: action) {
                Group {
                    if ImportedAsset.chevronLeft.existsInBundle {
                        ImportedSVGView(asset: .chevronLeft)
                            .padding(14)
                    } else {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(foregroundStyle)
                    }
                }
                .frame(width: 48, height: 48)
                .background(buttonBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

struct PhoneField: View {
    @Binding var text: String

    private let darkPrimary = Color(red: 13 / 255, green: 13 / 255, blue: 13 / 255)
    private let darkPrimaryMuted = Color(red: 13 / 255, green: 13 / 255, blue: 13 / 255).opacity(0.5)
    private let countryCodeMuted = Color(red: 141 / 255, green: 141 / 255, blue: 143 / 255)

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                Text("🇺🇸")
                    .font(.system(size: 16))

                Text("+1")
                    .font(AppFont.mono(16))
                    .foregroundStyle(countryCodeMuted)
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .frame(height: AppControlSize.inputHeight)
            .background(Color.white.opacity(0.58))

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(String(localized: AppStrings.phoneNumberPlaceholder))
                        .font(AppFont.telka(17))
                        .foregroundStyle(darkPrimaryMuted)
                        .allowsHitTesting(false)
                }

                TextField("", text: $text)
#if os(iOS)
                    .keyboardType(.phonePad)
#endif
                    .font(AppFont.telka(17))
                    .foregroundStyle(darkPrimary)
            }
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
    var trailingAsset: ImportedAsset? = nil
    var textColor: Color? = nil
    var backgroundColor: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)

                if let trailingAsset {
                    importedIcon(trailingAsset, size: 20, fallback: "arrow.up.right")
                }
            }
        }
        .buttonStyle(
            PikaRoundedPrimaryButtonStyle(
                isEnabled: enabled,
                textColor: textColor,
                backgroundColor: backgroundColor
            )
        )
        .disabled(!enabled)
    }
}

struct SecondaryButton: View {
    let title: LocalizedStringResource
    var trailingAsset: ImportedAsset? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)

                if let trailingAsset {
                    importedIcon(trailingAsset, size: 20, fallback: "square.and.arrow.up")
                }
            }
        }
        .buttonStyle(PikaRoundedSecondaryButtonStyle())
    }
}

struct DividerRow: View {
    private let dividerText = Color(red: 34 / 255, green: 34 / 255, blue: 34 / 255).opacity(0.5)

    var body: some View {
        HStack(spacing: 10) {
            dividerLine

            Text(AppStrings.continueWith)
                .font(AppFont.telka(12, weight: .medium))
                .foregroundStyle(dividerText)

            dividerLine
        }
    }

    @ViewBuilder
    private var dividerLine: some View {
        if ImportedAsset.dividerLine.existsInBundle {
            ImportedSVGView(asset: .dividerLine)
                .frame(height: 1)
        } else {
            Rectangle()
                .fill(AppColor.borderSubtle)
                .frame(height: 1)
        }
    }
}

struct CircleIconButton: View {
    let asset: ImportedAsset
    let fallbackSystemName: String

    var body: some View {
        Button(action: {}) {
            importedIcon(asset, size: 24, fallback: fallbackSystemName)
        }
        .buttonStyle(PikaGlassCircleButtonStyle(diameter: AppControlSize.iconButton))
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
    var outerDiameter: CGFloat = 108
    var innerDiameter: CGFloat = 84
    var symbolSize: CGFloat = 28
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AppColor.accentMuted)
                    .frame(width: outerDiameter, height: outerDiameter)

                Circle()
                    .fill(AppColor.accentSecondary)
                    .frame(width: innerDiameter, height: innerDiameter)

                switch style {
                case .mic:
                    if ImportedAsset.voiceRecordButton.existsInBundle {
                        ImportedSVGView(asset: .voiceRecordButton)
                            .padding(6)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: symbolSize, weight: .bold))
                            .foregroundStyle(AppColor.textPrimary)
                    }
                case .stop:
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppColor.textPrimary)
                        .frame(width: symbolSize, height: symbolSize)
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
        HStack(spacing: 21) {
            Button(action: onRestart) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
            }
            .buttonStyle(PikaGlassCircleButtonStyle(diameter: 50))

            Button(action: onConfirm) {
                ZStack {
                    Circle().fill(AppColor.accentMuted).frame(width: 80, height: 80)
                    Circle().fill(AppColor.accentSecondary).frame(width: 64, height: 64)
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                }
            }
            .buttonStyle(.plain)

            Button(action: onPlay) {
                importedIcon(.videoLinePrimary, size: 20, fallback: "play.fill")
            }
            .buttonStyle(PikaGlassCircleButtonStyle(diameter: 50))
        }
    }
}

@ViewBuilder
private func importedIcon(_ asset: ImportedAsset, size: CGFloat, fallback: String) -> some View {
    if asset.existsInBundle, asset.isSVG {
        ImportedSVGView(asset: asset)
            .frame(width: size, height: size)
    } else {
        Image(systemName: fallback)
            .font(.system(size: size * 0.8, weight: .semibold))
            .foregroundStyle(AppColor.textPrimary)
    }
}
