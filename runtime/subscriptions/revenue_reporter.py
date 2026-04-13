"""Unified revenue reporting across all 0pnMatrx monetization streams.

Pulls from subscription_store, usage_tracker, plugin_marketplace,
audit_service, badge_manager, certification_manager, metered_billing,
and referral_manager to produce unified revenue reports.

Revenue streams tracked:
  - Subscriptions (Pro, Enterprise — pricing defined in MTRX iOS app)
  - Audit Service (Standard $299, Advanced $599, Enterprise $999)
  - Security Badges ($99/year per badge)
  - Certifications (per-track assessment fees)
  - Plugin Marketplace (10% platform fee on paid plugins)
  - Metered API Overage (per-call charges above tier included calls)
  - Protocol Referrals (on-chain referral fees from DeFi protocols)
  - Referral Program (net cost of credited free months)
"""

from __future__ import annotations

import logging
import os
import time
import uuid
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

NEOSAFE_ADDRESS = "0x46fF491D7054A6F500026B3E81f358190f8d8Ec5"


class RevenueReporter:
    """Aggregates revenue data across all monetization streams.

    Pulls from subscription_store, usage_tracker, plugin_marketplace,
    audit_service, badge_manager, certification_manager, metered_billing,
    and referral_manager to produce unified revenue reports.
    """

    def __init__(self, db, config: dict | None = None):
        self.db = db
        self.config = config or {}

    # ------------------------------------------------------------------
    # Schema
    # ------------------------------------------------------------------

    async def initialize(self) -> None:
        """Create the unified revenue ledger table if it does not exist."""
        await self.db.execute(
            """
            CREATE TABLE IF NOT EXISTS revenue_events (
                id              TEXT PRIMARY KEY,
                stream          TEXT NOT NULL,
                amount_usd      REAL NOT NULL,
                wallet_address  TEXT,
                description     TEXT,
                recorded_at     REAL NOT NULL,
                month           TEXT NOT NULL
            )
            """,
            commit=True,
        )
        logger.info("revenue_events table ready")

    # ------------------------------------------------------------------
    # Event recording
    # ------------------------------------------------------------------

    async def record_revenue(
        self,
        stream: str,
        amount_usd: float,
        wallet_address: str = "",
        description: str = "",
    ) -> str:
        """Insert a revenue event into the unified ledger.

        Parameters
        ----------
        stream : str
            The revenue stream name (e.g. ``subscriptions``,
            ``audits``, ``badges``, ``marketplace_fees``).
        amount_usd : float
            Dollar amount of the revenue event.
        wallet_address : str, optional
            Associated wallet address, if any.
        description : str, optional
            Human-readable description of the event.

        Returns
        -------
        str
            The UUID of the newly created revenue event.
        """
        event_id = str(uuid.uuid4())
        now = time.time()
        month = datetime.now(timezone.utc).strftime("%Y-%m")

        await self.db.execute(
            """
            INSERT INTO revenue_events
                (id, stream, amount_usd, wallet_address, description,
                 recorded_at, month)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (event_id, stream, amount_usd, wallet_address, description,
             now, month),
            commit=True,
        )
        logger.info(
            "Recorded revenue event: stream=%s amount=$%.2f id=%s",
            stream, amount_usd, event_id,
        )
        return event_id

    # ------------------------------------------------------------------
    # MRR calculation
    # ------------------------------------------------------------------

    async def get_mrr(self) -> float:
        """Calculate current Monthly Recurring Revenue.

        Counts active Pro and Enterprise subscriptions at their
        configured price points plus the sum of metered billing base
        charges for all active metered API subscriptions.

        Returns
        -------
        float
            The current MRR in USD.
        """
        # Pro subscription revenue
        row = await self.db.fetchone(
            """
            SELECT COUNT(*) AS cnt FROM subscriptions
            WHERE tier = 'pro' AND status = 'active'
            """,
        )
        pro_count = row["cnt"] if row else 0

        # Enterprise subscription revenue
        row = await self.db.fetchone(
            """
            SELECT COUNT(*) AS cnt FROM subscriptions
            WHERE tier = 'enterprise' AND status = 'active'
            """,
        )
        enterprise_count = row["cnt"] if row else 0

        # Metered billing base charges
        row = await self.db.fetchone(
            """
            SELECT COALESCE(SUM(
                CASE ams.tier
                    WHEN 'growth'         THEN 49.99
                    WHEN 'scale'          THEN 199.99
                    WHEN 'infrastructure' THEN 499.99
                    ELSE 0
                END
            ), 0) AS metered_base
            FROM api_metered_subscriptions ams
            """,
        )
        metered_base = row["metered_base"] if row else 0.0

        # Pricing is defined in the MTRX iOS app — fetch from Stripe at runtime
        pro_price = float(os.environ.get("STRIPE_PRO_PRICE_AMOUNT", "0"))
        ent_price = float(os.environ.get("STRIPE_ENTERPRISE_PRICE_AMOUNT", "0"))
        mrr = (pro_count * pro_price) + (enterprise_count * ent_price) + metered_base
        return round(mrr, 2)

    # ------------------------------------------------------------------
    # Monthly breakdown
    # ------------------------------------------------------------------

    async def get_monthly_breakdown(self, month: str | None = None) -> dict:
        """Return revenue totals grouped by stream for a given month.

        Parameters
        ----------
        month : str, optional
            Month in ``YYYY-MM`` format.  Defaults to the current
            UTC month.

        Returns
        -------
        dict
            Keys: ``month``, ``subscriptions``, ``audits``, ``badges``,
            ``certifications``, ``marketplace_fees``,
            ``metered_overage``, ``referral_net``, ``total``.
        """
        if month is None:
            month = datetime.now(timezone.utc).strftime("%Y-%m")

        rows = await self.db.fetchall(
            """
            SELECT stream, COALESCE(SUM(amount_usd), 0) AS total
            FROM revenue_events
            WHERE month = ?
            GROUP BY stream
            """,
            (month,),
        )

        stream_totals: dict[str, float] = {}
        for row in rows:
            stream_totals[row["stream"]] = round(row["total"], 2)

        subscriptions = stream_totals.get("subscriptions", 0.0)
        audits = stream_totals.get("audits", 0.0)
        badges = stream_totals.get("badges", 0.0)
        certifications = stream_totals.get("certifications", 0.0)
        marketplace_fees = stream_totals.get("marketplace_fees", 0.0)
        metered_overage = stream_totals.get("metered_overage", 0.0)
        referral_net = stream_totals.get("referral_net", 0.0)

        total = round(
            subscriptions + audits + badges + certifications
            + marketplace_fees + metered_overage + referral_net,
            2,
        )

        return {
            "month": month,
            "subscriptions": subscriptions,
            "audits": audits,
            "badges": badges,
            "certifications": certifications,
            "marketplace_fees": marketplace_fees,
            "metered_overage": metered_overage,
            "referral_net": referral_net,
            "total": total,
        }

    # ------------------------------------------------------------------
    # Subscriber counts
    # ------------------------------------------------------------------

    async def get_subscriber_counts(self) -> dict:
        """Count subscribers by tier from the subscriptions table.

        Returns
        -------
        dict
            Keys: ``free``, ``pro``, ``enterprise``, ``total``,
            ``trial``.
        """
        row = await self.db.fetchone(
            """
            SELECT COUNT(*) AS cnt FROM subscriptions
            WHERE tier = 'free' AND status = 'active'
            """,
        )
        free = row["cnt"] if row else 0

        row = await self.db.fetchone(
            """
            SELECT COUNT(*) AS cnt FROM subscriptions
            WHERE tier = 'pro' AND status = 'active'
            """,
        )
        pro = row["cnt"] if row else 0

        row = await self.db.fetchone(
            """
            SELECT COUNT(*) AS cnt FROM subscriptions
            WHERE tier = 'enterprise' AND status = 'active'
            """,
        )
        enterprise = row["cnt"] if row else 0

        row = await self.db.fetchone(
            """
            SELECT COUNT(*) AS cnt FROM subscriptions
            WHERE status = 'trialing'
            """,
        )
        trial = row["cnt"] if row else 0

        total = free + pro + enterprise + trial

        return {
            "free": free,
            "pro": pro,
            "enterprise": enterprise,
            "total": total,
            "trial": trial,
        }

    # ------------------------------------------------------------------
    # Churn rate
    # ------------------------------------------------------------------

    async def get_churn_rate(self, months: int = 3) -> float:
        """Calculate average monthly churn over the last N months.

        For each month, counts subscriptions that transitioned to
        ``cancelled`` or ``canceled`` status, divided by total active
        subscriptions at the start of that month.  Returns the average
        as a decimal (0.05 = 5%).

        Parameters
        ----------
        months : int
            Number of recent months to average over (default ``3``).

        Returns
        -------
        float
            Average monthly churn rate as a decimal.
        """
        now = datetime.now(timezone.utc)
        churn_rates: list[float] = []

        for i in range(months):
            # Calculate the target month
            target_year = now.year
            target_month = now.month - i
            while target_month <= 0:
                target_month += 12
                target_year -= 1
            month_str = f"{target_year:04d}-{target_month:02d}"

            # Start of month timestamp (epoch)
            month_start = datetime(
                target_year, target_month, 1,
                tzinfo=timezone.utc,
            ).timestamp()

            # End of month timestamp
            next_month = target_month + 1
            next_year = target_year
            if next_month > 12:
                next_month = 1
                next_year += 1
            month_end = datetime(
                next_year, next_month, 1,
                tzinfo=timezone.utc,
            ).timestamp()

            # Active at start of month: created before month_start and
            # not already cancelled before month_start
            row = await self.db.fetchone(
                """
                SELECT COUNT(*) AS cnt FROM subscriptions
                WHERE created_at < ?
                  AND status NOT IN ('cancelled', 'canceled', 'deleted')
                  OR (updated_at >= ? AND status IN ('cancelled', 'canceled'))
                """,
                (month_start, month_start),
            )
            active_start = row["cnt"] if row and row["cnt"] else 0

            # Churned during month: status changed to cancelled/canceled
            # with updated_at within the month
            row = await self.db.fetchone(
                """
                SELECT COUNT(*) AS cnt FROM subscriptions
                WHERE status IN ('cancelled', 'canceled')
                  AND updated_at >= ? AND updated_at < ?
                """,
                (month_start, month_end),
            )
            churned = row["cnt"] if row else 0

            if active_start > 0:
                churn_rates.append(churned / active_start)
            else:
                churn_rates.append(0.0)

        if not churn_rates:
            return 0.0

        avg_churn = sum(churn_rates) / len(churn_rates)
        return round(avg_churn, 4)

    # ------------------------------------------------------------------
    # ARR projection
    # ------------------------------------------------------------------

    async def get_projected_arr(self) -> float:
        """Return projected Annual Recurring Revenue (MRR * 12).

        Returns
        -------
        float
            Projected ARR in USD.
        """
        mrr = await self.get_mrr()
        return round(mrr * 12, 2)

    # ------------------------------------------------------------------
    # Top plugins
    # ------------------------------------------------------------------

    async def get_top_plugins(self, limit: int = 10) -> list[dict]:
        """Return top plugins by total revenue from purchases.

        Joins ``plugin_purchases`` with ``plugin_listings`` to get
        plugin names and aggregates revenue.

        Parameters
        ----------
        limit : int
            Maximum number of plugins to return (default ``10``).

        Returns
        -------
        list[dict]
            Each dict has: ``plugin_id``, ``name``, ``total_revenue``,
            ``purchase_count``.
        """
        rows = await self.db.fetchall(
            """
            SELECT
                pp.plugin_id,
                COALESCE(pl.name, pp.plugin_id) AS name,
                SUM(pp.price_paid) AS total_revenue,
                COUNT(*) AS purchase_count
            FROM plugin_purchases pp
            LEFT JOIN plugin_listings pl ON pp.plugin_id = pl.plugin_id
            WHERE pp.price_paid > 0
            GROUP BY pp.plugin_id
            ORDER BY total_revenue DESC
            LIMIT ?
            """,
            (limit,),
        )

        result: list[dict] = []
        for row in rows:
            result.append({
                "plugin_id": row["plugin_id"],
                "name": row["name"],
                "total_revenue": round(row["total_revenue"], 2),
                "purchase_count": row["purchase_count"],
            })
        return result

    # ------------------------------------------------------------------
    # Master summary
    # ------------------------------------------------------------------

    async def get_revenue_summary(self) -> dict:
        """Produce the master revenue summary combining all metrics.

        Returns
        -------
        dict
            Comprehensive revenue data including MRR, ARR, subscriber
            counts, monthly breakdown, churn rate, top plugins,
            NeoSafe address, and per-stream historical totals.
        """
        current_month = datetime.now(timezone.utc).strftime("%Y-%m")

        # Compute previous month string for comparison
        now = datetime.now(timezone.utc)
        prev_month_num = now.month - 1
        prev_year = now.year
        if prev_month_num <= 0:
            prev_month_num += 12
            prev_year -= 1
        prev_month = f"{prev_year:04d}-{prev_month_num:02d}"

        # Gather all metrics concurrently-safe (sequential for SQLite)
        mrr = await self.get_mrr()
        arr_projected = await self.get_projected_arr()
        subscriber_counts = await self.get_subscriber_counts()
        monthly_breakdown = await self.get_monthly_breakdown(current_month)
        prev_breakdown = await self.get_monthly_breakdown(prev_month)
        churn_rate = await self.get_churn_rate()
        top_plugins = await self.get_top_plugins()

        # Per-stream all-time totals
        rows = await self.db.fetchall(
            """
            SELECT stream, COALESCE(SUM(amount_usd), 0) AS total
            FROM revenue_events
            GROUP BY stream
            ORDER BY total DESC
            """,
        )
        streams: list[dict] = []
        for row in rows:
            streams.append({
                "stream": row["stream"],
                "all_time_total": round(row["total"], 2),
            })

        # Referral program stats
        referral_stats = await self._get_referral_stats()

        return {
            "mrr": mrr,
            "arr_projected": arr_projected,
            "subscriber_counts": subscriber_counts,
            "monthly_breakdown": monthly_breakdown,
            "prev_monthly_breakdown": prev_breakdown,
            "churn_rate": churn_rate,
            "top_plugins": top_plugins,
            "neosafe_address": NEOSAFE_ADDRESS,
            "streams": streams,
            "referral_stats": referral_stats,
            "generated_at": time.time(),
            "generated_month": current_month,
        }

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    async def _get_referral_stats(self) -> dict:
        """Gather referral program statistics.

        Returns
        -------
        dict
            Keys: ``total_referrals``, ``credited_months``,
            ``pending_conversions``.
        """
        # Total referral events
        row = await self.db.fetchone(
            """
            SELECT COUNT(*) AS cnt FROM referral_events
            """,
        )
        total_referrals = row["cnt"] if row else 0

        # Total credited months
        row = await self.db.fetchone(
            """
            SELECT COALESCE(SUM(credit_months), 0) AS total
            FROM referral_events
            WHERE status = 'credited'
            """,
        )
        credited_months = row["total"] if row else 0

        # Pending conversions
        row = await self.db.fetchone(
            """
            SELECT COUNT(*) AS cnt FROM referral_events
            WHERE status = 'pending'
            """,
        )
        pending_conversions = row["cnt"] if row else 0

        return {
            "total_referrals": total_referrals,
            "credited_months": credited_months,
            "pending_conversions": pending_conversions,
        }
