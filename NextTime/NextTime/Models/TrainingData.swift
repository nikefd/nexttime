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
        // === 初级课程 ===
        beginnerQuickStart,
        beginnerBasic,
        beginnerGentle,

        // === 基础课程 ===
        elementaryStandard,
        elementaryEndurance,
        elementaryRhythm,

        // === 中级课程 ===
        intermediateStrength,
        intermediateIntensive,
        intermediateVariety,

        // === 高级课程 ===
        advancedPower,
        advancedMarathon,
        advancedChallenge,

        // === 专家课程 ===
        expertUltimate,
        expertMaster
    ]

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

        // 如果都完成了，返回最高级课程
        return expertMaster
    }
}
