// MTRX/Subscriptions/StoreKitManager.swift
// Copy this file to the MTRX iOS app's Subscriptions group.

import StoreKit
import SwiftUI

/// Manages StoreKit 2 subscriptions for the MTRX app.
@MainActor
@Observable
final class StoreKitManager {
    static let shared = StoreKitManager()

    static let proProductId = "io.openmatrix.mtrx.pro.monthly"
    static let enterpriseProductId = "io.openmatrix.mtrx.enterprise.monthly"

    private(set) var products: [Product] = []
    private(set) var purchasedSubscriptions: [Transaction] = []
    private(set) var isLoaded = false

    private var updateTask: Task<Void, Never>?

    private init() {
        updateTask = listenForUpdates()
    }

    deinit {
        updateTask?.cancel()
    }

    /// Load subscription products from the App Store.
    func loadProducts() async {
        do {
            let productIds = [Self.proProductId, Self.enterpriseProductId]
            products = try await Product.products(for: productIds)
                .sorted { $0.price < $1.price }
            isLoaded = true
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    /// Purchase a product and return the transaction.
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await checkEntitlements()
            return transaction

        case .userCancelled:
            return nil

        case .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    /// Check current entitlements and update the FeatureGate.
    func checkEntitlements() async {
        var highestTier: SubscriptionTier = .free

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }

            switch transaction.productID {
            case Self.enterpriseProductId:
                highestTier = .enterprise
            case Self.proProductId:
                if highestTier < .pro { highestTier = .pro }
            default:
                break
            }
        }

        FeatureGate.shared.currentTier = highestTier
    }

    /// Start a trial if eligible for the given product.
    func startTrialIfEligible(for productId: String) async {
        guard let product = products.first(where: { $0.id == productId }) else { return }
        guard product.subscription?.introductoryOffer != nil else { return }
        _ = try? await purchase(product)
    }

    // MARK: - Private

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let value):
            return value
        }
    }

    private func listenForUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let transaction = try? self?.checkVerified(result) else { continue }
                await transaction.finish()
                await self?.checkEntitlements()
            }
        }
    }
}

enum StoreError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        "Could not verify your subscription."
    }
}
