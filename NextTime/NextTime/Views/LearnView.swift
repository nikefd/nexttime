//
//  LearnView.swift
//  NextTime
//
//  知识科普页面
//

import SwiftUI

struct LearnView: View {
    var body: some View {
        NavigationStack {
            List {
                // 什么是凯格尔运动
                Section {
                    NavigationLink {
                        ArticleView(article: .whatIsKegel)
                    } label: {
                        ArticleRow(
                            icon: "questionmark.circle.fill",
                            color: .blue,
                            title: String(localized: "learn.whatIsKegel"),
                            subtitle: String(localized: "learn.whatIsKegel.subtitle")
                        )
                    }
                }

                // 好处
                Section {
                    NavigationLink {
                        ArticleView(article: .benefits)
                    } label: {
                        ArticleRow(
                            icon: "heart.fill",
                            color: .red,
                            title: String(localized: "learn.benefits"),
                            subtitle: String(localized: "learn.benefits.subtitle")
                        )
                    }
                }

                // 如何正确练习
                Section {
                    NavigationLink {
                        ArticleView(article: .howTo)
                    } label: {
                        ArticleRow(
                            icon: "figure.strengthtraining.traditional",
                            color: .green,
                            title: String(localized: "learn.howTo"),
                            subtitle: String(localized: "learn.howTo.subtitle")
                        )
                    }
                }

                // 常见问题
                Section {
                    NavigationLink {
                        ArticleView(article: .faq)
                    } label: {
                        ArticleRow(
                            icon: "bubble.left.and.bubble.right.fill",
                            color: .orange,
                            title: String(localized: "learn.faq"),
                            subtitle: String(localized: "learn.faq.subtitle")
                        )
                    }
                }

                // 提示
                Section {
                    NavigationLink {
                        ArticleView(article: .tips)
                    } label: {
                        ArticleRow(
                            icon: "lightbulb.fill",
                            color: .yellow,
                            title: String(localized: "learn.tips"),
                            subtitle: String(localized: "learn.tips.subtitle")
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "learn.title"))
        }
    }
}

// MARK: - 文章行
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

// MARK: - 文章类型
enum ArticleType: String {
    case whatIsKegel
    case benefits
    case howTo
    case faq
    case tips
}

// MARK: - 文章详情视图
struct ArticleView: View {
    let article: ArticleType

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch article {
                case .whatIsKegel:
                    whatIsKegelContent
                case .benefits:
                    benefitsContent
                case .howTo:
                    howToContent
                case .faq:
                    faqContent
                case .tips:
                    tipsContent
                }
            }
            .padding()
        }
        .navigationTitle(articleTitle)
        .navigationBarTitleDisplayMode(.large)
    }

    private var articleTitle: String {
        switch article {
        case .whatIsKegel: return String(localized: "learn.whatIsKegel")
        case .benefits: return String(localized: "learn.benefits")
        case .howTo: return String(localized: "learn.howTo")
        case .faq: return String(localized: "learn.faq")
        case .tips: return String(localized: "learn.tips")
        }
    }

    // MARK: - 什么是凯格尔运动
    private var whatIsKegelContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "article.whatIsKegel.intro"))
                .font(.body)

            infoCard(
                title: String(localized: "article.whatIsKegel.origin.title"),
                content: String(localized: "article.whatIsKegel.origin.content")
            )

            infoCard(
                title: String(localized: "article.whatIsKegel.muscles.title"),
                content: String(localized: "article.whatIsKegel.muscles.content")
            )
        }
    }

    // MARK: - 好处
    private var benefitsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "article.benefits.intro"))
                .font(.body)

            benefitItem(
                number: 1,
                title: String(localized: "article.benefits.1.title"),
                description: String(localized: "article.benefits.1.desc")
            )
            benefitItem(
                number: 2,
                title: String(localized: "article.benefits.2.title"),
                description: String(localized: "article.benefits.2.desc")
            )
            benefitItem(
                number: 3,
                title: String(localized: "article.benefits.3.title"),
                description: String(localized: "article.benefits.3.desc")
            )
            benefitItem(
                number: 4,
                title: String(localized: "article.benefits.4.title"),
                description: String(localized: "article.benefits.4.desc")
            )
            benefitItem(
                number: 5,
                title: String(localized: "article.benefits.5.title"),
                description: String(localized: "article.benefits.5.desc")
            )
        }
    }

    // MARK: - 如何正确练习
    private var howToContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "article.howTo.intro"))
                .font(.body)

            stepCard(
                step: 1,
                title: String(localized: "article.howTo.step1.title"),
                content: String(localized: "article.howTo.step1.content")
            )

            stepCard(
                step: 2,
                title: String(localized: "article.howTo.step2.title"),
                content: String(localized: "article.howTo.step2.content")
            )

            stepCard(
                step: 3,
                title: String(localized: "article.howTo.step3.title"),
                content: String(localized: "article.howTo.step3.content")
            )

            stepCard(
                step: 4,
                title: String(localized: "article.howTo.step4.title"),
                content: String(localized: "article.howTo.step4.content")
            )
        }
    }

    // MARK: - 常见问题
    private var faqContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            faqItem(
                question: String(localized: "article.faq.1.q"),
                answer: String(localized: "article.faq.1.a")
            )
            faqItem(
                question: String(localized: "article.faq.2.q"),
                answer: String(localized: "article.faq.2.a")
            )
            faqItem(
                question: String(localized: "article.faq.3.q"),
                answer: String(localized: "article.faq.3.a")
            )
            faqItem(
                question: String(localized: "article.faq.4.q"),
                answer: String(localized: "article.faq.4.a")
            )
        }
    }

    // MARK: - 练习提示
    private var tipsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "article.tips.intro"))
                .font(.body)

            tipItem(icon: "clock", content: String(localized: "article.tips.1"))
            tipItem(icon: "location", content: String(localized: "article.tips.2"))
            tipItem(icon: "figure.walk", content: String(localized: "article.tips.3"))
            tipItem(icon: "brain.head.profile", content: String(localized: "article.tips.4"))
            tipItem(icon: "calendar", content: String(localized: "article.tips.5"))
        }
    }

    // MARK: - 辅助视图
    private func infoCard(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func benefitItem(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.blue))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stepCard(step: Int, title: String, content: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Step \(step)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.green))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(content)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text("Q:")
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
                Text(question)
                    .fontWeight(.medium)
            }

            HStack(alignment: .top) {
                Text("A:")
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
                Text(answer)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func tipItem(icon: String, content: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 24)

            Text(content)
                .font(.body)
        }
    }
}

#Preview {
    LearnView()
}
