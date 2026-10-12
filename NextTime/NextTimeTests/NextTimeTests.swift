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
        defaults.set(true, forKey: "appLockEnabled")
        defaults.set(false, forKey: "discreetNotifications")

        service.clearAllData()

        #expect(service.loadRecords().isEmpty)
        #expect(service.loadCompletedProgramIds().isEmpty)
        #expect(service.hasCompletedOnboarding == false)
        #expect(service.loadWellnessProfile() == nil)
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

    @Test func sevenDayPlanFollowsSelectedRoutes() {
        let plan = TrainingData.sevenDayPlan(for: [.relaxation, .partnerConnection])
        let programRoutes = plan.days.compactMap { day in
            TrainingData.allPrograms.first { $0.id == day.programID }?.route
        }

        #expect(plan.days.count == 7)
        #expect(Set(programRoutes) == [.relaxation, .partner])
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

}
