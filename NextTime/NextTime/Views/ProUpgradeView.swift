//
//  ProUpgradeView.swift
//  NextTime
//
//  Pro 升级页面
//

import SwiftUI

struct ProUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var proManager = ProManager.shared
    @State private var showingRestoreAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 头部
                    headerSection

                    // 功能列表
                    featuresSection

                    // 价格和购买按钮
                    purchaseSection

                    // 恢复购买
                    restoreButton
                }
                .padding()
            }
            .navigationTitle(String(localized: "pro.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert(String(localized: "pro.restoreComplete"), isPresented: $showingRestoreAlert) {
                Button(String(localized: "alert.ok"), role: .cancel) {
                    if proManager.isPro {
                        dismiss()
                    }
                }
            } message: {
                Text(proManager.isPro ?
                     String(localized: "pro.restoreSuccess") :
                     String(localized: "pro.restoreNoPurchase"))
            }
        }
    }

    // MARK: - 头部
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)

            Text(String(localized: "pro.upgradeTitle"))
                .font(.title)
                .fontWeight(.bold)

            Text(String(localized: "pro.upgradeSubtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }

    // MARK: - 功能列表
    private var featuresSection: some View {
        VStack(spacing: 16) {
            FeatureRow(
                icon: "sparkles",
                color: .blue,
                title: String(localized: "pro.feature.courses"),
                description: String(localized: "pro.feature.courses.desc")
            )

            FeatureRow(
                icon: "slider.horizontal.3",
                color: .green,
                title: String(localized: "pro.feature.custom"),
                description: String(localized: "pro.feature.custom.desc")
            )

            FeatureRow(
                icon: "bell.fill",
                color: .orange,
                title: String(localized: "pro.feature.reminder"),
                description: String(localized: "pro.feature.reminder.desc")
            )

            FeatureRow(
                icon: "chart.bar.fill",
                color: .purple,
                title: String(localized: "pro.feature.stats"),
                description: String(localized: "pro.feature.stats.desc")
            )

            FeatureRow(
                icon: "heart.fill",
                color: .red,
                title: String(localized: "pro.feature.support"),
                description: String(localized: "pro.feature.support.desc")
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 购买区域
    private var purchaseSection: some View {
        VStack(spacing: 16) {
            // 一次性购买说明
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text(String(localized: "pro.oneTimePurchase"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // 购买按钮
            Button {
                Task {
                    let success = await proManager.purchase()
                    if success {
                        dismiss()
                    }
                }
            } label: {
                HStack {
                    if proManager.purchaseInProgress {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(String(localized: "pro.buyButton \(proManager.priceDisplayString)"))
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(proManager.purchaseInProgress)

            // 错误信息
            if let error = proManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - 恢复购买
    private var restoreButton: some View {
        Button {
            Task {
                await proManager.restorePurchases()
                showingRestoreAlert = true
            }
        } label: {
            Text(String(localized: "pro.restore"))
                .font(.subheadline)
                .foregroundStyle(.blue)
        }
        .disabled(proManager.purchaseInProgress)
    }
}

// MARK: - 功能行
struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    ProUpgradeView()
}
