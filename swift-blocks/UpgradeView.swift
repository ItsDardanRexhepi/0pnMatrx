// MTRX/Subscriptions/UpgradeView.swift
// Copy this file to the MTRX iOS app's Subscriptions group.

import SwiftUI

/// Modal shown when a user hits a usage limit.
struct UpgradeView: View {
    let blockedFeature: Feature
    let currentUsage: Int
    let limit: Int

    @State private var storeKit = StoreKitManager.shared
    @State private var isPurchasing = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color(hex: 0x00FF41))

                        Text("Limit Reached")
                            .font(.title2.bold())

                        Text("You've used \(currentUsage) of \(limit) \(blockedFeature.displayName.lowercased()) this month.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()

                    // Tier comparison
                    HStack(spacing: 12) {
                        tierColumn(.free, highlight: false)
                        tierColumn(.pro, highlight: true)
                        tierColumn(.enterprise, highlight: false)
                    }
                    .padding(.horizontal)

                    // CTA buttons
                    VStack(spacing: 12) {
                        Button {
                            Task { await startTrial(for: StoreKitManager.proProductId) }
                        } label: {
                            HStack {
                                if isPurchasing {
                                    ProgressView().tint(.black)
                                }
                                Text("Start 3-Day Free Trial — Pro")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: 0x00FF41))
                        .foregroundStyle(.black)
                        .disabled(isPurchasing)

                        Button {
                            Task { await startTrial(for: StoreKitManager.enterpriseProductId) }
                        } label: {
                            Text("Try Enterprise Free")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isPurchasing)
                    }
                    .padding(.horizontal)

                    Button("Maybe Later") { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical)
            }
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                if !storeKit.isLoaded {
                    await storeKit.loadProducts()
                }
            }
        }
    }

    private func tierColumn(_ tier: SubscriptionTier, highlight: Bool) -> some View {
        VStack(spacing: 8) {
            Text(tier.displayName)
                .font(.caption.bold())

            Text(tier.priceDisplay)
                .font(.caption2)
                .foregroundStyle(.secondary)

            let featureLimit = blockedFeature.limit(for: tier)
            Text(featureLimit == nil ? "\u{221E}" : "\(featureLimit!)")
                .font(.title3.bold())
                .foregroundStyle(highlight ? Color(hex: 0x00FF41) : .primary)

            Text(blockedFeature.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    highlight ? Color(hex: 0x00FF41) : .secondary.opacity(0.3),
                    lineWidth: highlight ? 2 : 1
                )
        )
    }

    private func startTrial(for productId: String) async {
        isPurchasing = true
        defer { isPurchasing = false }
        await storeKit.startTrialIfEligible(for: productId)
    }
}
