import AVFoundation

enum NarrationVoice: String, CaseIterable, Identifiable {
    case female = "default"
    case male = "nexttime.yunxi"

    var id: String { rawValue }
    var assetPrefix: String { self == .female ? "nexttime-xiaoyi" : "nexttime-yunxi" }
    var title: String { String(localized: self == .female ? "voice.pack.female" : "voice.pack.male") }
    static func resolve(_ identifier: String?) -> NarrationVoice? {
        guard let identifier, identifier != "default" else { return .female }
        return NarrationVoice(rawValue: identifier)
    }
}

final class SpeechService {
    static let shared = SpeechService()

    private var audioSession: AVAudioSession { AVAudioSession.sharedInstance() }
    private var recordedPlayer: AVAudioPlayer?
    private var voiceIdentifier: String?

    var isEnabled = true
    var volume: Float = 0.8

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.mixWithOthers, .duckOthers]
            )
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    var usesChinese: Bool { preferredLanguage.hasPrefix("zh") }

    func recordedLesson(for program: TrainingProgram) -> StageOneLesson? {
        guard usesChinese, isEnabled, program.id == TrainingData.foundationAwareness.id,
              let voice = NarrationVoice.resolve(voiceIdentifier) else { return nil }
        return try? StageOneLesson.load(voice: voice)
    }

    func formattedDuration(for program: TrainingProgram) -> String {
        guard let lesson = recordedLesson(for: program) else {
            if let stage = PracticeCurriculum.stage(for: program), stage != .awareness,
               program.id == stage.program.id,
               usesChinese, isEnabled, let voice = NarrationVoice.resolve(voiceIdentifier),
               let narration = try? CurriculumNarration.load(stage: stage, voice: voice) {
                let total = Int(ceil(narration.duration)) + program.totalDuration
                return String(localized: "curriculum.audioDuration \(total / 60) \(total % 60)")
            }
            if PracticeCurriculum.stage(for: program) != nil {
                return String(localized: "curriculum.duration \(program.totalDuration / 60) \(program.totalDuration % 60)")
            }
            return program.formattedDuration
        }
        let seconds = Int(ceil(lesson.timeline.duration))
        return String(localized: "stageOne.duration \(seconds / 60) \(seconds % 60)")
    }

    func setVoice(identifier: String?) {
        stop()
        voiceIdentifier = (NarrationVoice.resolve(identifier) ?? .female).rawValue
    }

    private func playRecording(_ suffix: String) -> Bool {
        guard let voice = NarrationVoice.resolve(voiceIdentifier),
              let url = Bundle.main.url(forResource: "\(voice.assetPrefix)-\(suffix)", withExtension: suffix == "preview" ? "mp3" : "m4a") else { return false }
        stop()
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            recordedPlayer = player
            player.prepareToPlay()
            return player.play()
        } catch { return false }
    }

    func speakContract() { if isEnabled { _ = playRecording("contract") } }
    func speakRelax() { if isEnabled { _ = playRecording("relax") } }
    func speakRest() { if isEnabled { _ = playRecording("rest") } }
    // Instructions are shown on screen. No system speech or synthetic fallback.
    func previewNaturalVoice() { if isEnabled { _ = playRecording("preview") } }

    private var preferredLanguage: String {
        let localization = Bundle.main.preferredLocalizations.first
            ?? Locale.preferredLanguages.first
            ?? "en"
        return localization.hasPrefix("zh") ? "zh-CN" : "en-US"
    }

    func stop(immediately: Bool = true) {
        recordedPlayer?.stop()
        recordedPlayer = nil
    }

    func activateAudioSession() {
        do {
            try audioSession.setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
    }

    func deactivateAudioSession() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
}
