//
//  TrainingView.swift
//  NextTime
//
//  训练界面
//

import SwiftUI

struct TrainingView: View {
    let program: TrainingProgram
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var trainingManager = TrainingManager.shared
    @State private var showExitAlert = false
    @State private var privacyMode = false
    @AppStorage("defaultPrivacyMode") private var defaultPrivacyMode = false

    var body: some View {
        ZStack {
            // 背景色
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部导航
                topBar

                Spacer()

                // 主要内容区域
                if trainingManager.isRunning || trainingManager.isPaused {
                    activeTrainingContent
                } else if trainingManager.progress.isCompleted {
                    completedContent
                } else {
                    preStartContent
                }

                Spacer()

                // 底部控制按钮
                controlButtons
            }
            .padding()

            // 隐私模式模糊遮罩
            if privacyMode {
                PrivacyBlurOverlay(
                    currentAction: trainingManager.progress.currentAction,
                    remainingSeconds: trainingManager.progress.remainingSeconds,
                    isCompleted: trainingManager.progress.isCompleted,
                    onTogglePrivacy: { privacyMode = false },
                    onExit: { showExitAlert = true }
                )
            }
        }
        .preferredColorScheme(privacyMode ? .dark : nil)
        .onAppear {
            privacyMode = defaultPrivacyMode
            // 重置并自动开始训练
            trainingManager.resetState()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                trainingManager.startTraining(program: program)
            }
        }
        .onDisappear {
            trainingManager.stopTraining()
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
        .statusBarHidden(privacyMode)
    }

    // MARK: - 背景色
    private var backgroundColor: Color {
        if privacyMode {
            return Color.black
        }
        switch trainingManager.progress.currentAction {
        case .contract:
            return Color.blue.opacity(0.3)
        case .relax:
            return Color.green.opacity(0.3)
        case .rest:
            return Color.orange.opacity(0.3)
        }
    }

    // MARK: - 顶部导航栏
    private var topBar: some View {
        HStack {
            Button {
                if trainingManager.isRunning {
                    showExitAlert = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(privacyMode ? .gray : .secondary)
            }

            Spacer()

            VStack {
                Text(NSLocalizedString(program.localizedNameKey, comment: ""))
                    .font(.headline)
                    .foregroundStyle(privacyMode ? .white : .primary)
                Text(trainingManager.progressDescription)
                    .font(.caption)
                    .foregroundStyle(privacyMode ? .gray : .secondary)
            }

            Spacer()

            // 隐私模式切换
            Button {
                withAnimation {
                    privacyMode.toggle()
                }
            } label: {
                Image(systemName: privacyMode ? "eye.slash.fill" : "eye.fill")
                    .font(.title2)
                    .foregroundStyle(privacyMode ? .gray : .secondary)
            }
        }
    }

    // MARK: - 训练中内容
    private var activeTrainingContent: some View {
        VStack(spacing: 32) {
            // 当前动作
            Text(trainingManager.currentActionDescription)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(privacyMode ? actionColorPrivacy : actionColor)

            // 倒计时
            ZStack {
                Circle()
                    .stroke(privacyMode ? Color.gray.opacity(0.3) : Color.gray.opacity(0.3), lineWidth: 12)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(privacyMode ? actionColorPrivacy : actionColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: progress)

                Text("\(trainingManager.progress.remainingSeconds)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(privacyMode ? actionColorPrivacy : actionColor)
            }

            // 跳过休息按钮
            if trainingManager.progress.currentAction == .rest {
                Button {
                    trainingManager.skipRest()
                } label: {
                    Text(String(localized: "button.skipRest"))
                        .font(.subheadline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.3))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }

            // 进度指示
            VStack(spacing: 8) {
                ProgressView(value: setProgress)
                    .tint(privacyMode ? actionColorPrivacy : actionColor)

                Text(String(localized: "training.elapsedTime \(formatTime(trainingManager.progress.elapsedTime))"))
                    .font(.caption)
                    .foregroundStyle(privacyMode ? .gray : .secondary)
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - 完成内容
    private var completedContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text(String(localized: "training.completed"))
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(privacyMode ? .white : .primary)

            Text(String(localized: "training.greatJob"))
                .font(.subheadline)
                .foregroundStyle(privacyMode ? .gray : .secondary)
        }
    }

    // MARK: - 开始前内容
    private var preStartContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text(String(localized: "training.getReady"))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(privacyMode ? .white : .primary)

            Text(String(localized: "training.startingSoon"))
                .font(.subheadline)
                .foregroundStyle(privacyMode ? .gray : .secondary)
        }
    }

    // MARK: - 控制按钮
    private var controlButtons: some View {
        HStack(spacing: 24) {
            if trainingManager.isRunning || trainingManager.isPaused {
                // 暂停/恢复按钮
                Button {
                    if trainingManager.isPaused {
                        trainingManager.resumeTraining()
                    } else {
                        trainingManager.pauseTraining()
                    }
                } label: {
                    Image(systemName: trainingManager.isPaused ? "play.fill" : "pause.fill")
                        .font(.title)
                        .frame(width: 70, height: 70)
                        .background(Circle().fill(Color.blue))
                        .foregroundStyle(.white)
                }

                // 停止按钮
                Button {
                    showExitAlert = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title)
                        .frame(width: 70, height: 70)
                        .background(Circle().fill(Color.red))
                        .foregroundStyle(.white)
                }
            } else if trainingManager.progress.isCompleted {
                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "button.done"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .padding(.bottom, 32)
    }

    // MARK: - 计算属性
    private var actionColor: Color {
        switch trainingManager.progress.currentAction {
        case .contract: return .blue
        case .relax: return .green
        case .rest: return .orange
        }
    }

    private var actionColorPrivacy: Color {
        switch trainingManager.progress.currentAction {
        case .contract: return .blue.opacity(0.8)
        case .relax: return .green.opacity(0.8)
        case .rest: return .orange.opacity(0.8)
        }
    }

    private var progress: CGFloat {
        guard let currentSet = program.sets[safe: trainingManager.progress.currentSetIndex] else {
            return 0
        }

        let totalSeconds: Int
        switch trainingManager.progress.currentAction {
        case .contract:
            totalSeconds = currentSet.contractDuration
        case .relax:
            totalSeconds = currentSet.relaxDuration
        case .rest:
            totalSeconds = program.restBetweenSets
        }

        guard totalSeconds > 0 else { return 0 }
        return CGFloat(trainingManager.progress.remainingSeconds) / CGFloat(totalSeconds)
    }

    private var setProgress: Double {
        let totalSets = program.sets.count
        guard totalSets > 0 else { return 0 }
        return Double(trainingManager.progress.currentSetIndex) / Double(totalSets)
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - 隐私模式模糊遮罩
struct PrivacyBlurOverlay: View {
    let currentAction: ExerciseAction
    let remainingSeconds: Int
    let isCompleted: Bool
    let onTogglePrivacy: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            // 深色模糊背景
            Color.black
                .ignoresSafeArea()

            // 极简显示
            VStack(spacing: 40) {
                Spacer()

                if isCompleted {
                    // 完成状态
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.green)

                    Text(String(localized: "training.completed"))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                } else {
                    // 当前动作指示（简化显示）
                    Circle()
                        .fill(actionColor)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Text("\(remainingSeconds)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        )

                    Text(actionText)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(actionColor)
                }

                Spacer()

                // 底部提示
                HStack(spacing: 40) {
                    // 显示按钮
                    Button {
                        onTogglePrivacy()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "eye.fill")
                                .font(.title2)
                            Text("显示")
                                .font(.caption)
                        }
                        .foregroundStyle(.gray)
                    }

                    // 退出按钮
                    Button {
                        onExit()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                            Text("退出")
                                .font(.caption)
                        }
                        .foregroundStyle(.gray)
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }

    private var actionColor: Color {
        switch currentAction {
        case .contract: return .blue
        case .relax: return .green
        case .rest: return .orange
        }
    }

    private var actionText: String {
        switch currentAction {
        case .contract: return String(localized: "action.contract")
        case .relax: return String(localized: "action.relax")
        case .rest: return String(localized: "action.rest")
        }
    }
}

#Preview {
    TrainingView(program: TrainingData.beginnerQuickStart)
}
