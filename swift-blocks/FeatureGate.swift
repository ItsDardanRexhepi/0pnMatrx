// MTRX/Subscriptions/FeatureGate.swift
// Copy this file to the MTRX iOS app's Subscriptions group.

import SwiftUI

/// Features that can be gated by subscription tier.
enum Feature: String, CaseIterable {
    case contractConversion
    case defiLoans
    case nftMinting
    case marketplaceListing
    case governanceVoting
    case dashboardExport
    case customSkills
    case teamAccounts
    case whiteLabel
    case auditLogExport
    case apiAccess
    case prioritySupport
    case earlyAccess

    var displayName: String {
        switch self {
        case .contractConversion: return "Contract Conversions"
        case .defiLoans: return "DeFi Loans"
        case .nftMinting: return "NFT Minting"
        case .marketplaceListing: return "Marketplace Listings"
        case .governanceVoting: return "Governance Voting"
        case .dashboardExport: return "Dashboard Export"
        case .customSkills: return "Custom Skills"
        case .teamAccounts: return "Team Accounts"
        case .whiteLabel: return "White Label"
        case .auditLogExport: return "Audit Log Export"
        case .apiAccess: return "API Access"
        case .prioritySupport: return "Priority Support"
        case .earlyAccess: return "Early Access"
        }
    }

    var minimumTier: SubscriptionTier {
        switch self {
        case .contractConversion, .defiLoans, .nftMinting,
             .marketplaceListing, .governanceVoting:
            return .free
        case .dashboardExport, .customSkills, .earlyAccess:
            return .pro
        case .teamAccounts, .whiteLabel, .auditLogExport,
             .apiAccess, .prioritySupport:
            return .enterprise
        }
    }

    /// Returns the count limit for this feature at the given tier, or nil if unlimited.
    func limit(for tier: SubscriptionTier) -> Int? {
        switch self {
        case .contractConversion:
            switch tier {
            case .free: return 5
            case .pro: return 100
            case .enterprise: return nil
            }
        case .defiLoans:
            switch tier {
            case .free: return 5000
            case .pro: return 500000
            case .enterprise: return nil
            }
        case .nftMinting:
            switch tier {
            case .free: return 3
            case .pro: return 50
            case .enterprise: return nil
            }
        case .marketplaceListing:
            switch tier {
            case .free: return 2
            case .pro: return 25
            case .enterprise: return nil
            }
        case .governanceVoting:
            switch tier {
            case .free: return 10
            case .pro: return 200
            case .enterprise: return nil
            }
        default:
            return nil
        }
    }
}

/// Result of checking a feature gate.
struct GateResult {
    let allowed: Bool
    let limit: Int
    let used: Int
    let remaining: Int
    let upgradeMessage: String?

    static func allowed(limit: Int, used: Int) -> GateResult {
        GateResult(
            allowed: true,
            limit: limit,
            used: used,
            remaining: max(0, limit - used),
            upgradeMessage: nil
        )
    }

    static func denied(limit: Int, used: Int, message: String) -> GateResult {
        GateResult(
            allowed: false,
            limit: limit,
            used: used,
            remaining: 0,
            upgradeMessage: message
        )
    }
}

/// Central feature gate — checks tier access and usage limits.
@Observable
final class FeatureGate {
    static let shared = FeatureGate()

    var currentTier: SubscriptionTier = .free

    /// Check if a boolean feature is enabled at the current tier.
    func isEnabled(_ feature: Feature) -> Bool {
        currentTier >= feature.minimumTier
    }

    /// Check a count-based feature against current usage.
    func checkLimit(_ feature: Feature, currentUsage: Int) -> GateResult {
        guard currentTier >= feature.minimumTier else {
            return .denied(
                limit: 0,
                used: currentUsage,
                message: "Upgrade to \(feature.minimumTier.displayName) to unlock \(feature.displayName)"
            )
        }

        guard let limit = feature.limit(for: currentTier) else {
            return .allowed(limit: -1, used: currentUsage)
        }

        if currentUsage >= limit {
            let nextTier: SubscriptionTier = currentTier == .free ? .pro : .enterprise
            let nextLimit = feature.limit(for: nextTier)
            let limitDesc = nextLimit == nil ? "unlimited" : "\(nextLimit!)"
            return .denied(
                limit: limit,
                used: currentUsage,
                message: "Upgrade to \(nextTier.displayName) for \(limitDesc) \(feature.displayName.lowercased())"
            )
        }

        return .allowed(limit: limit, used: currentUsage)
    }

    private init() {}
}
