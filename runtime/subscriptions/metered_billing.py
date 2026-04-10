"""Metered API billing for 0pnMatrx gateway.

Tracks per-API-key call counts, enforces tier-based rate limits,
computes overage charges, and generates invoices.  Each API key is
subscribed to exactly one metered tier that defines included calls,
per-call overage pricing, and requests-per-minute limits.
"""

from __future__ import annotations

import logging
import time
from datetime import datetime, timezone
from typing import Any

logger = logging.getLogger(__name__)

METERED_TIERS: dict[str, dict[str, Any]] = {
    "growth": {
        "monthly_base": 49.99,
        "included_calls": 10_000,
        "overage_per_call": 0.005,
        "rate_limit_rpm": 300,
        "description": "For startups building on 0pnMatrx",
    },
    "scale": {
        "monthly_base": 199.99,
        "included_calls": 100_000,
        "overage_per_call": 0.002,
        "rate_limit_rpm": 1_000,
        "description": "For growing applications",
    },
    "infrastructure": {
        "monthly_base": 499.99,
        "included_calls": 500_000,
        "overage_per_call": 0.001,
        "rate_limit_rpm": 3_000,
        "description": "For production infrastructure",
    },
}


class MeteredBillingManager:
    """Manages metered API billing backed by SQLite.

    Provides subscription management, per-call usage recording,
    overage calculation, invoice generation, and rate-limit lookups
    for API keys enrolled in a metered tier.
    """

    def __init__(self, db, config: dict | None = None) -> None:
        """Initialise with a ``Database`` instance and optional config.

        Parameters
        ----------
        db : runtime.db.database.Database
            The platform's shared async SQLite wrapper.
        config : dict, optional
            Override configuration.  Supports ``"tiers"`` key to
            replace or extend the default ``METERED_TIERS``.
        """
        self.db = db
        self.config = config or {}
        self.tiers: dict[str, dict[str, Any]] = {
            **METERED_TIERS,
            **self.config.get("tiers", {}),
        }

    # ------------------------------------------------------------------
    # Schema migration
    # ------------------------------------------------------------------

    async def initialize(self) -> None:
        """Create the metered-billing tables if they do not exist."""
        await self.db.execute(
            """
            CREATE TABLE IF NOT EXISTS api_usage_metered (
                api_key         TEXT NOT NULL,
                month           TEXT NOT NULL,
                call_count      INTEGER NOT NULL DEFAULT 0,
                last_updated    REAL NOT NULL,
                PRIMARY KEY (api_key, month)
            )
            """,
            commit=True,
        )
        await self.db.execute(
            """
            CREATE TABLE IF NOT EXISTS api_metered_subscriptions (
                api_key     TEXT PRIMARY KEY,
                tier        TEXT NOT NULL,
                created_at  REAL NOT NULL,
                updated_at  REAL NOT NULL
            )
            """,
            commit=True,
        )
        logger.info("Metered billing tables initialised")

    # ------------------------------------------------------------------
    # Subscription management
    # ------------------------------------------------------------------

    async def subscribe(self, api_key: str, tier: str) -> dict:
        """Subscribe an API key to a metered tier.

        If the key already has a metered subscription the tier is
        updated in place.

        Parameters
        ----------
        api_key : str
            The API key to subscribe.
        tier : str
            One of the configured metered tier names
            (``growth``, ``scale``, ``infrastructure``).

        Returns
        -------
        dict
            Subscription record including tier configuration.

        Raises
        ------
        ValueError
            If *tier* is not a recognised metered tier.
        """
        if tier not in self.tiers:
            raise ValueError(
                f"Unknown metered tier '{tier}'. "
                f"Valid tiers: {', '.join(sorted(self.tiers))}"
            )

        now = time.time()
        existing = await self.db.fetchone(
            "SELECT * FROM api_metered_subscriptions WHERE api_key = ?",
            (api_key,),
        )

        if existing:
            await self.db.execute(
                """
                UPDATE api_metered_subscriptions
                SET tier = ?, updated_at = ?
                WHERE api_key = ?
                """,
                (tier, now, api_key),
                commit=True,
            )
            logger.info("Updated metered subscription for %s to tier '%s'", api_key, tier)
        else:
            await self.db.execute(
                """
                INSERT INTO api_metered_subscriptions (api_key, tier, created_at, updated_at)
                VALUES (?, ?, ?, ?)
                """,
                (api_key, tier, now, now),
                commit=True,
            )
            logger.info("Created metered subscription for %s on tier '%s'", api_key, tier)

        tier_config = self.tiers[tier]
        return {
            "api_key": api_key,
            "tier": tier,
            "monthly_base": tier_config["monthly_base"],
            "included_calls": tier_config["included_calls"],
            "overage_per_call": tier_config["overage_per_call"],
            "rate_limit_rpm": tier_config["rate_limit_rpm"],
            "created_at": existing["created_at"] if existing else now,
            "updated_at": now,
        }

    async def get_tier_for_key(self, api_key: str) -> dict | None:
        """Return the metered tier configuration for an API key.

        Parameters
        ----------
        api_key : str
            The API key to look up.

        Returns
        -------
        dict or None
            The full tier configuration dict if the key is on a
            metered plan, otherwise ``None``.
        """
        row = await self.db.fetchone(
            "SELECT tier FROM api_metered_subscriptions WHERE api_key = ?",
            (api_key,),
        )
        if not row:
            return None

        tier_name = row["tier"]
        tier_config = self.tiers.get(tier_name)
        if tier_config is None:
            logger.warning(
                "API key %s references unknown tier '%s'", api_key, tier_name
            )
            return None

        return {"tier": tier_name, **tier_config}

    # ------------------------------------------------------------------
    # Usage recording
    # ------------------------------------------------------------------

    async def record_api_call(self, api_key: str) -> None:
        """Increment the call count for *api_key* in the current month.

        Uses an ``INSERT OR REPLACE`` pattern: if a row already exists
        for the (api_key, month) pair, it is replaced with the
        incremented count; otherwise a new row is inserted with
        ``call_count = 1``.

        Parameters
        ----------
        api_key : str
            The API key that made the call.
        """
        month = datetime.now(timezone.utc).strftime("%Y-%m")
        now = time.time()

        existing = await self.db.fetchone(
            """
            SELECT call_count FROM api_usage_metered
            WHERE api_key = ? AND month = ?
            """,
            (api_key, month),
        )

        if existing:
            new_count = existing["call_count"] + 1
            await self.db.execute(
                """
                INSERT OR REPLACE INTO api_usage_metered
                    (api_key, month, call_count, last_updated)
                VALUES (?, ?, ?, ?)
                """,
                (api_key, month, new_count, now),
                commit=True,
            )
        else:
            await self.db.execute(
                """
                INSERT OR REPLACE INTO api_usage_metered
                    (api_key, month, call_count, last_updated)
                VALUES (?, ?, 1, ?)
                """,
                (api_key, month, now),
                commit=True,
            )

        logger.debug("Recorded API call for %s in %s", api_key, month)

    # ------------------------------------------------------------------
    # Usage & billing queries
    # ------------------------------------------------------------------

    async def get_monthly_usage(
        self, api_key: str, month: str | None = None
    ) -> dict:
        """Return usage summary for an API key in a given month.

        Parameters
        ----------
        api_key : str
            The API key to query.
        month : str, optional
            Month in ``YYYY-MM`` format.  Defaults to the current
            UTC month.

        Returns
        -------
        dict
            Keys: ``calls``, ``included``, ``overage``,
            ``estimated_overage_charge``, ``tier``, ``month``.
        """
        if month is None:
            month = datetime.now(timezone.utc).strftime("%Y-%m")

        tier_info = await self.get_tier_for_key(api_key)
        if tier_info is None:
            return {
                "calls": 0,
                "included": 0,
                "overage": 0,
                "estimated_overage_charge": 0.0,
                "tier": None,
                "month": month,
            }

        row = await self.db.fetchone(
            """
            SELECT call_count FROM api_usage_metered
            WHERE api_key = ? AND month = ?
            """,
            (api_key, month),
        )
        calls = row["call_count"] if row else 0
        included = tier_info["included_calls"]
        overage = max(0, calls - included)
        overage_charge = round(overage * tier_info["overage_per_call"], 4)

        return {
            "calls": calls,
            "included": included,
            "overage": overage,
            "estimated_overage_charge": overage_charge,
            "tier": tier_info["tier"],
            "month": month,
        }

    async def calculate_invoice(self, api_key: str, month: str) -> dict:
        """Calculate the full invoice for an API key in a billing month.

        Parameters
        ----------
        api_key : str
            The API key to invoice.
        month : str
            Month in ``YYYY-MM`` format.

        Returns
        -------
        dict
            Keys: ``api_key``, ``month``, ``tier``, ``base_charge``,
            ``included_calls``, ``actual_calls``, ``overage_calls``,
            ``overage_charge``, ``total_charge``.

        Raises
        ------
        ValueError
            If the API key is not on a metered plan.
        """
        tier_info = await self.get_tier_for_key(api_key)
        if tier_info is None:
            raise ValueError(
                f"API key '{api_key}' is not subscribed to a metered plan"
            )

        row = await self.db.fetchone(
            """
            SELECT call_count FROM api_usage_metered
            WHERE api_key = ? AND month = ?
            """,
            (api_key, month),
        )
        actual_calls = row["call_count"] if row else 0
        included_calls = tier_info["included_calls"]
        base_charge = tier_info["monthly_base"]
        overage_calls = max(0, actual_calls - included_calls)
        overage_charge = round(overage_calls * tier_info["overage_per_call"], 4)
        total_charge = round(base_charge + overage_charge, 2)

        return {
            "api_key": api_key,
            "month": month,
            "tier": tier_info["tier"],
            "base_charge": base_charge,
            "included_calls": included_calls,
            "actual_calls": actual_calls,
            "overage_calls": overage_calls,
            "overage_charge": overage_charge,
            "total_charge": total_charge,
        }

    async def generate_usage_report(
        self, api_key: str, months: int = 3
    ) -> list[dict]:
        """Generate invoices for the last *months* billing periods.

        Parameters
        ----------
        api_key : str
            The API key to report on.
        months : int
            Number of most-recent months to include (default ``3``).

        Returns
        -------
        list[dict]
            A list of ``calculate_invoice`` results, sorted most-recent
            month first.

        Raises
        ------
        ValueError
            If the API key is not on a metered plan.
        """
        tier_info = await self.get_tier_for_key(api_key)
        if tier_info is None:
            raise ValueError(
                f"API key '{api_key}' is not subscribed to a metered plan"
            )

        rows = await self.db.fetchall(
            """
            SELECT DISTINCT month FROM api_usage_metered
            WHERE api_key = ?
            ORDER BY month DESC
            LIMIT ?
            """,
            (api_key, months),
        )

        report: list[dict] = []
        for row in rows:
            invoice = await self.calculate_invoice(api_key, row["month"])
            report.append(invoice)

        return report

    async def get_rate_limit(self, api_key: str) -> int:
        """Return the requests-per-minute limit for an API key.

        Parameters
        ----------
        api_key : str
            The API key to query.

        Returns
        -------
        int
            The RPM limit for the key's metered tier, or ``0`` if the
            key is not on a metered plan.
        """
        tier_info = await self.get_tier_for_key(api_key)
        if tier_info is None:
            return 0
        return tier_info["rate_limit_rpm"]
