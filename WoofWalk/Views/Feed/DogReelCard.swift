import SwiftUI
import AVFoundation

struct DogReelCard: View {
    let videoURL: URL
    let dogName: String
    let ownerName: String

    @State private var isMuted = true
    @State private var isLiked = false
    @State private var showHeartAnimation = false
    @StateObject private var playerManager: ReelPlayerManager

    init(videoURL: URL, dogName: String, ownerName: String) {
        self.videoURL = videoURL
        self.dogName = dogName
        self.ownerName = ownerName
        _playerManager = StateObject(wrappedValue: ReelPlayerManager(url: videoURL))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Video player
            ReelVideoPlayer(player: playerManager.player)
                .aspectRatio(9/16, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .onTapGesture(count: 2) {
                    if !isLiked {
                        isLiked = true
                        showHeartAnimation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            showHeartAnimation = false
                        }
                    }
                }

            // Heart animation overlay
            if showHeartAnimation {
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 8)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(10)
            }

            // Bottom gradient overlay with info
            VStack(spacing: 0) {
                Spacer()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dogName)
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        Text("@\(ownerName)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Side action buttons
            VStack(spacing: 20) {
                Spacer()

                // Like button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isLiked.toggle()
                        if isLiked {
                            showHeartAnimation = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                showHeartAnimation = false
                            }
                        }
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.title2)
                            .foregroundColor(isLiked ? .red : .white)
                            .scaleEffect(isLiked ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
                        Text("Like")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                }

                // Mute/unmute button
                Button {
                    isMuted.toggle()
                    playerManager.player.isMuted = isMuted
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text(isMuted ? "Unmute" : "Mute")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                }

                Spacer().frame(height: 40)
            }
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .background(Color.black.clipShape(RoundedRectangle(cornerRadius: 16)))
        .onAppear {
            playerManager.player.isMuted = isMuted
            playerManager.play()
        }
        .onDisappear {
            playerManager.pause()
        }
    }
}

// MARK: - AVPlayer Manager

@MainActor
class ReelPlayerManager: ObservableObject {
    let player: AVPlayer
    private var loopObserver: Any?

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        self.player = AVPlayer(playerItem: item)
        self.player.isMuted = true

        // Loop video
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    deinit {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Video Player UIViewRepresentable

struct ReelVideoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

// MARK: - Sample Reel Data

enum DogReelSamples {
    static let reels: [(url: String, dogName: String, ownerName: String)] = [
        ("https://videos.pexels.com/video-files/4641252/4641252-uhd_1440_2560_30fps.mp4", "Luna", "sarah_walks"),
        ("https://videos.pexels.com/video-files/4488286/4488286-uhd_1440_2560_24fps.mp4", "Max", "dogdad_mike"),
        ("https://videos.pexels.com/video-files/5749036/5749036-hd_1080_1920_30fps.mp4", "Bella", "bella_adventures"),
        ("https://videos.pexels.com/video-files/3191242/3191242-uhd_1440_2560_25fps.mp4", "Charlie", "charlie_paws"),
        ("https://videos.pexels.com/video-files/4812204/4812204-uhd_1440_2560_25fps.mp4", "Daisy", "daisy_trails"),
    ]

    static func reel(at index: Int) -> (url: URL, dogName: String, ownerName: String)? {
        let reelIndex = index % reels.count
        let reel = reels[reelIndex]
        guard let url = URL(string: reel.url) else { return nil }
        return (url, reel.dogName, reel.ownerName)
    }
}
