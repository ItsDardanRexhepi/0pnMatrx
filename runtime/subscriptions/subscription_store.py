"""Persistent subscription state backed by SQLite.

Stores which wallet has which tier, Stripe customer/subscription IDs,
trial status, and billing period info. The ``FeatureGate`` reads the
tier from here on every gated action.
"""

from __future__ import annotations

import logging
import time
from typing import Any

from runtime.subscriptions.tiers import SubscriptionTier

logger = logging.getLogger(__name__)


class SubscriptionStore:
    """SQLite-backed subscription persistence.

    Provides CRUD operations for per-wallet subscription records
    including Stripe metadata and trial tracking.
    """

    def __init__(self, db):
        """Initialise with a ``Database`` instance.

        Parameters
        ----------
        db : runtime.db.database.Database
            The platform's shared SQLite wrapper.
        """
        self.db = db

    async def initialize(self) -> None:
        """Create the subscriptions table if it does not exist."""
        await self.db.execute(
            """
            CREATE TABLE IF NOT EXISTS subscriptions (
                wallet_address          TEXT PRIMARY KEY,
                tier                    TEXT NOT NULL DEFAULT 'free',
                stripe_customer_id      TEXT,
                stripe_subscription_id  TEXT,
                status                  TEXT NOT NULL DEFAULT 'active',
                current_period_end      REAL,
                trial_end               REAL,
                created_at              REAL NOT NULL,
                updated_at              REAL NOT NULL
            )
            """,
            commit=True,
        )

    async def upsert(
        self,
        wallet_address: str,
        tier: str,
        stripe_data: dict | None = None,
    ) -> None:
        """Create or update a subscription record.

        Parameters
        ----------
        wallet_address : str
            The wallet address (primary key).
        tier : str
            The subscription tier (``free``, ``pro``, ``enterprise``).
        stripe_data : dict, optional
            Additional Stripe fields: ``customer_id``,
            ``subscription_id``, ``status``, ``current_period_end``,
            ``trial_end``.
        """
        stripe_data = stripe_data or {}
        now = time.time()

        existing = await self.get_subscription(wallet_address)
        if existing:
            await self.db.execute(
                """
                UPDATE subscriptions SET
                    tier = ?,
                    stripe_customer_id = COALESCE(?, stripe_customer_id),
                    stripe_subscription_id = COALESCE(?, stripe_subscription_id),
                    status = COALESCE(?, status),
                    current_period_end = COALESCE(?, current_period_end),
                    trial_end = COALESCE(?, trial_end),
                    updated_at = ?
                WHERE wallet_address = ?
                """,
                (
                    tier,
                    stripe_data.get("customer_id"),
                    stripe_data.get("subscription_id"),
                    stripe_data.get("status"),
                    stripe_data.get("current_period_end"),
                    stripe_data.get("trial_end"),
                    now,
                    wallet_address,
                ),
                commit=True,
            )
        else:
            await self.db.execute(
                """
                INSERT INTO subscriptions
                    (wallet_address, tier, stripe_customer_id, stripe_subscription_id,
                     status, current_period_end, trial_end, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    wallet_address,
                    tier,
                    stripe_data.get("customer_id"),
                    stripe_data.get("subscription_id"),
                    stripe_data.get("status", "active"),
                    stripe_data.get("current_period_end"),
                    stripe_data.get("trial_end"),
                    now,
                    now,
                ),
                commit=True,
            )

    async def get_tier(self, wallet_address: str) -> SubscriptionTier:
        """Return the current tier for a wallet. Defaults to FREE.

        Checks trial and period expiry — if a subscription has lapsed,
        falls back to FREE automatically.
        """
        row = await self.db.fetchone(
            "SELECT * FROM subscriptions WHERE wallet_address = ?",
            (wallet_address,),
        )
        if not row:
            return SubscriptionTier.FREE

        now = time.time()
        tier_str = row["tier"]
        status = row["status"]
        period_end = row["current_period_end"]
        trial_end = row["trial_end"]

        # Check if subscription is cancelled
        if status in ("cancelled", "canceled", "deleted"):
            return SubscriptionTier.FREE

        # Check if trial has expired without converting
        if trial_end and now > trial_end and status == "trialing":
            return SubscriptionTier.FREE

        # Check if billing period has lapsed
        if period_end and now > period_end and status != "active":
            return SubscriptionTier.FREE

        return SubscriptionTier.from_str(tier_str)

    async def get_subscription(self, wallet_address: str) -> dict | None:
        """Return the full subscription record for a wallet, or None."""
        row = await self.db.fetchone(
            "SELECT * FROM subscriptions WHERE wallet_address = ?",
            (wallet_address,),
        )
        if not row:
            return None
        return {
            "wallet_address": row["wallet_address"],
            "tier": row["tier"],
            "stripe_customer_id": row["stripe_customer_id"],
            "stripe_subscription_id": row["stripe_subscription_id"],
            "status": row["status"],
            "current_period_end": row["current_period_end"],
            "trial_end": row["trial_end"],
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }

    async def set_trial(
        self,
        wallet_address: str,
        tier: str,
        trial_days: int = 3,
    ) -> None:
        """Start a trial for a wallet.

        Parameters
        ----------
        wallet_address : str
            The wallet to grant a trial.
        tier : str
            The tier to trial (``pro`` or ``enterprise``).
        trial_days : int
            Duration of the trial in days (default 3).
        """
        now = time.time()
        trial_end = now + (trial_days * 86400)
        await self.upsert(
            wallet_address,
            tier,
            stripe_data={
                "status": "trialing",
                "trial_end": trial_end,
                "current_period_end": trial_end,
            },
        )

    async def is_trial(self, wallet_address: str) -> bool:
        """Return True if the wallet is currently in a trial."""
        row = await self.db.fetchone(
            "SELECT status, trial_end FROM subscriptions WHERE wallet_address = ?",
            (wallet_address,),
        )
        if not row:
            return False
        if row["status"] != "trialing":
            return False
        if row["trial_end"] and time.time() > row["trial_end"]:
            return False
        return True
