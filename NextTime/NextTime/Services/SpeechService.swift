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

enum SpeechStyle {
    case guidance
    case cue
    case completion

    func rate(for language: String) -> Float {
        switch self {
        case .guidance: return language.hasPrefix("zh") ? 0.46 : 0.48
        case .cue: return language.hasPrefix("zh") ? 0.48 : 0.50
        case .completion: return language.hasPrefix("zh") ? 0.47 : 0.49
        }
    }

    var pitch: Float {
        switch self {
        case .guidance: return 0.98
        case .cue: return 1.0
        case .completion: return 1.0
        }
    }
}

final class SpeechService {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()
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

    func availableChineseVoices() -> [AVSpeechSynthesisVoice] {
        sortedVoices(prefix: "zh")
    }

    func availableEnglishVoices() -> [AVSpeechSynthesisVoice] {
        sortedVoices(prefix: "en")
    }

    func availableVoicesForCurrentLanguage() -> [AVSpeechSynthesisVoice] {
        sortedVoices(prefix: preferredLanguage)
    }

    var usesChinese: Bool { preferredLanguage.hasPrefix("zh") }

    func recordedLesson(for program: TrainingProgram) -> StageOneLesson? {
        guard usesChinese, program.id == TrainingData.foundationAwareness.id,
              let voice = NarrationVoice.resolve(voiceIdentifier) else { return nil }
        return try? StageOneLesson.load(voice: voice)
    }

    func formattedDuration(for program: TrainingProgram) -> String {
        guard let lesson = recordedLesson(for: program) else { return program.formattedDuration }
        let seconds = Int(ceil(lesson.timeline.duration))
        return String(localized: "stageOne.duration \(seconds / 60) \(seconds % 60)")
    }

    func setVoice(identifier: String?) {
        stop()
        voiceIdentifier = identifier
    }

    private func playRecording(_ suffix: String) -> Bool {
        guard usesChinese, let voice = NarrationVoice.resolve(voiceIdentifier),
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

    func speakContract() {
        speak(text: String(localized: "voice.contract"), style: .cue)
    }

    func speakBreathe() {
        speak(text: String(localized: "voice.breathe"), style: .cue)
    }

    func speakRelax() {
        speak(text: String(localized: "voice.relax"), style: .cue)
    }

    func speakRest() {
        speak(text: String(localized: "voice.rest"), style: .cue)
    }

    func speakNextSet(setNumber: Int) {
        speak(text: String(localized: "voice.nextSet \(setNumber)"), style: .cue)
    }

    func speakComplete() {
        speak(text: String(localized: "voice.complete"), style: .completion)
    }

    func speakCountdown(_ seconds: Int) {
        guard seconds <= 3, seconds > 0 else { return }
        speak(text: "\(seconds)", style: .cue, addsPauses: false)
    }

    func speakGetReady() {
        speak(text: String(localized: "voice.getReady"), style: .cue)
    }

    func speakGuidance(localizedKey: String) {
        speak(text: NSLocalizedString(localizedKey, comment: ""), style: .guidance)
    }

    func previewNaturalVoice() {
        guard isEnabled else { return }
        if !playRecording("preview") { speak(text: String(localized: "voice.preview"), style: .guidance) }
    }

    private func speak(text: String, style: SpeechStyle, addsPauses: Bool = true) {
        guard isEnabled else { return }
        let recordedCues = [("voice.contract", "contract"), ("voice.relax", "relax"), ("voice.rest", "rest")]
        if let cue = recordedCues.first(where: { String(localized: String.LocalizationValue($0.0)) == text }), playRecording(cue.1) { return }
        recordedPlayer?.stop()
        recordedPlayer = nil
        if synthesizer.isSpeaking {
            // A new action cue must not queue behind the previous step.
            synthesizer.stopSpeaking(at: style == .cue ? .immediate : .word)
        }

        let language = preferredLanguage
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice(for: language)
        utterance.volume = volume
        utterance.rate = style.rate(for: language)
        utterance.pitchMultiplier = style.pitch
        utterance.preUtteranceDelay = addsPauses && style != .cue ? 0.14 : 0
        utterance.postUtteranceDelay = addsPauses && style != .cue ? 0.12 : 0
        utterance.prefersAssistiveTechnologySettings = false
        synthesizer.speak(utterance)
    }

    private var preferredLanguage: String {
        let localization = Bundle.main.preferredLocalizations.first
            ?? Locale.preferredLanguages.first
            ?? "en"
        return localization.hasPrefix("zh") ? "zh-CN" : "en-US"
    }

    private func selectedVoice(for language: String) -> AVSpeechSynthesisVoice? {
        if let voiceIdentifier,
           let selected = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            return selected
        }
        return sortedVoices(prefix: language).first
            ?? AVSpeechSynthesisVoice(language: language)
    }

    private func sortedVoices(prefix: String) -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(prefix) }
            .sorted { left, right in
                if left.quality.rawValue != right.quality.rawValue {
                    return left.quality.rawValue > right.quality.rawValue
                }
                let leftExact = left.language.caseInsensitiveCompare(prefix) == .orderedSame
                let rightExact = right.language.caseInsensitiveCompare(prefix) == .orderedSame
                if leftExact != rightExact { return leftExact }
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }
    }

    func stop(immediately: Bool = true) {
        recordedPlayer?.stop()
        recordedPlayer = nil
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: immediately ? .immediate : .word)
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
