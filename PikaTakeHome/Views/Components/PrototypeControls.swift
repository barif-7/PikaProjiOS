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
                            .padding(AppSpacing.sm)
                    } else {
                        Image(systemName: "chevron.left")
                            .font(AppFont.telka(17, weight: .medium))
                            .foregroundStyle(foregroundStyle)
                    }
                }
                .frame(width: AppControlSize.topButton, height: AppControlSize.topButton)
                .background(buttonBackground, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
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
            HStack(spacing: AppSpacing.xxxs) {
                Text("🇺🇸")
                    .font(AppFont.mono(16))
                    .foregroundStyle(AppColor.textPrimary)

                Text("+1")
                    .font(AppFont.mono(16))
                    .foregroundStyle(Color(red: 141 / 255, green: 141 / 255, blue: 143 / 255))
            }
            .padding(.leading, AppSpacing.fieldLeadingInset)
            .padding(.trailing, AppSpacing.fieldTrailingInset)
            .frame(height: AppControlSize.inputHeight)
            .background(AppColor.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(String(localized: AppStrings.phoneNumberPlaceholder))
                        .font(AppFont.telka(17))
                        .foregroundStyle(AppColor.textPrimary.opacity(0.5))
                        .allowsHitTesting(false)
                }

                TextField("", text: $text)
#if os(iOS)
                    .keyboardType(.phonePad)
#endif
                    .font(AppFont.telka(17))
                    .foregroundStyle(AppColor.textPrimary)
            }
            .padding(.horizontal, AppSpacing.fieldContentHorizontal)
            .frame(height: AppControlSize.inputHeight)
            .background(Color.clear)
        }
        .padding(AppSpacing.fieldInset)
        .background(AppColor.surfaceField)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .stroke(AppColor.borderSubtle, lineWidth: 1)
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
    var fontSize: CGFloat = 17
    var height: CGFloat = AppControlSize.primaryButtonHeight
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
                backgroundColor: backgroundColor,
                fontSize: fontSize,
                height: height
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
    var body: some View {
        HStack(spacing: AppSpacing.xs + 2) {
            dividerLine

            Text(AppStrings.continueWith)
                .font(AppFont.telka(12, weight: .medium))
                .foregroundStyle(AppColor.textTertiary)

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
        .padding(.horizontal, AppSpacing.cameraControlsHorizontal)
    }
}

struct CircleControl: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(AppFont.telka(20, weight: .medium))
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
            .foregroundStyle(AppColor.accentQuote)
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
    var outerDiameter: CGFloat = AppControlSize.voiceButton
    var innerDiameter: CGFloat = AppControlSize.voiceButtonInner
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
                            .font(AppFont.telka(symbolSize, weight: .bold))
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
        HStack(spacing: 55) {
            Button(action: onRestart) {
                Image(systemName: "arrow.counterclockwise")
                    .font(AppFont.telka(18, weight: .medium))
                    .foregroundStyle(AppColor.textPrimary)
            }
            .buttonStyle(PikaGlassCircleButtonStyle(diameter: AppControlSize.compactIconButton))

            Button(action: onConfirm) {
                ZStack {
                    Circle().fill(AppColor.accentMuted).frame(width: AppControlSize.voiceButton, height: AppControlSize.voiceButton)
                    Circle().fill(AppColor.accentSecondary).frame(width: AppControlSize.voiceButton, height: AppControlSize.voiceButton)
                    Image(systemName: "checkmark")
                        .font(AppFont.telka(20, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                }
            }
            .buttonStyle(.plain)

            Button(action: onPlay) {
                importedIcon(.videoLinePrimary, size: 20, fallback: "play.fill")
            }
            .buttonStyle(PikaGlassCircleButtonStyle(diameter: AppControlSize.compactIconButton))
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
            .font(AppFont.telka(size * 0.8, weight: .medium))
            .foregroundStyle(AppColor.textPrimary)
    }
}
