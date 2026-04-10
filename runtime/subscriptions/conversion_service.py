"""Professional smart contract conversion service.

Provides a paid conversion service for businesses that want Trinity to
convert their requirements into production-ready smart contracts.

Pricing:
  - One-time: $499 per contract
  - Monthly (5):  $1,499/month for up to 5 contracts
  - Unlimited:    $3,999/month for unlimited contracts

The free preview gives the first 50 lines of the generated contract.
Full delivery requires payment.
"""

from __future__ import annotations

import json
import logging
import time
import uuid
from typing import Any

logger = logging.getLogger(__name__)

CONVERSION_PLANS = {
    "single": {
        "name": "Single Contract",
        "price_usd": 499,
        "contracts_included": 1,
        "billing": "one-time",
        "features": [
            "Full Solidity contract generation from plain English",
            "Glasswing security audit included",
            "Gas optimisation pass",
            "Deployment-ready output",
            "30-day support window",
        ],
    },
    "monthly_5": {
        "name": "Professional (5/month)",
        "price_usd": 1499,
        "contracts_included": 5,
        "billing": "monthly",
        "features": [
            "Up to 5 contracts per month",
            "Full Glasswing audit on each",
            "Priority queue",
            "Revision requests included",
            "Dedicated support channel",
        ],
    },
    "unlimited": {
        "name": "Enterprise (Unlimited)",
        "price_usd": 3999,
        "contracts_included": -1,
        "billing": "monthly",
        "features": [
            "Unlimited contract generation",
            "Full audit + manual review",
            "Custom template creation",
            "SLA-backed turnaround",
            "Direct engineering support",
        ],
    },
}


class ConversionService:
    """Manages professional contract conversion requests."""

    def __init__(self, config: dict, stripe_client=None, db=None):
        """Initialise the conversion service.

        Parameters
        ----------
        config : dict
            Platform configuration.
        stripe_client : StripeClient, optional
            Stripe client for payment processing.
        db : Database, optional
            SQLite database for persistence.
        """
        self.config = config
        self.stripe = stripe_client
        self.db = db
        self._requests: dict[str, dict] = {}

    async def initialize(self) -> None:
        """Create the conversion_requests table if it does not exist."""
        if self.db:
            await self.db.execute(
                """
                CREATE TABLE IF NOT EXISTS conversion_requests (
                    request_id      TEXT PRIMARY KEY,
                    description     TEXT NOT NULL,
                    email           TEXT NOT NULL,
                    plan            TEXT NOT NULL,
                    status          TEXT NOT NULL DEFAULT 'pending_payment',
                    stripe_session  TEXT,
                    price_usd       REAL,
                    source_code     TEXT,
                    delivered_at    REAL,
                    created_at      REAL NOT NULL
                )
                """,
                commit=True,
            )

    async def create_conversion_request(
        self,
        description: str,
        email: str,
        plan: str = "single",
    ) -> dict:
        """Create a new conversion request.

        Parameters
        ----------
        description : str
            Plain English description of the desired contract.
        email : str
            Contact email for delivery.
        plan : str
            Pricing plan: ``single``, ``monthly_5``, or ``unlimited``.

        Returns
        -------
        dict
            Request details with preview and checkout URL.
        """
        if plan not in CONVERSION_PLANS:
            return {"status": "error", "message": f"Unknown plan: {plan}"}

        request_id = f"conv_{uuid.uuid4().hex[:12]}"
        plan_info = CONVERSION_PLANS[plan]

        # Generate a preview (first ~50 lines conceptual output)
        preview = self._generate_preview(description)

        # Create Stripe checkout
        checkout_url = None
        if self.stripe and self.stripe.available:
            base_url = self.config.get("gateway", {}).get("public_url", "http://localhost:18790")
            result = await self.stripe.create_checkout_session(
                tier=f"conversion_{plan}",
                wallet_address=email,
                success_url=f"{base_url}/services/conversion?request_id={request_id}&status=success",
                cancel_url=f"{base_url}/services/conversion?status=cancelled",
            )
            if result.get("status") == "ok":
                checkout_url = result["url"]

        record = {
            "request_id": request_id,
            "description": description,
            "email": email,
            "plan": plan,
            "price_usd": plan_info["price_usd"],
            "status": "pending_payment",
            "created_at": time.time(),
        }
        self._requests[request_id] = record

        if self.db:
            await self.db.execute(
                """
                INSERT INTO conversion_requests
                    (request_id, description, email, plan, status, price_usd, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (request_id, description, email, plan, "pending_payment",
                 plan_info["price_usd"], time.time()),
                commit=True,
            )

        return {
            "status": "ok",
            "request_id": request_id,
            "plan": plan_info["name"],
            "price_usd": plan_info["price_usd"],
            "billing": plan_info["billing"],
            "preview": preview,
            "checkout_url": checkout_url,
            "features": plan_info["features"],
        }

    async def deliver_conversion(
        self,
        request_id: str,
        source_code: str,
    ) -> dict:
        """Store the generated contract and mark as delivered.

        Parameters
        ----------
        request_id : str
            The conversion request ID.
        source_code : str
            The generated Solidity source code.

        Returns
        -------
        dict
            Delivery confirmation.
        """
        if request_id in self._requests:
            self._requests[request_id]["source_code"] = source_code
            self._requests[request_id]["status"] = "delivered"
            self._requests[request_id]["delivered_at"] = time.time()

        if self.db:
            await self.db.execute(
                """
                UPDATE conversion_requests
                SET source_code = ?, status = 'delivered', delivered_at = ?
                WHERE request_id = ?
                """,
                (source_code, time.time(), request_id),
                commit=True,
            )

        return {
            "status": "ok",
            "request_id": request_id,
            "delivered": True,
        }

    def _generate_preview(self, description: str) -> dict:
        """Generate a preview of what the conversion would produce.

        Returns a structured preview with contract outline and first
        ~50 lines of pseudo-Solidity.
        """
        # Extract key concepts from the description
        desc_lower = description.lower()
        contract_type = "Custom Contract"
        if any(w in desc_lower for w in ["loan", "lend", "borrow"]):
            contract_type = "Lending Agreement"
        elif any(w in desc_lower for w in ["rent", "lease", "tenant"]):
            contract_type = "Rental Agreement"
        elif any(w in desc_lower for w in ["escrow", "hold", "release"]):
            contract_type = "Escrow Contract"
        elif any(w in desc_lower for w in ["dao", "vote", "governance"]):
            contract_type = "DAO Governance"
        elif any(w in desc_lower for w in ["nft", "mint", "collection"]):
            contract_type = "NFT Collection"
        elif any(w in desc_lower for w in ["token", "erc20", "erc-20"]):
            contract_type = "ERC-20 Token"
        elif any(w in desc_lower for w in ["revenue", "share", "split"]):
            contract_type = "Revenue Sharing"
        elif any(w in desc_lower for w in ["vesting", "cliff", "unlock"]):
            contract_type = "Token Vesting"
        elif any(w in desc_lower for w in ["subscription", "recurring"]):
            contract_type = "Subscription Service"

        # Generate contract name
        words = description.split()[:3]
        contract_name = "".join(w.capitalize() for w in words if w.isalpha())
        if not contract_name:
            contract_name = "CustomContract"

        preview_code = f"""// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title {contract_name}
/// @notice {contract_type} generated by 0pnMatrx
/// @dev Auto-generated from: "{description[:80]}..."
contract {contract_name} is Ownable, ReentrancyGuard {{

    // ── State ────────────────────────────────────────
    // [Full implementation generated after payment]

    // ── Events ───────────────────────────────────────
    // [Event declarations included in full version]

    // ── Constructor ──────────────────────────────────
    constructor() Ownable(msg.sender) {{
        // [Initialisation logic in full version]
    }}

    // ── Core Functions ───────────────────────────────
    // [Core business logic in full version]

    // ── View Functions ───────────────────────────────
    // [Read-only query functions in full version]

    // ── Admin Functions ──────────────────────────────
    // [Owner-only management functions in full version]
}}"""

        return {
            "contract_type": contract_type,
            "contract_name": contract_name,
            "estimated_lines": max(150, len(description) // 2),
            "preview_code": preview_code,
            "includes": [
                "OpenZeppelin base contracts",
                "Reentrancy protection",
                "Access control",
                "Event emissions for every state change",
                "NatSpec documentation",
                "Gas-optimised storage layout",
            ],
            "audit_included": True,
        }
