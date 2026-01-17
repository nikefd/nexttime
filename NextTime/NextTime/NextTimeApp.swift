//
//  NextTimeApp.swift
//  NextTime
//
//  凯格尔训练应用
//

import SwiftUI
import AVFoundation

@main
struct NextTimeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // 初始化设置
        setupInitialSettings()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }

    private func setupInitialSettings() {
        let settings = DataService.shared.loadSettings()
        HapticService.shared.isEnabled = settings.vibrationEnabled
        HapticService.shared.intensity = settings.hapticIntensity
        SpeechService.shared.isEnabled = settings.voiceEnabled
        SpeechService.shared.volume = settings.voiceVolume
    }
}

// MARK: - App Delegate for Background Support
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 配置音频会话以支持后台播放
        configureAudioSession()
        return true
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playback,
                mode: .voicePrompt,
                options: [.mixWithOthers, .duckOthers]
            )
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // 当应用进入后台时，确保音频会话保持活跃
        SpeechService.shared.activateAudioSession()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // 当应用回到前台时，准备震动反馈
        HapticService.shared.prepare()
    }
}
