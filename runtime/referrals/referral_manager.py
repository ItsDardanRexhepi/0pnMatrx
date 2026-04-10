"""Referral manager backed by SQLite.

Generates unique referral codes, tracks referral events, and grants
subscription credits to both referrers and referred users when
trials convert to paid tiers.
"""

from __future__ import annotations

import logging
import secrets
import time
import uuid

logger = logging.getLogger(__name__)


class ReferralManager:
    """Referral system backed by SQLite.

    Generates unique referral codes, tracks referral events, and
    grants subscription credits to both referrers and referred users.
    """

    def __init__(self, db, config: dict | None = None):
        """Initialise with a ``Database`` instance.

        Parameters
        ----------
        db : runtime.db.database.Database
            The platform's shared SQLite wrapper.
        config : dict, optional
            Platform configuration dict. Reads from the ``referrals``
            sub-key for credit month overrides.
        """
        self.db = db
        self.config = config or {}
        referral_cfg = self.config.get("referrals", {})
        self.pro_credit_months = int(referral_cfg.get("pro_referral_months", 1))
        self.enterprise_credit_months = int(
            referral_cfg.get("enterprise_referral_months", 2)
        )

    async def initialize(self) -> None:
        """Create the referral tables if they do not exist."""
        await self.db.execute(
            """
            CREATE TABLE IF NOT EXISTS referral_codes (
                code            TEXT PRIMARY KEY,
                wallet_address  TEXT NOT NULL,
                created_at      REAL NOT NULL,
                uses            INT DEFAULT 0
            )
            """,
            commit=True,
        )
        await self.db.execute(
            """
            CREATE TABLE IF NOT EXISTS referral_events (
                id              TEXT PRIMARY KEY,
                referrer_wallet TEXT NOT NULL,
                referred_wallet TEXT NOT NULL,
                tier            TEXT NOT NULL,
                credited_at     REAL,
                credit_months   INT DEFAULT 0,
                status          TEXT DEFAULT 'pending'
            )
            """,
            commit=True,
        )

    async def generate_code(self, wallet_address: str) -> str:
        """Generate a unique 8-character referral code for a wallet.

        If the wallet already has a code, return the existing one
        rather than creating a duplicate.

        Parameters
        ----------
        wallet_address : str
            The wallet to generate a code for.

        Returns
        -------
        str
            The 8-character alphanumeric referral code.
        """
        existing = await self.get_code(wallet_address)
        if existing:
            return existing

        code = secrets.token_urlsafe(6)[:8].upper()

        # Guard against the astronomically unlikely collision.
        while True:
            collision = await self.db.fetchone(
                "SELECT code FROM referral_codes WHERE code = ?",
                (code,),
            )
            if not collision:
                break
            code = secrets.token_urlsafe(6)[:8].upper()

        now = time.time()
        await self.db.execute(
            """
            INSERT INTO referral_codes (code, wallet_address, created_at, uses)
            VALUES (?, ?, ?, 0)
            """,
            (code, wallet_address, now),
            commit=True,
        )
        logger.info("Generated referral code %s for %s", code, wallet_address)
        return code

    async def get_code(self, wallet_address: str) -> str | None:
        """Look up the existing referral code for a wallet.

        Parameters
        ----------
        wallet_address : str
            The wallet to look up.

        Returns
        -------
        str or None
            The referral code, or ``None`` if the wallet has none.
        """
        row = await self.db.fetchone(
            "SELECT code FROM referral_codes WHERE wallet_address = ?",
            (wallet_address,),
        )
        if not row:
            return None
        return row["code"]

    async def validate_code(self, code: str) -> dict | None:
        """Check whether a referral code exists.

        Parameters
        ----------
        code : str
            The referral code to validate.

        Returns
        -------
        dict or None
            ``{"code": "...", "wallet_address": "...", "uses": N}``
            if the code is valid, otherwise ``None``.
        """
        row = await self.db.fetchone(
            "SELECT code, wallet_address, uses FROM referral_codes WHERE code = ?",
            (code,),
        )
        if not row:
            return None
        return {
            "code": row["code"],
            "wallet_address": row["wallet_address"],
            "uses": row["uses"],
        }

    async def apply_referral(
        self, referral_code: str, new_wallet_address: str, tier: str
    ) -> dict:
        """Record a referral event when a new user signs up with a code.

        Validates the code, ensures no self-referral or duplicate
        referred wallet, and creates a pending referral event.

        Parameters
        ----------
        referral_code : str
            The referral code used at signup.
        new_wallet_address : str
            The wallet address of the new user.
        tier : str
            The subscription tier the new user signed up for.

        Returns
        -------
        dict
            ``{"valid": True, ...}`` on success or
            ``{"valid": False, "reason": "..."}`` on failure.
        """
        code_info = await self.validate_code(referral_code)
        if not code_info:
            return {"valid": False, "reason": "code not found"}

        referrer_wallet = code_info["wallet_address"]

        if referrer_wallet == new_wallet_address:
            return {"valid": False, "reason": "self-referral not allowed"}

        existing = await self.db.fetchone(
            "SELECT id FROM referral_events WHERE referred_wallet = ?",
            (new_wallet_address,),
        )
        if existing:
            return {"valid": False, "reason": "wallet already referred"}

        event_id = str(uuid.uuid4())
        await self.db.execute(
            """
            INSERT INTO referral_events
                (id, referrer_wallet, referred_wallet, tier, status)
            VALUES (?, ?, ?, ?, 'pending')
            """,
            (event_id, referrer_wallet, new_wallet_address, tier),
            commit=True,
        )

        await self.db.execute(
            "UPDATE referral_codes SET uses = uses + 1 WHERE code = ?",
            (referral_code,),
            commit=True,
        )

        logger.info(
            "Referral applied: %s referred %s (tier=%s)",
            referrer_wallet,
            new_wallet_address,
            tier,
        )
        return {
            "valid": True,
            "referrer_wallet": referrer_wallet,
            "credit_applied": "pending trial conversion",
        }

    async def grant_credit(self, wallet_address: str, months: int = 1) -> dict:
        """Extend a wallet's subscription by the given number of months.

        Each month is treated as 30 days (30 * 86400 seconds).  If the
        wallet has no subscription row yet, one is inserted with tier
        ``free`` and a ``current_period_end`` set to *now + credit*.

        Parameters
        ----------
        wallet_address : str
            The wallet to credit.
        months : int
            Number of months to add (default 1).

        Returns
        -------
        dict
            ``{"credited": True, "months": N, "wallet": "0x..."}``
        """
        credit_seconds = months * 30 * 86400

        existing = await self.db.fetchone(
            "SELECT wallet_address FROM subscriptions WHERE wallet_address = ?",
            (wallet_address,),
        )

        if existing:
            await self.db.execute(
                """
                UPDATE subscriptions
                SET current_period_end = current_period_end + ?
                WHERE wallet_address = ?
                """,
                (credit_seconds, wallet_address),
                commit=True,
            )
        else:
            now = time.time()
            await self.db.execute(
                """
                INSERT INTO subscriptions
                    (wallet_address, tier, status,
                     current_period_end, created_at, updated_at)
                VALUES (?, 'free', 'active', ?, ?, ?)
                """,
                (wallet_address, now + credit_seconds, now, now),
                commit=True,
            )

        logger.info(
            "Granted %d month(s) credit to %s", months, wallet_address
        )
        return {"credited": True, "months": months, "wallet": wallet_address}

    async def process_conversion(self, referred_wallet: str) -> dict:
        """Process a trial-to-paid conversion for a referred user.

        Called by the Stripe webhook when a referred user's trial
        converts to a paid subscription.  Looks up the pending
        referral event, determines the credit amount based on tier,
        grants credit to the *referrer*, and marks the event as
        ``credited``.

        Parameters
        ----------
        referred_wallet : str
            The wallet address of the user whose trial converted.

        Returns
        -------
        dict
            ``{"processed": True, "referrer_credited": N, "referrer_wallet": "0x..."}``
            on success, or ``{"processed": False, "reason": "..."}`` if
            no pending referral exists.
        """
        row = await self.db.fetchone(
            """
            SELECT id, referrer_wallet, tier
            FROM referral_events
            WHERE referred_wallet = ? AND status = 'pending'
            """,
            (referred_wallet,),
        )
        if not row:
            return {"processed": False, "reason": "no pending referral found"}

        event_id = row["id"]
        referrer_wallet = row["referrer_wallet"]
        tier = row["tier"]

        if tier == "enterprise":
            months = self.enterprise_credit_months
        else:
            months = self.pro_credit_months

        await self.grant_credit(referrer_wallet, months)

        now = time.time()
        await self.db.execute(
            """
            UPDATE referral_events
            SET status = 'credited', credited_at = ?, credit_months = ?
            WHERE id = ?
            """,
            (now, months, event_id),
            commit=True,
        )

        logger.info(
            "Conversion processed: referrer %s credited %d month(s) "
            "(referred %s, tier=%s)",
            referrer_wallet,
            months,
            referred_wallet,
            tier,
        )
        return {
            "processed": True,
            "referrer_credited": months,
            "referrer_wallet": referrer_wallet,
        }

    async def get_referral_stats(self, wallet_address: str) -> dict:
        """Return referral statistics for a wallet.

        Parameters
        ----------
        wallet_address : str
            The wallet to query stats for.

        Returns
        -------
        dict
            Contains ``total_referrals``, ``credited_referrals``,
            ``total_months_earned``, ``pending_referrals``, and
            ``referral_code``.
        """
        total_row = await self.db.fetchone(
            """
            SELECT COUNT(*) AS cnt
            FROM referral_events
            WHERE referrer_wallet = ?
            """,
            (wallet_address,),
        )
        total_referrals = total_row["cnt"] if total_row else 0

        credited_row = await self.db.fetchone(
            """
            SELECT COUNT(*) AS cnt
            FROM referral_events
            WHERE referrer_wallet = ? AND status = 'credited'
            """,
            (wallet_address,),
        )
        credited_referrals = credited_row["cnt"] if credited_row else 0

        months_row = await self.db.fetchone(
            """
            SELECT COALESCE(SUM(credit_months), 0) AS total
            FROM referral_events
            WHERE referrer_wallet = ? AND status = 'credited'
            """,
            (wallet_address,),
        )
        total_months_earned = months_row["total"] if months_row else 0

        pending_row = await self.db.fetchone(
            """
            SELECT COUNT(*) AS cnt
            FROM referral_events
            WHERE referrer_wallet = ? AND status = 'pending'
            """,
            (wallet_address,),
        )
        pending_referrals = pending_row["cnt"] if pending_row else 0

        referral_code = await self.get_code(wallet_address)

        return {
            "total_referrals": total_referrals,
            "credited_referrals": credited_referrals,
            "total_months_earned": total_months_earned,
            "pending_referrals": pending_referrals,
            "referral_code": referral_code,
        }
