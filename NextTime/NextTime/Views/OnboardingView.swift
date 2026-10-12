//
//  OnboardingView.swift
//  NextTime
//
//  成人、安全、隐私和目标选择引导
//

import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var page = 0
    @State private var confirmedAdult = false
    @State private var understandsSafety = false
    @State private var selectedGoals: Set<WellnessGoal> = []

    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= page ? Color.accentColor : Color(.systemGray5))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .accessibilityHidden(true)

            Group {
                switch page {
                case 0: welcomePage
                case 1: safetyPage
                case 2: privacyPage
                default: goalsPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            navigationButton
                .padding(24)
        }
        .background(Color(.systemBackground))
    }

    private var welcomePage: some View {
        onboardingPage(
            icon: "heart.circle.fill",
            color: .pink,
            title: String(localized: "onboarding.welcome.title"),
            message: String(localized: "onboarding.welcome.message")
        ) {
            Toggle(String(localized: "onboarding.adultConfirmation"), isOn: $confirmedAdult)
                .toggleStyle(.switch)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityIdentifier("onboarding.adult-confirmation")
        }
    }

    private var safetyPage: some View {
        onboardingPage(
            icon: "cross.case.fill",
            color: .red,
            title: String(localized: "onboarding.safety.title"),
            message: String(localized: "onboarding.safety.message")
        ) {
            VStack(alignment: .leading, spacing: 12) {
                safetyRow("onboarding.safety.notMedical", icon: "stethoscope")
                safetyRow("onboarding.safety.stop", icon: "hand.raised.fill")
                safetyRow("onboarding.safety.professional", icon: "person.crop.circle.badge.checkmark")

                Toggle(String(localized: "onboarding.safety.confirmation"), isOn: $understandsSafety)
                    .padding(.top, 8)
                    .accessibilityIdentifier("onboarding.safety-confirmation")
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var privacyPage: some View {
        onboardingPage(
            icon: "lock.shield.fill",
            color: .blue,
            title: String(localized: "onboarding.privacy.title"),
            message: String(localized: "onboarding.privacy.message")
        ) {
            VStack(alignment: .leading, spacing: 16) {
                privacyRow("onboarding.privacy.local", icon: "iphone")
                privacyRow("onboarding.privacy.noAccount", icon: "person.crop.circle.badge.xmark")
                privacyRow("onboarding.privacy.delete", icon: "trash")
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var goalsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "scope")
                    .font(.system(size: 48))
                    .foregroundStyle(.purple)

                Text(String(localized: "onboarding.goals.title"))
                    .font(.largeTitle.bold())

                Text(String(localized: "onboarding.goals.message"))
                    .foregroundStyle(.secondary)

                ForEach(WellnessGoal.allCases) { goal in
                    Button {
                        if selectedGoals.contains(goal) {
                            selectedGoals.remove(goal)
                        } else {
                            selectedGoals.insert(goal)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: goal.systemImage)
                                .font(.title2)
                                .frame(width: 34)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(goal.title)
                                    .font(.headline)
                                Text(goal.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: selectedGoals.contains(goal) ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                        }
                        .padding()
                        .foregroundStyle(.primary)
                        .background(
                            selectedGoals.contains(goal)
                                ? Color.accentColor.opacity(0.12)
                                : Color(.secondarySystemBackground)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding.goal.\(goal.rawValue)")
                }
            }
            .padding(24)
        }
    }

    private var navigationButton: some View {
        Button {
            if page < pageCount - 1 {
                withAnimation { page += 1 }
            } else {
                DataService.shared.completeOnboarding(selectedGoals: selectedGoals)
                onComplete()
            }
        } label: {
            Text(page == pageCount - 1
                 ? String(localized: "onboarding.start")
                 : String(localized: "onboarding.continue"))
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canContinue)
        .opacity(canContinue ? 1 : 0.45)
        .accessibilityIdentifier("onboarding.continue-button")
    }

    private var canContinue: Bool {
        switch page {
        case 0: return confirmedAdult
        case 1: return understandsSafety
        default: return true
        }
    }

    private func onboardingPage<Content: View>(
        icon: String,
        color: Color,
        title: String,
        message: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 28)
                Image(systemName: icon)
                    .font(.system(size: 56))
                    .foregroundStyle(color)
                Text(title)
                    .font(.largeTitle.bold())
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                content()
            }
            .padding(24)
        }
    }

    private func safetyRow(_ key: String, icon: String) -> some View {
        Label(NSLocalizedString(key, comment: ""), systemImage: icon)
            .font(.subheadline)
    }

    private func privacyRow(_ key: String, icon: String) -> some View {
        Label(NSLocalizedString(key, comment: ""), systemImage: icon)
            .font(.body)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
