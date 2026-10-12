import SwiftUI

struct TrainingView: View {
    let program: TrainingProgram
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var trainingManager = TrainingManager.shared
    @AppStorage("defaultPrivacyMode") private var defaultDiscreetMode = false
    @State private var showExitAlert = false
    @State private var discreetMode = false
    @State private var temporarilyRevealed = false
    @State private var revealTask: Task<Void, Never>?
    @State private var postComfort = 3
    @State private var postRelaxation = 3
    @State private var experiencedDiscomfort = false
    @State private var savedPostCheckIn = false

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            VStack(spacing: 20) {
                topBar
                if trainingManager.isRunning || trainingManager.isPaused {
                    activeContent
                } else if trainingManager.progress.isCompleted {
                    completedContent
                }
                Spacer(minLength: 8)
                controls
            }
            .padding()

            if discreetMode && !temporarilyRevealed {
                DiscreetPracticeOverlay(
                    progress: stepProgress,
                    isPaused: trainingManager.isPaused,
                    isCompleted: trainingManager.progress.isCompleted,
                    onReveal: revealTemporarily,
                    onExit: { showExitAlert = true }
                )
            }
        }
        .preferredColorScheme(discreetMode ? .dark : nil)
        .statusBarHidden(discreetMode && !temporarilyRevealed)
        .onAppear {
            discreetMode = defaultDiscreetMode
            trainingManager.startTraining(program: program)
        }
        .onDisappear {
            revealTask?.cancel()
            if trainingManager.currentProgram != nil { trainingManager.stopTraining() }
        }
        .alert(String(localized: "alert.exitTraining.title"), isPresented: $showExitAlert) {
            Button(String(localized: "alert.cancel"), role: .cancel) {}
            Button(String(localized: "alert.exit"), role: .destructive) {
                trainingManager.stopTraining()
                dismiss()
            }
        } message: {
            Text(String(localized: "alert.exitTraining.message"))
        }
    }

    private var topBar: some View {
        HStack {
            Button { showExitAlert = true } label: {
                Image(systemName: "xmark.circle.fill").font(.title2)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(NSLocalizedString(program.localizedNameKey, comment: "")).font(.headline)
                Text(trainingManager.progressDescription).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                revealTask?.cancel()
                temporarilyRevealed = false
                discreetMode.toggle()
            } label: {
                Image(systemName: discreetMode ? "eye.slash.fill" : "eye.fill").font(.title2)
            }
            .accessibilityLabel(String(localized: "discreet.mode.title"))
        }
        .foregroundStyle(.primary)
    }

    private var activeContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                stepVisual
                if let step = trainingManager.currentStep {
                    Text(NSLocalizedString(step.titleKey, comment: ""))
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text(NSLocalizedString(step.guidanceKey, comment: ""))
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .lineSpacing(5)
                        .padding(.horizontal)

                    if step.kind == .partnerPrompt {
                        Label(String(localized: "guided.partner.optional"), systemImage: "hand.raised.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                ProgressView(value: stepProgress)
                    .tint(accentColor)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
        }
    }

    @ViewBuilder
    private var stepVisual: some View {
        let kind = trainingManager.currentStep?.kind ?? .instruction
        if trainingManager.progress.isAwaitingContinue {
            Image(systemName: icon(for: kind))
                .font(.system(size: 64))
                .foregroundStyle(accentColor)
                .frame(width: 150, height: 150)
                .background(Circle().fill(accentColor.opacity(0.12)))
        } else {
            ZStack {
                Circle().stroke(accentColor.opacity(0.18), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: timedStepProgress)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.4), value: timedStepProgress)
                Image(systemName: icon(for: kind))
                    .font(.system(size: 46))
                    .foregroundStyle(accentColor)
            }
            .frame(width: 180, height: 180)
            Text(String(localized: "guided.secondsRemaining \(trainingManager.progress.remainingSeconds)"))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        Group {
            if trainingManager.isRunning || trainingManager.isPaused {
                if trainingManager.progress.isAwaitingContinue {
                    Button(String(localized: "guided.continue")) { trainingManager.advanceStep() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 20) {
                        Button {
                            trainingManager.isPaused ? trainingManager.resumeTraining() : trainingManager.pauseTraining()
                        } label: {
                            Label(
                                trainingManager.isPaused ? String(localized: "button.resume") : String(localized: "button.pause"),
                                systemImage: trainingManager.isPaused ? "play.fill" : "pause.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        if trainingManager.currentStep?.kind == .rest {
                            Button(String(localized: "button.skipRest")) { trainingManager.skipRest() }
                                .buttonStyle(.bordered)
                        }
                    }
                    .controlSize(.large)
                }
            } else if trainingManager.progress.isCompleted {
                Button(String(localized: "button.done")) { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 16)
    }

    private var completedContent: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 72)).foregroundStyle(.green)
                Text(String(localized: "training.completed")).font(.title.bold())
                Text(String(localized: "training.greatJob")).foregroundStyle(.secondary)
                if !savedPostCheckIn {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(String(localized: "checkin.after.title")).font(.headline)
                        WellnessRatingRow(title: String(localized: "checkin.comfort"), value: $postComfort)
                        WellnessRatingRow(title: String(localized: "checkin.relaxation"), value: $postRelaxation)
                        Toggle(String(localized: "checkin.discomfort"), isOn: $experiencedDiscomfort)
                        Button(String(localized: "checkin.save")) {
                            DataService.shared.saveCheckIn(WellnessCheckIn(
                                moment: .afterPractice,
                                comfort: postComfort,
                                tension: max(1, 6 - postRelaxation),
                                relaxation: postRelaxation,
                                experiencedDiscomfort: experiencedDiscomfort
                            ))
                            savedPostCheckIn = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Label(String(localized: "checkin.saved"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private var backgroundColor: Color {
        switch trainingManager.currentStep?.kind {
        case .contract: return .blue.opacity(0.12)
        case .relax, .bodyScan: return .green.opacity(0.12)
        case .partnerPrompt: return .pink.opacity(0.12)
        case .reflection: return .purple.opacity(0.12)
        case .breathe: return .cyan.opacity(0.12)
        default: return Color(.systemBackground)
        }
    }

    private var accentColor: Color {
        switch trainingManager.currentStep?.kind {
        case .contract: return .blue
        case .relax, .bodyScan: return .green
        case .partnerPrompt: return .pink
        case .reflection: return .purple
        case .rest: return .orange
        default: return .cyan
        }
    }

    private var stepProgress: Double {
        guard trainingManager.progress.totalSteps > 0 else { return 0 }
        return Double(trainingManager.progress.currentStepIndex) / Double(trainingManager.progress.totalSteps)
    }

    private var timedStepProgress: Double {
        guard let duration = trainingManager.currentStep?.duration, duration > 0 else { return 0 }
        return 1 - Double(trainingManager.progress.remainingSeconds) / Double(duration)
    }

    private func icon(for kind: GuidedStepKind) -> String {
        switch kind {
        case .instruction: return "text.book.closed.fill"
        case .breathe: return "wind"
        case .contract: return "circle.circle.fill"
        case .relax: return "leaf.fill"
        case .bodyScan: return "figure.mind.and.body"
        case .reflection: return "bubble.left.and.text.bubble.right.fill"
        case .partnerPrompt: return "person.2.fill"
        case .rest: return "cup.and.saucer.fill"
        }
    }

    private func revealTemporarily() {
        revealTask?.cancel()
        temporarilyRevealed = true
        revealTask = Task {
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            await MainActor.run { temporarilyRevealed = false }
        }
    }
}

private struct DiscreetPracticeOverlay: View {
    let progress: Double
    let isPaused: Bool
    let isCompleted: Bool
    let onReveal: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.04, blue: 0.045).ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Image(systemName: isCompleted ? "checkmark" : "circle.dotted")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(.gray)
                Text(isCompleted ? String(localized: "discreet.complete") : (isPaused ? String(localized: "discreet.paused") : String(localized: "discreet.inProgress")))
                    .font(.headline)
                    .foregroundStyle(.gray)
                ProgressView(value: progress).tint(.gray).padding(.horizontal, 64)
                Text(String(localized: "discreet.hint")).font(.caption).foregroundStyle(.gray.opacity(0.7))
                Spacer()
                HStack(spacing: 42) {
                    Button(action: onReveal) {
                        Label(String(localized: "discreet.reveal"), systemImage: "eye.fill")
                    }
                    Button(action: onExit) {
                        Label(String(localized: "discreet.exit"), systemImage: "xmark")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.gray)
                .padding(.bottom, 42)
            }
        }
    }
}

#Preview { TrainingView(program: TrainingData.beginnerQuickStart) }
