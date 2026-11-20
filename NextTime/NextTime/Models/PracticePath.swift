import Foundation

enum PracticeStage: Int, Codable, CaseIterable, Identifiable {
    case awareness = 1, steady, rhythm, integration
    var id: Int { rawValue }
    var title: String { NSLocalizedString("path.stage.\(rawValue).title", comment: "") }
    var detail: String { NSLocalizedString("path.stage.\(rawValue).detail", comment: "") }
    var checkpoint: String { NSLocalizedString("path.stage.\(rawValue).checkpoint", comment: "") }
    var next: PracticeStage? { PracticeStage(rawValue: rawValue + 1) }
    var program: TrainingProgram { PracticeCurriculum.program(for: self) }

}

struct PracticePathContext {
    let pathID: UUID
    let stage: PracticeStage
}

struct PracticeStageReview: Codable {
    let stage: PracticeStage
    let recordID: UUID
    let confirmedAt: Date
    let breathingComfortable: Bool
    let fullyReleased: Bool
    let noDiscomfort: Bool
    var isConfirmed: Bool { breathingComfortable && fullyReleased && noDiscomfort }
}

struct PracticePathState: Codable {
    let id: UUID
    let createdAt: Date
    var currentStage: PracticeStage
    var stageEnteredAt: Date
    var isFollowUp: Bool?
    var program: TrainingProgram {
        isFollowUp == true ? PracticeCurriculum.followUp(for: currentStage) : currentStage.program
    }
    var nextProgram: TrainingProgram? {
        isFollowUp == true ? currentStage.next?.program : PracticeCurriculum.followUp(for: currentStage)
    }
    var lessonNumber: Int { (currentStage.rawValue - 1) * 2 + (isFollowUp == true ? 2 : 1) }
    var reviews: [PracticeStageReview]

    init(id: UUID = UUID(), now: Date = Date()) {
        self.id = id
        createdAt = now
        currentStage = .awareness
        stageEnteredAt = now
        reviews = []
    }

    var context: PracticePathContext { .init(pathID: id, stage: currentStage) }

    func completedRecords(in records: [TrainingRecord], now: Date = Date()) -> [TrainingRecord] {
        records.filter {
            $0.pathID == id && $0.pathStage == currentStage
                && $0.programId == program.id
                && ($0.lessonVersion == PracticeCurriculum.version(for: currentStage)
                    || (currentStage == .awareness && $0.lessonVersion == StageOneLesson.version))
                && $0.isCompleted && $0.duration > 0
                && $0.completedAt >= stageEnteredAt && $0.completedAt <= now
        }.sorted { $0.completedAt > $1.completedAt }
    }
}
