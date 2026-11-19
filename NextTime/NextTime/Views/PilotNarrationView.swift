import AVFoundation
import Combine
import SwiftUI

struct PilotNarrationTimeline: Decodable {
    struct Section: Decodable { let start: Double; let end: Double; let title: String }
    let duration: Double
    let sections: [Section]
}

struct PilotNarrationView: View {
    let voice: NarrationVoice
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var elapsed: Double = 0
    @State private var unavailable = false
    @State private var playbackFailed = false
    @State private var sections: [PilotNarrationTimeline.Section] = []
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Text(String(localized: "voice.pilot.title")).font(.title.bold())
                Text(voice.title).foregroundStyle(.secondary).accessibilityIdentifier("pilot.voice")
                Text(String(localized: "voice.pilot.description"))
                Text(String(localized: "voice.pilot.draft")).font(.footnote).foregroundStyle(.secondary)
                if unavailable {
                    Text(String(localized: "voice.pilot.unavailable"))
                } else {
                    if let section = sections.first(where: { elapsed >= $0.start && elapsed < $0.end }) {
                        Text(section.title).font(.headline).accessibilityIdentifier("pilot.section")
                    }
                    ProgressView(value: elapsed, total: max(player?.duration ?? 1, 1))
                    HStack {
                        Text(time(elapsed)).accessibilityIdentifier("pilot.elapsed")
                        Spacer()
                        Text(time(player?.duration ?? 0))
                    }.monospacedDigit()
                    Button(isPlaying ? String(localized: "button.pause") : String(localized: "button.resume")) {
                        SpeechService.shared.stop()
                        guard let player else { return }
                        if isPlaying {
                            player.pause()
                            elapsed = player.currentTime
                            isPlaying = false
                        } else {
                            SpeechService.shared.activateAudioSession()
                            playbackFailed = !player.play()
                            isPlaying = !playbackFailed
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("pilot.play-pause")
                    if playbackFailed {
                        Text(String(localized: "voice.pilot.playError"))
                            .font(.footnote).foregroundStyle(.red)
                            .accessibilityIdentifier("pilot.playback-error")
                    }
                    Button(String(localized: "voice.pilot.restart")) {
                        player?.stop()
                        player?.currentTime = 0
                        elapsed = 0
                        isPlaying = false
                        playbackFailed = false
                    }
                }
                Spacer()
            }
            .padding(24)
            .navigationTitle(String(localized: "voice.pilot.open"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(String(localized: "button.done")) { dismiss() } } }
        }
        .onAppear {
            SpeechService.shared.stop()
            guard let url = Bundle.main.url(forResource: "\(voice.assetPrefix)-pilot", withExtension: "m4a"),
                  let audio = try? AVAudioPlayer(contentsOf: url) else {
                unavailable = true
                return
            }
            if let timelineURL = Bundle.main.url(forResource: "\(voice.assetPrefix)-pilot", withExtension: "json"),
               let data = try? Data(contentsOf: timelineURL),
               let timeline = try? JSONDecoder().decode(PilotNarrationTimeline.self, from: data) {
                sections = timeline.sections
            }
            audio.volume = SpeechService.shared.volume
            audio.prepareToPlay()
            player = audio
        }
        .onReceive(ticker) { _ in
            guard let player, isPlaying || player.isPlaying else { return }
            elapsed = !player.isPlaying && player.currentTime == 0 && elapsed > 0 ? player.duration : player.currentTime
            isPlaying = player.isPlaying
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                player?.pause()
                elapsed = player?.currentTime ?? elapsed
                isPlaying = false
            }
        }
        .onDisappear { player?.stop() }
    }

    private func time(_ value: Double) -> String {
        let seconds = max(0, Int(value))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
