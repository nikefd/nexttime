import SwiftUI

struct PracticePathView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var state: PracticePathState?
    @State private var records: [TrainingRecord] = []
    @State private var selectedStage: PracticeStage = .awareness
    @State private var showReview = false
    @State private var breathing = false
    @State private var release = false
    @State private var comfortable = false
    @State private var showError = false

    private var currentRecords: [TrainingRecord] { state?.completedRecords(in: records) ?? [] }
    private var isCurrent: Bool { state?.currentStage == selectedStage }
    private var canReview: Bool {
        guard let state, state.nextProgram != nil, !currentRecords.isEmpty else { return false }
        if let record = currentRecords.first, record.lessonVersion != nil,
           DataService.shared.loadSessionFeedback().first(where: { $0.recordID == record.id })?.outcome != .comfortable { return false }
        return PracticeRecommendationEngine.recommend(
            plannedProgramID: state.program.id,
            relaxationProgramID: TrainingData.relaxationBreathing.id,
            bodyScanProgramID: TrainingData.confidenceBodyScan.id,
            checkIns: DataService.shared.loadCheckIns(), safetyEvents: DataService.shared.loadSafetyEvents()
        ).kind == .onPlan
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(String(localized: "path.intro")).foregroundStyle(.secondary)
                if let state {
                    Text(String(localized: "path.position \(state.currentStage.rawValue)"))
                        .font(.headline).accessibilityIdentifier("path.position")
                    ForEach(PracticeStage.allCases) { stage in
                        Button {
                            selectedStage = stage
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Text("\(stage.rawValue)")
                                    .font(.headline).frame(width: 32, height: 32)
                                    .background(stage == state.currentStage ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemFill))
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(stage.title).font(.headline)
                                    Text(status(stage, state)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedStage == stage ? "chevron.down" : "chevron.right")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("path.stage.\(stage.rawValue)")
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text(selectedStage.title).font(.title2.bold())
                        Text(selectedStage.detail)
                        Label(NSLocalizedString(selectedStage.program.localizedNameKey, comment: ""), systemImage: "figure.mind.and.body")
                        Text(NSLocalizedString(selectedStage.program.localizedDescriptionKey, comment: ""))
                        Text(PracticeCurriculum.structure(for: selectedStage.program))
                            .font(.subheadline).foregroundStyle(.secondary)
                        ForEach(PracticeCurriculum.lessons(for: selectedStage).dropFirst()) { lesson in
                            Label(NSLocalizedString(lesson.localizedNameKey, comment: ""), systemImage: "figure.mind.and.body")
                        }
                        if isCurrent { Text(String(localized: "lesson.position \(state.lessonNumber)")) }
                        Text(selectedStage.checkpoint).foregroundStyle(.secondary)
                        if isCurrent {
                            Text(String(localized: "path.completed \(currentRecords.count)"))
                                .accessibilityIdentifier("path.completed")
                            Text(String(localized: "path.practiceDays \(Set(currentRecords.map { Calendar.current.startOfDay(for: $0.completedAt) }).count)"))
                                .font(.caption).foregroundStyle(.secondary)
                            if let record = currentRecords.first, record.lessonVersion != nil,
                               DataService.shared.loadSessionFeedback().first(where: { $0.recordID == record.id }) == nil {
                                NavigationLink {
                                    SessionFeedbackView(record: record, showsPathButton: false)
                                        .padding().navigationTitle(String(localized: "stageOne.feedback.title"))
                                } label: { Text(String(localized: "stageOne.feedback.completeLater")) }
                                .accessibilityIdentifier("path.complete-feedback")
                            }
                            if state.nextProgram != nil {
                                Button(String(localized: "path.review.open")) {
                                    breathing = false; release = false; comfortable = false
                                    showReview = true
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!canReview)
                                .accessibilityIdentifier("path.review")
                                Text(String(localized: canReview ? "path.review.available" : "path.review.required"))
                                    .font(.footnote).foregroundStyle(.secondary)
                            } else {
                                Text(String(localized: "path.maintenance.detail"))
                            }
                        }
                    }
                    Text(String(localized: "path.progressMeaning")).font(.footnote).foregroundStyle(.secondary)
                    Text(String(localized: "path.legacy")).font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text(String(localized: "path.saveError"))
                    Button(String(localized: "path.retry"), action: load)
                }
            }
            .padding()
        }
        .navigationTitle(String(localized: "path.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "button.done")) { dismiss() }
        } }
        .onAppear(perform: load)
        .sheet(isPresented: $showReview) {
            NavigationStack {
                Form {
                    Section {
                        Text(String(localized: "path.review.intro"))
                        Toggle(String(localized: "path.review.breathing"), isOn: $breathing)
                        Toggle(String(localized: "path.review.release"), isOn: $release)
                        Toggle(String(localized: "path.review.comfortable"), isOn: $comfortable)
                    }
                    Section {
                        Button(String(localized: "path.review.confirm")) { advance() }
                            .disabled(!breathing || !release || !comfortable)
                            .accessibilityIdentifier("path.review.confirm")
                    } footer: {
                        Text(String(localized: "path.review.footer"))
                    }
                }
                .navigationTitle(String(localized: "path.review.open"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(String(localized: "alert.cancel")) { showReview = false } } }
            }
        }
        .alert(String(localized: "path.saveError"), isPresented: $showError) {
            Button(String(localized: "button.done"), role: .cancel) {}
        }
    }

    private func status(_ stage: PracticeStage, _ state: PracticePathState) -> String {
        if stage == state.currentStage { return String(localized: "path.status.current") }
        return String(localized: stage.rawValue < state.currentStage.rawValue ? "path.status.reviewed" : "path.status.preview")
    }

    private func load() {
        do {
            state = try DataService.shared.startPracticePathIfNeeded()
            records = DataService.shared.loadRecords()
            selectedStage = state?.currentStage ?? .awareness
        } catch { showError = true }
    }

    private func advance() {
        guard let state, let record = currentRecords.first else { return }
        let review = PracticeStageReview(stage: state.currentStage, recordID: record.id, confirmedAt: Date(),
                                         breathingComfortable: breathing, fullyReleased: release, noDiscomfort: comfortable)
        do {
            self.state = try DataService.shared.advancePracticePath(review)
            selectedStage = self.state?.currentStage ?? .awareness
            showReview = false
        } catch { showReview = false; showError = true; load() }
    }
}
