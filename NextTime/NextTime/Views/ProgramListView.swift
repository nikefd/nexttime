import SwiftUI

struct ProgramListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var proManager = ProManager.shared
    @State private var selectedStage: PracticeStage?
    @State private var selection: TrainingSelection?
    @State private var showUpgrade = false
    @State private var showRest = false
    @State private var search = ""
    @State private var favoritesOnly = false
    @AppStorage("catalog.favoriteLessonIDs") private var favoriteIDs = ""

    private var favorites: Set<String> { Set(favoriteIDs.split(separator: ",").map(String.init)) }

    private func isFavorite(_ lesson: TrainingProgram) -> Bool {
        favorites.contains(lesson.id.uuidString)
    }

    private func toggleFavorite(_ lesson: TrainingProgram) {
        var updated = favorites
        if !updated.insert(lesson.id.uuidString).inserted {
            updated.remove(lesson.id.uuidString)
        }
        favoriteIDs = updated.sorted().joined(separator: ",")
    }

    private var visibleStages: [PracticeStage] {
        PracticeStage.allCases.filter { stage in
            (selectedStage == nil || selectedStage == stage)
                && !matchingLessons(in: stage).isEmpty
        }
    }

    private func matchingLessons(in stage: PracticeStage) -> [(offset: Int, element: TrainingProgram)] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return PracticeCurriculum.lessons(for: stage).enumerated().filter { _, lesson in
            guard !favoritesOnly || isFavorite(lesson) else { return false }
            return query.isEmpty || [lesson.localizedNameKey, lesson.localizedDescriptionKey].contains { key in
                NSLocalizedString(key, comment: "").localizedStandardContains(query)
            } || stage.title.localizedStandardContains(query)
        }
    }

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
                    Toggle(String(localized: "catalog.favoritesOnly"), isOn: $favoritesOnly)
                        .accessibilityIdentifier("catalog.favorites-only")
                }
                if visibleStages.isEmpty {
                    Text(String(localized: "catalog.empty")).foregroundStyle(.secondary)
                }
                ForEach(visibleStages) { stage in
                    Section(stage.title) {
                        ForEach(matchingLessons(in: stage), id: \.element.id) { index, lesson in
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
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: String(localized: "catalog.search"))
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
            if isFavorite(lesson) {
                Label(String(localized: "catalog.favorite"), systemImage: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
                    toggleFavorite(lesson)
                } label: {
                    Label(String(localized: isFavorite(lesson) ? "catalog.unfavorite" : "catalog.favorite"),
                          systemImage: isFavorite(lesson) ? "star.fill" : "star")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("catalog.favorite-toggle")
                lessonStructure(lesson)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                start(lesson)
            } label: {
                Text(String(localized: proManager.isProgramLocked(lesson) ? "catalog.unlock" : "catalog.start"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("catalog.start")
            .padding()
            .background(.bar)
        }
        .navigationTitle(String(localized: "catalog.details"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func lessonStructure(_ lesson: TrainingProgram) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "catalog.structure")).font(.headline)
            if SpeechService.shared.recordedLesson(for: lesson) != nil {
                Text(String(localized: "catalog.recordedStructure"))
            } else {
                let checks = lesson.guidedSteps.filter { $0.kind == .instruction && $0.duration == nil }.dropFirst()
                ForEach(Array(lesson.sets.enumerated()), id: \.offset) { index, set in
                    Text(String(localized: "catalog.set \(index + 1) \(set.repetitions) \(set.contractDuration) \(set.relaxDuration)"))
                        .font(.subheadline.weight(.semibold))
                    if let check = checks.dropFirst(index).first, index + 1 < lesson.sets.count {
                        Text(NSLocalizedString(check.guidanceKey, comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if let reflection = lesson.guidedSteps.last(where: { $0.kind == .reflection }) {
                    Text(String(localized: "catalog.reflect")).font(.headline)
                    Text(NSLocalizedString(reflection.guidanceKey, comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
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
