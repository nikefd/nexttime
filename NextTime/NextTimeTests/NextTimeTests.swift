//
//  NextTimeTests.swift
//  NextTimeTests
//
//  Created by zhang005 on 1/17/26.
//

import AVFoundation
import Testing
import Foundation
@testable import NextTime

@MainActor
struct NextTimeTests {

    private func pathService() throws -> (DataService, UserDefaults, String) {
        let suite = "PathTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let service = DataService(userDefaults: defaults, protectedStore: try ProtectedDataStore(inMemory: true))
        return (service, defaults, suite)
    }

    private func pathRecord(_ state: PracticePathState, at date: Date, duration: Int = 30,
                            completed: Bool = true, tagged: Bool = true) -> TrainingRecord {
        TrainingRecord(programId: state.program.id, programName: "Path", completedAt: date,
                       duration: duration, completedSets: 1, totalSets: 1, isCompleted: completed,
                       route: .foundation, pathID: tagged ? state.id : nil,
                       pathStage: tagged ? state.currentStage : nil,
                       lessonVersion: tagged ? PracticeCurriculum.version(for: state.currentStage) : nil)
    }

    @Test func pathIgnoresCalendarLegacyOptionalIncompleteAndFutureRecords() throws {
        let (service, defaults, suite) = try pathService()
        defer { defaults.removePersistentDomain(forName: suite) }
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let state = try service.startPracticePathIfNeeded(now: start)
        let later = start.addingTimeInterval(90 * 86400)
        let records = [pathRecord(state, at: start, tagged: false),
                       pathRecord(state, at: start, duration: 0),
                       pathRecord(state, at: start, completed: false),
                       pathRecord(state, at: later.addingTimeInterval(1))]
        for record in records { service.saveRecord(record) }
        let unchanged = try service.startPracticePathIfNeeded(now: later)
        #expect(unchanged.currentStage == .awareness)
        #expect(unchanged.id == state.id)
        #expect(unchanged.completedRecords(in: service.loadRecords(), now: later).isEmpty)
        for _ in 0..<3 { service.saveRecord(pathRecord(state, at: later)) }
        #expect(service.loadPracticePath()?.currentStage == .awareness)
        #expect(state.completedRecords(in: service.loadRecords(), now: later).count == 3)
    }

    @Test func legacyRecordDecodesWithoutPathFields() throws {
        let state = PracticePathState()
        let record = pathRecord(state, at: Date(), tagged: false)
        let encoded = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(TrainingRecord.self, from: encoded)
        #expect(decoded.pathID == nil)
        #expect(decoded.pathStage == nil)
        #expect(decoded.id == record.id)
    }

    @Test func pathAdvancesOnlyWithExplicitReviewAndRejectsRepeatedReview() throws {
        let (service, defaults, suite) = try pathService()
        defer { defaults.removePersistentDomain(forName: suite) }
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let state = try service.startPracticePathIfNeeded(now: start)
        let record = pathRecord(state, at: start.addingTimeInterval(10))
        service.saveRecord(record)
        let now = start.addingTimeInterval(20)
        try service.saveSessionFeedback(recordID: record.id, outcome: .comfortable, now: now)
        let incomplete = PracticeStageReview(stage: .awareness, recordID: record.id, confirmedAt: now,
                                            breathingComfortable: true, fullyReleased: false, noDiscomfort: true)
        #expect(throws: PracticePathError.self) { try service.advancePracticePath(incomplete, now: now) }
        let review = PracticeStageReview(stage: .awareness, recordID: record.id, confirmedAt: now,
                                        breathingComfortable: true, fullyReleased: true, noDiscomfort: true)
        let advanced = try service.advancePracticePath(review, now: now)
        #expect(advanced.currentStage == .awareness && advanced.isFollowUp == true)
        #expect(advanced.reviews.count == 1)
        #expect(advanced.completedRecords(in: service.loadRecords(), now: now).isEmpty)
        #expect(throws: PracticePathError.self) { try service.advancePracticePath(review, now: now) }
        #expect(service.loadPracticePath()?.isFollowUp == true)
    }

    @Test func eightLessonsAdvanceInOrderWithoutReusingPriorRecords() throws {
        let (service, defaults, suite) = try pathService()
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date()
        var path = try service.startPracticePathIfNeeded(now: now.addingTimeInterval(-1))
        var ids = Set<UUID>()
        for lesson in 1...8 {
            #expect(path.lessonNumber == lesson)
            #expect(ids.insert(path.program.id).inserted)
            #expect(path.completedRecords(in: service.loadRecords(), now: now).isEmpty)
            let record = pathRecord(path, at: now)
            service.saveRecord(record)
            try service.saveSessionFeedback(recordID: record.id, outcome: .comfortable, now: now)
            let review = PracticeStageReview(stage: path.currentStage, recordID: record.id,
                confirmedAt: now, breathingComfortable: true, fullyReleased: true, noDiscomfort: true)
            if lesson < 8 {
                path = try service.advancePracticePath(review, now: now)
            } else {
                #expect(path.nextProgram == nil)
                #expect(throws: PracticePathError.self) { try service.advancePracticePath(review, now: now) }
            }
        }
    }

    @Test func safetyFeedbackBlocksPathAdvanceAndClearRemovesPath() throws {
        let (service, defaults, suite) = try pathService()
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date()
        let state = try service.startPracticePathIfNeeded(now: now.addingTimeInterval(-60))
        let record = pathRecord(state, at: now.addingTimeInterval(-30))
        service.saveRecord(record)
        try service.saveSessionFeedback(recordID: record.id, outcome: .comfortable, now: now.addingTimeInterval(-20))
        service.saveSafetyEvent(PracticeSafetyEvent(createdAt: now.addingTimeInterval(-10),
                                programID: record.programId, response: .seekProfessionalCare))
        let review = PracticeStageReview(stage: .awareness, recordID: record.id, confirmedAt: now,
                                        breathingComfortable: true, fullyReleased: true, noDiscomfort: true)
        #expect(throws: PracticePathError.self) { try service.advancePracticePath(review, now: now) }
        #expect(service.loadPracticePath()?.reviews.isEmpty == true)
        service.clearAllData()
        #expect(service.loadPracticePath() == nil)
        #expect(service.loadRecords().isEmpty)
    }

    @Test func trainingManagerWritesActualPathContextOnce() throws {
        let (service, defaults, suite) = try pathService()
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = try service.startPracticePathIfNeeded(now: Date().addingTimeInterval(-1))
        let manager = TrainingManager(dataService: service, recordedLessonsEnabled: false)
        defer { manager.resetState() }
        manager.startTraining(program: state.currentStage.program, pathContext: state.context)
        manager.progress.elapsedTime = 12
        while manager.isRunning { manager.advanceStep() }
        manager.stopTraining()
        let records = service.loadRecords()
        #expect(records.count == 1)
        #expect(records.first?.pathID == state.id)
        #expect(records.first?.pathStage == .awareness)
        #expect(state.completedRecords(in: records).count == 1)
    }

    @Test func stageOneClipsMatchBothVoicesAndCountOnlyFullRepetitions() throws {
        #expect(StageOneLesson.completedRepetitions(after: 5) == 0)
        #expect(StageOneLesson.completedRepetitions(after: 7) == 0)
        #expect(StageOneLesson.completedRepetitions(after: 8) == 1)
        #expect(StageOneLesson.completedRepetitions(after: 17) == 5)
        #expect(StageOneLesson.completedRepetitions(after: 18) == 6)
        for voice in NarrationVoice.allCases {
            let lesson = try StageOneLesson.load(voice: voice)
            var practiceSeconds: Double = 0
            for index in lesson.audioURLs.indices {
                let player = try AVAudioPlayer(contentsOf: lesson.audioURLs[index])
                let section = lesson.timeline.sections[index]
                #expect(abs(player.duration - (section.end - section.start)) < 0.05)
                if StageOneLesson.countsAsPractice(index) { practiceSeconds += player.duration }
            }
            #expect(abs(practiceSeconds - 117) < 0.1)
            #expect(lesson.steps.filter { $0.kind == .contract }.count == 8)
            #expect(StageOneLesson.needsReadyAfter(0))
            #expect(StageOneLesson.needsReadyAfter(1))
            #expect(!StageOneLesson.needsReadyAfter(5))
        }
    }

    @Test func recordedInstructionPausesWithoutCountingOrSavingPractice() async throws {
        let (service, defaults, suite) = try pathService()
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = try service.startPracticePathIfNeeded()
        let manager = TrainingManager(dataService: service, recordedVoice: .male)
        defer { manager.resetState() }
        manager.startTraining(program: TrainingData.foundationAwareness, pathContext: state.context)
        #expect(manager.recordedLesson?.voice == .male)
        try await Task.sleep(for: .milliseconds(1200))
        manager.pauseTraining()
        let seconds = manager.recordedElapsed
        #expect(seconds > 0)
        #expect(manager.progress.elapsedTime == 0)
        try await Task.sleep(for: .milliseconds(1200))
        #expect(manager.recordedElapsed == seconds)
        #expect(manager.progress.currentStepIndex == 0)
        manager.resumeTraining()
        #expect(!manager.isPaused)
        manager.stopTraining()
        #expect(service.loadRecords().isEmpty)
    }

    @Test func sessionFeedbackIsBoundToRecordAndUnsureDoesNotAllowProgress() throws {
        for outcome in SessionFeedbackOutcome.allCases {
            let (service, defaults, suite) = try pathService()
            defer { defaults.removePersistentDomain(forName: suite) }
            let now = Date()
            let path = try service.startPracticePathIfNeeded(now: now.addingTimeInterval(-60))
            let record = TrainingRecord(programId: path.currentStage.program.id, programName: "First", completedAt: now.addingTimeInterval(-10), duration: 117, completedSets: 1, totalSets: 1, isCompleted: true, route: .foundation, pathID: path.id, pathStage: .awareness, lessonVersion: StageOneLesson.version, completedRepetitions: 6, totalRepetitions: 6)
            service.saveRecord(record)
            let review = PracticeStageReview(stage: .awareness, recordID: record.id, confirmedAt: now, breathingComfortable: true, fullyReleased: true, noDiscomfort: true)
            #expect(throws: PracticePathError.self) { try service.advancePracticePath(review, now: now) }
            #expect(throws: PracticePathError.self) { try service.saveSessionFeedback(recordID: UUID(), outcome: outcome, now: now) }
            try service.saveSessionFeedback(recordID: record.id, outcome: outcome, now: now)
            try service.saveSessionFeedback(recordID: record.id, outcome: outcome, now: now)
            #expect(service.loadSessionFeedback().count == 1)
            if outcome == .comfortable {
                #expect(try service.advancePracticePath(review, now: now).isFollowUp == true)
            } else {
                #expect(throws: PracticePathError.self) { try service.advancePracticePath(review, now: now) }
                #expect(service.loadPracticePath()?.currentStage == .awareness)
            }
            if outcome == .discomfort {
                #expect(service.loadSafetyEvents().contains { $0.id == record.id })
                #expect(throws: PracticePathError.self) { try service.saveSessionFeedback(recordID: record.id, outcome: .comfortable, now: now) }
            }
            service.clearAllData()
            #expect(service.loadSessionFeedback().isEmpty)
        }
    }

    @Test func productionCurriculumNarrationCoversBothVoicesAndEveryLaterStage() throws {
        for voice in NarrationVoice.allCases {
            var introductions: Set<URL> = []
            var checks: Set<URL> = []
            for stage in PracticeStage.allCases where stage != .awareness {
                let narration = try CurriculumNarration.load(stage: stage, voice: voice)
                #expect(narration.voice == voice)
                #expect(narration.stage == stage)
                #expect(narration.urls.count == 3)
                #expect(narration.durations.values.allSatisfy { $0 > 5 && $0 < 60 })
                #expect(narration.duration > 30)
                introductions.insert(try #require(narration.urls[.prepare]))
                checks.insert(try #require(narration.urls[.check]))
                let matched = stage.program.resolvedGuidedSteps.compactMap { narration.part(for: $0) }
                #expect(matched == [.prepare, .check, .reflect])
                for url in narration.urls.values {
                    #expect(url.lastPathComponent.hasPrefix(voice.assetPrefix))
                    #expect(try AVAudioPlayer(contentsOf: url).duration > 0)
                }
            }
            #expect(introductions.count == 3)
            #expect(checks.count == 1)
        }
        let female = try CurriculumNarration.load(stage: .steady, voice: .female)
        let male = try CurriculumNarration.load(stage: .steady, voice: .male)
        #expect(try Data(contentsOf: #require(female.urls[.check])) != Data(contentsOf: #require(male.urls[.check])))
    }

    private func instructionFixture(long: Bool) throws -> (Bundle, URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("NarrationFixture-\(UUID()).bundle")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let info = ["CFBundleIdentifier": "test.nexttime.narration", "CFBundleName": "NarrationFixture", "CFBundlePackageType": "BNDL"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: folder.appendingPathComponent("Info.plist"))
        let source = try #require(Bundle.main.url(forResource: long ? "nexttime-xiaoyi-section-00" : "nexttime-xiaoyi-contract", withExtension: "m4a"))
        for suffix in ["prepare-2", "check", "reflect"] {
            try FileManager.default.copyItem(at: source, to: folder.appendingPathComponent("nexttime-xiaoyi-curriculum-\(suffix).m4a"))
        }
        let cue = try #require(Bundle.main.url(forResource: "nexttime-xiaoyi-contract-3s", withExtension: "m4a"))
        try FileManager.default.copyItem(at: cue, to: folder.appendingPathComponent(cue.lastPathComponent))
        return (try #require(Bundle(url: folder)), folder)
    }

    @Test func narratedInstructionPausesReplaysAndCanSwitchToReading() async throws {
        let (service, defaults, suite) = try pathService()
        defer { defaults.removePersistentDomain(forName: suite) }
        let (bundle, folder) = try instructionFixture(long: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let manager = TrainingManager(dataService: service, recordedVoice: .female, narrationBundle: bundle)
        defer { manager.resetState() }
        manager.startTraining(program: PracticeStage.steady.program)
        #expect(manager.instructionAudioDuration > 10)
        #expect(!manager.progress.isAwaitingContinue)
        try await Task.sleep(for: .milliseconds(300))
        manager.pauseTraining()
        let elapsed = manager.instructionAudioElapsed
        #expect(elapsed > 0)
        try await Task.sleep(for: .milliseconds(300))
        #expect(manager.instructionAudioElapsed == elapsed)
        #expect(manager.progress.elapsedTime == 0)
        manager.advanceStep()
        #expect(manager.progress.currentStepIndex == 0)
        manager.resumeTraining()
        #expect(!manager.isPaused)
        manager.readInstructionInstead()
        #expect(manager.progress.isAwaitingContinue)
        manager.replayInstructionAudio()
        #expect(!manager.progress.isAwaitingContinue)
        #expect(manager.instructionAudioElapsed == 0)
        manager.readInstructionInstead()
        manager.advanceStep()
        #expect(manager.currentStep?.kind == .contract)
        #expect(manager.instructionAudioDuration == 0)
        #expect(manager.progress.currentRepetition == 0)
        manager.stopTraining()
        #expect(service.loadRecords().isEmpty)
    }

    @Test func narratedInstructionWaitsForReadinessAfterActualAudioEnds() async throws {
        let (service, defaults, suite) = try pathService()
        defer { defaults.removePersistentDomain(forName: suite) }
        let (bundle, folder) = try instructionFixture(long: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let manager = TrainingManager(dataService: service, recordedVoice: .female, narrationBundle: bundle)
        defer { manager.resetState() }
        manager.startTraining(program: PracticeStage.steady.program)
        #expect(manager.instructionAudioDuration > 0)
        #expect(!manager.progress.isAwaitingContinue)
        for _ in 0..<30 {
            if manager.progress.isAwaitingContinue { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(manager.progress.isAwaitingContinue)
        #expect(manager.instructionAudioElapsed == manager.instructionAudioDuration)
        #expect(manager.progress.currentStepIndex == 0)
        #expect(manager.progress.elapsedTime == 0)
        manager.stopTraining()
        #expect(service.loadRecords().isEmpty)
    }

    @Test func voiceOffUsesReadablePreparationInsteadOfSilentAudioWaiting() throws {
        let original = SpeechService.shared.isEnabled
        SpeechService.shared.isEnabled = false
        defer { SpeechService.shared.isEnabled = original }
        let (service, defaults, suite) = try pathService()
        defer { defaults.removePersistentDomain(forName: suite) }
        for stage in PracticeStage.allCases {
            let manager = TrainingManager(dataService: service, recordedVoice: .female)
            manager.startTraining(program: stage.program)
            #expect(manager.recordedLesson == nil)
            #expect(manager.instructionAudioDuration == 0)
            #expect(manager.progress.isAwaitingContinue)
            #expect(!manager.recordedPlaybackFailed)
            manager.stopTraining()
        }
        #expect(service.loadRecords().isEmpty)
    }

    @Test func missingCurriculumNarrationFailsWithoutSubstitutingVoices() throws {
        let (service, defaults, suite) = try pathService()
        defer { defaults.removePersistentDomain(forName: suite) }
        let (bundle, folder) = try instructionFixture(long: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let manager = TrainingManager(dataService: service, recordedVoice: .female, narrationBundle: bundle)
        defer { manager.resetState() }
        manager.startTraining(program: PracticeStage.rhythm.program) // fixture deliberately lacks stage three
        #expect(manager.recordedPlaybackFailed)
        #expect(manager.isPaused)
        #expect(manager.progress.elapsedTime == 0)
        manager.resumeTraining()
        #expect(manager.isPaused)
        manager.stopTraining()
        #expect(service.loadRecords().isEmpty)
    }

    @Test func bundledNarrationHasBothVoicesAndAccuratePilotTimelines() throws {
        #expect(NarrationVoice.resolve(nil) == .female)
        #expect(NarrationVoice.resolve(UserSettings().selectedVoice) == .female)
        #expect(NarrationVoice.resolve("nexttime.yunxi") == .male)
        #expect(NarrationVoice.resolve("system") == nil)
        for voice in NarrationVoice.allCases {
            for suffix in ["contract", "relax", "rest", "pilot"] {
                let url = try #require(Bundle.main.url(forResource: "\(voice.assetPrefix)-\(suffix)", withExtension: "m4a"))
                let audio = try AVAudioPlayer(contentsOf: url)
                #expect(audio.duration > 0)
                if suffix != "pilot" { #expect(audio.duration < 1.5) }
            }
            #expect(Bundle.main.url(forResource: "\(voice.assetPrefix)-preview", withExtension: "mp3") != nil)
            let url = try #require(Bundle.main.url(forResource: "\(voice.assetPrefix)-pilot", withExtension: "json"))
            let timeline = try JSONDecoder().decode(PilotNarrationTimeline.self, from: Data(contentsOf: url))
            #expect(timeline.sections.count == 21)
            #expect(timeline.sections.first?.start == 0)
            #expect(timeline.sections.last?.end == timeline.duration)
            for (left, right) in zip(timeline.sections, timeline.sections.dropFirst()) {
                #expect(abs(left.end - right.start) < 0.001)
            }
        }
    }

    @Test func narrationSelectionMigratesRemovedSystemVoicesToFemale() throws {
        let suite = "NextTimeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = DataService(userDefaults: defaults, protectedStore: try ProtectedDataStore(inMemory: true))
        var settings = service.loadSettings()
        #expect(settings.selectedVoice == "default")
        settings.selectedVoice = NarrationVoice.male.rawValue
        service.saveSettings(settings)
        #expect(service.loadSettings().selectedVoice == "nexttime.yunxi")
        settings.selectedVoice = "existing.system.voice"
        service.saveSettings(settings)
        #expect(service.loadSettings().selectedVoice == "default")
        #expect(service.loadSettings().selectedVoice == "default")
    }

    @Test func trainingRecordsActiveSecondsAndDoesNotSaveTwice() throws {
        let suite = "NextTimeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = DataService(userDefaults: defaults, protectedStore: try ProtectedDataStore(inMemory: true))
        let manager = TrainingManager(dataService: service, recordedLessonsEnabled: false)
        defer { manager.resetState() }
        manager.startTraining(program: TrainingData.foundationAwareness)
        manager.advanceStep()
        manager.progress.elapsedTime = 7
        manager.pauseTraining()
        #expect(manager.isPaused)
        #expect(manager.progress.elapsedTime == 7)
        manager.stopTraining()
        manager.stopTraining()
        #expect(service.loadRecords().count == 1)
        #expect(service.loadRecords().first?.duration == 7)
        #expect(service.loadRecords().first?.isCompleted == false)
    }

    @Test func pausedTrainingKeepsStepAndSecondsUntilManualResume() async throws {
        let suite = "NextTimeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = DataService(userDefaults: defaults, protectedStore: try ProtectedDataStore(inMemory: true))
        let manager = TrainingManager(dataService: service, recordedLessonsEnabled: false)
        defer { manager.resetState() }
        manager.startTraining(program: TrainingData.foundationAwareness)
        manager.advanceStep()
        #expect(manager.currentStep?.duration != nil)
        let index = manager.progress.currentStepIndex
        let remaining = manager.progress.remainingSeconds
        let elapsed = manager.progress.elapsedTime
        manager.pauseTraining()
        manager.pauseTraining()
        try await Task.sleep(for: .milliseconds(1200))
        #expect(manager.isRunning)
        #expect(manager.isPaused)
        #expect(manager.progress.currentStepIndex == index)
        #expect(manager.progress.remainingSeconds == remaining)
        #expect(manager.progress.elapsedTime == elapsed)
        manager.resumeTraining()
        #expect(!manager.isPaused)
        #expect(manager.progress.currentStepIndex == index)
        manager.resetState()
        #expect(!manager.isRunning)
        #expect(!manager.isPaused)
    }

    @Test func failedLegacyDecodePreservesSourceAndAllowsRetry() throws {
        let suite = "NextTimeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = try ProtectedDataStore(inMemory: true)
        let invalid = Data("incomplete record".utf8)
        defaults.set(invalid, forKey: "trainingRecords")
        _ = DataService(userDefaults: defaults, protectedStore: store)
        #expect(defaults.data(forKey: "trainingRecords") == invalid)
        #expect(store.load(Bool.self, forKey: "migration.user-defaults.v1") != true)
        defaults.set(try JSONEncoder().encode([TrainingRecord]()), forKey: "trainingRecords")
        _ = DataService(userDefaults: defaults, protectedStore: store)
        #expect(defaults.data(forKey: "trainingRecords") == nil)
        #expect(store.load(Bool.self, forKey: "migration.user-defaults.v1") == true)
    }

    @Test func migratesLegacyTrainingDataIntoProtectedStore() throws {
        let suiteName = "NextTimeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let record = TrainingRecord(
            id: UUID(),
            programId: UUID(),
            programName: "Legacy Program",
            completedAt: Date(timeIntervalSince1970: 1_700_000_000),
            duration: 180,
            completedSets: 2,
            totalSets: 2,
            isCompleted: true
        )
        defaults.set(try JSONEncoder().encode([record]), forKey: "trainingRecords")
        defaults.set(
            try JSONEncoder().encode([record.programId]),
            forKey: "completedPrograms"
        )

        let protectedStore = try ProtectedDataStore(inMemory: true)
        let service = DataService(userDefaults: defaults, protectedStore: protectedStore)

        #expect(service.loadRecords().map(\.id) == [record.id])
        #expect(service.loadCompletedProgramIds() == [record.programId])
        #expect(defaults.data(forKey: "trainingRecords") == nil)
        #expect(defaults.data(forKey: "completedPrograms") == nil)
    }

    @Test func onboardingRequiresCurrentAdultSafetyAcknowledgement() throws {
        let suiteName = "NextTimeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = DataService(
            userDefaults: defaults,
            protectedStore: try ProtectedDataStore(inMemory: true)
        )
        #expect(service.hasCompletedOnboarding == false)

        let goals: Set<WellnessGoal> = [.pelvicFoundation, .relaxation]
        let date = Date(timeIntervalSince1970: 1_700_000_100)
        service.completeOnboarding(selectedGoals: goals, now: date)

        #expect(service.hasCompletedOnboarding)
        #expect(service.loadWellnessProfile() == WellnessProfile(selectedGoals: goals, createdAt: date))
        #expect(service.loadSafetyAcknowledgement()?.confirmedAdult == true)
        #expect(service.loadSafetyAcknowledgement()?.version == SafetyAcknowledgement.currentVersion)
    }

    @Test func clearAllDataRemovesSensitiveAndPreferenceData() throws {
        let suiteName = "NextTimeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = DataService(
            userDefaults: defaults,
            protectedStore: try ProtectedDataStore(inMemory: true)
        )
        service.completeOnboarding(selectedGoals: [.bodyConfidence])
        service.saveRecord(
            TrainingRecord(
                programId: UUID(),
                programName: "Protected Program",
                duration: 60,
                completedSets: 1,
                totalSets: 1,
                isCompleted: true
            )
        )
        service.saveSettings(UserSettings())
        service.saveSafetyEvent(
            PracticeSafetyEvent(programID: UUID(), response: .stopAndRecover)
        )
        defaults.set(true, forKey: "appLockEnabled")
        defaults.set(false, forKey: "discreetNotifications")

        service.clearAllData()

        #expect(service.loadRecords().isEmpty)
        #expect(service.loadCompletedProgramIds().isEmpty)
        #expect(service.hasCompletedOnboarding == false)
        #expect(service.loadWellnessProfile() == nil)
        #expect(service.loadSafetyEvents().isEmpty)
        #expect(defaults.data(forKey: "userSettings") == nil)
        #expect(defaults.object(forKey: "appLockEnabled") == nil)
        #expect(defaults.object(forKey: "discreetNotifications") == nil)
    }

    @Test func discreetReminderUsesDifferentCopy() {
        let discreet = ReminderService.reminderCopy(discreet: true)
        let detailed = ReminderService.reminderCopy(discreet: false)

        #expect(discreet.title != detailed.title)
        #expect(discreet.body != detailed.body)
    }

    @Test func sevenDayPlanIgnoresLegacyPartnerGoal() {
        let plan = TrainingData.sevenDayPlan(for: [.relaxation, .partnerConnection])
        let programRoutes = plan.days.compactMap { day in
            TrainingData.allPrograms.first { $0.id == day.programID }?.route
        }

        #expect(plan.days.count == 7)
        #expect(Set(programRoutes) == [.relaxation])
        #expect(programRoutes.allSatisfy { $0 != .partner })
    }

    @Test func milestoneFProvidesTwentyFourSubstantialCourses() {
        #expect(TrainingData.allPrograms.count == 24)
        #expect(Set(TrainingData.allPrograms.map(\.id)).count == 24)

        for route in PracticeRoute.allCases {
            let programs = TrainingData.programs(for: route)
            #expect(programs.count == 6)
            #expect(programs.allSatisfy { $0.totalDuration >= 180 })
            #expect(programs.allSatisfy { $0.totalDuration <= 12 * 60 })
        }
    }

    @Test func personalExperienceUsesOnlyEighteenIndividualPrograms() {
        #expect(TrainingData.personalPrograms.count == 18)
        #expect(TrainingData.personalPrograms.allSatisfy { $0.route != .partner })
        #expect(WellnessGoal.personalCases == [.pelvicFoundation, .relaxation, .bodyConfidence])
        #expect(PracticeRoute.personalCases == [.foundation, .relaxation, .confidence])

        let legacyPartnerPlan = TrainingData.sixWeekPlan(for: [.partnerConnection])
        #expect(legacyPartnerPlan.days.allSatisfy { day in
            TrainingData.personalPrograms.contains { $0.id == day.programID }
        })
    }

    @Test func sixWeekPlanProgressesAndIncludesRecoveryDays() {
        let plan = TrainingData.sixWeekPlan(for: [.pelvicFoundation])

        #expect(plan.days.count == 42)
        #expect(Set(plan.days.map(\.week)) == Set(1...6))
        #expect(plan.days.filter(\.isRecoveryDay).count == 12)
        #expect(Set(plan.days.map(\.programID)).count > 7)
        #expect(plan.days.allSatisfy { day in
            TrainingData.allPrograms.contains { $0.id == day.programID }
        })
    }

    @Test func longTermPlanAvoidsRecentlyCompletedCourse() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let planned = TrainingData.longTermRecommendation(
            for: [.pelvicFoundation],
            createdAt: start,
            records: [],
            now: start,
            calendar: calendar
        )
        let recent = TrainingRecord(
            programId: planned.programID,
            programName: "Recent",
            completedAt: start,
            duration: 180,
            completedSets: 1,
            totalSets: 1,
            isCompleted: true
        )
        let adjusted = TrainingData.longTermRecommendation(
            for: [.pelvicFoundation],
            createdAt: start,
            records: [recent],
            now: start,
            calendar: calendar
        )

        #expect(adjusted.mode == .progressive)
        #expect(adjusted.programID != planned.programID)
    }

    @Test func planMovesIntoMaintenanceAfterSixWeeks() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let later = calendar.date(byAdding: .day, value: 60, to: start)!
        let recommendation = TrainingData.longTermRecommendation(
            for: [.relaxation],
            createdAt: start,
            records: [],
            now: later,
            calendar: calendar
        )

        #expect(recommendation.mode == .maintenance)
        #expect(recommendation.absoluteDay == 61)
        #expect(TrainingData.personalPrograms.contains { $0.id == recommendation.programID })
    }

    @Test func storesWellnessCheckInsAndPartnerCardProgressLocally() throws {
        let suiteName = "NextTimeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let service = DataService(
            userDefaults: defaults,
            protectedStore: try ProtectedDataStore(inMemory: true)
        )
        let checkIn = WellnessCheckIn(
            moment: .beforePractice,
            comfort: 4,
            tension: 2,
            energy: 3
        )

        service.saveCheckIn(checkIn)
        service.markPartnerCardCompleted("boundary")

        #expect(service.loadCheckIns() == [checkIn])
        #expect(service.loadCompletedPartnerCardIDs() == ["boundary"])
    }

    @Test func eachPracticeRouteUsesARealGuidedScript() {
        #expect(TrainingData.foundationAwareness.resolvedGuidedSteps.contains { $0.kind == .contract })
        #expect(TrainingData.relaxationBreathing.resolvedGuidedSteps.contains { $0.kind == .bodyScan })
        #expect(TrainingData.confidenceBodyScan.resolvedGuidedSteps.contains { $0.kind == .reflection })
        #expect(TrainingData.partnerPause.resolvedGuidedSteps.contains { $0.kind == .partnerPrompt })

        for program in TrainingData.allPrograms {
            #expect(program.resolvedGuidedSteps.count >= 4)
            #expect(program.resolvedGuidedSteps.first?.kind == .instruction)
        }
    }

    @Test func legacyProgramsReceiveACompatibleGuidedScript() {
        let program = TrainingProgram(
            name: "Legacy",
            localizedNameKey: "legacy.name",
            description: "Legacy timer program",
            localizedDescriptionKey: "legacy.description",
            difficulty: .beginner,
            sets: [ExerciseSet(contractDuration: 3, relaxDuration: 5, repetitions: 2)],
            order: 1
        )

        let steps = program.resolvedGuidedSteps
        #expect(steps.map(\.kind) == [.instruction, .contract, .relax, .contract, .relax])
        #expect(program.totalDuration == 16)
    }

    @Test func interactiveGuidanceDoesNotInflateTimedDuration() {
        let program = TrainingData.partnerPause
        let timedDuration = program.resolvedGuidedSteps.compactMap(\.duration).reduce(0, +)

        #expect(program.totalDuration == timedDuration)
        #expect(program.resolvedGuidedSteps.contains { $0.duration == nil })
    }

    @Test func dailyRecommendationAdaptsToTodaysCheckIn() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let lowComfort = WellnessCheckIn(
            createdAt: now,
            moment: .beforePractice,
            comfort: 2,
            tension: 4,
            energy: 4
        )
        let result = PracticeRecommendationEngine.recommend(
            plannedProgramID: TrainingData.foundationAwareness.id,
            relaxationProgramID: TrainingData.relaxationBreathing.id,
            bodyScanProgramID: TrainingData.confidenceBodyScan.id,
            checkIns: [lowComfort],
            safetyEvents: [],
            now: now
        )

        #expect(result.programID == TrainingData.relaxationBreathing.id)
        #expect(result.kind == .lowerIntensity)
    }

    @Test func lowEnergyChoosesBodyScanWithoutClaimingDiagnosis() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let checkIn = WellnessCheckIn(
            createdAt: now,
            moment: .beforePractice,
            comfort: 4,
            tension: 2,
            energy: 2
        )
        let result = PracticeRecommendationEngine.recommend(
            plannedProgramID: TrainingData.foundationAwareness.id,
            relaxationProgramID: TrainingData.relaxationBreathing.id,
            bodyScanProgramID: TrainingData.confidenceBodyScan.id,
            checkIns: [checkIn],
            safetyEvents: [],
            now: now
        )

        #expect(result.programID == TrainingData.confidenceBodyScan.id)
        #expect(result.kind == .lowEnergy)
    }

    @Test func warningSymptomsPauseDailyPractice() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let event = PracticeSafetyEvent(
            createdAt: now.addingTimeInterval(-3600),
            programID: TrainingData.foundationAwareness.id,
            response: .seekProfessionalCare
        )
        let result = PracticeRecommendationEngine.recommend(
            plannedProgramID: TrainingData.foundationAwareness.id,
            relaxationProgramID: TrainingData.relaxationBreathing.id,
            bodyScanProgramID: TrainingData.confidenceBodyScan.id,
            checkIns: [],
            safetyEvents: [event],
            now: now
        )

        #expect(result.kind == .seekCare)
        #expect(result.kind.canStartPractice == false)
    }

    @Test func safetyEventsStayInProtectedLocalStore() throws {
        let suiteName = "NextTimeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let service = DataService(
            userDefaults: defaults,
            protectedStore: try ProtectedDataStore(inMemory: true)
        )
        let event = PracticeSafetyEvent(
            programID: TrainingData.relaxationBreathing.id,
            response: .stopAndRecover
        )

        service.saveSafetyEvent(event)

        #expect(service.loadSafetyEvents() == [event])
    }

    @Test func curriculumHasOnlyFourPurposefulCoursesWithoutLoadEscalation() {
        #expect(PracticeCurriculum.programs.count == 4)
        #expect(Set(PracticeCurriculum.programs.map(\.id)).count == 4)
        for stage in PracticeStage.allCases {
            let program = stage.program
            #expect(program.localizedNameKey == "curriculum.\(stage.rawValue).title")
            #expect(PracticeCurriculum.stage(for: program) == stage)
            #expect(program.totalRepetitions == 6)
            #expect(program.totalDuration == 99)
            #expect(!program.guidedSteps.contains { $0.kind == .breathe || $0.kind == .bodyScan })
            #expect(program.guidedSteps.filter { $0.kind == .contract }.allSatisfy { $0.duration == 3 })
            #expect(program.guidedSteps.filter { $0.kind == .relax }.allSatisfy { $0.duration == 6 })
            #expect(program.guidedSteps.filter { $0.kind == .instruction }.count == 2)
        }
        #expect(PracticeCurriculum.stage(for: TrainingData.relaxationBreathing) == nil)
    }

    @Test func newCurriculumCountsAfterReleaseAndRequiresItsOwnFeedback() throws {
        let (service, defaults, suite) = try pathService()
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = TrainingManager(dataService: service, recordedLessonsEnabled: false)
        defer { manager.resetState() }
        manager.startTraining(program: PracticeStage.steady.program)
        #expect(manager.progress.isAwaitingContinue)
        manager.advanceStep() // first contraction
        manager.advanceStep() // first release has not completed
        #expect(manager.progress.currentRepetition == 0)
        manager.advanceStep()
        #expect(manager.progress.currentRepetition == 1)
        manager.progress.elapsedTime = 99
        while manager.isRunning { manager.advanceStep() }
        manager.stopTraining()
        let record = try #require(service.loadRecords().first)
        #expect(record.completedRepetitions == 6)
        #expect(record.totalRepetitions == 6)
        #expect(record.lessonVersion == PracticeCurriculum.version(for: .steady))
        #expect(record.completedSets == 2)
        #expect(service.loadRecords().count == 1)
        try service.saveSessionFeedback(recordID: record.id, outcome: .unsure)
        #expect(service.loadSessionFeedback().first?.recordID == record.id)
    }

    @Test func archivedCoursesDoNotCountAsRebuiltStagePractice() {
        var path = PracticePathState(now: Date().addingTimeInterval(-60))
        path.currentStage = .steady
        let legacy = TrainingRecord(programId: path.currentStage.program.id, programName: "Legacy",
            duration: 100, completedSets: 1, totalSets: 1, isCompleted: true,
            pathID: path.id, pathStage: .steady)
        #expect(path.completedRecords(in: [legacy]).isEmpty)
    }

    @Test func leavingCurriculumPreparationDoesNotCreateTraining() throws {
        let (service, defaults, suite) = try pathService()
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = TrainingManager(dataService: service, recordedLessonsEnabled: false)
        manager.startTraining(program: PracticeStage.rhythm.program)
        manager.stopTraining()
        #expect(service.loadRecords().isEmpty)
    }

    @Test func learnLibraryCoversCurrentPlanAndSafetyBoundaries() {
        #expect(ArticleType.allCases == [
            .plan,
            .basics,
            .balance,
            .wellbeing,
            .partner,
            .safety,
            .sources
        ])
        #expect(ArticleType.plan.sections.count == 5)
        #expect(ArticleType.safety.externalURL != nil)
        #expect(ArticleType.sources.externalURL != nil)
        #expect(ArticleType.allCases.allSatisfy { !$0.sections.isEmpty })
    }

}
