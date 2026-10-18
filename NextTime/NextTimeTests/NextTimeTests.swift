//
//  NextTimeTests.swift
//  NextTimeTests
//
//  Created by zhang005 on 1/17/26.
//

import Testing
import Foundation
@testable import NextTime

@MainActor
struct NextTimeTests {

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

    @Test func speechTuningKeepsGuidanceNaturalAndCuesConcise() {
        let chineseGuidance = SpeechStyle.guidance.rate(for: "zh-CN")
        let englishGuidance = SpeechStyle.guidance.rate(for: "en-US")

        #expect(chineseGuidance >= 0.4 && chineseGuidance <= 0.55)
        #expect(englishGuidance >= 0.4 && englishGuidance <= 0.55)
        #expect(SpeechStyle.guidance.pitch < SpeechStyle.cue.pitch)
        #expect(SpeechStyle.cue.rate(for: "zh-CN") >= chineseGuidance)
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
