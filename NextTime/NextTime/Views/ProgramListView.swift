import SwiftUI

struct ProgramListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var proManager = ProManager.shared
    @State private var selectedStage: PracticeStage?
    @State private var selection: TrainingSelection?
    @State private var showUpgrade = false
    @State private var showRest = false

    private struct TrainingSelection: Identifiable {
        let program: TrainingProgram
        let context: PracticePathContext?
        var id: UUID { program.id }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(String(localized: "catalog.access"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker(String(localized: "catalog.filter"), selection: $selectedStage) {
                        Text(String(localized: "catalog.all")).tag(nil as PracticeStage?)
                        ForEach(PracticeStage.allCases) { stage in
                            Text(stage.title).tag(Optional(stage))
                        }
                    }
                    .accessibilityIdentifier("catalog.filter")
                }
                ForEach(PracticeStage.allCases.filter { selectedStage == nil || $0 == selectedStage }) { stage in
                    Section(stage.title) {
                        ForEach(Array(PracticeCurriculum.lessons(for: stage).enumerated()), id: \.element.id) { index, lesson in
                            let number = (stage.rawValue - 1) * PracticeCurriculum.lessonsPerStage + index + 1
                            NavigationLink {
                                detail(lesson, number: number)
                            } label: {
                                lessonLabel(lesson, number: number)
                            }
                            .accessibilityIdentifier("catalog.lesson.\(number)")
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "catalog.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "button.done")) { dismiss() }
                }
            }
            .fullScreenCover(item: $selection) { item in
                TrainingView(program: item.program, pathContext: item.context)
            }
            .sheet(isPresented: $showUpgrade) { ProUpgradeView() }
            .alert(String(localized: "lesson.replayBlocked"), isPresented: $showRest) {
                Button(String(localized: "button.done"), role: .cancel) {}
            }
        }
    }

    private func lessonLabel(_ lesson: TrainingProgram, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(NSLocalizedString(lesson.localizedNameKey, comment: ""),
                  systemImage: proManager.isProgramLocked(lesson) ? "lock" : "figure.mind.and.body")
                .font(.headline)
            Text(String(localized: "lesson.position \(number)") + " · " + PracticeCurriculum.structure(for: lesson))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func detail(_ lesson: TrainingProgram, number: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                lessonLabel(lesson, number: number)
                Text(NSLocalizedString(lesson.localizedDescriptionKey, comment: ""))
                Text(SpeechService.shared.formattedDuration(for: lesson))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    start(lesson)
                } label: {
                    Text(String(localized: proManager.isProgramLocked(lesson) ? "catalog.unlock" : "catalog.start"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("catalog.start")
            }
            .padding()
        }
        .navigationTitle(String(localized: "catalog.details"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func start(_ lesson: TrainingProgram) {
        guard !proManager.isProgramLocked(lesson) else {
            showUpgrade = true
            return
        }
        let service = DataService.shared
        let advice = PracticeRecommendationEngine.recommend(
            plannedProgramID: lesson.id,
            relaxationProgramID: TrainingData.relaxationBreathing.id,
            bodyScanProgramID: TrainingData.confidenceBodyScan.id,
            checkIns: service.loadCheckIns(), safetyEvents: service.loadSafetyEvents()
        )
        guard advice.kind == .onPlan else {
            showRest = true
            return
        }
        let path = try? service.startPracticePathIfNeeded()
        selection = TrainingSelection(program: lesson, context: path?.program.id == lesson.id ? path?.context : nil)
    }
}
