import AVFoundation
import AVKit
import SwiftUI
import WebKit

enum ImportedAsset: String {
    case onboardingHero = "AppHeroVideo-720x1280-optimized.mp4"
    case onboardingHeroProxy = "AppHeroVideo-540x960-proxy.mp4"
    case onboardingBackgroundAudio = "onboarding-background-audio.m4a"
    case voiceBackground = "voice-background.png"
    case semiPortrait = "semi-portrait.png"
    case chevronLeft = "chevron-left.svg"
    case dividerLine = "divider-line.svg"
    case googleIcon = "google-icon.svg"
    case mailIcon = "mail-icon.svg"
    case voiceRecordButton = "voice-record-button.svg"
    case progressLine = "progress-line.svg"
    case videoLinePrimary = "video-line-primary.svg"
    case arrowTopRight = "arrow-top-right.svg"
    case shareIcon = "share-icon.svg"
    case closeIcon = "close-icon.svg"
    case successGlow = "success-glow.svg"
    case idRabbitMark = "id-rabbit-mark.svg"
    case idNameRule = "id-name-rule.svg"
    case idFieldRule = "id-field-rule.svg"
    case idBarcode = "id-barcode.svg"

    var fileName: String { rawValue }

    var fileExtension: String {
        (fileName as NSString).pathExtension
    }

    var resourceName: String {
        (fileName as NSString).deletingPathExtension
    }

    var bundlePath: String? {
        Bundle.main.path(forResource: resourceName, ofType: fileExtension, inDirectory: "ImportedAssets")
    }

    var existsInBundle: Bool {
        guard let bundlePath else { return false }
        return FileManager.default.fileExists(atPath: bundlePath)
    }

    var isSVG: Bool {
        fileExtension.lowercased() == "svg"
    }
}

struct ImportedBitmapImage: View {
    let asset: ImportedAsset
    let contentMode: ContentMode

    var body: some View {
        if let bundlePath = asset.bundlePath, let uiImage = UIImage(contentsOfFile: bundlePath) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        }
    }
}

final class BackgroundAudioStore {
    static let shared = BackgroundAudioStore()

    private var players: [String: AVAudioPlayer] = [:]
    private var fadeTimers: [String: Timer] = [:]

    private init() {}

    func prewarm(_ asset: ImportedAsset) {
        _ = player(for: asset)
    }

    func play(_ asset: ImportedAsset, volume: Float = 0.42) {
        guard let bundlePath = asset.bundlePath, let player = player(for: asset) else { return }
        configureSessionIfNeeded()
        fadeTimers[bundlePath]?.invalidate()
        fadeTimers[bundlePath] = nil

        if !player.isPlaying {
            player.currentTime = 0
            player.volume = 0
            player.play()
        }

        fade(player: player, assetPath: bundlePath, targetVolume: volume, duration: 0.45, stopOnCompletion: false)
    }

    func stop(_ asset: ImportedAsset) {
        guard let bundlePath = asset.bundlePath, let player = players[bundlePath] else { return }
        fadeTimers[bundlePath]?.invalidate()
        fade(player: player, assetPath: bundlePath, targetVolume: 0, duration: 0.35, stopOnCompletion: true)
    }

    private func player(for asset: ImportedAsset) -> AVAudioPlayer? {
        guard let bundlePath = asset.bundlePath else { return nil }

        if let cached = players[bundlePath] {
            return cached
        }

        let url = URL(fileURLWithPath: bundlePath)
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }

        player.numberOfLoops = -1
        player.prepareToPlay()
        players[bundlePath] = player
        return player
    }

    private func configureSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [])
        try? session.setActive(true)
    }

    private func fade(
        player: AVAudioPlayer,
        assetPath: String,
        targetVolume: Float,
        duration: TimeInterval,
        stopOnCompletion: Bool
    ) {
        let startVolume = player.volume
        let steps = max(Int(duration / 0.05), 1)
        var currentStep = 0

        let timer = Timer.scheduledTimer(withTimeInterval: duration / Double(steps), repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            currentStep += 1
            let progress = min(Float(currentStep) / Float(steps), 1)
            player.volume = startVolume + ((targetVolume - startVolume) * progress)

            if currentStep >= steps {
                timer.invalidate()
                self.fadeTimers[assetPath] = nil
                player.volume = targetVolume

                if stopOnCompletion {
                    player.stop()
                    player.currentTime = 0
                }
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        fadeTimers[assetPath] = timer
    }
}

struct ImportedLoopingVideoView: UIViewRepresentable {
    let asset: ImportedAsset
    var onReadyForDisplay: (() -> Void)? = nil

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.onReadyForDisplay = onReadyForDisplay
        view.configure(with: asset)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.onReadyForDisplay = onReadyForDisplay
        uiView.configure(with: asset)
    }
}

final class LoopingVideoPlayback {
    let assetPath: String
    let player: AVQueuePlayer
    let looper: AVPlayerLooper

    init?(asset: ImportedAsset) {
        guard let bundlePath = asset.bundlePath else { return nil }

        assetPath = bundlePath

        let item = AVPlayerItem(url: URL(fileURLWithPath: bundlePath))
        let player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none
        player.automaticallyWaitsToMinimizeStalling = false

        self.player = player
        looper = AVPlayerLooper(player: player, templateItem: item)
    }
}

final class VideoThumbnailStore {
    static let shared = VideoThumbnailStore()

    private let queue = DispatchQueue(label: "com.openclaw.pika.video-thumbnail", qos: .userInitiated)
    private var images: [String: UIImage] = [:]
    private var callbacks: [String: [(UIImage?) -> Void]] = [:]
    private var inflight: Set<String> = []

    private init() {}

    func prewarm(_ asset: ImportedAsset) {
        guard let bundlePath = asset.bundlePath else { return }
        requestImage(for: bundlePath, completion: { _ in })
    }

    func image(for asset: ImportedAsset, completion: @escaping (UIImage?) -> Void) {
        guard let bundlePath = asset.bundlePath else {
            completion(nil)
            return
        }

        requestImage(for: bundlePath, completion: completion)
    }

    private func requestImage(for path: String, completion: @escaping (UIImage?) -> Void) {
        if let cached = images[path] {
            completion(cached)
            return
        }

        callbacks[path, default: []].append(completion)
        guard !inflight.contains(path) else { return }

        inflight.insert(path)

        queue.async { [weak self] in
            guard let self else { return }

            let asset = AVAsset(url: URL(fileURLWithPath: path))
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 720, height: 1280)

            let time = CMTime(seconds: 0.05, preferredTimescale: 600)
            var renderedImage: UIImage?

            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                renderedImage = UIImage(cgImage: cgImage)
            }

            DispatchQueue.main.async {
                self.inflight.remove(path)
                if let renderedImage {
                    self.images[path] = renderedImage
                }

                let pending = self.callbacks.removeValue(forKey: path) ?? []
                pending.forEach { $0(renderedImage) }
            }
        }
    }
}

final class LoopingVideoStore {
    static let shared = LoopingVideoStore()

    private var playbacks: [String: LoopingVideoPlayback] = [:]

    private init() {}

    func prewarm(_ asset: ImportedAsset) {
        _ = playback(for: asset)
    }

    func playback(for asset: ImportedAsset) -> LoopingVideoPlayback? {
        guard let bundlePath = asset.bundlePath else { return nil }

        if let cached = playbacks[bundlePath] {
            return cached
        }

        guard let playback = LoopingVideoPlayback(asset: asset) else { return nil }
        playbacks[bundlePath] = playback
        return playback
    }
}

final class PlayerContainerView: UIView {
    private let playerLayer = AVPlayerLayer()
    private let previewImageView = UIImageView()
    private var configuredAssetPath: String?
    private var readyObservation: NSKeyValueObservation?
    private var hasReportedReady = false
    var onReadyForDisplay: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(previewImageView)
        layer.addSublayer(playerLayer)
        previewImageView.contentMode = .scaleAspectFill
        previewImageView.clipsToBounds = true
        previewImageView.backgroundColor = .white
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.opacity = 0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewImageView.frame = bounds
        playerLayer.frame = bounds
    }

    func configure(with asset: ImportedAsset) {
        guard let playback = LoopingVideoStore.shared.playback(for: asset) else { return }
        if configuredAssetPath != playback.assetPath {
            configuredAssetPath = playback.assetPath
            playerLayer.player = playback.player
            playerLayer.opacity = 0
            previewImageView.alpha = 1
            previewImageView.image = nil
            hasReportedReady = false

            readyObservation = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
                guard let self, layer.isReadyForDisplay else { return }

                if !self.hasReportedReady {
                    self.hasReportedReady = true
                    self.onReadyForDisplay?()
                }

                UIView.animate(withDuration: 0.18) {
                    self.playerLayer.opacity = 1
                    self.previewImageView.alpha = 0
                }
            }

            VideoThumbnailStore.shared.image(for: asset) { [weak self] image in
                guard let self, self.configuredAssetPath == playback.assetPath else { return }
                self.previewImageView.image = image
            }
        }

        playback.player.playImmediately(atRate: 1.0)
    }
}

struct OnboardingHeroBackground: View {
    @State private var canPromoteToHighQuality = false
    @State private var highQualityReady = false
    @State private var hasStartedProxy = false
    var onPrimaryPlaybackStarted: (() -> Void)? = nil

    var body: some View {
        ZStack {
            ImportedLoopingVideoView(asset: .onboardingHeroProxy) {
                guard !hasStartedProxy else { return }
                hasStartedProxy = true
                onPrimaryPlaybackStarted?()
            }

            if canPromoteToHighQuality {
                ImportedLoopingVideoView(asset: .onboardingHero) {
                    highQualityReady = true
                }
                .opacity(highQualityReady ? 1 : 0)
                .animation(.easeInOut(duration: 0.24), value: highQualityReady)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(1200))
            LoopingVideoStore.shared.prewarm(.onboardingHero)
            VideoThumbnailStore.shared.prewarm(.onboardingHero)
            canPromoteToHighQuality = true
        }
    }
}

struct ImportedSVGView: UIViewRepresentable {
    let asset: ImportedAsset

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.isUserInteractionEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard
            asset.isSVG,
            let bundlePath = asset.bundlePath,
            let svgMarkup = try? String(contentsOfFile: bundlePath, encoding: .utf8)
        else {
            webView.loadHTMLString("", baseURL: nil)
            return
        }

        let html = """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <style>
        html, body {
          margin: 0;
          padding: 0;
          width: 100%;
          height: 100%;
          overflow: hidden;
          background: transparent;
        }
        body, svg {
          width: 100%;
          height: 100%;
        }
        svg {
          display: block;
        }
        </style>
        </head>
        <body>\(svgMarkup)</body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
    }
}

struct HeroFace: View {
    var onPrimaryPlaybackStarted: (() -> Void)? = nil

    var body: some View {
        GeometryReader { proxy in
            if ImportedAsset.onboardingHero.existsInBundle {
                OnboardingHeroBackground(onPrimaryPlaybackStarted: onPrimaryPlaybackStarted)
                    .frame(
                        width: max(proxy.size.width, proxy.size.height * 0.62),
                        height: proxy.size.height
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .overlay(
                        ZStack {
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.56),
                                    Color.white.opacity(0.2),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )

                            LinearGradient(
                                stops: [
                                    .init(color: .white, location: 0),
                                    .init(color: Color.white.opacity(0.94), location: 0.14),
                                    .init(color: Color.white.opacity(0.72), location: 0.24),
                                    .init(color: Color.white.opacity(0.28), location: 0.38),
                                    .init(color: .clear, location: 0.58)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        }
                    )
                    .clipped()
            } else {
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
            HStack(alignment: .top, spacing: 16) {
                portrait

                Spacer(minLength: 0)

                if ImportedAsset.idRabbitMark.existsInBundle {
                    ImportedSVGView(asset: .idRabbitMark)
                        .frame(width: 28, height: 24)
                        .padding(.top, 4)
                } else {
                    Image(systemName: "hare.fill")
                        .font(AppFont.telka(24, weight: .black))
                        .foregroundStyle(AppColor.textPrimary)
                        .padding(.top, 4)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(AppFont.telka(21.5, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                if ImportedAsset.idNameRule.existsInBundle {
                    ImportedSVGView(asset: .idNameRule)
                        .frame(height: 3)
                } else {
                    Rectangle()
                        .fill(AppColor.textPrimary)
                        .frame(height: 2.5)
                }
            }
            .padding(.top, 16)

            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    cardField(title: card.birthLabel, value: card.birthDate)
                    cardField(title: AppStrings.identityLocation, value: card.location)
                    cardField(title: AppStrings.identityStatus, value: card.status)
                    cardField(title: AppStrings.identityFindMeOn, value: card.profileLink)
                }

                Spacer(minLength: 0)

                if ImportedAsset.idBarcode.existsInBundle {
                    ImportedSVGView(asset: .idBarcode)
                        .frame(width: 40, height: 124)
                        .padding(.bottom, 4)
                }
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            LinearGradient(
                colors: [
                    AppColor.surfaceSuccessCardTop,
                    AppColor.surfaceSuccessCardBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                .stroke(AppColor.successStroke, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 30, x: 8, y: 14)
    }

    private var portrait: some View {
        Group {
            if let avatarImage = card.avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
            } else if ImportedAsset.semiPortrait.existsInBundle {
                ImportedBitmapImage(asset: .semiPortrait, contentMode: .fill)
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.87, green: 0.88, blue: 0.90),
                        Color(red: 0.95, green: 0.96, blue: 0.98)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(width: 158, height: 218)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func cardField(title: LocalizedStringResource, value: LocalizedStringResource) -> some View {
        VStack(alignment: .leading, spacing: 3.5) {
            Text(title)
                .font(AppFont.telkaCompact(7.9, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(AppColor.textPrimary)

            Text(value)
                .font(AppFont.mono(10.1))
                .textCase(.uppercase)
                .foregroundStyle(AppColor.textPrimary)

            if ImportedAsset.idFieldRule.existsInBundle {
                ImportedSVGView(asset: .idFieldRule)
                    .frame(height: 1)
                    .padding(.top, 3)
            } else {
                Rectangle()
                    .fill(AppColor.borderSubtle.opacity(0.65))
                    .frame(height: 0.8)
                    .padding(.top, 3)
            }
        }
    }
}
