//
//  TrainingManager.swift
//  NextTime
//
//  训练管理器 - 核心训练逻辑
//

import Foundation
import Combine
import UIKit
import AVFoundation

class TrainingManager: ObservableObject {
    static let shared = TrainingManager()

    // MARK: - Published 状态
    @Published var currentProgram: TrainingProgram?
    @Published var progress: TrainingProgress = TrainingProgress()
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false

    // MARK: - 服务
    private let hapticService = HapticService.shared
    private let speechService = SpeechService.shared

    // MARK: - 计时器
    private var timer: Timer?
    private var startTime: Date?

    // MARK: - 震动计时器（用于持续震动）
    private var hapticTimer: Timer?

    // MARK: - 回调
    var onTrainingComplete: ((TrainingRecord) -> Void)?

    // MARK: - 后台任务
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    // MARK: - 音频播放器（用于保持后台活跃）
    private var silentAudioPlayer: AVAudioPlayer?

    private init() {
        setupSilentAudio()
    }

    // MARK: - 设置静音音频（保持后台运行）
    private func setupSilentAudio() {
        // 创建一个静音的音频数据
        guard let silentSoundURL = Bundle.main.url(forResource: "silence", withExtension: "wav") else {
            // 如果没有静音文件，动态创建
            createSilentAudioPlayer()
            return
        }

        do {
            silentAudioPlayer = try AVAudioPlayer(contentsOf: silentSoundURL)
            silentAudioPlayer?.numberOfLoops = -1 // 无限循环
            silentAudioPlayer?.volume = 0.01
        } catch {
            print("Failed to setup silent audio: \(error)")
            createSilentAudioPlayer()
        }
    }

    private func createSilentAudioPlayer() {
        // 创建一个极短的静音音频
        let sampleRate: Double = 44100
        let duration: Double = 1.0
        let numSamples = Int(sampleRate * duration)

        var audioData = Data()
        // WAV header
        let header = createWAVHeader(sampleRate: Int(sampleRate), numSamples: numSamples)
        audioData.append(header)

        // Silent samples
        for _ in 0..<numSamples {
            var sample: Int16 = 0
            audioData.append(Data(bytes: &sample, count: 2))
        }

        do {
            silentAudioPlayer = try AVAudioPlayer(data: audioData)
            silentAudioPlayer?.numberOfLoops = -1
            silentAudioPlayer?.volume = 0.01
        } catch {
            print("Failed to create silent audio player: \(error)")
        }
    }

    private func createWAVHeader(sampleRate: Int, numSamples: Int) -> Data {
        var header = Data()
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate = sampleRate * Int(numChannels) * Int(bitsPerSample) / 8
        let blockAlign = Int16(numChannels) * bitsPerSample / 8
        let dataSize = numSamples * Int(numChannels) * Int(bitsPerSample) / 8

        // RIFF header
        header.append("RIFF".data(using: .ascii)!)
        var chunkSize = Int32(36 + dataSize)
        header.append(Data(bytes: &chunkSize, count: 4))
        header.append("WAVE".data(using: .ascii)!)

        // fmt subchunk
        header.append("fmt ".data(using: .ascii)!)
        var subchunk1Size: Int32 = 16
        header.append(Data(bytes: &subchunk1Size, count: 4))
        var audioFormat: Int16 = 1
        header.append(Data(bytes: &audioFormat, count: 2))
        var channels = numChannels
        header.append(Data(bytes: &channels, count: 2))
        var rate = Int32(sampleRate)
        header.append(Data(bytes: &rate, count: 4))
        var bRate = Int32(byteRate)
        header.append(Data(bytes: &bRate, count: 4))
        var bAlign = blockAlign
        header.append(Data(bytes: &bAlign, count: 2))
        var bits = bitsPerSample
        header.append(Data(bytes: &bits, count: 2))

        // data subchunk
        header.append("data".data(using: .ascii)!)
        var dSize = Int32(dataSize)
        header.append(Data(bytes: &dSize, count: 4))

        return header
    }

    // MARK: - 重置状态
    func resetState() {
        timer?.invalidate()
        timer = nil
        stopHapticTimer()
        stopSilentAudio()
        isRunning = false
        isPaused = false
        currentProgram = nil
        progress = TrainingProgress()
        endBackgroundTask()
    }

    // MARK: - 开始训练
    func startTraining(program: TrainingProgram) {
        // 先重置状态
        resetState()

        currentProgram = program
        progress = TrainingProgress()
        progress.totalSets = program.sets.count
        isRunning = true
        isPaused = false
        startTime = Date()

        // 准备震动和语音
        hapticService.prepare()

        // 开始后台任务
        beginBackgroundTask()

        // 开始播放静音音频保持后台活跃
        startSilentAudio()

        // 初始化第一个动作
        if let firstSet = program.sets.first {
            progress.currentAction = program.primaryAction
            progress.remainingSeconds = firstSet.contractDuration

            // 延迟开始，给用户准备时间
            speechService.speakGetReady()
            hapticService.simplePulse()

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.startTimer()
                self?.announceCurrentAction()
            }
        }
    }

    // MARK: - 暂停训练
    func pauseTraining() {
        guard isRunning, !isPaused else { return }
        isPaused = true
        timer?.invalidate()
        timer = nil
        stopHapticTimer()
    }

    // MARK: - 恢复训练
    func resumeTraining() {
        guard isRunning, isPaused else { return }
        isPaused = false
        startTimer()

        // 如果当前是收缩状态，恢复震动
        if progress.currentAction == .contract {
            startContinuousHaptic()
        }
    }

    // MARK: - 停止训练
    func stopTraining() {
        timer?.invalidate()
        timer = nil
        stopHapticTimer()
        stopSilentAudio()
        isRunning = false
        isPaused = false

        // 保存训练记录
        if let program = currentProgram, let start = startTime {
            let duration = Int(Date().timeIntervalSince(start))
            let record = TrainingRecord(
                programId: program.id,
                programName: program.name,
                duration: duration,
                completedSets: progress.currentSetIndex,
                totalSets: program.sets.count,
                isCompleted: progress.isCompleted,
                route: program.route
            )
            onTrainingComplete?(record)
            DataService.shared.saveRecord(record)
        }

        // 结束后台任务
        endBackgroundTask()

        currentProgram = nil
        progress = TrainingProgress()
    }

    // MARK: - 跳过休息
    func skipRest() {
        guard progress.currentAction == .rest, let program = currentProgram else { return }

        // 直接进入下一组的收缩
        let nextSet = program.sets[progress.currentSetIndex]
        progress.currentAction = program.primaryAction
        progress.remainingSeconds = nextSet.contractDuration
        progress.isResting = false

        announceNextSet()
    }

    // MARK: - 静音音频控制
    private func startSilentAudio() {
        // 配置音频会话以支持后台播放
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session for background: \(error)")
        }

        silentAudioPlayer?.prepareToPlay()
        silentAudioPlayer?.play()
    }

    private func stopSilentAudio() {
        silentAudioPlayer?.stop()
        // 不要在这里 deactivate audio session，可能会影响语音播报
    }

    // MARK: - 定时器逻辑
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }

        // 确保定时器在后台也能运行
        RunLoop.current.add(timer!, forMode: .common)
    }

    private func tick() {
        guard isRunning, !isPaused, let program = currentProgram else { return }

        progress.elapsedTime += 1
        progress.remainingSeconds -= 1

        // 倒计时提醒（最后3秒）
        if progress.remainingSeconds <= 3 && progress.remainingSeconds > 0 {
            speechService.speakCountdown(progress.remainingSeconds)
        }

        // 当前动作完成
        if progress.remainingSeconds <= 0 {
            moveToNextAction(program: program)
        }
    }

    private func moveToNextAction(program: TrainingProgram) {
        let currentSet = program.sets[progress.currentSetIndex]

        switch progress.currentAction {
        case .contract, .breathe:
            // 收缩完成，停止震动，切换到放松
            stopHapticTimer()
            progress.currentAction = .relax
            progress.remainingSeconds = currentSet.relaxDuration
            announceCurrentAction()

        case .relax:
            // 放松完成，检查是否还有重复
            progress.currentRepetition += 1

            if progress.currentRepetition < currentSet.repetitions {
                // 还有重复，继续收缩
                progress.currentAction = program.primaryAction
                progress.remainingSeconds = currentSet.contractDuration
                announceCurrentAction()
            } else {
                // 本组完成，检查是否还有下一组
                progress.currentSetIndex += 1
                progress.currentRepetition = 0

                if progress.currentSetIndex < program.sets.count {
                    // 还有下一组，先休息
                    progress.currentAction = .rest
                    progress.remainingSeconds = program.restBetweenSets
                    progress.isResting = true
                    announceRest()
                } else {
                    // 训练完成
                    completeTraining()
                }
            }

        case .rest:
            // 休息完成，开始下一组
            progress.isResting = false
            let nextSet = program.sets[progress.currentSetIndex]
            progress.currentAction = program.primaryAction
            progress.remainingSeconds = nextSet.contractDuration
            announceNextSet()
        }
    }

    // MARK: - 持续震动控制
    private func startContinuousHaptic() {
        guard hapticService.isEnabled else { return }

        stopHapticTimer()

        // 立即震动一次
        hapticService.contractStart()

        // 每0.5秒震动一次，模拟持续震动
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.hapticService.contractStart()
        }
        RunLoop.current.add(hapticTimer!, forMode: .common)
    }

    private func stopHapticTimer() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }

    // MARK: - 语音和震动提示
    private func announceCurrentAction() {
        switch progress.currentAction {
        case .contract:
            speechService.speakContract()
            startContinuousHaptic()
        case .breathe:
            speechService.speakBreathe()
            stopHapticTimer()
            hapticService.simplePulse()
        case .relax:
            speechService.speakRelax()
            stopHapticTimer()
            hapticService.relaxStart()
        case .rest:
            break
        }
    }

    private func announceRest() {
        stopHapticTimer()
        speechService.speakRest()
        hapticService.restStart()
    }

    private func announceNextSet() {
        speechService.speakNextSet(setNumber: progress.currentSetIndex + 1)

        // 稍后宣布收缩并开始震动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.announceCurrentAction()
        }
    }

    private func completeTraining() {
        timer?.invalidate()
        timer = nil
        stopHapticTimer()
        stopSilentAudio()
        isRunning = false

        speechService.speakComplete()
        hapticService.trainingComplete()

        // 保存训练记录
        if let program = currentProgram, let start = startTime {
            let duration = Int(Date().timeIntervalSince(start))
            let record = TrainingRecord(
                programId: program.id,
                programName: program.name,
                duration: duration,
                completedSets: program.sets.count,
                totalSets: program.sets.count,
                isCompleted: true,
                route: program.route
            )
            onTrainingComplete?(record)
            DataService.shared.saveRecord(record)
        }

        // 结束后台任务
        endBackgroundTask()
    }

    // MARK: - 后台任务管理
    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    // MARK: - 获取当前状态描述
    var currentActionDescription: String {
        switch progress.currentAction {
        case .contract:
            return String(localized: "action.contract")
        case .breathe:
            return String(localized: "action.breathe")
        case .relax:
            return String(localized: "action.relax")
        case .rest:
            return String(localized: "action.rest")
        }
    }

    var progressDescription: String {
        guard let program = currentProgram else { return "" }
        let currentSet = progress.currentSetIndex + 1
        let totalSets = program.sets.count
        let currentRep = progress.currentRepetition + 1
        let totalReps = program.sets[safe: progress.currentSetIndex]?.repetitions ?? 0

        return String(localized: "progress.description \(currentSet) \(totalSets) \(currentRep) \(totalReps)")
    }
}

// MARK: - Array 安全访问扩展
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
