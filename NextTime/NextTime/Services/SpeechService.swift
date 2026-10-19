import AVFoundation

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

    func setVoice(identifier: String?) {
        voiceIdentifier = identifier == "default" ? nil : identifier
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
        speak(text: String(localized: "voice.preview"), style: .guidance)
    }

    private func speak(text: String, style: SpeechStyle, addsPauses: Bool = true) {
        guard isEnabled else { return }
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
