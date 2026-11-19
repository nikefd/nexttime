//
//  HomeView.swift
//  NextTime
//
//  以“今天只做这一件事”为核心的个人训练首页。
//

import SwiftUI

struct HomeView: View {
    @ObservedObject private var proManager = ProManager.shared
    @State private var recommendedProgram: TrainingProgram?
    @State private var recommendationKind: PracticeRecommendationKind = .onPlan
    private struct TrainingSelection: Identifiable {
        let id = UUID()
        let program: TrainingProgram
        let pathContext: PracticePathContext?
    }
    @State private var trainingSelection: TrainingSelection?
    @State private var practicePath: PracticePathState?
    @State private var pathRecords: [TrainingRecord] = []
    @State private var showPath = false
    @State private var comfort = 3
    @State private var tension = 3
    @State private var energy = 3
    @State private var checkInSavedToday = false
    @State private var showCheckIn = false
    @State private var showProUpgrade = false
    @State private var showPrograms = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    todayPracticeSection
                    compactPlanSection
                    adjustmentSection
                    Button {
                        showPrograms = true
                    } label: {
                        Label(String(localized: "program.browse"), systemImage: "list.bullet.rectangle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .accessibilityIdentifier("home.browse-programs")
                }
                .padding()
            }
            .navigationTitle(String(localized: "home.today.title"))
            .onAppear(perform: loadData)
            .fullScreenCover(item: $trainingSelection, onDismiss: loadData) { selection in
                TrainingView(program: selection.program, pathContext: selection.pathContext)
            }
            .sheet(isPresented: $showCheckIn) {
                checkInSheet
            }
            .sheet(isPresented: $showProUpgrade) {
                ProUpgradeView()
            }
            .sheet(isPresented: $showPath, onDismiss: loadData) {
                NavigationStack { PracticePathView() }
            }
            .sheet(isPresented: $showPrograms, onDismiss: loadData) {
                ProgramListView()
            }
        }
    }

    private var todayPracticeSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(recommendationKind.title, systemImage: recommendationIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(recommendationColor)
                Spacer()
                Label(String(localized: "recommendation.localOnly"), systemImage: "iphone")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let program = recommendedProgram, recommendationKind == .onPlan {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString(program.localizedNameKey, comment: ""))
                        .font(.largeTitle.bold())
                    Text(recommendationKind == .onPlan ? (practicePath?.currentStage.detail ?? recommendationKind.detail) : recommendationKind.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 16) {
                    Label(SpeechService.shared.formattedDuration(for: program), systemImage: "clock")
                    Label(String(localized: SpeechService.shared.recordedLesson(for: program) != nil ? "stageOne.structure" : "curriculum.structure"), systemImage: "list.number")

                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if recommendationKind.canStartPractice {
                    Button {
                        if proManager.isProgramLocked(program) {
                            showProUpgrade = true
                        } else {
                            trainingSelection = TrainingSelection(program: program, pathContext: recommendationKind == .onPlan ? practicePath?.context : nil)
                        }
                    } label: {
                        Label(
                            proManager.isProgramLocked(program)
                                ? String(localized: "home.today.unlock")
                                : String(localized: "home.today.start"),
                            systemImage: proManager.isProgramLocked(program) ? "crown.fill" : "play.fill"
                        )
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .accessibilityIdentifier(
                        proManager.isProgramLocked(program) ? "home.unlock-today" : "home.start-today"
                    )
                } else {
                    Label(String(localized: "home.today.paused"), systemImage: "cross.case.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if recommendationKind != .onPlan {
                Text(String(localized: "curriculum.recovery.title")).font(.title2.bold())
                Text(recommendationKind.detail).foregroundStyle(.secondary)
                Text(String(localized: "curriculum.recovery.body"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Button(String(localized: "curriculum.recovery.adjust")) { showCheckIn = true }
                    .accessibilityIdentifier("home.review-state")
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 180)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [recommendationColor.opacity(0.16), Color(.secondarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var compactPlanSection: some View {
        Button { showPath = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(String(localized: "path.title")).font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                if let path = practicePath {
                    Text(String(localized: "path.position \(path.currentStage.rawValue)"))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(path.currentStage.title).font(.title3.weight(.semibold))
                    Text(String(localized: "path.completed \(pathRecords.count)"))
                        .font(.subheadline)
                    if let next = path.currentStage.next {
                        Text(String(localized: "path.next \(next.title)"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text(String(localized: "path.saveError")).font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.practice-path")
    }

    private var adjustmentSection: some View {
        Button {
            showCheckIn = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: checkInSavedToday ? "checkmark.circle.fill" : "slider.horizontal.3")
                    .foregroundStyle(checkInSavedToday ? .green : .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(checkInSavedToday
                         ? String(localized: "home.today.adjusted")
                         : String(localized: "home.today.adjust"))
                        .font(.subheadline.weight(.semibold))
                    Text(String(localized: "home.today.adjust.detail"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var checkInSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(String(localized: "home.today.checkin.intro"))
                        .foregroundStyle(.secondary)
                    WellnessRatingRow(title: String(localized: "checkin.comfort"), value: $comfort)
                    WellnessRatingRow(title: String(localized: "checkin.tension"), value: $tension)
                    WellnessRatingRow(title: String(localized: "checkin.energy"), value: $energy)
                    Button(String(localized: "home.today.apply")) {
                        DataService.shared.saveCheckIn(
                            WellnessCheckIn(
                                moment: .beforePractice,
                                comfort: comfort,
                                tension: tension,
                                energy: energy
                            )
                        )
                        checkInSavedToday = true
                        loadData()
                        showCheckIn = false
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                }
                .padding()
            }
            .navigationTitle(String(localized: "home.today.adjust"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "alert.cancel")) { showCheckIn = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var recommendationIcon: String {
        switch recommendationKind {
        case .onPlan: return "sparkles"
        case .lowerIntensity: return "wind"
        case .lowEnergy: return "figure.mind.and.body"
        case .recovery: return "leaf.fill"
        case .professionalSupport: return "person.crop.circle.badge.questionmark"
        case .seekCare: return "cross.case.fill"
        }
    }

    private var recommendationColor: Color {
        switch recommendationKind {
        case .onPlan: return .blue
        case .lowerIntensity, .lowEnergy, .recovery: return .green
        case .professionalSupport: return .orange
        case .seekCare: return .red
        }
    }

    private func loadData() {
        let records = DataService.shared.loadRecords()
        practicePath = try? DataService.shared.startPracticePathIfNeeded()
        pathRecords = practicePath?.completedRecords(in: records) ?? []
        let checkIns = DataService.shared.loadCheckIns()
        let recommendation = PracticeRecommendationEngine.recommend(
            plannedProgramID: practicePath?.currentStage.program.id ?? TrainingData.foundationAwareness.id,
            relaxationProgramID: TrainingData.relaxationBreathing.id,
            bodyScanProgramID: TrainingData.confidenceBodyScan.id,
            checkIns: checkIns,
            safetyEvents: DataService.shared.loadSafetyEvents()
        )
        recommendedProgram = practicePath?.currentStage.program ?? PracticeCurriculum.program(for: .awareness)
        recommendationKind = recommendation.kind
        checkInSavedToday = checkIns.contains {
            $0.moment == .beforePractice && Calendar.current.isDateInToday($0.createdAt)
        }
        if let latest = checkIns.first(where: {
            $0.moment == .beforePractice && Calendar.current.isDateInToday($0.createdAt)
        }) {
            comfort = latest.comfort
            tension = latest.tension
            energy = latest.energy ?? 3
        }
    }
}

struct WellnessRatingRow: View {
    let title: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(value)/5")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { score in
                    Button("\(score)") { value = score }
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(score == value ? Color.accentColor : Color(.tertiarySystemFill))
                        .foregroundStyle(score == value ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("\(title) \(score)")
                        .accessibilityAddTraits(score == value ? .isSelected : [])
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
