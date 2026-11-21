import Foundation

/// The only trainable catalog. Archived TrainingData remains for decoding old history.
enum PracticeCurriculum {
    static let programs = PracticeStage.allCases.map(program(for:))
    static let allLessons = PracticeStage.allCases.flatMap { lessons(for: $0) }

    static let lessonsPerStage = 6

    static func lessons(for stage: PracticeStage) -> [TrainingProgram] {
        [program(for: stage), followUp(for: stage), advanced(for: stage)]
            + (0..<3).map { extensionLesson(for: stage, index: $0) }
    }

    static func program(for stage: PracticeStage) -> TrainingProgram {
        let ids = ["000000000001", "000000000002", "000000000009", "000000000011"]
        let prefix = "curriculum.\(stage.rawValue)"
        var steps = [GuidedPracticeStep(id: "\(prefix)-prepare", kind: .instruction,
                         titleKey: "\(prefix).title", guidanceKey: "\(prefix).prepare")]
        for repetition in 1...6 {
            steps += [
                GuidedPracticeStep(id: "\(prefix)-rep-\(repetition)-contract", kind: .contract,
                    titleKey: "guided.contract.title", guidanceKey: "\(prefix).contract", duration: 3),
                GuidedPracticeStep(id: "\(prefix)-rep-\(repetition)-relax", kind: .relax,
                    titleKey: "guided.relax.title", guidanceKey: "\(prefix).relax", duration: 6)
            ]
            if repetition == 3 {
                steps.append(GuidedPracticeStep(id: "\(prefix)-rest", kind: .rest,
                    titleKey: "guided.rest.title", guidanceKey: "curriculum.rest", duration: 20))
                steps.append(GuidedPracticeStep(id: "\(prefix)-check", kind: .instruction,
                    titleKey: "curriculum.check.title", guidanceKey: "curriculum.narration.check"))
            }
        }
        steps.append(GuidedPracticeStep(id: "\(prefix)-finish", kind: .rest,
            titleKey: "guided.release.title", guidanceKey: "curriculum.finish", duration: 25))
        steps.append(GuidedPracticeStep(id: "\(prefix)-reflect", kind: .reflection,
            titleKey: "guided.reflection.title", guidanceKey: "curriculum.narration.reflect"))
        return TrainingProgram(
            id: UUID(uuidString: "4E585442-0000-4000-8000-\(ids[stage.rawValue - 1])")!,
            name: "Practice stage \(stage.rawValue)", localizedNameKey: "\(prefix).title",
            description: "Quality, breathing and complete release", localizedDescriptionKey: "\(prefix).goal",
            difficulty: stage == .awareness ? .beginner : .elementary,
            sets: [ExerciseSet(contractDuration: 3, relaxDuration: 6, repetitions: 3),
                   ExerciseSet(contractDuration: 3, relaxDuration: 6, repetitions: 3)],
            restBetweenSets: 20, order: stage.rawValue, route: .foundation,
            isPremium: stage != .awareness, guidedSteps: steps)
    }

    static func followUp(for stage: PracticeStage) -> TrainingProgram {
        let base = program(for: stage)
        let key = "curriculum.followUp.\(stage.rawValue)"
        let repetitionsPerSet = stage == .awareness ? 3 : (stage == .steady ? 4 : 5)
        let sets = [
            ExerciseSet(contractDuration: 3, relaxDuration: 6, repetitions: repetitionsPerSet),
            ExerciseSet(contractDuration: stage == .integration ? 2 : 3, relaxDuration: 6, repetitions: repetitionsPerSet)
        ]
        let sourceSteps = base.guidedSteps
        var expandedSteps = Array(sourceSteps.prefix(1))
        for (group, set) in sets.enumerated() {
            for position in 1...set.repetitions {
                let repetition = group * repetitionsPerSet + position
                expandedSteps.append(GuidedPracticeStep(id: "\(key)-rep-\(repetition)-contract", kind: .contract,
                    titleKey: "guided.contract.title", guidanceKey: key, duration: set.contractDuration))
                expandedSteps.append(GuidedPracticeStep(id: "\(key)-rep-\(repetition)-relax", kind: .relax,
                    titleKey: "guided.relax.title", guidanceKey: key, duration: set.relaxDuration))
            }
            if group == 0 {
                expandedSteps += sourceSteps.filter { $0.id.hasSuffix("-rest") || $0.id.hasSuffix("-check") }
            }
        }
        expandedSteps += sourceSteps.suffix(2)
        let steps = expandedSteps.map { step in
            let isPreparation = step.id.hasSuffix("-prepare")
            let guidanceKey: String
            switch step.kind {
            case .instruction: guidanceKey = "\(key).\(isPreparation ? "goal" : "check")"
            case .contract, .relax:
                let group = (repetition(for: step) ?? 1) <= repetitionsPerSet ? "observe" : "apply"
                guidanceKey = "\(key).\(group).\(step.kind.rawValue)"
            case .reflection: guidanceKey = "\(key).reflect"
            default: guidanceKey = step.guidanceKey
            }
            return GuidedPracticeStep(id: "follow-up-\(step.id)", kind: step.kind,
                titleKey: isPreparation ? "\(key).title" : step.titleKey,
                guidanceKey: guidanceKey,
                duration: step.duration, repeatCount: step.repeatCount)
        }
        return TrainingProgram(id: UUID(uuidString: "4E585442-0000-4000-8001-00000000000\(stage.rawValue)")!,
            name: "Practice follow-up", localizedNameKey: "\(key).title", description: "",
            localizedDescriptionKey: "\(key).goal", difficulty: base.difficulty, sets: sets,
            restBetweenSets: base.restBetweenSets, order: stage.rawValue, route: .foundation,
            isPremium: base.isPremium, guidedSteps: steps)
    }

    static func advanced(for stage: PracticeStage) -> TrainingProgram {
        let key = "curriculum.advanced.\(stage.rawValue)"
        let durations: [Int]
        let counts: [Int]
        switch stage {
        case .awareness: durations = [3, 3]; counts = [4, 4]
        case .steady: durations = [3, 4]; counts = [4, 4]
        case .rhythm: durations = [3, 2, 3]; counts = [4, 4, 4]
        case .integration: durations = [4, 2, 3]; counts = [4, 4, 4]
        }
        return structuredLesson(stage: stage, key: key, identifierGroup: 8002, durations: durations, counts: counts)
    }

    private static func extensionLesson(for stage: PracticeStage, index: Int) -> TrainingProgram {
        let schedules: [[(durations: [Int], counts: [Int])]] = [
            [([3, 3], [5, 5]), ([2, 3], [5, 5]), ([3, 3, 3], [4, 4, 4])],
            [([4, 4], [5, 5]), ([4, 3, 4], [4, 4, 4]), ([4, 4, 4], [5, 5, 5])],
            [([2, 3, 2], [4, 4, 4]), ([3, 4, 2], [4, 4, 4]), ([2, 3, 4], [5, 5, 5])],
            [([3, 3, 3], [5, 5, 5]), ([4, 2, 3], [5, 5, 5]), ([3, 4, 2], [5, 5, 5])]
        ]
        let schedule = schedules[stage.rawValue - 1][index]
        return structuredLesson(stage: stage, key: "curriculum.extension.\(stage.rawValue).\(index + 1)",
            identifierGroup: 8003 + index, durations: schedule.durations, counts: schedule.counts)
    }

    private static func structuredLesson(stage: PracticeStage, key: String, identifierGroup: Int,
                                         durations: [Int], counts: [Int]) -> TrainingProgram {
        let isExtension = key.hasPrefix("curriculum.extension.")
        let sets = zip(durations, counts).map {
            ExerciseSet(contractDuration: $0, relaxDuration: 6, repetitions: $1)
        }
        var steps = [GuidedPracticeStep(id: "\(key)-prepare", kind: .instruction,
            titleKey: "\(key).title", guidanceKey: "\(key).goal")]
        var repetition = 0
        for (index, set) in sets.enumerated() {
            for _ in 0..<set.repetitions {
                repetition += 1
                steps.append(.init(id: "\(key)-rep-\(repetition)-contract", kind: .contract,
                    titleKey: "guided.contract.title", guidanceKey: isExtension ? "curriculum.extension.contract.\(set.contractDuration)" : "\(key).contract.\(index + 1)", duration: set.contractDuration))
                steps.append(.init(id: "\(key)-rep-\(repetition)-relax", kind: .relax,
                    titleKey: "guided.relax.title", guidanceKey: "curriculum.advanced.release", duration: set.relaxDuration))
            }
            if index + 1 < sets.count {
                steps.append(.init(id: "\(key)-rest-\(index)", kind: .rest,
                    titleKey: "guided.rest.title", guidanceKey: "curriculum.rest", duration: 20))
                steps.append(.init(id: "\(key)-check-\(index)", kind: .instruction,
                    titleKey: "curriculum.check.title", guidanceKey: isExtension && index > 0 ? "curriculum.extension.check.final" : "\(key).check.\(index + 1)"))
            }
        }
        steps.append(.init(id: "\(key)-finish", kind: .rest,
            titleKey: "guided.release.title", guidanceKey: "curriculum.finish", duration: 25))
        steps.append(.init(id: "\(key)-reflect", kind: .reflection,
            titleKey: "guided.reflection.title", guidanceKey: "\(key).reflect"))
        return TrainingProgram(id: UUID(uuidString: "4E585442-0000-4000-\(identifierGroup)-00000000000\(stage.rawValue)")!,
            name: "Advanced practice", localizedNameKey: "\(key).title", description: "",
            localizedDescriptionKey: "\(key).goal", difficulty: .elementary, sets: sets,
            restBetweenSets: 20, order: stage.rawValue, route: .foundation,
            isPremium: stage != .awareness, guidedSteps: steps)
    }

    static func structure(for program: TrainingProgram) -> String {
        if SpeechService.shared.recordedLesson(for: program) != nil {
            return String(localized: "stageOne.structure")
        }
        return String(localized: "curriculum.load \(program.sets.count) \(program.totalRepetitions)")
    }

    static func stage(for program: TrainingProgram) -> PracticeStage? {
        guard program.localizedNameKey.hasPrefix("curriculum.") else { return nil }
        return PracticeStage.allCases.first { lessons(for: $0).contains { $0.id == program.id } }
    }

    static func version(for stage: PracticeStage) -> String { "curriculum-\(stage.rawValue)-2026-11-v2" }

    static func repetition(for step: GuidedPracticeStep) -> Int? {
        guard step.id.contains("-rep-") else { return nil }
        return Int(step.id.components(separatedBy: "-rep-").last?.split(separator: "-").first ?? "")
    }
}
