//
//  SpeechService.swift
//  NextTime
//
//  语音提示服务
//

import AVFoundation

class SpeechService {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    private var audioSession: AVAudioSession { AVAudioSession.sharedInstance() }

    var isEnabled: Bool = true
    var volume: Float = 0.8

    // 语音设置
    private var voiceIdentifier: String?

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            // 设置音频会话类别，允许后台播放和与其他音频混合
            try audioSession.setCategory(
                .playback,
                mode: .voicePrompt,
                options: [.mixWithOthers, .duckOthers]
            )
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - 获取可用的中文语音
    func availableChineseVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("zh")
        }
    }

    // MARK: - 获取可用的英文语音
    func availableEnglishVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("en")
        }
    }

    // MARK: - 设置语音
    func setVoice(identifier: String?) {
        self.voiceIdentifier = identifier
    }

    // MARK: - 收缩提示
    func speakContract() {
        guard isEnabled else { return }
        speak(text: String(localized: "voice.contract"))
    }

    func speakBreathe() {
        guard isEnabled else { return }
        speak(text: String(localized: "voice.breathe"))
    }

    // MARK: - 放松提示
    func speakRelax() {
        guard isEnabled else { return }
        speak(text: String(localized: "voice.relax"))
    }

    // MARK: - 组间休息提示
    func speakRest() {
        guard isEnabled else { return }
        speak(text: String(localized: "voice.rest"))
    }

    // MARK: - 下一组提示
    func speakNextSet(setNumber: Int) {
        guard isEnabled else { return }
        speak(text: String(localized: "voice.nextSet \(setNumber)"))
    }

    // MARK: - 训练完成
    func speakComplete() {
        guard isEnabled else { return }
        speak(text: String(localized: "voice.complete"))
    }

    // MARK: - 倒计时
    func speakCountdown(_ seconds: Int) {
        guard isEnabled, seconds <= 3, seconds > 0 else { return }
        speak(text: "\(seconds)")
    }

    // MARK: - 准备开始
    func speakGetReady() {
        guard isEnabled else { return }
        speak(text: String(localized: "voice.getReady"))
    }

    // MARK: - 通用语音播放
    private func speak(text: String) {
        // 如果正在说话，停止当前语音
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)

        // 设置语音
        if let voiceId = voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            // 根据当前语言选择默认语音
            let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
            if languageCode == "zh" {
                utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            } else {
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            }
        }

        utterance.volume = volume
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0

        synthesizer.speak(utterance)
    }

    // MARK: - 停止语音
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: - 激活音频会话（用于后台播放）
    func activateAudioSession() {
        do {
            try audioSession.setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
    }

    // MARK: - 释放音频会话
    func deactivateAudioSession() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
}
