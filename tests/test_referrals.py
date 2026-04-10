"""Tests for the referral program module."""

import asyncio
import sqlite3
import time

import pytest

from runtime.referrals.referral_manager import ReferralManager


# -- Helpers ---------------------------------------------------------------


class FakeDB:
    """Minimal async SQLite wrapper matching Database interface."""

    def __init__(self, db_path=":memory:"):
        self.conn = sqlite3.connect(db_path)
        self.conn.row_factory = sqlite3.Row

    async def execute(self, sql, params=(), commit=True):
        self.conn.execute(sql, params)
        if commit:
            self.conn.commit()

    async def fetchall(self, sql, params=()):
        return self.conn.execute(sql, params).fetchall()

    async def fetchone(self, sql, params=()):
        return self.conn.execute(sql, params).fetchone()


@pytest.fixture
def fake_db():
    """Provide a fresh in-memory SQLite database."""
    db = FakeDB()
    # The subscriptions table must exist because grant_credit reads/writes it.
    db.conn.execute(
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
        """
    )
    db.conn.commit()
    return db


@pytest.fixture
def manager(fake_db):
    """Provide an initialised ReferralManager."""
    mgr = ReferralManager(fake_db)
    asyncio.run(mgr.initialize())
    return mgr


# -- Code Generation Tests ------------------------------------------------


class TestCodeGeneration:
    """Tests for referral code generation."""

    @pytest.mark.asyncio
    async def test_generates_8_char_code(self, manager):
        code = await manager.generate_code("0xAlice")
        assert len(code) == 8
        assert code == code.upper()
        assert code.isalnum() or "-" in code or "_" in code

    @pytest.mark.asyncio
    async def test_code_is_idempotent(self, manager):
        code1 = await manager.generate_code("0xAlice")
        code2 = await manager.generate_code("0xAlice")
        assert code1 == code2

    @pytest.mark.asyncio
    async def test_different_wallets_get_different_codes(self, manager):
        code_a = await manager.generate_code("0xAlice")
        code_b = await manager.generate_code("0xBob")
        assert code_a != code_b

    @pytest.mark.asyncio
    async def test_get_code_returns_none_for_unknown(self, manager):
        result = await manager.get_code("0xNobody")
        assert result is None

    @pytest.mark.asyncio
    async def test_get_code_returns_existing(self, manager):
        generated = await manager.generate_code("0xAlice")
        fetched = await manager.get_code("0xAlice")
        assert fetched == generated


# -- Code Validation Tests ------------------------------------------------


class TestCodeValidation:
    """Tests for referral code validation."""

    @pytest.mark.asyncio
    async def test_validate_existing_code(self, manager):
        code = await manager.generate_code("0xAlice")
        info = await manager.validate_code(code)
        assert info is not None
        assert info["code"] == code
        assert info["wallet_address"] == "0xAlice"
        assert info["uses"] == 0

    @pytest.mark.asyncio
    async def test_validate_nonexistent_code(self, manager):
        info = await manager.validate_code("FAKECODE")
        assert info is None


# -- Referral Application Tests --------------------------------------------


class TestApplyReferral:
    """Tests for applying referral codes."""

    @pytest.mark.asyncio
    async def test_apply_referral_success(self, manager):
        code = await manager.generate_code("0xAlice")
        result = await manager.apply_referral(code, "0xBob", "pro")
        assert result["valid"] is True
        assert result["referrer_wallet"] == "0xAlice"
        assert result["credit_applied"] == "pending trial conversion"

    @pytest.mark.asyncio
    async def test_apply_referral_increments_uses(self, manager):
        code = await manager.generate_code("0xAlice")
        await manager.apply_referral(code, "0xBob", "pro")
        info = await manager.validate_code(code)
        assert info["uses"] == 1

    @pytest.mark.asyncio
    async def test_self_referral_rejected(self, manager):
        code = await manager.generate_code("0xAlice")
        result = await manager.apply_referral(code, "0xAlice", "pro")
        assert result["valid"] is False
        assert "self-referral" in result["reason"]

    @pytest.mark.asyncio
    async def test_duplicate_referred_wallet_rejected(self, manager):
        code = await manager.generate_code("0xAlice")
        await manager.apply_referral(code, "0xBob", "pro")
        result = await manager.apply_referral(code, "0xBob", "pro")
        assert result["valid"] is False
        assert "already referred" in result["reason"]

    @pytest.mark.asyncio
    async def test_invalid_code_rejected(self, manager):
        result = await manager.apply_referral("BADCODE", "0xBob", "pro")
        assert result["valid"] is False
        assert "code not found" in result["reason"]

    @pytest.mark.asyncio
    async def test_multiple_referrals_different_wallets(self, manager):
        code = await manager.generate_code("0xAlice")
        r1 = await manager.apply_referral(code, "0xBob", "pro")
        r2 = await manager.apply_referral(code, "0xCharlie", "enterprise")
        assert r1["valid"] is True
        assert r2["valid"] is True
        info = await manager.validate_code(code)
        assert info["uses"] == 2


# -- Credit Granting Tests ------------------------------------------------


class TestGrantCredit:
    """Tests for subscription credit granting."""

    @pytest.mark.asyncio
    async def test_grant_credit_existing_subscription(self, manager, fake_db):
        now = time.time()
        period_end = now + 86400  # 1 day from now
        await fake_db.execute(
            """
            INSERT INTO subscriptions
                (wallet_address, tier, status, current_period_end,
                 created_at, updated_at)
            VALUES (?, 'pro', 'active', ?, ?, ?)
            """,
            ("0xAlice", period_end, now, now),
            commit=True,
        )

        result = await manager.grant_credit("0xAlice", months=1)
        assert result["credited"] is True
        assert result["months"] == 1
        assert result["wallet"] == "0xAlice"

        row = await fake_db.fetchone(
            "SELECT current_period_end FROM subscriptions WHERE wallet_address = ?",
            ("0xAlice",),
        )
        expected = period_end + (1 * 30 * 86400)
        assert abs(row["current_period_end"] - expected) < 1.0

    @pytest.mark.asyncio
    async def test_grant_credit_no_existing_subscription(self, manager, fake_db):
        before = time.time()
        result = await manager.grant_credit("0xNewUser", months=2)
        assert result["credited"] is True
        assert result["months"] == 2

        row = await fake_db.fetchone(
            "SELECT * FROM subscriptions WHERE wallet_address = ?",
            ("0xNewUser",),
        )
        assert row is not None
        assert row["tier"] == "free"
        assert row["status"] == "active"
        expected_min = before + (2 * 30 * 86400)
        assert row["current_period_end"] >= expected_min

    @pytest.mark.asyncio
    async def test_grant_credit_multiple_months(self, manager, fake_db):
        now = time.time()
        period_end = now + 86400
        await fake_db.execute(
            """
            INSERT INTO subscriptions
                (wallet_address, tier, status, current_period_end,
                 created_at, updated_at)
            VALUES (?, 'enterprise', 'active', ?, ?, ?)
            """,
            ("0xAlice", period_end, now, now),
            commit=True,
        )

        await manager.grant_credit("0xAlice", months=3)

        row = await fake_db.fetchone(
            "SELECT current_period_end FROM subscriptions WHERE wallet_address = ?",
            ("0xAlice",),
        )
        expected = period_end + (3 * 30 * 86400)
        assert abs(row["current_period_end"] - expected) < 1.0


# -- Conversion Processing Tests ------------------------------------------


class TestProcessConversion:
    """Tests for trial-to-paid conversion processing."""

    @pytest.mark.asyncio
    async def test_process_pro_conversion(self, manager, fake_db):
        now = time.time()
        # Set up referrer subscription.
        await fake_db.execute(
            """
            INSERT INTO subscriptions
                (wallet_address, tier, status, current_period_end,
                 created_at, updated_at)
            VALUES (?, 'pro', 'active', ?, ?, ?)
            """,
            ("0xAlice", now + 86400, now, now),
            commit=True,
        )

        code = await manager.generate_code("0xAlice")
        await manager.apply_referral(code, "0xBob", "pro")

        result = await manager.process_conversion("0xBob")
        assert result["processed"] is True
        assert result["referrer_credited"] == 1  # default pro_credit_months
        assert result["referrer_wallet"] == "0xAlice"

    @pytest.mark.asyncio
    async def test_process_enterprise_conversion(self, manager, fake_db):
        now = time.time()
        await fake_db.execute(
            """
            INSERT INTO subscriptions
                (wallet_address, tier, status, current_period_end,
                 created_at, updated_at)
            VALUES (?, 'enterprise', 'active', ?, ?, ?)
            """,
            ("0xAlice", now + 86400, now, now),
            commit=True,
        )

        code = await manager.generate_code("0xAlice")
        await manager.apply_referral(code, "0xBob", "enterprise")

        result = await manager.process_conversion("0xBob")
        assert result["processed"] is True
        assert result["referrer_credited"] == 2  # default enterprise_credit_months

    @pytest.mark.asyncio
    async def test_process_conversion_no_pending(self, manager):
        result = await manager.process_conversion("0xNobody")
        assert result["processed"] is False
        assert "no pending referral" in result["reason"]

    @pytest.mark.asyncio
    async def test_conversion_updates_event_status(self, manager, fake_db):
        now = time.time()
        await fake_db.execute(
            """
            INSERT INTO subscriptions
                (wallet_address, tier, status, current_period_end,
                 created_at, updated_at)
            VALUES (?, 'pro', 'active', ?, ?, ?)
            """,
            ("0xAlice", now + 86400, now, now),
            commit=True,
        )

        code = await manager.generate_code("0xAlice")
        await manager.apply_referral(code, "0xBob", "pro")
        await manager.process_conversion("0xBob")

        row = await fake_db.fetchone(
            "SELECT status, credited_at, credit_months FROM referral_events WHERE referred_wallet = ?",
            ("0xBob",),
        )
        assert row["status"] == "credited"
        assert row["credited_at"] is not None
        assert row["credit_months"] == 1

    @pytest.mark.asyncio
    async def test_double_conversion_ignored(self, manager, fake_db):
        now = time.time()
        await fake_db.execute(
            """
            INSERT INTO subscriptions
                (wallet_address, tier, status, current_period_end,
                 created_at, updated_at)
            VALUES (?, 'pro', 'active', ?, ?, ?)
            """,
            ("0xAlice", now + 86400, now, now),
            commit=True,
        )

        code = await manager.generate_code("0xAlice")
        await manager.apply_referral(code, "0xBob", "pro")
        await manager.process_conversion("0xBob")

        # Second conversion should find no pending event.
        result = await manager.process_conversion("0xBob")
        assert result["processed"] is False

    @pytest.mark.asyncio
    async def test_custom_credit_months_config(self, fake_db):
        config = {
            "referrals": {
                "pro_referral_months": 3,
                "enterprise_referral_months": 6,
            }
        }
        mgr = ReferralManager(fake_db, config=config)
        await mgr.initialize()

        now = time.time()
        await fake_db.execute(
            """
            INSERT INTO subscriptions
                (wallet_address, tier, status, current_period_end,
                 created_at, updated_at)
            VALUES (?, 'pro', 'active', ?, ?, ?)
            """,
            ("0xAlice", now + 86400, now, now),
            commit=True,
        )

        code = await mgr.generate_code("0xAlice")
        await mgr.apply_referral(code, "0xBob", "pro")
        result = await mgr.process_conversion("0xBob")
        assert result["referrer_credited"] == 3


# -- Referral Stats Tests --------------------------------------------------


class TestReferralStats:
    """Tests for referral statistics retrieval."""

    @pytest.mark.asyncio
    async def test_stats_empty(self, manager):
        stats = await manager.get_referral_stats("0xAlice")
        assert stats["total_referrals"] == 0
        assert stats["credited_referrals"] == 0
        assert stats["total_months_earned"] == 0
        assert stats["pending_referrals"] == 0
        assert stats["referral_code"] is None

    @pytest.mark.asyncio
    async def test_stats_with_code(self, manager):
        await manager.generate_code("0xAlice")
        stats = await manager.get_referral_stats("0xAlice")
        assert stats["referral_code"] is not None

    @pytest.mark.asyncio
    async def test_stats_with_pending_referrals(self, manager):
        code = await manager.generate_code("0xAlice")
        await manager.apply_referral(code, "0xBob", "pro")
        await manager.apply_referral(code, "0xCharlie", "pro")

        stats = await manager.get_referral_stats("0xAlice")
        assert stats["total_referrals"] == 2
        assert stats["pending_referrals"] == 2
        assert stats["credited_referrals"] == 0
        assert stats["total_months_earned"] == 0

    @pytest.mark.asyncio
    async def test_stats_with_credited_referrals(self, manager, fake_db):
        now = time.time()
        await fake_db.execute(
            """
            INSERT INTO subscriptions
                (wallet_address, tier, status, current_period_end,
                 created_at, updated_at)
            VALUES (?, 'pro', 'active', ?, ?, ?)
            """,
            ("0xAlice", now + 86400, now, now),
            commit=True,
        )

        code = await manager.generate_code("0xAlice")
        await manager.apply_referral(code, "0xBob", "pro")
        await manager.apply_referral(code, "0xCharlie", "enterprise")
        await manager.process_conversion("0xBob")

        stats = await manager.get_referral_stats("0xAlice")
        assert stats["total_referrals"] == 2
        assert stats["credited_referrals"] == 1
        assert stats["total_months_earned"] == 1  # pro = 1 month
        assert stats["pending_referrals"] == 1

    @pytest.mark.asyncio
    async def test_stats_referred_wallet_not_counted(self, manager):
        """Stats for the referred wallet should not show referrer stats."""
        code = await manager.generate_code("0xAlice")
        await manager.apply_referral(code, "0xBob", "pro")

        stats = await manager.get_referral_stats("0xBob")
        assert stats["total_referrals"] == 0
        assert stats["referral_code"] is None
