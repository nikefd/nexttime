import SwiftUI

struct SessionFeedbackView: View {
    let record: TrainingRecord
    var showsPathButton = true
    @State private var savedOutcome: SessionFeedbackOutcome?
    @State private var failed = false
    @State private var showPath = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "stageOne.feedback.title")).font(.headline)
            Text(String(localized: "stageOne.repetitions \(record.completedRepetitions ?? 0) \(record.totalRepetitions ?? 6)"))
                .accessibilityIdentifier("training.repetitions-saved")
            if let outcome = savedOutcome {
                Label(outcome.title, systemImage: "checkmark.circle")
                    .accessibilityIdentifier("training.feedback-saved")
                Text(NSLocalizedString("stageOne.feedback.next.\(outcome.rawValue)", comment: ""))
                    .foregroundStyle(.secondary)
                if showsPathButton && record.pathID != nil {
                    Button(String(localized: "path.title")) { showPath = true }
                        .accessibilityIdentifier("training.open-path")
                }
            } else {
                Text(String(localized: "stageOne.feedback.intro")).foregroundStyle(.secondary)
                ForEach(SessionFeedbackOutcome.allCases, id: \.self) { outcome in
                    Button(outcome.title) { save(outcome) }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("training.feedback.\(outcome.rawValue)")
                }
                if failed { Text(String(localized: "stageOne.saveError")).foregroundStyle(.red) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            savedOutcome = DataService.shared.loadSessionFeedback().first(where: { $0.recordID == record.id })?.outcome
        }
        .sheet(isPresented: $showPath) { NavigationStack { PracticePathView() } }
    }

    private func save(_ outcome: SessionFeedbackOutcome) {
        do {
            try DataService.shared.saveSessionFeedback(recordID: record.id, outcome: outcome)
            savedOutcome = outcome
            failed = false
        } catch { failed = true }
    }
}
