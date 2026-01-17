//
//  HapticService.swift
//  NextTime
//
//  震动反馈服务
//

import UIKit
import CoreHaptics
import AudioToolbox

class HapticService {
    static let shared = HapticService()

    private var hapticEngine: CHHapticEngine?
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)

    var isEnabled: Bool = true
    var intensity: UserSettings.HapticIntensity = .medium

    // 标记是否在后台运行
    var isInBackground: Bool = false

    private init() {
        setupHapticEngine()
        feedbackGenerator.prepare()
        impactGenerator.prepare()

        // 监听应用进入后台/前台
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        isInBackground = true
    }

    @objc private func appWillEnterForeground() {
        isInBackground = false
        // 重新准备震动引擎
        prepare()
    }

    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()

            hapticEngine?.stoppedHandler = { [weak self] reason in
                print("Haptic engine stopped: \(reason)")
                self?.restartHapticEngine()
            }

            hapticEngine?.resetHandler = { [weak self] in
                print("Haptic engine reset")
                self?.restartHapticEngine()
            }
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }

    private func restartHapticEngine() {
        do {
            try hapticEngine?.start()
        } catch {
            print("Failed to restart haptic engine: \(error)")
        }
    }

    // MARK: - 收缩开始震动
    func contractStart() {
        guard isEnabled else { return }

        if isInBackground {
            // 后台使用系统震动
            vibrateInBackground()
        } else {
            // 前台使用 Core Haptics
            playHapticPattern(type: .contract)
        }
    }

    // MARK: - 放松开始震动
    func relaxStart() {
        guard isEnabled else { return }

        if isInBackground {
            vibrateInBackground()
        } else {
            playHapticPattern(type: .relax)
        }
    }

    // MARK: - 组间休息震动
    func restStart() {
        guard isEnabled else { return }

        if isInBackground {
            vibrateInBackground()
        } else {
            feedbackGenerator.notificationOccurred(.warning)
        }
    }

    // MARK: - 训练完成震动
    func trainingComplete() {
        guard isEnabled else { return }

        if isInBackground {
            vibrateInBackground()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.vibrateInBackground()
            }
        } else {
            feedbackGenerator.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.feedbackGenerator.notificationOccurred(.success)
            }
        }
    }

    // MARK: - 简单的震动反馈
    func simplePulse() {
        guard isEnabled else { return }

        if isInBackground {
            vibrateInBackground()
        } else {
            impactGenerator.impactOccurred()
        }
    }

    // MARK: - 后台震动（使用系统震动）
    private func vibrateInBackground() {
        // 使用 AudioServicesPlaySystemSound 在后台触发震动
        // kSystemSoundID_Vibrate = 4095
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    // MARK: - 使用 Core Haptics 播放复杂模式
    private func playHapticPattern(type: HapticType) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else {
            // 降级到简单震动
            fallbackHaptic(type: type)
            return
        }

        do {
            let pattern = try createPattern(for: type)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play haptic pattern: \(error)")
            fallbackHaptic(type: type)
        }
    }

    private func createPattern(for type: HapticType) throws -> CHHapticPattern {
        let intensityValue: Float
        switch intensity {
        case .light: intensityValue = 0.4
        case .medium: intensityValue = 0.7
        case .heavy: intensityValue = 1.0
        }

        let events: [CHHapticEvent]

        switch type {
        case .contract:
            // 收缩：强烈的持续震动
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityValue),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityValue * 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0.05,
                    duration: 0.3
                )
            ]

        case .relax:
            // 放松：轻柔的单次震动
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityValue * 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: 0
                )
            ]
        }

        return try CHHapticPattern(events: events, parameters: [])
    }

    private func fallbackHaptic(type: HapticType) {
        switch type {
        case .contract:
            impactGenerator.impactOccurred(intensity: 1.0)
        case .relax:
            impactGenerator.impactOccurred(intensity: 0.5)
        }
    }

    private enum HapticType {
        case contract
        case relax
    }

    // MARK: - 准备震动引擎
    func prepare() {
        feedbackGenerator.prepare()
        impactGenerator.prepare()

        if hapticEngine == nil {
            setupHapticEngine()
        }
    }
}
