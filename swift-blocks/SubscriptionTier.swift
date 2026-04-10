// MTRX/Subscriptions/SubscriptionTier.swift
// Copy this file to the MTRX iOS app's Subscriptions group.

import SwiftUI

/// Subscription tier levels matching the gateway's tier system.
enum SubscriptionTier: String, Codable, CaseIterable, Comparable {
    case free
    case pro
    case enterprise

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .enterprise: return "Enterprise"
        }
    }

    var monthlyPrice: Decimal {
        switch self {
        case .free: return 0
        case .pro: return 4.99
        case .enterprise: return 19.99
        }
    }

    var priceDisplay: String {
        switch self {
        case .free: return "Free"
        case .pro: return "$4.99/mo"
        case .enterprise: return "$19.99/mo"
        }
    }

    var color: Color {
        switch self {
        case .free: return .secondary
        case .pro: return Color(hex: 0x00FF41)
        case .enterprise: return .purple
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return [
                "5 contract conversions/month",
                "3 NFT mints/month",
                "$5,000 DeFi loan volume",
                "2 marketplace listings",
                "10 governance votes",
                "20 conversation turns",
            ]
        case .pro:
            return [
                "100 contract conversions/month",
                "50 NFT mints/month",
                "$500,000 DeFi loan volume",
                "25 marketplace listings",
                "200 governance votes",
                "100 conversation turns",
                "Dashboard export",
                "Custom agent skills",
                "Early access to new features",
            ]
        case .enterprise:
            return [
                "Unlimited contract conversions",
                "Unlimited NFT mints",
                "Unlimited DeFi volume",
                "Unlimited listings & votes",
                "500 conversation turns",
                "Team & multi-user accounts",
                "White-label branding",
                "Audit log export",
                "Direct API access",
                "Priority support",
            ]
        }
    }

    private var sortOrder: Int {
        switch self {
        case .free: return 0
        case .pro: return 1
        case .enterprise: return 2
        }
    }

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
