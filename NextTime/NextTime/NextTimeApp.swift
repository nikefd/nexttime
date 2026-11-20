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
                .preferredColorScheme(
                    ProcessInfo.processInfo.arguments.contains("--store-screenshot-seed")
                        ? .light
                        : nil
                )
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
        UserDefaults.standard.set(
            ProcessInfo.processInfo.arguments.contains("--store-screenshot-pro"),
            forKey: "isPro"
        )

        let calendar = Calendar.current
        let profileDate = calendar.date(byAdding: .day, value: -18, to: now) ?? now
        dataService.completeOnboarding(
            selectedGoals: Set(WellnessGoal.personalCases),
            now: profileDate
        )

        let targetStage = ProcessInfo.processInfo.arguments.contains("--uitesting-stage-four") ? 4
            : (ProcessInfo.processInfo.arguments.contains("--uitesting-stage-two") ? 2 : 1)
        if (ProcessInfo.processInfo.arguments.contains("--uitesting-path-review-ready") || targetStage > 1),
           let path = try? dataService.startPracticePathIfNeeded(now: now.addingTimeInterval(-60)) {
            dataService.saveRecord(TrainingRecord(
                programId: path.program.id, programName: path.program.name,
                completedAt: now.addingTimeInterval(-30), duration: 195,
                completedSets: 1, totalSets: 1, isCompleted: true, route: .foundation,
                pathID: path.id, pathStage: path.currentStage, lessonVersion: StageOneLesson.version,
                completedRepetitions: 6, totalRepetitions: 6
            ))
            if let record = dataService.loadRecords().first {
                try? dataService.saveSessionFeedback(recordID: record.id, outcome: .comfortable, now: now)
            }
        }

        while let path = dataService.loadPracticePath(), path.currentStage.rawValue < targetStage {
            if path.completedRecords(in: dataService.loadRecords(), now: now).isEmpty {
                let record = TrainingRecord(programId: path.program.id,
                    programName: path.program.name, completedAt: now, duration: 99,
                    completedSets: 2, totalSets: 2, isCompleted: true, route: .foundation,
                    pathID: path.id, pathStage: path.currentStage,
                    lessonVersion: PracticeCurriculum.version(for: path.currentStage),
                    completedRepetitions: 6, totalRepetitions: 6)
                dataService.saveRecord(record)
                try? dataService.saveSessionFeedback(recordID: record.id, outcome: .comfortable, now: now)
            }
            guard let record = path.completedRecords(in: dataService.loadRecords(), now: now).first,
                  (try? dataService.advancePracticePath(PracticeStageReview(stage: path.currentStage,
                    recordID: record.id, confirmedAt: now, breathingComfortable: true,
                    fullyReleased: true, noDiscomfort: true), now: now)) != nil else { break }
        }

        for dayOffset in 1...16 {
            let program = TrainingData.personalPrograms[(dayOffset - 1) % TrainingData.personalPrograms.count]
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
                energy: ProcessInfo.processInfo.arguments.contains("--uitesting-low-energy") ? 1 : 4
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

    func applicationWillEnterForeground(_ application: UIApplication) {
        // 当应用回到前台时，准备震动反馈
        HapticService.shared.prepare()
    }
}
