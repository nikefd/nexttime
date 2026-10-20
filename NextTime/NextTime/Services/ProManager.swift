//
//  ProManager.swift
//  NextTime
//
//  Pro 版本功能管理
//

import Foundation
import StoreKit
import Combine

@MainActor
class ProManager: ObservableObject {
    static let shared = ProManager()

    // 产品 ID
    static let proProductID = "com.nexttime.pro"

    // MARK: - Published 状态
    @Published var isPro: Bool = false
    @Published var products: [Product] = []
    @Published var purchaseInProgress: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var isLoadingProducts = false

    private var updateListenerTask: Task<Void, Error>?

    private init() {
        // 检查本地存储的购买状态
        isPro = UserDefaults.standard.bool(forKey: "isPro")

        // 启动交易监听
        updateListenerTask = listenForTransactions()

        // 加载产品
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - 加载产品
    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: [ProManager.proProductID])
            errorMessage = products.isEmpty ? String(localized: "pro.error.unavailable") : nil
        } catch {
            print("Failed to load products: \(error)")
            errorMessage = String(localized: "pro.error.unavailable")
        }
    }

    // MARK: - 购买产品
    func purchase() async -> Bool {
        guard !purchaseInProgress else { return false }
        guard let product = products.first else {
            errorMessage = String(localized: "pro.error.unavailable")
            return false
        }

        purchaseInProgress = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                await transaction.finish()
                isPro = true
                savePurchaseState()
                purchaseInProgress = false
                return true

            case .userCancelled:
                purchaseInProgress = false
                return false

            case .pending:
                errorMessage = String(localized: "pro.error.pending")
                purchaseInProgress = false
                return false

            @unknown default:
                purchaseInProgress = false
                return false
            }
        } catch {
            print("Purchase failed: \(error)")
            errorMessage = String(localized: "pro.error.purchase")
            purchaseInProgress = false
            return false
        }
    }

    // MARK: - 恢复购买
    func restorePurchases() async {
        guard !purchaseInProgress else { return }
        purchaseInProgress = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            purchaseInProgress = false
        } catch {
            print("Restore failed: \(error)")
            errorMessage = String(localized: "pro.error.restore")
            purchaseInProgress = false
        }
    }

    // MARK: - 更新购买状态
    func updatePurchasedProducts() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--store-screenshot-seed") { return }
        #endif
        var hasProEntitlement = false
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                if transaction.productID == ProManager.proProductID && transaction.revocationDate == nil {
                    hasProEntitlement = true
                }
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }
        isPro = hasProEntitlement
        savePurchaseState()
    }

    // MARK: - 监听交易
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }

                // 直接在这里验证，不调用 actor 方法
                let transaction: Transaction
                switch result {
                case .unverified:
                    continue
                case .verified(let safe):
                    transaction = safe
                }

                if transaction.productID == ProManager.proProductID {
                    await self.updatePurchasedProducts()
                }
                await transaction.finish()
            }
        }
    }

    // MARK: - 验证交易
    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - 保存购买状态
    private func savePurchaseState() {
        UserDefaults.standard.set(isPro, forKey: "isPro")
    }

    // MARK: - Debug 设置 Pro 状态
    #if DEBUG
    func setProStatus(_ value: Bool) {
        isPro = value
        savePurchaseState()
    }
    #endif

    // MARK: - 获取价格显示
    var priceDisplayString: String {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--store-screenshot-price-cn") {
            return "¥12.00"
        }
        #endif
        guard let product = products.first else {
            return String(localized: "pro.priceUnavailable")
        }
        return product.displayPrice
    }

    // MARK: - 错误类型
    enum StoreError: Error {
        case failedVerification
    }
}

// MARK: - Pro 功能检查扩展
extension ProManager {
    /// 检查课程是否需要 Pro
    func isProgramLocked(_ program: TrainingProgram) -> Bool {
        if isPro { return false }

        return program.isPremium
    }

    /// 检查是否可以使用自定义训练
    var canUseCustomTraining: Bool {
        return isPro
    }

    /// 检查是否可以使用提醒功能
    var canUseReminders: Bool {
        return isPro
    }

    /// 检查是否可以查看详细统计
    var canViewDetailedStats: Bool {
        return isPro
    }
}
