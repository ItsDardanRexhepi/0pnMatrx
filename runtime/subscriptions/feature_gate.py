"""Feature gate — checks tier limits and records usage atomically.

Every gated action in the platform passes through ``FeatureGate.check()``
before executing. The gate:
  1. Looks up the limit for the action at the caller's tier
  2. Queries current monthly usage from ``UsageTracker``
  3. Returns an allow/deny dict with full context
  4. If allowed, records the usage so the next check sees it

The gate never raises — it always returns a well-formed dict so
callers can branch on ``result["allowed"]`` without try/except.
"""

from __future__ import annotations

import logging
from typing import Any

from runtime.subscriptions.tiers import (
    SubscriptionTier,
    TIER_LIMITS,
    FEATURE_DESCRIPTIONS,
    get_limit,
    is_unlimited,
)
from runtime.subscriptions.usage_tracker import UsageTracker

logger = logging.getLogger(__name__)


# Maps platform_action names to (feature_limit_key, default_value).
# ``default_value`` is either a numeric literal (always use that value)
# or a string naming the parameter whose value to use from the action args.
ACTION_GATE_MAP: dict[str, tuple[str, Any]] = {
    "convert_contract": ("contract_conversions_per_month", 1),
    "deploy_contract": ("contract_conversions_per_month", 1),
    "estimate_contract_cost": ("contract_conversions_per_month", 0),
    "list_templates": ("contract_conversions_per_month", 0),
    "mint_nft": ("nft_mints_per_month", 1),
    "create_nft_collection": ("nft_mints_per_month", 1),
    "transfer_nft": ("nft_mints_per_month", 0),
    "list_nft_for_sale": ("marketplace_listings_per_month", 1),
    "buy_nft": ("nft_mints_per_month", 0),
    "estimate_nft_value": ("nft_mints_per_month", 0),
    "get_nft_rarity": ("nft_mints_per_month", 0),
    "set_nft_rights": ("nft_mints_per_month", 0),
    "check_nft_rights": ("nft_mints_per_month", 0),
    "configure_nft_royalty": ("nft_mints_per_month", 0),
    "create_loan": ("loan_volume_usd_per_month", "borrow_amount"),
    "repay_loan": ("loan_volume_usd_per_month", 0),
    "get_loan": ("loan_volume_usd_per_month", 0),
    "list_marketplace": ("marketplace_listings_per_month", 1),
    "vote": ("governance_votes_per_month", 1),
    "create_proposal": ("governance_votes_per_month", 1),
    "get_dashboard": ("dashboard_export", False),
    "export_dashboard": ("dashboard_export", False),
    "tokenize_asset": ("marketplace_listings_per_month", 1),
    "transfer_rwa_ownership": ("marketplace_listings_per_month", 0),
}

# Next tier upgrade path
_UPGRADE_PATH: dict[SubscriptionTier, SubscriptionTier | None] = {
    SubscriptionTier.FREE: SubscriptionTier.PRO,
    SubscriptionTier.PRO: SubscriptionTier.ENTERPRISE,
    SubscriptionTier.ENTERPRISE: None,
}


class FeatureGate:
    """Central feature-gating system for the 0pnMatrx gateway.

    Checks tier-based access limits and records usage for every
    gated platform action.
    """

    def __init__(self, config: dict, usage_tracker: UsageTracker):
        """Initialise the gate.

        Parameters
        ----------
        config : dict
            Platform configuration (used for trial_days, etc.).
        usage_tracker : UsageTracker
            The usage tracking backend.
        """
        self.config = config
        self.tracker = usage_tracker

    async def check(
        self,
        wallet_address: str,
        tier: SubscriptionTier,
        action: str,
        value: float = 1.0,
        session_id: str = "",
        action_params: dict | None = None,
    ) -> dict:
        """Check whether an action is allowed for the given tier.

        Parameters
        ----------
        wallet_address : str
            The wallet address (or session ID for anonymous users).
        tier : SubscriptionTier
            The user's current subscription tier.
        action : str
            The platform action name (e.g. ``convert_contract``).
        value : float
            The usage value to record if allowed (default 1.0).
        session_id : str
            Current session identifier for tracking.
        action_params : dict, optional
            The action's parameters — used when the gate value is
            a parameter name (e.g. ``borrow_amount`` for loans).

        Returns
        -------
        dict
            Always contains ``allowed`` (bool). On denial, includes
            ``upgrade_to`` and ``upgrade_message``.
        """
        try:
            return await self._check_internal(
                wallet_address, tier, action, value, session_id, action_params
            )
        except Exception as exc:
            # Gate never raises — log and allow on error so the
            # platform doesn't block users due to a gate bug.
            logger.error("FeatureGate error for %s/%s: %s", wallet_address, action, exc)
            return {
                "allowed": True,
                "action": action,
                "limit": -1,
                "used": 0,
                "remaining": -1,
                "tier": tier.value,
                "upgrade_to": None,
                "upgrade_message": None,
                "error": str(exc),
            }

    async def _check_internal(
        self,
        wallet_address: str,
        tier: SubscriptionTier,
        action: str,
        value: float,
        session_id: str,
        action_params: dict | None,
    ) -> dict:
        """Internal check logic — may raise on unexpected errors."""
        # Look up the feature key for this action
        gate_entry = ACTION_GATE_MAP.get(action)

        if gate_entry is None:
            # Action not gated — always allowed
            return {
                "allowed": True,
                "action": action,
                "limit": -1,
                "used": 0,
                "remaining": -1,
                "tier": tier.value,
                "upgrade_to": None,
                "upgrade_message": None,
            }

        feature_key, default_value = gate_entry

        # Resolve the actual usage value
        if isinstance(default_value, str) and action_params:
            # Value comes from a parameter (e.g. borrow_amount)
            effective_value = float(action_params.get(default_value, value))
        elif isinstance(default_value, (int, float)):
            effective_value = float(default_value) if default_value else value
        else:
            effective_value = value

        # Get the limit for this tier
        try:
            limit = get_limit(tier, feature_key)
        except KeyError:
            # Unknown feature — allow
            return {
                "allowed": True,
                "action": action,
                "limit": -1,
                "used": 0,
                "remaining": -1,
                "tier": tier.value,
                "upgrade_to": None,
                "upgrade_message": None,
            }

        # Boolean feature gate
        if isinstance(limit, bool):
            upgrade_tier = _UPGRADE_PATH.get(tier)
            if limit:
                return {
                    "allowed": True,
                    "action": action,
                    "limit": 1,
                    "used": 0,
                    "remaining": 1,
                    "tier": tier.value,
                    "upgrade_to": None,
                    "upgrade_message": None,
                }
            else:
                # Find the tier that enables this feature
                required_tier = None
                for t in SubscriptionTier:
                    t_limits = TIER_LIMITS.get(t, {})
                    if t_limits.get(feature_key) is True:
                        required_tier = t
                        break
                feature_desc = FEATURE_DESCRIPTIONS.get(feature_key, feature_key)
                tier_name = required_tier.value.title() if required_tier else "a higher tier"
                return {
                    "allowed": False,
                    "action": action,
                    "limit": 0,
                    "used": 0,
                    "remaining": 0,
                    "tier": tier.value,
                    "upgrade_to": required_tier.value if required_tier else None,
                    "upgrade_message": f"Upgrade to {tier_name} for {feature_desc}",
                }

        # Count-based limit
        assert isinstance(limit, int)

        # Unlimited (-1) — always allowed
        if limit == -1:
            if effective_value > 0:
                await self.tracker.record(
                    session_id=session_id,
                    wallet_address=wallet_address,
                    action=feature_key,
                    value=effective_value,
                )
            return {
                "allowed": True,
                "action": action,
                "limit": -1,
                "used": 0,
                "remaining": -1,
                "tier": tier.value,
                "upgrade_to": None,
                "upgrade_message": None,
            }

        # Check current usage
        used = await self.tracker.get_monthly_total(wallet_address, feature_key)

        if used + effective_value > limit:
            upgrade_tier = _UPGRADE_PATH.get(tier)
            feature_desc = FEATURE_DESCRIPTIONS.get(feature_key, feature_key)
            if upgrade_tier:
                upgrade_limit = get_limit(upgrade_tier, feature_key)
                if isinstance(upgrade_limit, int) and upgrade_limit == -1:
                    upgrade_desc = f"unlimited {feature_desc}"
                else:
                    upgrade_desc = f"{upgrade_limit} {feature_desc}"
                msg = f"Upgrade to {upgrade_tier.value.title()} for {upgrade_desc}"
            else:
                msg = None
            return {
                "allowed": False,
                "action": action,
                "limit": limit,
                "used": int(used),
                "remaining": max(0, limit - int(used)),
                "tier": tier.value,
                "upgrade_to": upgrade_tier.value if upgrade_tier else None,
                "upgrade_message": msg,
            }

        # Allowed — record usage
        if effective_value > 0:
            await self.tracker.record(
                session_id=session_id,
                wallet_address=wallet_address,
                action=feature_key,
                value=effective_value,
            )

        remaining = max(0, limit - int(used) - int(effective_value))
        return {
            "allowed": True,
            "action": action,
            "limit": limit,
            "used": int(used) + int(effective_value),
            "remaining": remaining,
            "tier": tier.value,
            "upgrade_to": None,
            "upgrade_message": None,
        }
