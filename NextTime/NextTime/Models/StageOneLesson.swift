import Foundation

struct StageOneLesson {
    static let version = "stage-one-2026-11-v1"
    let voice: NarrationVoice
    let timeline: PilotNarrationTimeline
    let audioURLs: [URL]

    static func load(voice: NarrationVoice, bundle: Bundle = .main) throws -> StageOneLesson {
        guard let url = bundle.url(forResource: "\(voice.assetPrefix)-pilot", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let timeline = try JSONDecoder().decode(PilotNarrationTimeline.self, from: Data(contentsOf: url))
        guard timeline.sections.count == 21 else { throw CocoaError(.fileReadCorruptFile) }
        let urls = try timeline.sections.indices.map { index -> URL in
            guard let url = bundle.url(forResource: String(format: "%@-section-%02d", voice.assetPrefix, index), withExtension: "m4a") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return url
        }
        return StageOneLesson(voice: voice, timeline: timeline, audioURLs: urls)
    }

    static func kind(at index: Int) -> GuidedStepKind {
        switch index {
        case 0, 1: return .instruction
        case 6, 19: return .rest
        case 20: return .reflection
        default: return index.isMultiple(of: 2) ? (index < 6 ? .contract : .relax) : (index < 6 ? .relax : .contract)
        }
    }

    static func isDemonstration(_ index: Int) -> Bool { (2...5).contains(index) }
    static func isMainPractice(_ index: Int) -> Bool { (7...18).contains(index) }
    static func countsAsPractice(_ index: Int) -> Bool { (2...19).contains(index) }
    static func needsReadyAfter(_ index: Int) -> Bool { index == 0 || index == 1 }
    static func completedRepetitions(after index: Int) -> Int {
        max(0, min(6, (index - 6) / 2))
    }

    var steps: [GuidedPracticeStep] {
        timeline.sections.indices.map { index in
            let kind = Self.kind(at: index)
            let title: String
            switch kind {
            case .contract: title = "guided.contract.title"
            case .relax: title = "guided.relax.title"
            case .rest: title = "guided.release.title"
            case .reflection: title = "guided.reflection.title"
            default: title = index == 0 ? "voice.pilot.title" : "stageOne.demo.title"
            }
            return GuidedPracticeStep(id: "stage-one-\(index)", kind: kind, titleKey: title,
                                      guidanceKey: "stageOne.guidance.\(kind.rawValue)",
                                      duration: Int(ceil(timeline.sections[index].end - timeline.sections[index].start)))
        }
    }
}

enum SessionFeedbackOutcome: String, Codable, CaseIterable {
    case comfortable, unsure, discomfort
    var title: String { NSLocalizedString("stageOne.feedback.\(rawValue)", comment: "") }
}

struct SessionFeedback: Identifiable, Codable {
    var id: UUID { recordID }
    let recordID: UUID
    let outcome: SessionFeedbackOutcome
    let createdAt: Date
}
