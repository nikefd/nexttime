//
//  TrainingData.swift
//  NextTime
//
//  预设训练课程数据
//

import Foundation

struct TrainingData {

    // MARK: - 所有预设训练课程
    static let allPrograms: [TrainingProgram] = [
        foundationAwareness, foundationCoordination,
        relaxationBreathing, relaxationRelease,
        confidenceBodyScan, confidenceCalmRhythm,
        partnerPause, partnerSharedReset
    ]

    static let partnerCards: [PartnerCommunicationCard] = [
        .init(id: "appreciation", titleKey: "partner.card.appreciation.title", promptKey: "partner.card.appreciation.prompt"),
        .init(id: "comfort", titleKey: "partner.card.comfort.title", promptKey: "partner.card.comfort.prompt"),
        .init(id: "boundary", titleKey: "partner.card.boundary.title", promptKey: "partner.card.boundary.prompt"),
        .init(id: "checkin", titleKey: "partner.card.checkin.title", promptKey: "partner.card.checkin.prompt")
    ]

    private static func stableID(_ suffix: String) -> UUID {
        UUID(uuidString: "4E585442-0000-4000-8000-\(suffix)")!
    }

    // MARK: - 里程碑 B：四条练习路线

    static let foundationAwareness = TrainingProgram(
        id: stableID("000000000001"), name: "Foundation Awareness",
        localizedNameKey: "program.route.foundation.awareness",
        description: "Identify gentle contraction and full release.",
        localizedDescriptionKey: "program.route.foundation.awareness.desc",
        difficulty: .beginner,
        sets: [ExerciseSet(contractDuration: 3, relaxDuration: 6, repetitions: 5)],
        restBetweenSets: 15, order: 1, route: .foundation
    )

    static let foundationCoordination = TrainingProgram(
        id: stableID("000000000002"), name: "Foundation Coordination",
        localizedNameKey: "program.route.foundation.coordination",
        description: "Coordinate breathing, contraction, and release without strain.",
        localizedDescriptionKey: "program.route.foundation.coordination.desc",
        difficulty: .elementary,
        sets: [
            ExerciseSet(contractDuration: 4, relaxDuration: 8, repetitions: 6),
            ExerciseSet(contractDuration: 2, relaxDuration: 5, repetitions: 6)
        ],
        restBetweenSets: 20, order: 2, route: .foundation, isPremium: true
    )

    static let relaxationBreathing = TrainingProgram(
        id: stableID("000000000003"), name: "Breathing Reset",
        localizedNameKey: "program.route.relaxation.breathing",
        description: "Slow breathing with a long, easy release.",
        localizedDescriptionKey: "program.route.relaxation.breathing.desc",
        difficulty: .beginner,
        sets: [ExerciseSet(contractDuration: 4, relaxDuration: 6, repetitions: 6)],
        restBetweenSets: 15, order: 3, route: .relaxation, primaryAction: .breathe
    )

    static let relaxationRelease = TrainingProgram(
        id: stableID("000000000004"), name: "Full Release",
        localizedNameKey: "program.route.relaxation.release",
        description: "Practice noticing and releasing unnecessary tension.",
        localizedDescriptionKey: "program.route.relaxation.release.desc",
        difficulty: .elementary,
        sets: [
            ExerciseSet(contractDuration: 5, relaxDuration: 10, repetitions: 5),
            ExerciseSet(contractDuration: 4, relaxDuration: 8, repetitions: 5)
        ],
        restBetweenSets: 20, order: 4, route: .relaxation,
        primaryAction: .breathe, isPremium: true
    )

    static let confidenceBodyScan = TrainingProgram(
        id: stableID("000000000005"), name: "Body Scan",
        localizedNameKey: "program.route.confidence.scan",
        description: "Notice sensations without judging performance.",
        localizedDescriptionKey: "program.route.confidence.scan.desc",
        difficulty: .beginner,
        sets: [ExerciseSet(contractDuration: 5, relaxDuration: 7, repetitions: 5)],
        restBetweenSets: 15, order: 5, route: .confidence, primaryAction: .breathe
    )

    static let confidenceCalmRhythm = TrainingProgram(
        id: stableID("000000000006"), name: "Calm Rhythm",
        localizedNameKey: "program.route.confidence.rhythm",
        description: "Use a steady rhythm to reduce performance pressure.",
        localizedDescriptionKey: "program.route.confidence.rhythm.desc",
        difficulty: .elementary,
        sets: [
            ExerciseSet(contractDuration: 4, relaxDuration: 8, repetitions: 6),
            ExerciseSet(contractDuration: 3, relaxDuration: 6, repetitions: 6)
        ],
        restBetweenSets: 20, order: 6, route: .confidence,
        primaryAction: .breathe, isPremium: true
    )

    static let partnerPause = TrainingProgram(
        id: stableID("000000000007"), name: "Shared Pause",
        localizedNameKey: "program.route.partner.pause",
        description: "A short same-device pause before a conversation.",
        localizedDescriptionKey: "program.route.partner.pause.desc",
        difficulty: .beginner,
        sets: [ExerciseSet(contractDuration: 4, relaxDuration: 6, repetitions: 5)],
        restBetweenSets: 15, order: 7, route: .partner, primaryAction: .breathe
    )

    static let partnerSharedReset = TrainingProgram(
        id: stableID("000000000008"), name: "Listen and Reset",
        localizedNameKey: "program.route.partner.reset",
        description: "Settle together before sharing a need or boundary.",
        localizedDescriptionKey: "program.route.partner.reset.desc",
        difficulty: .elementary,
        sets: [
            ExerciseSet(contractDuration: 5, relaxDuration: 8, repetitions: 5),
            ExerciseSet(contractDuration: 4, relaxDuration: 8, repetitions: 5)
        ],
        restBetweenSets: 20, order: 8, route: .partner,
        primaryAction: .breathe, isPremium: true
    )

    static func programs(for route: PracticeRoute) -> [TrainingProgram] {
        allPrograms.filter { $0.route == route }.sorted { $0.order < $1.order }
    }

    static func sevenDayPlan(for goals: Set<WellnessGoal>) -> PracticePlan {
        let selectedRoutes = PracticeRoute.routes(for: goals)
        let routeCycle = selectedRoutes.isEmpty ? PracticeRoute.allCases : selectedRoutes
        let days = (1...7).map { day -> PracticePlanDay in
            let route = routeCycle[(day - 1) % routeCycle.count]
            let program = programs(for: route).first ?? foundationAwareness
            return PracticePlanDay(day: day, programID: program.id)
        }
        return PracticePlan(days: days)
    }

    // MARK: - 初级课程 (Beginner)

    /// 初级 - 快速入门：最简单的入门训练
    static let beginnerQuickStart = TrainingProgram(
        name: "Quick Start",
        localizedNameKey: "program.beginner.quickstart",
        description: "Perfect for absolute beginners. Short contractions with equal rest.",
        localizedDescriptionKey: "program.beginner.quickstart.desc",
        difficulty: .beginner,
        sets: [
            ExerciseSet(contractDuration: 3, relaxDuration: 3, repetitions: 5),
            ExerciseSet(contractDuration: 3, relaxDuration: 3, repetitions: 5)
        ],
        restBetweenSets: 15,
        order: 1
    )

    /// 初级 - 基础训练
    static let beginnerBasic = TrainingProgram(
        name: "Basic Training",
        localizedNameKey: "program.beginner.basic",
        description: "Build your foundation with simple exercises.",
        localizedDescriptionKey: "program.beginner.basic.desc",
        difficulty: .beginner,
        sets: [
            ExerciseSet(contractDuration: 3, relaxDuration: 5, repetitions: 8),
            ExerciseSet(contractDuration: 2, relaxDuration: 2, repetitions: 10),
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 5)
        ],
        restBetweenSets: 15,
        order: 2
    )

    /// 初级 - 温和练习
    static let beginnerGentle = TrainingProgram(
        name: "Gentle Practice",
        localizedNameKey: "program.beginner.gentle",
        description: "Slow and steady approach for gradual improvement.",
        localizedDescriptionKey: "program.beginner.gentle.desc",
        difficulty: .beginner,
        sets: [
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 3, relaxDuration: 3, repetitions: 8),
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 5)
        ],
        restBetweenSets: 20,
        order: 3
    )

    // MARK: - 基础课程 (Elementary)

    /// 基础 - 标准训练
    static let elementaryStandard = TrainingProgram(
        name: "Standard Training",
        localizedNameKey: "program.elementary.standard",
        description: "Well-balanced training for developing strength.",
        localizedDescriptionKey: "program.elementary.standard.desc",
        difficulty: .elementary,
        sets: [
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 10),
            ExerciseSet(contractDuration: 3, relaxDuration: 3, repetitions: 15),
            ExerciseSet(contractDuration: 8, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 2, relaxDuration: 2, repetitions: 20)
        ],
        restBetweenSets: 15,
        order: 4
    )

    /// 基础 - 耐力训练
    static let elementaryEndurance = TrainingProgram(
        name: "Endurance Builder",
        localizedNameKey: "program.elementary.endurance",
        description: "Focus on holding contractions longer.",
        localizedDescriptionKey: "program.elementary.endurance.desc",
        difficulty: .elementary,
        sets: [
            ExerciseSet(contractDuration: 8, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 3),
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 8)
        ],
        restBetweenSets: 20,
        order: 5
    )

    /// 基础 - 节奏训练
    static let elementaryRhythm = TrainingProgram(
        name: "Rhythm Training",
        localizedNameKey: "program.elementary.rhythm",
        description: "Quick pulses mixed with sustained holds.",
        localizedDescriptionKey: "program.elementary.rhythm.desc",
        difficulty: .elementary,
        sets: [
            ExerciseSet(contractDuration: 1, relaxDuration: 1, repetitions: 20),
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 1, relaxDuration: 1, repetitions: 20),
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 5)
        ],
        restBetweenSets: 15,
        order: 6
    )

    // MARK: - 中级课程 (Intermediate)

    /// 中级 - 力量训练
    static let intermediateStrength = TrainingProgram(
        name: "Strength Focus",
        localizedNameKey: "program.intermediate.strength",
        description: "Build muscle strength with longer holds.",
        localizedDescriptionKey: "program.intermediate.strength.desc",
        difficulty: .intermediate,
        sets: [
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 5, relaxDuration: 3, repetitions: 10),
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 3, relaxDuration: 2, repetitions: 15)
        ],
        restBetweenSets: 15,
        order: 7
    )

    /// 中级 - 强化训练
    static let intermediateIntensive = TrainingProgram(
        name: "Intensive Training",
        localizedNameKey: "program.intermediate.intensive",
        description: "Higher repetitions for serious improvement.",
        localizedDescriptionKey: "program.intermediate.intensive.desc",
        difficulty: .intermediate,
        sets: [
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 15),
            ExerciseSet(contractDuration: 2, relaxDuration: 2, repetitions: 25),
            ExerciseSet(contractDuration: 8, relaxDuration: 5, repetitions: 8),
            ExerciseSet(contractDuration: 1, relaxDuration: 1, repetitions: 30)
        ],
        restBetweenSets: 20,
        order: 8
    )

    /// 中级 - 综合训练
    static let intermediateVariety = TrainingProgram(
        name: "Variety Mix",
        localizedNameKey: "program.intermediate.variety",
        description: "Diverse exercises for all-round development.",
        localizedDescriptionKey: "program.intermediate.variety.desc",
        difficulty: .intermediate,
        sets: [
            ExerciseSet(contractDuration: 3, relaxDuration: 3, repetitions: 10),
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 3),
            ExerciseSet(contractDuration: 1, relaxDuration: 1, repetitions: 20),
            ExerciseSet(contractDuration: 8, relaxDuration: 8, repetitions: 5),
            ExerciseSet(contractDuration: 5, relaxDuration: 3, repetitions: 10)
        ],
        restBetweenSets: 15,
        order: 9
    )

    // MARK: - 高级课程 (Advanced)

    /// 高级 - 力量突破
    static let advancedPower = TrainingProgram(
        name: "Power Breakthrough",
        localizedNameKey: "program.advanced.power",
        description: "Push your limits with extended holds.",
        localizedDescriptionKey: "program.advanced.power.desc",
        difficulty: .advanced,
        sets: [
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 8),
            ExerciseSet(contractDuration: 15, relaxDuration: 5, repetitions: 3),
            ExerciseSet(contractDuration: 5, relaxDuration: 3, repetitions: 15),
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 8)
        ],
        restBetweenSets: 20,
        order: 10
    )

    /// 高级 - 马拉松训练
    static let advancedMarathon = TrainingProgram(
        name: "Marathon Session",
        localizedNameKey: "program.advanced.marathon",
        description: "Extended training for maximum endurance.",
        localizedDescriptionKey: "program.advanced.marathon.desc",
        difficulty: .advanced,
        sets: [
            ExerciseSet(contractDuration: 5, relaxDuration: 5, repetitions: 20),
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 10),
            ExerciseSet(contractDuration: 3, relaxDuration: 2, repetitions: 20),
            ExerciseSet(contractDuration: 15, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 2, relaxDuration: 1, repetitions: 30)
        ],
        restBetweenSets: 15,
        order: 11
    )

    /// 高级 - 挑战模式
    static let advancedChallenge = TrainingProgram(
        name: "Challenge Mode",
        localizedNameKey: "program.advanced.challenge",
        description: "Are you ready for a real challenge?",
        localizedDescriptionKey: "program.advanced.challenge.desc",
        difficulty: .advanced,
        sets: [
            ExerciseSet(contractDuration: 1, relaxDuration: 1, repetitions: 30),
            ExerciseSet(contractDuration: 15, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 3, relaxDuration: 2, repetitions: 20),
            ExerciseSet(contractDuration: 10, relaxDuration: 3, repetitions: 10),
            ExerciseSet(contractDuration: 20, relaxDuration: 10, repetitions: 2)
        ],
        restBetweenSets: 20,
        order: 12
    )

    // MARK: - 专家课程 (Expert)

    /// 专家 - 终极训练
    static let expertUltimate = TrainingProgram(
        name: "Ultimate Training",
        localizedNameKey: "program.expert.ultimate",
        description: "The ultimate test of your abilities.",
        localizedDescriptionKey: "program.expert.ultimate.desc",
        difficulty: .expert,
        sets: [
            ExerciseSet(contractDuration: 20, relaxDuration: 10, repetitions: 3),
            ExerciseSet(contractDuration: 5, relaxDuration: 3, repetitions: 20),
            ExerciseSet(contractDuration: 15, relaxDuration: 5, repetitions: 8),
            ExerciseSet(contractDuration: 1, relaxDuration: 1, repetitions: 40),
            ExerciseSet(contractDuration: 30, relaxDuration: 10, repetitions: 2),
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 10)
        ],
        restBetweenSets: 20,
        order: 13
    )

    /// 专家 - 大师级
    static let expertMaster = TrainingProgram(
        name: "Master Level",
        localizedNameKey: "program.expert.master",
        description: "Only for the most dedicated practitioners.",
        localizedDescriptionKey: "program.expert.master.desc",
        difficulty: .expert,
        sets: [
            ExerciseSet(contractDuration: 10, relaxDuration: 5, repetitions: 15),
            ExerciseSet(contractDuration: 30, relaxDuration: 10, repetitions: 3),
            ExerciseSet(contractDuration: 2, relaxDuration: 1, repetitions: 40),
            ExerciseSet(contractDuration: 20, relaxDuration: 5, repetitions: 5),
            ExerciseSet(contractDuration: 5, relaxDuration: 3, repetitions: 25),
            ExerciseSet(contractDuration: 15, relaxDuration: 5, repetitions: 10)
        ],
        restBetweenSets: 25,
        order: 14
    )

    // MARK: - 按难度获取课程
    static func programs(for difficulty: DifficultyLevel) -> [TrainingProgram] {
        return allPrograms.filter { $0.difficulty == difficulty }.sorted { $0.order < $1.order }
    }

    // MARK: - 获取推荐课程（基于用户训练记录）
    static func recommendedProgram(basedOn records: [TrainingRecord]) -> TrainingProgram {
        // 如果没有记录，返回第一个入门课程
        guard !records.isEmpty else {
            return beginnerQuickStart
        }

        // 根据最近的训练记录推荐下一个课程
        let completedProgramIds = Set(records.filter { $0.isCompleted }.map { $0.programId })

        // 找到第一个未完成的课程
        for program in allPrograms.sorted(by: { $0.order < $1.order }) {
            if !completedProgramIds.contains(program.id) {
                return program
            }
        }

        // 如果都完成了，从第一条路线重新开始温和练习
        return allPrograms.first ?? foundationAwareness
    }
}
