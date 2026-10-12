//
//  TrainingModels.swift
//  NextTime
//
//  凯格尔训练数据模型
//

import Foundation

// MARK: - 训练动作类型
enum ExerciseAction: String, Codable {
    case contract = "contract"  // 收缩
    case breathe = "breathe"    // 呼吸
    case relax = "relax"        // 放松
    case rest = "rest"          // 组间休息
}

// MARK: - 引导练习脚本
enum GuidedStepKind: String, Codable {
    case instruction
    case breathe
    case contract
    case relax
    case bodyScan
    case reflection
    case partnerPrompt
    case rest

    var exerciseAction: ExerciseAction {
        switch self {
        case .contract: return .contract
        case .breathe, .bodyScan, .reflection, .partnerPrompt, .instruction: return .breathe
        case .relax: return .relax
        case .rest: return .rest
        }
    }

    var isInteractive: Bool {
        switch self {
        case .instruction, .reflection, .partnerPrompt: return true
        default: return false
        }
    }
}

struct GuidedPracticeStep: Identifiable, Codable, Equatable {
    let id: String
    let kind: GuidedStepKind
    let titleKey: String
    let guidanceKey: String
    let duration: Int?
    let repeatCount: Int

    init(
        id: String,
        kind: GuidedStepKind,
        titleKey: String,
        guidanceKey: String,
        duration: Int? = nil,
        repeatCount: Int = 1
    ) {
        self.id = id
        self.kind = kind
        self.titleKey = titleKey
        self.guidanceKey = guidanceKey
        self.duration = duration
        self.repeatCount = max(1, repeatCount)
    }

    var expanded: [GuidedPracticeStep] {
        (0..<repeatCount).map { index in
            GuidedPracticeStep(
                id: "\(id)-\(index)",
                kind: kind,
                titleKey: titleKey,
                guidanceKey: guidanceKey,
                duration: duration,
                repeatCount: 1
            )
        }
    }
}

// MARK: - 训练难度级别
enum DifficultyLevel: Int, Codable, CaseIterable {
    case beginner = 1      // 初级
    case elementary = 2    // 基础
    case intermediate = 3  // 中级
    case advanced = 4      // 高级
    case expert = 5        // 专家

    var localizedName: String {
        switch self {
        case .beginner: return String(localized: "difficulty.beginner")
        case .elementary: return String(localized: "difficulty.elementary")
        case .intermediate: return String(localized: "difficulty.intermediate")
        case .advanced: return String(localized: "difficulty.advanced")
        case .expert: return String(localized: "difficulty.expert")
        }
    }

    var color: String {
        switch self {
        case .beginner: return "green"
        case .elementary: return "blue"
        case .intermediate: return "orange"
        case .advanced: return "red"
        case .expert: return "purple"
        }
    }
}

// MARK: - 单个训练组
struct ExerciseSet: Identifiable, Codable {
    let id: UUID
    let contractDuration: Int    // 收缩时长（秒）
    let relaxDuration: Int       // 放松时长（秒）
    let repetitions: Int         // 重复次数

    init(id: UUID = UUID(), contractDuration: Int, relaxDuration: Int, repetitions: Int) {
        self.id = id
        self.contractDuration = contractDuration
        self.relaxDuration = relaxDuration
        self.repetitions = repetitions
    }

    // 计算本组总时长（秒）
    var totalDuration: Int {
        return (contractDuration + relaxDuration) * repetitions
    }
}

// MARK: - 训练课程
struct TrainingProgram: Identifiable, Codable {
    let id: UUID
    let name: String
    let localizedNameKey: String  // 用于本地化
    let description: String
    let localizedDescriptionKey: String
    let difficulty: DifficultyLevel
    let sets: [ExerciseSet]
    let restBetweenSets: Int      // 组间休息时间（秒）
    let order: Int                // 课程顺序
    let route: PracticeRoute
    let primaryAction: ExerciseAction
    let isPremium: Bool
    let guidedSteps: [GuidedPracticeStep]

    init(id: UUID = UUID(), name: String, localizedNameKey: String, description: String,
         localizedDescriptionKey: String, difficulty: DifficultyLevel, sets: [ExerciseSet],
         restBetweenSets: Int = 10, order: Int, route: PracticeRoute = .foundation,
         primaryAction: ExerciseAction = .contract, isPremium: Bool = false,
         guidedSteps: [GuidedPracticeStep] = []) {
        self.id = id
        self.name = name
        self.localizedNameKey = localizedNameKey
        self.description = description
        self.localizedDescriptionKey = localizedDescriptionKey
        self.difficulty = difficulty
        self.sets = sets
        self.restBetweenSets = restBetweenSets
        self.order = order
        self.route = route
        self.primaryAction = primaryAction
        self.isPremium = isPremium
        self.guidedSteps = guidedSteps
    }

    // 计算总时长（秒）
    var totalDuration: Int {
        if !guidedSteps.isEmpty {
            return resolvedGuidedSteps.compactMap(\.duration).reduce(0, +)
        }
        let setsDuration = sets.reduce(0) { $0 + $1.totalDuration }
        let restDuration = restBetweenSets * max(0, sets.count - 1)
        return setsDuration + restDuration
    }

    // 格式化总时长
    var formattedDuration: String {
        let minutes = totalDuration / 60
        let seconds = totalDuration % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    // 总重复次数
    var totalRepetitions: Int {
        return sets.reduce(0) { $0 + $1.repetitions }
    }

    var resolvedGuidedSteps: [GuidedPracticeStep] {
        if !guidedSteps.isEmpty {
            return guidedSteps.flatMap(\.expanded)
        }

        var steps = [
            GuidedPracticeStep(
                id: "legacy-intro",
                kind: .instruction,
                titleKey: "guided.prepare.title",
                guidanceKey: "guided.prepare.body"
            )
        ]
        for (setIndex, set) in sets.enumerated() {
            for repetition in 0..<set.repetitions {
                steps.append(
                    GuidedPracticeStep(
                        id: "legacy-\(setIndex)-\(repetition)-active",
                        kind: primaryAction == .contract ? .contract : .breathe,
                        titleKey: primaryAction == .contract ? "guided.contract.title" : "guided.breathe.title",
                        guidanceKey: primaryAction == .contract ? "guided.contract.body" : "guided.breathe.body",
                        duration: set.contractDuration
                    )
                )
                steps.append(
                    GuidedPracticeStep(
                        id: "legacy-\(setIndex)-\(repetition)-relax",
                        kind: .relax,
                        titleKey: "guided.relax.title",
                        guidanceKey: "guided.relax.body",
                        duration: set.relaxDuration
                    )
                )
            }
            if setIndex < sets.count - 1 {
                steps.append(
                    GuidedPracticeStep(
                        id: "legacy-\(setIndex)-rest",
                        kind: .rest,
                        titleKey: "guided.rest.title",
                        guidanceKey: "guided.rest.body",
                        duration: restBetweenSets
                    )
                )
            }
        }
        return steps
    }
}

// MARK: - 训练记录
struct TrainingRecord: Identifiable, Codable {
    let id: UUID
    let programId: UUID
    let programName: String
    let completedAt: Date
    let duration: Int             // 实际训练时长（秒）
    let completedSets: Int        // 完成的组数
    let totalSets: Int            // 总组数
    let isCompleted: Bool         // 是否完整完成
    let route: PracticeRoute?

    init(id: UUID = UUID(), programId: UUID, programName: String, completedAt: Date = Date(),
         duration: Int, completedSets: Int, totalSets: Int, isCompleted: Bool,
         route: PracticeRoute? = nil) {
        self.id = id
        self.programId = programId
        self.programName = programName
        self.completedAt = completedAt
        self.duration = duration
        self.completedSets = completedSets
        self.totalSets = totalSets
        self.isCompleted = isCompleted
        self.route = route
    }
}

// MARK: - 训练进度状态
struct TrainingProgress {
    var currentSetIndex: Int = 0
    var currentRepetition: Int = 0
    var currentAction: ExerciseAction = .contract
    var remainingSeconds: Int = 0
    var isResting: Bool = false
    var elapsedTime: Int = 0
    var totalSets: Int = 0
    var currentStepIndex: Int = 0
    var totalSteps: Int = 0
    var isAwaitingContinue: Bool = false

    var isCompleted: Bool {
        if totalSteps > 0 {
            return currentStepIndex >= totalSteps
        }
        return totalSets > 0 && currentSetIndex >= totalSets
    }
}

// MARK: - 用户设置
struct UserSettings: Codable {
    var vibrationEnabled: Bool = true
    var voiceEnabled: Bool = true
    var voiceVolume: Float = 0.8
    var selectedVoice: String = "default"
    var reminderEnabled: Bool = false
    var reminderTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    var hapticIntensity: HapticIntensity = .medium

    enum HapticIntensity: String, Codable, CaseIterable {
        case light = "light"
        case medium = "medium"
        case heavy = "heavy"

        var localizedName: String {
            switch self {
            case .light: return String(localized: "settings.haptic.light")
            case .medium: return String(localized: "settings.haptic.medium")
            case .heavy: return String(localized: "settings.haptic.heavy")
            }
        }
    }
}

// MARK: - 统计数据
struct TrainingStatistics {
    var totalSessions: Int = 0
    var totalMinutes: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastTrainingDate: Date?
    var thisWeekSessions: Int = 0
    var thisMonthSessions: Int = 0
}
