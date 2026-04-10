"""Tests for the subscription tier system, feature gate, and usage tracking."""

import asyncio
import sqlite3
import time
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from runtime.subscriptions.tiers import (
    SubscriptionTier,
    TIER_LIMITS,
    TIER_PRICES,
    get_limit,
    is_unlimited,
)
from runtime.subscriptions.usage_tracker import UsageTracker
from runtime.subscriptions.feature_gate import FeatureGate, ACTION_GATE_MAP
from runtime.subscriptions.subscription_store import SubscriptionStore
from runtime.subscriptions.stripe_client import StripeClient


# ── Helpers ──────────────────────────────────────────────────────────


class FakeDB:
    """Minimal async SQLite wrapper matching Database interface."""

    def __init__(self, db_path=":memory:"):
        self.conn = sqlite3.connect(db_path)
        self.conn.row_factory = sqlite3.Row

    async def execute(self, sql, params=(), commit=True):
        self.conn.execute(sql, params)
        if commit:
            self.conn.commit()

    async def executemany(self, sql, seq):
        self.conn.executemany(sql, seq)
        self.conn.commit()

    async def fetchall(self, sql, params=()):
        return self.conn.execute(sql, params).fetchall()

    async def fetchone(self, sql, params=()):
        return self.conn.execute(sql, params).fetchone()


@pytest.fixture
def fake_db():
    """Provide a fresh in-memory SQLite database."""
    return FakeDB()


@pytest.fixture
def usage_tracker(fake_db):
    """Provide an initialised UsageTracker."""
    tracker = UsageTracker(fake_db)
    asyncio.get_event_loop().run_until_complete(tracker.initialize())
    return tracker


@pytest.fixture
def feature_gate(fake_db, usage_tracker):
    """Provide an initialised FeatureGate."""
    return FeatureGate({}, usage_tracker)


@pytest.fixture
def sub_store(fake_db):
    """Provide an initialised SubscriptionStore."""
    store = SubscriptionStore(fake_db)
    asyncio.get_event_loop().run_until_complete(store.initialize())
    return store


# ── Tier Tests ───────────────────────────────────────────────────────


class TestSubscriptionTier:
    """Tests for the SubscriptionTier enum and limits."""

    def test_tier_values(self):
        assert SubscriptionTier.FREE.value == "free"
        assert SubscriptionTier.PRO.value == "pro"
        assert SubscriptionTier.ENTERPRISE.value == "enterprise"

    def test_from_str_valid(self):
        assert SubscriptionTier.from_str("free") == SubscriptionTier.FREE
        assert SubscriptionTier.from_str("PRO") == SubscriptionTier.PRO
        assert SubscriptionTier.from_str("Enterprise") == SubscriptionTier.ENTERPRISE

    def test_from_str_unknown_defaults_to_free(self):
        assert SubscriptionTier.from_str("unknown") == SubscriptionTier.FREE
        assert SubscriptionTier.from_str("") == SubscriptionTier.FREE

    def test_tier_prices(self):
        assert TIER_PRICES[SubscriptionTier.FREE] == 0.00
        assert TIER_PRICES[SubscriptionTier.PRO] == 4.99
        assert TIER_PRICES[SubscriptionTier.ENTERPRISE] == 19.99

    def test_all_tiers_have_limits(self):
        for tier in SubscriptionTier:
            assert tier in TIER_LIMITS
            assert len(TIER_LIMITS[tier]) > 0

    def test_get_limit_returns_int_for_counts(self):
        limit = get_limit(SubscriptionTier.FREE, "contract_conversions_per_month")
        assert isinstance(limit, int)
        assert limit == 5

    def test_get_limit_returns_bool_for_features(self):
        limit = get_limit(SubscriptionTier.FREE, "dashboard_export")
        assert isinstance(limit, bool)
        assert limit is False

    def test_get_limit_unknown_feature_raises(self):
        with pytest.raises(KeyError):
            get_limit(SubscriptionTier.FREE, "nonexistent_feature")

    def test_is_unlimited_enterprise(self):
        assert is_unlimited(SubscriptionTier.ENTERPRISE, "contract_conversions_per_month")
        assert is_unlimited(SubscriptionTier.ENTERPRISE, "nft_mints_per_month")

    def test_is_unlimited_free_false(self):
        assert not is_unlimited(SubscriptionTier.FREE, "contract_conversions_per_month")
        assert not is_unlimited(SubscriptionTier.FREE, "nft_mints_per_month")

    def test_enterprise_has_all_boolean_features(self):
        enterprise = TIER_LIMITS[SubscriptionTier.ENTERPRISE]
        for key, value in enterprise.items():
            if isinstance(value, bool):
                assert value is True, f"Enterprise should have {key} enabled"

    def test_free_tier_has_reasonable_limits(self):
        free = TIER_LIMITS[SubscriptionTier.FREE]
        assert free["contract_conversions_per_month"] > 0
        assert free["nft_mints_per_month"] > 0
        assert free["loan_volume_usd_per_month"] > 0

    def test_pro_limits_higher_than_free(self):
        for key in TIER_LIMITS[SubscriptionTier.FREE]:
            free_val = TIER_LIMITS[SubscriptionTier.FREE][key]
            pro_val = TIER_LIMITS[SubscriptionTier.PRO][key]
            if isinstance(free_val, int) and isinstance(pro_val, int):
                assert pro_val >= free_val, f"Pro {key} should be >= Free"


# ── Usage Tracker Tests ──────────────────────────────────────────────


class TestUsageTracker:
    """Tests for UsageTracker."""

    @pytest.mark.asyncio
    async def test_record_and_get_total(self, usage_tracker):
        await usage_tracker.record("sess1", "0xabc", "contract_conversions_per_month", 1.0)
        await usage_tracker.record("sess1", "0xabc", "contract_conversions_per_month", 1.0)
        total = await usage_tracker.get_monthly_total("0xabc", "contract_conversions_per_month")
        assert total == 2.0

    @pytest.mark.asyncio
    async def test_different_wallets_isolated(self, usage_tracker):
        await usage_tracker.record("s1", "0xaaa", "nft_mints_per_month", 1.0)
        await usage_tracker.record("s1", "0xbbb", "nft_mints_per_month", 3.0)
        assert await usage_tracker.get_monthly_total("0xaaa", "nft_mints_per_month") == 1.0
        assert await usage_tracker.get_monthly_total("0xbbb", "nft_mints_per_month") == 3.0

    @pytest.mark.asyncio
    async def test_different_actions_isolated(self, usage_tracker):
        await usage_tracker.record("s1", "0xabc", "contract_conversions_per_month", 2.0)
        await usage_tracker.record("s1", "0xabc", "nft_mints_per_month", 5.0)
        assert await usage_tracker.get_monthly_total("0xabc", "contract_conversions_per_month") == 2.0
        assert await usage_tracker.get_monthly_total("0xabc", "nft_mints_per_month") == 5.0

    @pytest.mark.asyncio
    async def test_get_summary(self, usage_tracker):
        await usage_tracker.record("s1", "0xabc", "contract_conversions_per_month", 3.0)
        await usage_tracker.record("s1", "0xabc", "nft_mints_per_month", 1.0)
        summary = await usage_tracker.get_summary("0xabc")
        assert summary["contract_conversions_per_month"] == 3.0
        assert summary["nft_mints_per_month"] == 1.0

    @pytest.mark.asyncio
    async def test_empty_wallet_returns_zero(self, usage_tracker):
        total = await usage_tracker.get_monthly_total("0xnonexistent", "nft_mints_per_month")
        assert total == 0.0

    @pytest.mark.asyncio
    async def test_empty_summary(self, usage_tracker):
        summary = await usage_tracker.get_summary("0xnew")
        assert summary == {}

    @pytest.mark.asyncio
    async def test_different_months_isolated(self, usage_tracker):
        await usage_tracker.record("s1", "0xabc", "nft_mints_per_month", 5.0)
        total_this_month = await usage_tracker.get_monthly_total("0xabc", "nft_mints_per_month")
        total_old = await usage_tracker.get_monthly_total("0xabc", "nft_mints_per_month", "2020-01")
        assert total_this_month == 5.0
        assert total_old == 0.0


# ── Feature Gate Tests ───────────────────────────────────────────────


class TestFeatureGate:
    """Tests for the FeatureGate."""

    @pytest.mark.asyncio
    async def test_ungated_action_always_allowed(self, feature_gate):
        result = await feature_gate.check("0xabc", SubscriptionTier.FREE, "some_random_action")
        assert result["allowed"] is True

    @pytest.mark.asyncio
    async def test_free_tier_allows_within_limit(self, feature_gate):
        result = await feature_gate.check("0xabc", SubscriptionTier.FREE, "convert_contract")
        assert result["allowed"] is True
        assert result["limit"] == 5

    @pytest.mark.asyncio
    async def test_free_tier_blocks_at_limit(self, feature_gate):
        # Use up all 5 conversions
        for _ in range(5):
            await feature_gate.check("0xabc", SubscriptionTier.FREE, "convert_contract")
        # 6th should be blocked
        result = await feature_gate.check("0xabc", SubscriptionTier.FREE, "convert_contract")
        assert result["allowed"] is False
        assert result["upgrade_to"] == "pro"
        assert "Pro" in result["upgrade_message"]

    @pytest.mark.asyncio
    async def test_pro_tier_higher_limit(self, feature_gate):
        # Use up Free's limit of 5
        for _ in range(5):
            await feature_gate.check("0xabc", SubscriptionTier.PRO, "convert_contract")
        # Still allowed at Pro
        result = await feature_gate.check("0xabc", SubscriptionTier.PRO, "convert_contract")
        assert result["allowed"] is True

    @pytest.mark.asyncio
    async def test_enterprise_unlimited(self, feature_gate):
        result = await feature_gate.check("0xabc", SubscriptionTier.ENTERPRISE, "convert_contract")
        assert result["allowed"] is True
        assert result["limit"] == -1

    @pytest.mark.asyncio
    async def test_boolean_feature_denied_for_free(self, feature_gate):
        result = await feature_gate.check("0xabc", SubscriptionTier.FREE, "get_dashboard")
        assert result["allowed"] is False
        assert result["upgrade_to"] is not None

    @pytest.mark.asyncio
    async def test_boolean_feature_allowed_for_pro(self, feature_gate):
        result = await feature_gate.check("0xabc", SubscriptionTier.PRO, "get_dashboard")
        assert result["allowed"] is True

    @pytest.mark.asyncio
    async def test_gate_never_raises(self, feature_gate):
        """Gate should return a dict even on unexpected inputs."""
        result = await feature_gate.check("", SubscriptionTier.FREE, "convert_contract")
        assert "allowed" in result

    @pytest.mark.asyncio
    async def test_different_wallets_independent_usage(self, feature_gate):
        # Wallet A uses 4
        for _ in range(4):
            await feature_gate.check("0xaaa", SubscriptionTier.FREE, "convert_contract")
        # Wallet B should still have full allowance
        result = await feature_gate.check("0xbbb", SubscriptionTier.FREE, "convert_contract")
        assert result["allowed"] is True
        assert result["used"] == 1  # just recorded this one

    @pytest.mark.asyncio
    async def test_action_gate_map_has_key_actions(self):
        assert "convert_contract" in ACTION_GATE_MAP
        assert "mint_nft" in ACTION_GATE_MAP
        assert "create_loan" in ACTION_GATE_MAP
        assert "vote" in ACTION_GATE_MAP


# ── Subscription Store Tests ─────────────────────────────────────────


class TestSubscriptionStore:
    """Tests for SubscriptionStore."""

    @pytest.mark.asyncio
    async def test_default_tier_is_free(self, sub_store):
        tier = await sub_store.get_tier("0xnew")
        assert tier == SubscriptionTier.FREE

    @pytest.mark.asyncio
    async def test_upsert_and_get_tier(self, sub_store):
        await sub_store.upsert("0xabc", "pro", {"status": "active"})
        tier = await sub_store.get_tier("0xabc")
        assert tier == SubscriptionTier.PRO

    @pytest.mark.asyncio
    async def test_cancelled_returns_free(self, sub_store):
        await sub_store.upsert("0xabc", "pro", {"status": "cancelled"})
        tier = await sub_store.get_tier("0xabc")
        assert tier == SubscriptionTier.FREE

    @pytest.mark.asyncio
    async def test_set_trial(self, sub_store):
        await sub_store.set_trial("0xabc", "pro", trial_days=3)
        assert await sub_store.is_trial("0xabc") is True
        tier = await sub_store.get_tier("0xabc")
        assert tier == SubscriptionTier.PRO

    @pytest.mark.asyncio
    async def test_expired_trial_returns_free(self, sub_store):
        await sub_store.set_trial("0xabc", "pro", trial_days=0)
        # Trial with 0 days has already expired
        # Give it a tiny window — the trial_end is in the past
        import time
        await sub_store.upsert("0xabc", "pro", {
            "status": "trialing",
            "trial_end": time.time() - 1,
        })
        tier = await sub_store.get_tier("0xabc")
        assert tier == SubscriptionTier.FREE

    @pytest.mark.asyncio
    async def test_get_subscription(self, sub_store):
        await sub_store.upsert("0xabc", "enterprise", {
            "customer_id": "cus_123",
            "subscription_id": "sub_456",
            "status": "active",
        })
        sub = await sub_store.get_subscription("0xabc")
        assert sub is not None
        assert sub["tier"] == "enterprise"
        assert sub["stripe_customer_id"] == "cus_123"

    @pytest.mark.asyncio
    async def test_get_subscription_nonexistent(self, sub_store):
        sub = await sub_store.get_subscription("0xnone")
        assert sub is None


# ── Stripe Client Tests ──────────────────────────────────────────────


class TestStripeClient:
    """Tests for StripeClient."""

    def test_not_configured_by_default(self):
        client = StripeClient({})
        assert client.available is False

    def test_configured_with_real_key(self):
        client = StripeClient({
            "subscriptions": {"stripe_secret_key": "sk_test_realkey123456"}
        })
        assert client.available is True

    def test_placeholder_key_not_available(self):
        client = StripeClient({
            "subscriptions": {"stripe_secret_key": "YOUR_STRIPE_SECRET_KEY"}
        })
        assert client.available is False

    @pytest.mark.asyncio
    async def test_checkout_not_configured(self):
        client = StripeClient({})
        result = await client.create_checkout_session("pro", "0xabc", "http://ok", "http://cancel")
        assert result["status"] == "not_configured"

    @pytest.mark.asyncio
    async def test_checkout_unknown_tier(self):
        client = StripeClient({
            "subscriptions": {"stripe_secret_key": "sk_test_realkey123456"}
        })
        result = await client.create_checkout_session("gold", "0xabc", "http://ok", "http://cancel")
        assert result["status"] == "error"

    @pytest.mark.asyncio
    async def test_webhook_no_secret(self):
        client = StripeClient({})
        result = await client.handle_webhook(b'{}', "")
        assert result["status"] == "error"

    @pytest.mark.asyncio
    async def test_get_subscription_not_configured(self):
        client = StripeClient({})
        result = await client.get_subscription("cus_123")
        assert result["status"] == "not_configured"
