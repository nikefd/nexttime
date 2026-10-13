//
//  LearnView.swift
//  NextTime
//
//  Educational content for the current practice plan and safety boundaries.
//

import SwiftUI

struct LearnView: View {
    var body: some View {
        NavigationStack {
            List(ArticleType.allCases) { article in
                NavigationLink {
                    ArticleView(article: article)
                } label: {
                    ArticleRow(
                        icon: article.icon,
                        color: article.color,
                        title: article.title,
                        subtitle: article.subtitle
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "learn.title"))
        }
    }
}

struct ArticleRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ArticleSection: Identifiable, Equatable {
    let titleKey: String
    let contentKey: String

    var id: String { titleKey }

    var title: String { NSLocalizedString(titleKey, comment: "") }
    var content: String { NSLocalizedString(contentKey, comment: "") }
}

enum ArticleType: String, CaseIterable, Identifiable {
    case plan
    case basics
    case balance
    case wellbeing
    case partner
    case safety
    case sources

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .plan: return "calendar.badge.clock"
        case .basics: return "figure.mind.and.body"
        case .balance: return "arrow.left.arrow.right.circle.fill"
        case .wellbeing: return "heart.text.square.fill"
        case .partner: return "person.2.fill"
        case .safety: return "cross.case.fill"
        case .sources: return "books.vertical.fill"
        }
    }

    var color: Color {
        switch self {
        case .plan: return .blue
        case .basics: return .teal
        case .balance: return .green
        case .wellbeing: return .purple
        case .partner: return .pink
        case .safety: return .orange
        case .sources: return .indigo
        }
    }

    var title: String { localized("learn.\(rawValue)") }
    var subtitle: String { localized("learn.\(rawValue).subtitle") }
    var intro: String { localized("article.\(rawValue).intro") }

    var sections: [ArticleSection] {
        let count: Int
        switch self {
        case .plan: count = 5
        case .basics, .balance, .wellbeing, .partner, .safety, .sources: count = 3
        }

        return (1...count).map {
            ArticleSection(
                titleKey: "article.\(rawValue).\($0).title",
                contentKey: "article.\(rawValue).\($0).content"
            )
        }
    }

    var externalURL: URL? {
        let languageSuffix = Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "" : "_en"
        switch self {
        case .safety:
            return URL(string: "https://nikefd.github.io/nexttime-site/safety\(languageSuffix).html")
        case .sources:
            return URL(string: "https://nikefd.github.io/nexttime-site/sources\(languageSuffix).html")
        default:
            return nil
        }
    }

    var externalLinkTitle: String {
        localized("article.\(rawValue).link")
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

struct ArticleView: View {
    let article: ArticleType

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.intro)
                    .font(.body)

                ForEach(article.sections) { section in
                    infoCard(section)
                }

                if let url = article.externalURL {
                    Link(destination: url) {
                        Label(article.externalLinkTitle, systemImage: "arrow.up.right.square")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.large)
    }

    private func infoCard(_ section: ArticleSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.headline)
            Text(section.content)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    LearnView()
}
