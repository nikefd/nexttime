import Foundation

enum PracticeStage: Int, Codable, CaseIterable, Identifiable {
    case awareness = 1, steady, rhythm, integration
    var id: Int { rawValue }
    var title: String { NSLocalizedString("path.stage.\(rawValue).title", comment: "") }
    var detail: String { NSLocalizedString("path.stage.\(rawValue).detail", comment: "") }
    var checkpoint: String { NSLocalizedString("path.stage.\(rawValue).checkpoint", comment: "") }
    var next: PracticeStage? { PracticeStage(rawValue: rawValue + 1) }
    var program: TrainingProgram {
        switch self {
        case .awareness: return TrainingData.foundationAwareness
        case .steady: return TrainingData.foundationCoordination
        case .rhythm: return TrainingData.foundationSteadyControl
        case .integration: return TrainingData.foundationDailyTransfer
        }
    }
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
                && $0.programId == currentStage.program.id
                && $0.isCompleted && $0.duration > 0
                && $0.completedAt >= stageEnteredAt && $0.completedAt <= now
        }.sorted { $0.completedAt > $1.completedAt }
    }
}
