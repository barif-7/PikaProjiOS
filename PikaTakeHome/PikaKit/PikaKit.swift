//
//  PikaKit.swift
//  PikaTakeHome
//
//  Created by Basil Arif on 4/20/26.
//

import SwiftUI
import UIKit

enum PikaKit {
    static let current = PikaKitServices()

    static var fonts: PikaFontProviding { current.fonts }
    static var colors: PikaColorProviding { current.colors }
    static var images: PikaImageProviding { current.images }

    typealias Fonts = PikaFonts
    typealias Colors = PikaColors
    typealias Images = PikaImages
    typealias Spacing = AppSpacing
    typealias Radius = AppRadius
    typealias ControlSize = AppControlSize
    typealias Shadow = AppShadow
}

struct PikaKitServices {
    let fonts: PikaFontProviding
    let colors: PikaColorProviding
    let images: PikaImageProviding

    init(
        fonts: PikaFontProviding = PikaFontProvider(),
        colors: PikaColorProviding = PikaColorProvider(),
        images: PikaImageProviding = PikaImageProvider()
    ) {
        self.fonts = fonts
        self.colors = colors
        self.images = images
    }
}

protocol PikaFontProviding {
    func telka(_ size: CGFloat, weight: Font.Weight) -> Font
    func telkaCompact(_ size: CGFloat, weight: Font.Weight) -> Font
    func mono(_ size: CGFloat, weight: Font.Weight) -> Font
    func dots(_ size: CGFloat) -> Font
}

struct PikaFontProvider: PikaFontProviding {
    func telka(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        AppFont.telka(size, weight: weight)
    }

    func telkaCompact(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        AppFont.telkaCompact(size, weight: weight)
    }

    func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        AppFont.mono(size, weight: weight)
    }

    func dots(_ size: CGFloat) -> Font {
        AppFont.dots(size)
    }
}

enum PikaFonts {
    static func telka(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        PikaKit.fonts.telka(size, weight: weight)
    }

    static func telkaCompact(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        PikaKit.fonts.telkaCompact(size, weight: weight)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        PikaKit.fonts.mono(size, weight: weight)
    }

    static func dots(_ size: CGFloat) -> Font {
        PikaKit.fonts.dots(size)
    }
}

protocol PikaColorProviding {
    var screenBackground: Color { get }
    var screenBackgroundElevated: Color { get }
    var surfacePrimary: Color { get }
    var surfaceSecondary: Color { get }
    var surfaceAccent: Color { get }
    var surfaceChrome: Color { get }
    var surfaceField: Color { get }
    var surfaceGlass: Color { get }
    var surfaceOverlay: Color { get }
    var surfaceSuccessCardTop: Color { get }
    var surfaceSuccessCardBottom: Color { get }
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textTertiary: Color { get }
    var textInverse: Color { get }
    var borderSubtle: Color { get }
    var accentPrimary: Color { get }
    var accentSecondary: Color { get }
    var accentMuted: Color { get }
    var accentQuote: Color { get }
    var cameraBackground: Color { get }
    var successPrimaryButton: Color { get }
    var shadow: Color { get }
}

struct PikaColorProvider: PikaColorProviding {
    let screenBackground = AppColor.screenBackground
    let screenBackgroundElevated = AppColor.screenBackgroundElevated
    let surfacePrimary = AppColor.surfacePrimary
    let surfaceSecondary = AppColor.surfaceSecondary
    let surfaceAccent = AppColor.surfaceAccent
    let surfaceChrome = AppColor.surfaceChrome
    let surfaceField = AppColor.surfaceField
    let surfaceGlass = AppColor.surfaceGlass
    let surfaceOverlay = AppColor.surfaceOverlay
    let surfaceSuccessCardTop = AppColor.surfaceSuccessCardTop
    let surfaceSuccessCardBottom = AppColor.surfaceSuccessCardBottom
    let textPrimary = AppColor.textPrimary
    let textSecondary = AppColor.textSecondary
    let textTertiary = AppColor.textTertiary
    let textInverse = AppColor.textInverse
    let borderSubtle = AppColor.borderSubtle
    let accentPrimary = AppColor.accentPrimary
    let accentSecondary = AppColor.accentSecondary
    let accentMuted = AppColor.accentMuted
    let accentQuote = AppColor.accentQuote
    let cameraBackground = AppColor.cameraBackground
    let successPrimaryButton = AppColor.successPrimaryButton
    let shadow = AppColor.shadow
}

enum PikaColors {
    static var screenBackground: Color { PikaKit.colors.screenBackground }
    static var screenBackgroundElevated: Color { PikaKit.colors.screenBackgroundElevated }
    static var surfacePrimary: Color { PikaKit.colors.surfacePrimary }
    static var surfaceSecondary: Color { PikaKit.colors.surfaceSecondary }
    static var surfaceAccent: Color { PikaKit.colors.surfaceAccent }
    static var surfaceChrome: Color { PikaKit.colors.surfaceChrome }
    static var surfaceField: Color { PikaKit.colors.surfaceField }
    static var surfaceGlass: Color { PikaKit.colors.surfaceGlass }
    static var surfaceOverlay: Color { PikaKit.colors.surfaceOverlay }
    static var surfaceSuccessCardTop: Color { PikaKit.colors.surfaceSuccessCardTop }
    static var surfaceSuccessCardBottom: Color { PikaKit.colors.surfaceSuccessCardBottom }
    static var textPrimary: Color { PikaKit.colors.textPrimary }
    static var textSecondary: Color { PikaKit.colors.textSecondary }
    static var textTertiary: Color { PikaKit.colors.textTertiary }
    static var textInverse: Color { PikaKit.colors.textInverse }
    static var borderSubtle: Color { PikaKit.colors.borderSubtle }
    static var accentPrimary: Color { PikaKit.colors.accentPrimary }
    static var accentSecondary: Color { PikaKit.colors.accentSecondary }
    static var accentMuted: Color { PikaKit.colors.accentMuted }
    static var accentQuote: Color { PikaKit.colors.accentQuote }
    static var cameraBackground: Color { PikaKit.colors.cameraBackground }
    static var successPrimaryButton: Color { PikaKit.colors.successPrimaryButton }
    static var shadow: Color { PikaKit.colors.shadow }
}

enum PikaSystemImage: String {
    case back = "chevron.left"
    case close = "xmark"
    case checkmark = "checkmark"
    case checkmarkCircleFill = "checkmark.circle.fill"
    case gear = "gearshape.fill"
    case hare = "hare.fill"
    case microphone = "mic.fill"
    case play = "play.fill"
    case restart = "arrow.counterclockwise"
    case waveformCircle = "waveform.circle.fill"
}

protocol PikaImageProviding {
    func system(named name: String) -> Image
    func system(_ name: PikaSystemImage) -> Image
    func path(for asset: ImportedAsset) -> String?
    func bitmap(for asset: ImportedAsset) -> UIImage?
}

struct PikaImageProvider: PikaImageProviding {
    func system(named name: String) -> Image {
        Image(systemName: name)
    }

    func system(_ name: PikaSystemImage) -> Image {
        system(named: name.rawValue)
    }

    func path(for asset: ImportedAsset) -> String? {
        asset.bundlePath
    }

    func bitmap(for asset: ImportedAsset) -> UIImage? {
        BitmapImageStore.shared.image(for: asset)
    }
}

enum PikaImages {
    static func system(named name: String) -> Image {
        PikaKit.images.system(named: name)
    }

    static func system(_ name: PikaSystemImage) -> Image {
        PikaKit.images.system(name)
    }

    static func path(for asset: ImportedAsset) -> String? {
        PikaKit.images.path(for: asset)
    }

    static func bitmap(for asset: ImportedAsset) -> UIImage? {
        PikaKit.images.bitmap(for: asset)
    }
}
