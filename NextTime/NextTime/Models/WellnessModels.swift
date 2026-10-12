//
//  WellnessModels.swift
//  NextTime
//
//  本地优先 MVP 的引导与安全模型
//

import Foundation

enum WellnessGoal: String, Codable, CaseIterable, Identifiable {
    case pelvicFoundation
    case relaxation
    case bodyConfidence
    case partnerConnection

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pelvicFoundation: return String(localized: "onboarding.goal.pelvicFoundation.title")
        case .relaxation: return String(localized: "onboarding.goal.relaxation.title")
        case .bodyConfidence: return String(localized: "onboarding.goal.bodyConfidence.title")
        case .partnerConnection: return String(localized: "onboarding.goal.partnerConnection.title")
        }
    }

    var detail: String {
        switch self {
        case .pelvicFoundation: return String(localized: "onboarding.goal.pelvicFoundation.detail")
        case .relaxation: return String(localized: "onboarding.goal.relaxation.detail")
        case .bodyConfidence: return String(localized: "onboarding.goal.bodyConfidence.detail")
        case .partnerConnection: return String(localized: "onboarding.goal.partnerConnection.detail")
        }
    }

    var systemImage: String {
        switch self {
        case .pelvicFoundation: return "figure.strengthtraining.traditional"
        case .relaxation: return "wind"
        case .bodyConfidence: return "heart.text.square"
        case .partnerConnection: return "person.2.fill"
        }
    }
}

enum PracticeRoute: String, Codable, CaseIterable, Identifiable {
    case foundation
    case relaxation
    case confidence
    case partner

    var id: String { rawValue }
    var title: String {
        switch self {
        case .foundation: return String(localized: "route.foundation.title")
        case .relaxation: return String(localized: "route.relaxation.title")
        case .confidence: return String(localized: "route.confidence.title")
        case .partner: return String(localized: "route.partner.title")
        }
    }
    var detail: String {
        switch self {
        case .foundation: return String(localized: "route.foundation.detail")
        case .relaxation: return String(localized: "route.relaxation.detail")
        case .confidence: return String(localized: "route.confidence.detail")
        case .partner: return String(localized: "route.partner.detail")
        }
    }

    var systemImage: String {
        switch self {
        case .foundation: return "figure.strengthtraining.traditional"
        case .relaxation: return "wind"
        case .confidence: return "heart.text.square"
        case .partner: return "person.2.fill"
        }
    }

    static func routes(for goals: Set<WellnessGoal>) -> [PracticeRoute] {
        let mapped = goals.map { goal -> PracticeRoute in
            switch goal {
            case .pelvicFoundation: return .foundation
            case .relaxation: return .relaxation
            case .bodyConfidence: return .confidence
            case .partnerConnection: return .partner
            }
        }
        return mapped.isEmpty ? allCases : allCases.filter(Set(mapped).contains)
    }
}

enum CheckInMoment: String, Codable {
    case beforePractice
    case afterPractice
}

struct WellnessCheckIn: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let moment: CheckInMoment
    let comfort: Int
    let tension: Int
    let energy: Int?
    let relaxation: Int?
    let experiencedDiscomfort: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        moment: CheckInMoment,
        comfort: Int,
        tension: Int,
        energy: Int? = nil,
        relaxation: Int? = nil,
        experiencedDiscomfort: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.moment = moment
        self.comfort = min(max(comfort, 1), 5)
        self.tension = min(max(tension, 1), 5)
        self.energy = energy.map { min(max($0, 1), 5) }
        self.relaxation = relaxation.map { min(max($0, 1), 5) }
        self.experiencedDiscomfort = experiencedDiscomfort
    }
}

struct PracticePlanDay: Identifiable, Equatable {
    let day: Int
    let programID: UUID
    var id: Int { day }
}

struct PracticePlan: Equatable {
    let days: [PracticePlanDay]

    func programID(for day: Int) -> UUID? {
        days.first { $0.day == day }?.programID
    }
}

struct PartnerCommunicationCard: Identifiable, Equatable {
    let id: String
    let titleKey: String
    let promptKey: String

    var title: String { NSLocalizedString(titleKey, comment: "") }
    var prompt: String { NSLocalizedString(promptKey, comment: "") }
}

struct WellnessProfile: Codable, Equatable {
    var selectedGoals: Set<WellnessGoal>
    var createdAt: Date

    init(selectedGoals: Set<WellnessGoal>, createdAt: Date = Date()) {
        self.selectedGoals = selectedGoals
        self.createdAt = createdAt
    }
}

struct SafetyAcknowledgement: Codable, Equatable {
    static let currentVersion = "2026-10-12-v1"

    let version: String
    let confirmedAdult: Bool
    let acceptedAt: Date

    init(
        version: String = SafetyAcknowledgement.currentVersion,
        confirmedAdult: Bool,
        acceptedAt: Date = Date()
    ) {
        self.version = version
        self.confirmedAdult = confirmedAdult
        self.acceptedAt = acceptedAt
    }
}
