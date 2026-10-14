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
    @StateObject private var appLockManager = AppLockManager()

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--store-screenshot-seed") {
            seedStoreScreenshotData()
        } else if arguments.contains("--uitesting-reset-state") {
            DataService.shared.clearAllData()
        }
        #endif
        // 初始化设置
        setupInitialSettings()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appLockManager)
        }
    }

    private func setupInitialSettings() {
        let settings = DataService.shared.loadSettings()
        HapticService.shared.isEnabled = settings.vibrationEnabled
        HapticService.shared.intensity = settings.hapticIntensity
        SpeechService.shared.isEnabled = settings.voiceEnabled
        SpeechService.shared.volume = settings.voiceVolume
        SpeechService.shared.setVoice(identifier: settings.selectedVoice)
    }

    #if DEBUG
    private func seedStoreScreenshotData(now: Date = Date()) {
        let dataService = DataService.shared
        dataService.clearAllData()
        UserDefaults.standard.set(false, forKey: "isPro")

        let calendar = Calendar.current
        let profileDate = calendar.date(byAdding: .day, value: -18, to: now) ?? now
        dataService.completeOnboarding(
            selectedGoals: Set(WellnessGoal.allCases),
            now: profileDate
        )

        for dayOffset in 1...16 {
            let program = TrainingData.allPrograms[(dayOffset - 1) % TrainingData.allPrograms.count]
            let completedAt = calendar.date(byAdding: .day, value: -dayOffset, to: now) ?? now
            dataService.saveRecord(
                TrainingRecord(
                    programId: program.id,
                    programName: program.name,
                    completedAt: completedAt,
                    duration: program.totalDuration,
                    completedSets: max(program.sets.count, 1),
                    totalSets: max(program.sets.count, 1),
                    isCompleted: true,
                    route: program.route
                )
            )
        }

        dataService.saveCheckIn(
            WellnessCheckIn(
                createdAt: now,
                moment: .beforePractice,
                comfort: 4,
                tension: 2,
                energy: 4
            )
        )
    }
    #endif
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
                mode: .spokenAudio,
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
