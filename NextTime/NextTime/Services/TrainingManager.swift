import Combine
import Foundation
import UIKit

@MainActor
final class TrainingManager: ObservableObject {
    static let shared = TrainingManager()

    @Published var currentProgram: TrainingProgram?
    @Published var progress = TrainingProgress()
    @Published var isRunning = false
    @Published var isPaused = false
    @Published private(set) var activeSteps: [GuidedPracticeStep] = []

    private let hapticService = HapticService.shared
    private let speechService = SpeechService.shared
    private var timer: Timer?
    private var hapticTimer: Timer?
    private var startTime: Date?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    var onTrainingComplete: ((TrainingRecord) -> Void)?

    private init() {}

    var currentStep: GuidedPracticeStep? {
        activeSteps[safe: progress.currentStepIndex]
    }

    func resetState() {
        timer?.invalidate()
        timer = nil
        stopHapticTimer()
        speechService.stop()
        endBackgroundTask()
        isRunning = false
        isPaused = false
        currentProgram = nil
        activeSteps = []
        progress = TrainingProgress()
    }

    func startTraining(program: TrainingProgram) {
        resetState()
        currentProgram = program
        activeSteps = program.resolvedGuidedSteps
        progress = TrainingProgress()
        progress.totalSets = program.sets.count
        progress.totalSteps = activeSteps.count
        isRunning = true
        startTime = Date()
        hapticService.prepare()
        beginBackgroundTask()
        beginCurrentStep()
    }

    func pauseTraining() {
        guard isRunning, !isPaused, !progress.isAwaitingContinue else { return }
        isPaused = true
        timer?.invalidate()
        timer = nil
        stopHapticTimer()
    }

    func resumeTraining() {
        guard isRunning, isPaused, currentStep?.duration != nil else { return }
        isPaused = false
        startTimer()
        if currentStep?.kind == .contract { startContinuousHaptic() }
    }

    func advanceStep() {
        guard isRunning else { return }
        timer?.invalidate()
        timer = nil
        stopHapticTimer()
        speechService.stop(immediately: false)
        progress.currentStepIndex += 1
        progress.isAwaitingContinue = false
        updateLegacyProgress()
        progress.currentStepIndex >= progress.totalSteps ? completeTraining() : beginCurrentStep()
    }

    func stopTraining() {
        saveRecord(isCompleted: progress.isCompleted)
        resetState()
    }

    func skipRest() {
        guard currentStep?.kind == .rest else { return }
        advanceStep()
    }

    private func beginCurrentStep() {
        guard let step = currentStep else {
            completeTraining()
            return
        }
        isPaused = false
        progress.currentAction = step.kind.exerciseAction
        progress.remainingSeconds = step.duration ?? 0
        progress.isResting = step.kind == .rest
        progress.isAwaitingContinue = step.kind.isInteractive || step.duration == nil
        announce(step)
        if step.duration != nil { startTimer() }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if let timer { RunLoop.current.add(timer, forMode: .common) }
    }

    private func tick() {
        guard isRunning, !isPaused, currentStep?.duration != nil else { return }
        progress.elapsedTime += 1
        progress.remainingSeconds -= 1
        if progress.remainingSeconds <= 0 { advanceStep() }
    }

    private func announce(_ step: GuidedPracticeStep) {
        switch step.kind {
        case .contract:
            speechService.speakContract()
            startContinuousHaptic()
        case .relax:
            speechService.speakRelax()
            hapticService.relaxStart()
        case .rest:
            speechService.speakRest()
            hapticService.restStart()
        case .instruction, .breathe, .bodyScan, .reflection, .partnerPrompt:
            speechService.speakGuidance(localizedKey: step.guidanceKey)
            hapticService.simplePulse()
        }
    }

    private func startContinuousHaptic() {
        guard hapticService.isEnabled else { return }
        stopHapticTimer()
        hapticService.contractStart()
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.hapticService.contractStart()
        }
        if let hapticTimer { RunLoop.current.add(hapticTimer, forMode: .common) }
    }

    private func stopHapticTimer() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }

    private func updateLegacyProgress() {
        guard let program = currentProgram, progress.totalSteps > 0 else { return }
        let fraction = Double(progress.currentStepIndex) / Double(progress.totalSteps)
        progress.currentSetIndex = min(program.sets.count, Int(fraction * Double(program.sets.count)))
    }

    private func completeTraining() {
        timer?.invalidate()
        timer = nil
        stopHapticTimer()
        progress.currentStepIndex = progress.totalSteps
        progress.isAwaitingContinue = false
        progress.currentSetIndex = currentProgram?.sets.count ?? 0
        isRunning = false
        isPaused = false
        speechService.speakComplete()
        hapticService.trainingComplete()
        saveRecord(isCompleted: true)
        endBackgroundTask()
    }

    private func saveRecord(isCompleted: Bool) {
        guard let program = currentProgram, let startTime else { return }
        let record = TrainingRecord(
            programId: program.id,
            programName: program.name,
            duration: max(0, Int(Date().timeIntervalSince(startTime))),
            completedSets: isCompleted ? program.sets.count : progress.currentSetIndex,
            totalSets: program.sets.count,
            isCompleted: isCompleted,
            route: program.route
        )
        onTrainingComplete?(record)
        DataService.shared.saveRecord(record)
        self.startTime = nil
    }

    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            Task { @MainActor in self?.endBackgroundTask() }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    var currentActionDescription: String {
        guard let currentStep else { return "" }
        return NSLocalizedString(currentStep.titleKey, comment: "")
    }

    var progressDescription: String {
        guard progress.totalSteps > 0 else { return "" }
        return String(localized: "guided.progress \(min(progress.currentStepIndex + 1, progress.totalSteps)) \(progress.totalSteps)")
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
