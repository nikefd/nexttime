import Foundation

/// The only trainable catalog. Archived TrainingData remains for decoding old history.
enum PracticeCurriculum {
    static let programs = PracticeStage.allCases.map(program(for:))
    static let allLessons = programs + PracticeStage.allCases.map { followUp(for: $0) }

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
        let steps = base.guidedSteps.map { step in
            GuidedPracticeStep(id: "follow-up-\(step.id)", kind: step.kind,
                titleKey: step.id.hasSuffix("-prepare") ? "\(key).title" : step.titleKey,
                guidanceKey: step.id.hasSuffix("-prepare") ? "\(key).goal" : step.guidanceKey,
                duration: step.duration, repeatCount: step.repeatCount)
        }
        return TrainingProgram(id: UUID(uuidString: "4E585442-0000-4000-8001-00000000000\(stage.rawValue)")!,
            name: "Practice follow-up", localizedNameKey: "\(key).title", description: "",
            localizedDescriptionKey: "\(key).goal", difficulty: base.difficulty, sets: base.sets,
            restBetweenSets: base.restBetweenSets, order: stage.rawValue, route: .foundation,
            isPremium: base.isPremium, guidedSteps: steps)
    }

    static func stage(for program: TrainingProgram) -> PracticeStage? {
        guard program.localizedNameKey.hasPrefix("curriculum.") else { return nil }
        return PracticeStage.allCases.first { self.program(for: $0).id == program.id || followUp(for: $0).id == program.id }
    }

    static func version(for stage: PracticeStage) -> String { "curriculum-\(stage.rawValue)-2026-11-v2" }

    static func repetition(for step: GuidedPracticeStep) -> Int? {
        guard step.id.contains("-rep-") else { return nil }
        return Int(step.id.components(separatedBy: "-rep-").last?.split(separator: "-").first ?? "")
    }
}
