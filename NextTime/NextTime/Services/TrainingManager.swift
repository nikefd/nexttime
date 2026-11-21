import AVFoundation
import Combine
import Foundation
import UIKit

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
    @Published private(set) var instructionAudioElapsed: Double = 0
    @Published private(set) var instructionAudioDuration: Double = 0
    private var actionVoice: NarrationVoice?
    private var actionAudioStart: Int?
    private var curriculumNarration: CurriculumNarration?
    private let recordedLessonsEnabled: Bool
    private let forcedRecordedVoice: NarrationVoice?
    private let narrationBundle: Bundle
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

    var curriculumStage: PracticeStage? { currentProgram.flatMap(PracticeCurriculum.stage(for:)) }

    @Published var discreetPracticeEnabled = false

    var allowsDiscreetBackgroundAudio: Bool {
        discreetPracticeEnabled && speechService.isEnabled && speechService.volume > 0
            && (recordedLesson != nil || actionVoice != nil)
    }

    func pauseUnlessDiscreetAudio() {
        if !allowsDiscreetBackgroundAudio { pauseTraining() }
    }

    var onTrainingComplete: ((TrainingRecord) -> Void)?

    init(dataService: DataService = .shared, recordedLessonsEnabled: Bool = true, recordedVoice: NarrationVoice? = nil, narrationBundle: Bundle = .main) {
        self.dataService = dataService
        self.recordedLessonsEnabled = recordedLessonsEnabled
        self.forcedRecordedVoice = recordedVoice
        self.narrationBundle = narrationBundle
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
        curriculumNarration = nil
        actionVoice = nil
        instructionAudioElapsed = 0
        actionAudioStart = nil
        instructionAudioDuration = 0
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
        if recordedLessonsEnabled, speechService.isEnabled, program.id == TrainingData.foundationAwareness.id, let voice {
            do {
                let lesson = try StageOneLesson.load(voice: voice, bundle: narrationBundle)
                recordedLesson = lesson
                activeSteps = lesson.steps
            } catch { recordedPlaybackFailed = true }
        }
        if recordedLessonsEnabled, speechService.isEnabled, let stage = curriculumStage, program.id == stage.program.id, stage != .awareness, let voice {
            do { curriculumNarration = try CurriculumNarration.load(stage: stage, voice: voice, bundle: narrationBundle) }
            catch { recordedPlaybackFailed = true }
        }
        if recordedLessonsEnabled, speechService.isEnabled, curriculumStage != nil {
            actionVoice = NarrationVoice.resolve(dataService.loadSettings().selectedVoice)
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
        else if actionAudioStart != nil { sampleActionAudio() }
        else { sampleInstructionAudioProgress() }
        isPaused = true
        timer?.invalidate()
        timer = nil
        stopHapticTimer()
    }

    func resumeTraining() {
        guard isRunning, isPaused, (currentStep?.duration != nil || instructionAudioDuration > 0) else { return }
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
        } else if actionAudioStart != nil, let player = lessonPlayer {
            if recordedSectionEnded {
                finishActionAudio(player)
                return
            }
            guard player.play() else { failRecordedPlayback(); return }
            startActionAudioTimer()
            if currentStep?.kind == .contract { startContinuousHaptic() }
        } else if instructionAudioDuration > 0 {
            if recordedSectionEnded, let player = lessonPlayer {
                recordedSectionEnded = false
                finishInstructionAudio(player)
                return
            }
            guard lessonPlayer?.play() == true else { failRecordedPlayback(); return }
            startInstructionAudioTimer()
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
        if instructionAudioDuration > 0 {
            guard progress.isAwaitingContinue, !isPaused else { return }
        }
        timer?.invalidate()
        timer = nil
        stopHapticTimer()
        speechService.stop()
        lessonPlayer?.stop()
        lessonPlayer = nil
        instructionAudioElapsed = 0
        actionAudioStart = nil
        instructionAudioDuration = 0
        recordedSectionEnded = false
        progress.currentStepIndex += 1
        progress.isAwaitingContinue = false
        updateLegacyProgress()
        progress.currentStepIndex >= progress.totalSteps ? completeTraining() : beginCurrentStep()
    }

    func stopTraining() {
        if recordedLesson != nil { sampleRecordedProgress() }
        else if actionAudioStart != nil { sampleActionAudio() }
        saveRecord(isCompleted: progress.isCompleted)
        resetState()
    }

    func skipRest() {
        guard recordedLesson == nil, curriculumStage == nil, currentStep?.kind == .rest else { return }
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
        if let voice = actionVoice, let duration = step.duration {
            beginActionAudio(step, duration: duration, voice: voice)
            return
        }
        announce(step)
        if let narration = curriculumNarration, let part = narration.part(for: step), speechService.isEnabled {
            beginInstructionAudio(narration, part: part)
        } else if step.duration != nil { startTimer() }
    }

    private func beginActionAudio(_ step: GuidedPracticeStep, duration: Int, voice: NarrationVoice) {
        guard let url = narrationBundle.url(forResource: "\(voice.assetPrefix)-\(step.kind.rawValue)-\(duration)s",
                                           withExtension: "m4a") else {
            failRecordedPlayback()
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = speechService.volume
            lessonPlayer = player
            actionAudioStart = progress.elapsedTime
            guard player.play() else { failRecordedPlayback(); return }
            switch step.kind {
            case .contract: startContinuousHaptic()
            case .relax: hapticService.relaxStart()
            case .rest: hapticService.restStart()
            default: break
            }
            startActionAudioTimer()
        } catch { failRecordedPlayback() }
    }

    private func startActionAudioTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleActionAudio() }
        }
        if let timer { RunLoop.current.add(timer, forMode: .common) }
    }

    private func sampleActionAudio() {
        guard !isPaused, let player = lessonPlayer, let start = actionAudioStart,
              let duration = currentStep?.duration else { return }
        let elapsed = min(duration, Int(player.currentTime))
        progress.elapsedTime = max(progress.elapsedTime, start + elapsed)
        progress.remainingSeconds = duration - (progress.elapsedTime - start)
    }

    private func finishActionAudio(_ player: AVAudioPlayer) {
        guard let start = actionAudioStart, let duration = currentStep?.duration else { return }
        progress.elapsedTime = start + duration
        advanceStep()
    }

    func readInstructionInstead() {
        guard recordedLesson == nil, instructionAudioDuration > 0,
              currentStep?.kind.isInteractive == true else { return }
        lessonPlayer?.stop()
        lessonPlayer = nil
        timer?.invalidate()
        timer = nil
        recordedSectionEnded = false
        instructionAudioElapsed = instructionAudioDuration
        progress.remainingSeconds = 0
        progress.isAwaitingContinue = true
        isPaused = false
    }

    func replayInstructionAudio() {
        guard let narration = curriculumNarration, let step = currentStep,
              let part = narration.part(for: step), speechService.isEnabled,
              progress.isAwaitingContinue else { return }
        isPaused = false
        beginInstructionAudio(narration, part: part)
    }

    private func beginInstructionAudio(_ narration: CurriculumNarration, part: CurriculumNarration.Part) {
        guard let url = narration.urls[part] else { failRecordedPlayback(); return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = speechService.volume
            lessonPlayer = player
            recordedSectionEnded = false
            instructionAudioDuration = player.duration
            instructionAudioElapsed = 0
            progress.remainingSeconds = Int(ceil(player.duration))
            progress.isAwaitingContinue = false
            guard player.play() else { failRecordedPlayback(); return }
            startInstructionAudioTimer()
        } catch { failRecordedPlayback() }
    }

    private func startInstructionAudioTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleInstructionAudioProgress() }
        }
        if let timer { RunLoop.current.add(timer, forMode: .common) }
    }

    private func sampleInstructionAudioProgress() {
        guard instructionAudioDuration > 0, !isPaused, let player = lessonPlayer else { return }
        instructionAudioElapsed = max(instructionAudioElapsed, player.currentTime)
        progress.remainingSeconds = max(0, Int(ceil(instructionAudioDuration - instructionAudioElapsed)))
        // Teaching and user readiness never contribute to movement/rest seconds.
    }

    private func finishInstructionAudio(_ player: AVAudioPlayer) {
        timer?.invalidate()
        timer = nil
        instructionAudioElapsed = player.duration
        progress.remainingSeconds = 0
        progress.isAwaitingContinue = true
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
        if curriculumStage != nil {
            progress.currentRepetition = activeSteps.prefix(progress.currentStepIndex).filter {
                $0.kind == .relax && PracticeCurriculum.repetition(for: $0) != nil
            }.count
            var remaining = progress.currentRepetition
            progress.currentSetIndex = program.sets.prefix { set in
                guard remaining >= set.repetitions else { return false }
                remaining -= set.repetitions
                return true
            }.count
            return
        }
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
        lessonPlayer?.stop()
        hapticService.trainingComplete()
        saveRecord(isCompleted: true)
    }

    private func saveRecord(isCompleted: Bool) {
        guard let program = currentProgram, startTime != nil else { return }
        if (recordedLesson != nil || curriculumStage != nil), progress.elapsedTime == 0, !isCompleted {
            self.startTime = nil
            return
        }
        let record = pendingRecord ?? TrainingRecord(
            programId: program.id,
            programName: NSLocalizedString(program.localizedNameKey, comment: ""),
            duration: progress.elapsedTime,
            completedSets: isCompleted ? program.sets.count : progress.currentSetIndex,
            totalSets: program.sets.count,
            isCompleted: isCompleted,
            route: program.route,
            pathID: pathContext?.pathID, pathStage: pathContext?.stage,
            lessonVersion: recordedLesson != nil ? StageOneLesson.version : curriculumStage.map(PracticeCurriculum.version(for:)),
            completedRepetitions: (recordedLesson != nil || curriculumStage != nil) ? progress.currentRepetition : nil,
            totalRepetitions: (recordedLesson != nil || curriculumStage != nil) ? (recordedLesson != nil ? 6 : program.totalRepetitions) : nil
        )
        if allowsDiscreetBackgroundAudio && UIApplication.shared.applicationState == .background {
            pendingRecord = record
            recordSaveFailed = true
            return
        }
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
            if self.recordedLesson != nil { self.finishRecordedSection(player) }
            else if self.actionAudioStart != nil { self.finishActionAudio(player) }
            else if self.instructionAudioDuration > 0 { self.finishInstructionAudio(player) }
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
        if curriculumStage != nil, let step = currentStep, let program = currentProgram {
            if let repetition = PracticeCurriculum.repetition(for: step) {
                return String(localized: "curriculum.repetition \(repetition) \(program.totalRepetitions)")
            }
            return String(localized: "curriculum.completed \(progress.currentRepetition) \(program.totalRepetitions)")
        }
        return String(localized: "guided.progress \(min(progress.currentStepIndex + 1, progress.totalSteps)) \(progress.totalSteps)")
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
