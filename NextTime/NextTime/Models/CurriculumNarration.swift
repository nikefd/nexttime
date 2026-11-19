import AVFoundation

/// Shared safety check and reflection, with a separate introduction for each learning stage.
struct CurriculumNarration {
    enum Part: String, CaseIterable { case prepare, check, reflect }
    let voice: NarrationVoice
    let stage: PracticeStage
    let urls: [Part: URL]
    let durations: [Part: TimeInterval]

    static func load(stage: PracticeStage, voice: NarrationVoice, bundle: Bundle = .main) throws -> Self {
        guard stage != .awareness else { throw CocoaError(.fileReadCorruptFile) }
        var urls: [Part: URL] = [:]
        var durations: [Part: TimeInterval] = [:]
        for part in Part.allCases {
            let suffix = part == .prepare ? "prepare-\(stage.rawValue)" : part.rawValue
            guard let url = bundle.url(forResource: "\(voice.assetPrefix)-curriculum-\(suffix)", withExtension: "m4a") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let duration = try AVAudioPlayer(contentsOf: url).duration
            guard duration > 0 else { throw CocoaError(.fileReadCorruptFile) }
            urls[part] = url
            durations[part] = duration
        }
        return Self(voice: voice, stage: stage, urls: urls, durations: durations)
    }

    var duration: TimeInterval { durations.values.reduce(0, +) }

    func part(for step: GuidedPracticeStep) -> Part? {
        Part.allCases.first { step.id.split(separator: "-").contains(Substring($0.rawValue)) && step.kind.isInteractive }
    }
}
