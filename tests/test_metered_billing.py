"""Tests for metered API billing system.

Verifies tier management, call recording, usage tracking,
invoice calculation, and usage report generation.
"""

from __future__ import annotations

import asyncio
import time
import pytest
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock


class MockDB:
    """In-memory mock of the SQLite database wrapper."""

    def __init__(self):
        self._tables: dict[str, list[dict]] = {}

    async def execute(self, sql: str, params=None, commit=False):
        sql_lower = sql.strip().lower()
        if sql_lower.startswith("create table"):
            return
        if sql_lower.startswith("insert"):
            table = self._extract_table(sql, "insert")
            if table not in self._tables:
                self._tables[table] = []
            if params:
                self._tables[table].append({"_params": params, "_sql": sql})
        if sql_lower.startswith("update"):
            pass

    async def fetchone(self, sql: str, params=None):
        sql_lower = sql.strip().lower()
        table = self._extract_table(sql, "select")
        if table == "api_metered_subscriptions" and params:
            for row in self._tables.get(table, []):
                if row.get("_params") and row["_params"][0] == params[0]:
                    return {"api_key": row["_params"][0], "tier": row["_params"][1],
                            "created_at": time.time(), "updated_at": time.time()}
        if table == "api_usage_metered" and params:
            for row in self._tables.get(table, []):
                if row.get("_params") and row["_params"][0] == params[0]:
                    if len(params) > 1 and row["_params"][1] == params[1]:
                        return {"api_key": params[0], "month": params[1],
                                "call_count": 150, "last_updated": time.time()}
        return None

    async def fetchall(self, sql: str, params=None):
        return []

    @staticmethod
    def _extract_table(sql: str, verb: str) -> str:
        sql_lower = sql.strip().lower()
        if verb == "insert":
            idx = sql_lower.find("into") + 5
            end = sql_lower.find("(", idx)
            if end == -1:
                end = sql_lower.find(" ", idx)
            return sql_lower[idx:end].strip()
        if verb == "select":
            idx = sql_lower.find("from") + 5
            end = sql_lower.find(" ", idx)
            if end == -1:
                end = len(sql_lower)
            return sql_lower[idx:end].strip()
        return ""


@pytest.fixture
def db():
    return MockDB()


@pytest.fixture
def manager(db):
    from runtime.subscriptions.metered_billing import MeteredBillingManager
    return MeteredBillingManager(db)


@pytest.mark.asyncio
async def test_initialize(manager):
    """Initialize should create tables without error."""
    await manager.initialize()


@pytest.mark.asyncio
async def test_metered_tiers_exist(manager):
    """All three metered tiers should be defined."""
    from runtime.subscriptions.metered_billing import METERED_TIERS
    assert "growth" in METERED_TIERS
    assert "scale" in METERED_TIERS
    assert "infrastructure" in METERED_TIERS


@pytest.mark.asyncio
async def test_growth_tier_config():
    """Growth tier should have correct pricing."""
    from runtime.subscriptions.metered_billing import METERED_TIERS
    growth = METERED_TIERS["growth"]
    assert growth["monthly_base"] == 49.99
    assert growth["included_calls"] == 10000
    assert growth["overage_per_call"] == 0.005
    assert growth["rate_limit_rpm"] == 300


@pytest.mark.asyncio
async def test_scale_tier_config():
    """Scale tier should have correct pricing."""
    from runtime.subscriptions.metered_billing import METERED_TIERS
    scale = METERED_TIERS["scale"]
    assert scale["monthly_base"] == 199.99
    assert scale["included_calls"] == 100000
    assert scale["overage_per_call"] == 0.002
    assert scale["rate_limit_rpm"] == 1000


@pytest.mark.asyncio
async def test_infrastructure_tier_config():
    """Infrastructure tier should have correct pricing."""
    from runtime.subscriptions.metered_billing import METERED_TIERS
    infra = METERED_TIERS["infrastructure"]
    assert infra["monthly_base"] == 499.99
    assert infra["included_calls"] == 500000
    assert infra["overage_per_call"] == 0.001
    assert infra["rate_limit_rpm"] == 3000


@pytest.mark.asyncio
async def test_subscribe_valid_tier(manager):
    """Subscribing to a valid tier should succeed."""
    await manager.initialize()
    result = await manager.subscribe("test-key-123", "growth")
    assert result.get("status") == "subscribed" or result.get("tier") == "growth"


@pytest.mark.asyncio
async def test_subscribe_invalid_tier(manager):
    """Subscribing to an invalid tier should fail."""
    await manager.initialize()
    with pytest.raises((ValueError, KeyError)):
        await manager.subscribe("test-key-123", "nonexistent")


@pytest.mark.asyncio
async def test_record_api_call(manager):
    """Recording an API call should not raise."""
    await manager.initialize()
    await manager.record_api_call("test-key-123")


@pytest.mark.asyncio
async def test_get_monthly_usage_no_subscription(manager):
    """Usage for a non-subscribed key should return sensible defaults."""
    await manager.initialize()
    usage = await manager.get_monthly_usage("unknown-key")
    assert "calls" in usage or "call_count" in usage or "error" in usage


@pytest.mark.asyncio
async def test_calculate_invoice_structure(manager):
    """Invoice for non-subscribed key should raise."""
    await manager.initialize()
    month = datetime.now(timezone.utc).strftime("%Y-%m")
    with pytest.raises((ValueError, KeyError)):
        await manager.calculate_invoice("test-key", month)


@pytest.mark.asyncio
async def test_generate_usage_report_unsubscribed(manager):
    """Usage report for non-subscribed key should raise."""
    await manager.initialize()
    with pytest.raises((ValueError, KeyError)):
        await manager.generate_usage_report("test-key", months=3)


@pytest.mark.asyncio
async def test_get_rate_limit_no_subscription(manager):
    """Rate limit for non-subscribed key should be 0."""
    await manager.initialize()
    rpm = await manager.get_rate_limit("unknown-key")
    assert rpm == 0
