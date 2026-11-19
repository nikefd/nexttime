import AVFoundation
import Combine
import Foundation

@MainActor
final class TrainingManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = TrainingManager()

    @Published var currentProgram: TrainingProgram?
    @Published var progress = TrainingProgress()
    @Published var isRunning = false
    @Published var isPaused = false
    @Published private(set) var activeSteps: [GuidedPracticeStep] = []

    @Published private(set) var recordedLesson: StageOneLesson?
    @Published private(set) var recordedElapsed: Double = 0
    @Published private(set) var completedRecord: TrainingRecord?
    @Published private(set) var recordSaveFailed = false
    @Published private(set) var recordedPlaybackFailed = false
    private let recordedLessonsEnabled: Bool
    private let forcedRecordedVoice: NarrationVoice?
    private var lessonPlayer: AVAudioPlayer?
    private var precedingLessonSeconds: Double = 0
    private var precedingPracticeSeconds: Double = 0
    private var sectionPlayedSeconds: Double = 0
    private var pendingRecord: TrainingRecord?
    private var recordedSectionEnded = false

    private let hapticService = HapticService.shared
    private let speechService = SpeechService.shared
    private let dataService: DataService
    private var timer: Timer?
    private var hapticTimer: Timer?
    private var startTime: Date?
    private var pathContext: PracticePathContext?

    var onTrainingComplete: ((TrainingRecord) -> Void)?

    init(dataService: DataService = .shared, recordedLessonsEnabled: Bool = true, recordedVoice: NarrationVoice? = nil) {
        self.dataService = dataService
        self.recordedLessonsEnabled = recordedLessonsEnabled
        self.forcedRecordedVoice = recordedVoice
        super.init()
    }

    var currentStep: GuidedPracticeStep? {
        activeSteps[safe: progress.currentStepIndex]
    }

    func resetState() {
        timer?.invalidate()
        timer = nil
        stopHapticTimer()
        speechService.stop()
        lessonPlayer?.stop()
        lessonPlayer = nil
        recordedLesson = nil
        recordedElapsed = 0
        precedingLessonSeconds = 0
        precedingPracticeSeconds = 0
        sectionPlayedSeconds = 0
        completedRecord = nil
        pendingRecord = nil
        recordedSectionEnded = false
        recordSaveFailed = false
        recordedPlaybackFailed = false
        startTime = nil
        isRunning = false
        isPaused = false
        currentProgram = nil
        pathContext = nil
        activeSteps = []
        progress = TrainingProgress()
    }

    func startTraining(program: TrainingProgram, pathContext: PracticePathContext? = nil) {
        resetState()
        currentProgram = program
        self.pathContext = pathContext
        activeSteps = program.resolvedGuidedSteps
        let voice = forcedRecordedVoice ?? (speechService.usesChinese ? NarrationVoice.resolve(dataService.loadSettings().selectedVoice) : nil)
        if recordedLessonsEnabled, program.id == TrainingData.foundationAwareness.id, let voice {
            do {
                let lesson = try StageOneLesson.load(voice: voice)
                recordedLesson = lesson
                activeSteps = lesson.steps
            } catch { recordedPlaybackFailed = true }
        }
        progress = TrainingProgress()
        progress.totalSets = program.sets.count
        progress.totalSteps = activeSteps.count
        isRunning = true
        startTime = Date()
        hapticService.prepare()
        if recordedPlaybackFailed { isPaused = true } else { beginCurrentStep() }
    }

    func pauseTraining() {
        speechService.stop()
        guard isRunning, !isPaused, !progress.isAwaitingContinue else { return }
        lessonPlayer?.pause()
        if recordedLesson != nil { sampleRecordedProgress() }
        isPaused = true
        timer?.invalidate()
        timer = nil
        stopHapticTimer()
    }

    func resumeTraining() {
        guard isRunning, isPaused, currentStep?.duration != nil else { return }
        guard !recordedPlaybackFailed else { return }
        isPaused = false
        if recordedLesson != nil {
            if recordedSectionEnded, let player = lessonPlayer {
                recordedSectionEnded = false
                finishRecordedSection(player)
                return
            }
            guard lessonPlayer?.play() == true else { failRecordedPlayback(); return }
            startRecordedTimer()
            if currentStep?.kind == .contract { startContinuousHaptic() }
        } else {
            startTimer()
            if let step = currentStep { announce(step) }
        }
    }

    func advanceStep() {
        guard isRunning else { return }
        if recordedLesson != nil {
            guard progress.isAwaitingContinue, !isPaused else { return }
            advanceRecordedSection()
            return
        }
        timer?.invalidate()
        timer = nil
        stopHapticTimer()
        speechService.stop()
        progress.currentStepIndex += 1
        progress.isAwaitingContinue = false
        updateLegacyProgress()
        progress.currentStepIndex >= progress.totalSteps ? completeTraining() : beginCurrentStep()
    }

    func stopTraining() {
        if recordedLesson != nil { sampleRecordedProgress() }
        saveRecord(isCompleted: progress.isCompleted)
        resetState()
    }

    func skipRest() {
        guard recordedLesson == nil, currentStep?.kind == .rest else { return }
        advanceStep()
    }

    private func beginCurrentStep() {
        if recordedLesson != nil { beginRecordedSection(); return }
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
        progress.currentSetIndex = recordedLesson != nil ? 1 : (currentProgram?.sets.count ?? 0)
        isRunning = false
        isPaused = false
        if recordedLesson == nil { speechService.speakComplete() }
        lessonPlayer?.stop()
        hapticService.trainingComplete()
        saveRecord(isCompleted: true)
    }

    private func saveRecord(isCompleted: Bool) {
        guard let program = currentProgram, startTime != nil else { return }
        if recordedLesson != nil, progress.elapsedTime == 0, !isCompleted {
            self.startTime = nil
            return
        }
        let record = pendingRecord ?? TrainingRecord(
            programId: program.id,
            programName: recordedLesson != nil ? String(localized: "voice.pilot.title") : program.name,
            duration: progress.elapsedTime,
            completedSets: isCompleted ? program.sets.count : progress.currentSetIndex,
            totalSets: program.sets.count,
            isCompleted: isCompleted,
            route: program.route,
            pathID: pathContext?.pathID, pathStage: pathContext?.stage,
            lessonVersion: recordedLesson != nil ? StageOneLesson.version : nil,
            completedRepetitions: recordedLesson != nil ? progress.currentRepetition : nil,
            totalRepetitions: recordedLesson != nil ? 6 : nil
        )
        if dataService.saveRecord(record) {
            completedRecord = record
            pendingRecord = nil
            recordSaveFailed = false
            self.startTime = nil
            onTrainingComplete?(record)
        } else {
            pendingRecord = record
            recordSaveFailed = true
        }
    }

    func retrySaveRecord() { if pendingRecord != nil { saveRecord(isCompleted: progress.isCompleted) } }

    private func beginRecordedSection() {
        guard let lesson = recordedLesson, let step = currentStep,
              lesson.audioURLs.indices.contains(progress.currentStepIndex) else { completeTraining(); return }
        sectionPlayedSeconds = 0
        recordedSectionEnded = false
        isPaused = false
        progress.isAwaitingContinue = false
        progress.currentAction = step.kind.exerciseAction
        progress.remainingSeconds = step.duration ?? 0
        progress.isResting = step.kind == .rest
        do {
            let player = try AVAudioPlayer(contentsOf: lesson.audioURLs[progress.currentStepIndex])
            player.delegate = self
            player.volume = speechService.isEnabled ? speechService.volume : 0
            lessonPlayer = player
            guard player.play() else { failRecordedPlayback(); return }
            if step.kind == .contract { startContinuousHaptic() }
            else if step.kind == .relax { hapticService.relaxStart() }
            else if step.kind == .rest { hapticService.restStart() }
            startRecordedTimer()
        } catch { failRecordedPlayback() }
    }

    private func startRecordedTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleRecordedProgress() }
        }
        if let timer { RunLoop.current.add(timer, forMode: .common) }
    }

    private func sampleRecordedProgress() {
        guard let player = lessonPlayer, recordedLesson != nil, !isPaused else { return }
        sectionPlayedSeconds = max(sectionPlayedSeconds, player.currentTime)
        recordedElapsed = precedingLessonSeconds + sectionPlayedSeconds
        progress.remainingSeconds = max(0, Int(ceil(player.duration - sectionPlayedSeconds)))
        let active = StageOneLesson.countsAsPractice(progress.currentStepIndex) ? sectionPlayedSeconds : 0
        progress.elapsedTime = Int((precedingPracticeSeconds + active + 0.001).rounded(.down))
    }

    private func advanceRecordedSection() {
        guard recordedLesson != nil else { return }
        timer?.invalidate()
        timer = nil
        stopHapticTimer()
        precedingLessonSeconds += sectionPlayedSeconds
        if StageOneLesson.countsAsPractice(progress.currentStepIndex) { precedingPracticeSeconds += sectionPlayedSeconds }
        progress.currentRepetition = StageOneLesson.completedRepetitions(after: progress.currentStepIndex)
        progress.currentSetIndex = progress.currentRepetition == 6 ? 1 : 0
        progress.currentStepIndex += 1
        progress.isAwaitingContinue = false
        progress.currentStepIndex >= progress.totalSteps ? completeTraining() : beginRecordedSection()
    }

    private func failRecordedPlayback() {
        lessonPlayer?.pause()
        timer?.invalidate()
        timer = nil
        stopHapticTimer()
        isPaused = true
        recordedPlaybackFailed = true
    }

    private func finishRecordedSection(_ player: AVAudioPlayer) {
        sectionPlayedSeconds = player.duration
        sampleRecordedProgress()
        timer?.invalidate()
        timer = nil
        stopHapticTimer()
        if StageOneLesson.needsReadyAfter(progress.currentStepIndex) {
            progress.isAwaitingContinue = true
            progress.remainingSeconds = 0
        } else { advanceRecordedSection() }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.isRunning, self.lessonPlayer === player else { return }
            guard flag else { self.failRecordedPlayback(); return }
            if self.isPaused { self.recordedSectionEnded = true; return }
            self.finishRecordedSection(player)
        }
    }

    var currentActionDescription: String {
        guard let currentStep else { return "" }
        return NSLocalizedString(currentStep.titleKey, comment: "")
    }

    var progressDescription: String {
        guard progress.totalSteps > 0 else { return "" }
        if let lesson = recordedLesson, lesson.timeline.sections.indices.contains(progress.currentStepIndex) {
            return lesson.timeline.sections[progress.currentStepIndex].title
        }
        return String(localized: "guided.progress \(min(progress.currentStepIndex + 1, progress.totalSteps)) \(progress.totalSteps)")
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
