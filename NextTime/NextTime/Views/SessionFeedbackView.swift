import SwiftUI

struct SessionFeedbackView: View {
    let record: TrainingRecord
    var showsPathButton = true
    @State private var savedOutcome: SessionFeedbackOutcome?
    @State private var failed = false
    @State private var showPath = false
    @State private var confirmAdvance = false
    @State private var advanced = false

    private var nextProgram: TrainingProgram? {
        guard let path = DataService.shared.loadPracticePath(), path.id == record.pathID,
              path.currentStage == record.pathStage,
              path.completedRecords(in: DataService.shared.loadRecords()).first?.id == record.id else { return nil }
        return path.nextProgram
    }

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
                if advanced {
                    Label(String(localized: "training.nextSaved"), systemImage: "checkmark.circle")
                } else if outcome == .comfortable, let nextProgram {
                    Button {
                        confirmAdvance = true
                    } label: {
                        Text(String(localized: "training.nextStage \(NSLocalizedString(nextProgram.localizedNameKey, comment: ""))"))
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("training.review-next")
                }
                if failed { Text(String(localized: "path.saveError")).foregroundStyle(.red) }
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
        .alert(String(localized: "path.review.open"), isPresented: $confirmAdvance) {
            Button(String(localized: "path.review.confirm")) { advance() }
            Button(String(localized: "alert.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "training.nextConfirmation"))
        }
        .sheet(isPresented: $showPath) { NavigationStack { PracticePathView() } }
    }

    private func advance() {
        guard let stage = record.pathStage else { return }
        do {
            _ = try DataService.shared.advancePracticePath(.init(stage: stage, recordID: record.id,
                confirmedAt: Date(), breathingComfortable: true, fullyReleased: true, noDiscomfort: true))
            advanced = true
            failed = false
        } catch { failed = true }
    }

    private func save(_ outcome: SessionFeedbackOutcome) {
        do {
            try DataService.shared.saveSessionFeedback(recordID: record.id, outcome: outcome)
            savedOutcome = outcome
            failed = false
        } catch { failed = true }
    }
}
