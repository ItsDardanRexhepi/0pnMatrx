"""Usage tracking for subscription-gated features.

Records per-wallet usage events in SQLite and provides monthly
aggregation for the FeatureGate to check limits against.
"""

from __future__ import annotations

import logging
import time
from datetime import datetime, timezone

logger = logging.getLogger(__name__)


class UsageTracker:
    """Tracks feature usage per wallet address per billing month.

    Backed by the platform's existing SQLite ``Database`` class.
    The ``usage_events`` table is created via a migration added to
    ``runtime.db.database.MIGRATIONS``.
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
        """Create the usage_events table if it does not exist."""
        await self.db.execute(
            """
            CREATE TABLE IF NOT EXISTS usage_events (
                id              INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id      TEXT,
                wallet_address  TEXT,
                action          TEXT NOT NULL,
                value           REAL NOT NULL DEFAULT 1.0,
                month           TEXT NOT NULL,
                created_at      REAL NOT NULL
            )
            """,
            commit=True,
        )
        await self.db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_usage_wallet_action_month
            ON usage_events (wallet_address, action, month)
            """,
            commit=True,
        )

    async def record(
        self,
        session_id: str,
        wallet_address: str,
        action: str,
        value: float = 1.0,
    ) -> None:
        """Record a usage event.

        Parameters
        ----------
        session_id : str
            The current session identifier.
        wallet_address : str
            The wallet address associated with the usage. May be empty
            for unauthenticated users (keyed by session instead).
        action : str
            The feature/action name (e.g. ``contract_conversions_per_month``).
        value : float
            The numeric value of this usage event (default ``1.0``).
        """
        month = datetime.now(timezone.utc).strftime("%Y-%m")
        now = time.time()
        await self.db.execute(
            """
            INSERT INTO usage_events (session_id, wallet_address, action, value, month, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (session_id, wallet_address, action, value, month, now),
            commit=True,
        )

    async def get_monthly_total(
        self,
        wallet_address: str,
        action: str,
        month: str | None = None,
    ) -> float:
        """Return the total usage for a wallet + action in a given month.

        Parameters
        ----------
        wallet_address : str
            The wallet to query.
        action : str
            The feature/action name.
        month : str, optional
            Month in ``YYYY-MM`` format. Defaults to the current month.

        Returns
        -------
        float
            Sum of all ``value`` entries for this wallet+action+month.
        """
        if month is None:
            month = datetime.now(timezone.utc).strftime("%Y-%m")
        row = await self.db.fetchone(
            """
            SELECT COALESCE(SUM(value), 0) AS total
            FROM usage_events
            WHERE wallet_address = ? AND action = ? AND month = ?
            """,
            (wallet_address, action, month),
        )
        return float(row["total"]) if row else 0.0

    async def get_summary(
        self,
        wallet_address: str,
        month: str | None = None,
    ) -> dict[str, float]:
        """Return all action totals for a wallet in a given month.

        Parameters
        ----------
        wallet_address : str
            The wallet to query.
        month : str, optional
            Month in ``YYYY-MM`` format. Defaults to the current month.

        Returns
        -------
        dict[str, float]
            Mapping of action name to total usage value.
        """
        if month is None:
            month = datetime.now(timezone.utc).strftime("%Y-%m")
        rows = await self.db.fetchall(
            """
            SELECT action, COALESCE(SUM(value), 0) AS total
            FROM usage_events
            WHERE wallet_address = ? AND month = ?
            GROUP BY action
            """,
            (wallet_address, month),
        )
        return {row["action"]: float(row["total"]) for row in rows}
