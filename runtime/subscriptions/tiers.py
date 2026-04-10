"""Subscription tier definitions and limits for 0pnMatrx.

Three tiers gate access to the platform's 30 blockchain services:
  - FREE  ($0)     — generous limits for personal use
  - PRO   ($4.99)  — higher limits, priority, early access
  - ENTERPRISE ($19.99) — unlimited usage, team accounts, API access
"""

from __future__ import annotations

import enum
from typing import Union


class SubscriptionTier(str, enum.Enum):
    """Subscription tier levels."""
    FREE = "free"
    PRO = "pro"
    ENTERPRISE = "enterprise"

    @classmethod
    def from_str(cls, value: str) -> "SubscriptionTier":
        """Parse a tier string, defaulting to FREE for unknown values."""
        try:
            return cls(value.lower())
        except ValueError:
            return cls.FREE


TIER_LIMITS: dict[SubscriptionTier, dict] = {
    SubscriptionTier.FREE: {
        "contract_conversions_per_month": 5,
        "loan_volume_usd_per_month": 5000,
        "nft_mints_per_month": 3,
        "marketplace_listings_per_month": 2,
        "governance_votes_per_month": 10,
        "api_calls_per_minute": 20,
        "context_memory_turns": 20,
        "dashboard_export": False,
        "custom_skills": False,
        "team_accounts": False,
        "white_label": False,
        "audit_log_export": False,
        "api_access": False,
        "priority_support": False,
        "early_access": False,
    },
    SubscriptionTier.PRO: {
        "contract_conversions_per_month": 100,
        "loan_volume_usd_per_month": 500000,
        "nft_mints_per_month": 50,
        "marketplace_listings_per_month": 25,
        "governance_votes_per_month": 200,
        "api_calls_per_minute": 120,
        "context_memory_turns": 100,
        "dashboard_export": True,
        "custom_skills": True,
        "team_accounts": False,
        "white_label": False,
        "audit_log_export": False,
        "api_access": False,
        "priority_support": False,
        "early_access": True,
    },
    SubscriptionTier.ENTERPRISE: {
        "contract_conversions_per_month": -1,
        "loan_volume_usd_per_month": -1,
        "nft_mints_per_month": -1,
        "marketplace_listings_per_month": -1,
        "governance_votes_per_month": -1,
        "api_calls_per_minute": 600,
        "context_memory_turns": 500,
        "dashboard_export": True,
        "custom_skills": True,
        "team_accounts": True,
        "white_label": True,
        "audit_log_export": True,
        "api_access": True,
        "priority_support": True,
        "early_access": True,
    },
}

TIER_PRICES: dict[SubscriptionTier, float] = {
    SubscriptionTier.FREE: 0.00,
    SubscriptionTier.PRO: 4.99,
    SubscriptionTier.ENTERPRISE: 19.99,
}

# Human-readable feature descriptions for upgrade messages
FEATURE_DESCRIPTIONS: dict[str, str] = {
    "contract_conversions_per_month": "contract conversions/month",
    "loan_volume_usd_per_month": "DeFi loan volume/month",
    "nft_mints_per_month": "NFT mints/month",
    "marketplace_listings_per_month": "marketplace listings/month",
    "governance_votes_per_month": "governance votes/month",
    "api_calls_per_minute": "API calls/minute",
    "context_memory_turns": "conversation memory turns",
    "dashboard_export": "dashboard export",
    "custom_skills": "custom agent skills",
    "team_accounts": "team & multi-user accounts",
    "white_label": "white-label branding",
    "audit_log_export": "audit log export",
    "api_access": "direct API access",
    "priority_support": "priority support",
    "early_access": "early access to new features",
}


def get_limit(tier: SubscriptionTier, feature: str) -> Union[int, bool]:
    """Return the limit for a feature at the given tier.

    Returns an ``int`` for count-based limits (``-1`` means unlimited)
    or a ``bool`` for feature flags. Raises ``KeyError`` if the
    feature is not recognised.
    """
    tier_limits = TIER_LIMITS.get(tier)
    if tier_limits is None:
        tier_limits = TIER_LIMITS[SubscriptionTier.FREE]
    if feature not in tier_limits:
        raise KeyError(f"Unknown feature: {feature}")
    return tier_limits[feature]


def is_unlimited(tier: SubscriptionTier, feature: str) -> bool:
    """Return True if the feature has no count cap at this tier."""
    limit = get_limit(tier, feature)
    return isinstance(limit, int) and limit == -1
