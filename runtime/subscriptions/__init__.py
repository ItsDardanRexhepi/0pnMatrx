"""Subscription tier system for 0pnMatrx gateway.

Enforces usage limits and feature gates at the API level so every
client — web, iOS, third-party — is gated correctly regardless of
what the client claims.
"""

from runtime.subscriptions.tiers import SubscriptionTier, TIER_LIMITS, TIER_PRICES, get_limit, is_unlimited
from runtime.subscriptions.usage_tracker import UsageTracker
from runtime.subscriptions.feature_gate import FeatureGate

__all__ = [
    "SubscriptionTier",
    "TIER_LIMITS",
    "TIER_PRICES",
    "UsageTracker",
    "FeatureGate",
    "get_limit",
    "is_unlimited",
]
