"""Stripe API client for 0pnMatrx subscription payments.

Uses raw HTTP requests via the ``requests`` library (already in
requirements.txt) rather than the Stripe SDK. This keeps the
dependency tree minimal.

All methods are fault-tolerant — they never raise and always return
a dict with a ``status`` field.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
import os
import time
from typing import Any

import requests as http_requests

logger = logging.getLogger(__name__)

_STRIPE_API_BASE = "https://api.stripe.com/v1"


class StripeClient:
    """Thin wrapper around the Stripe HTTP API for subscription management."""

    def __init__(self, config: dict | None = None):
        """Initialise with optional config dict.

        Falls back to environment variables if config keys are missing.

        Environment variables:
            STRIPE_SECRET_KEY
            STRIPE_WEBHOOK_SECRET
            STRIPE_PRO_PRICE_ID
            STRIPE_ENTERPRISE_PRICE_ID
        """
        config = config or {}
        sub_cfg = config.get("subscriptions", {})

        self.secret_key = (
            sub_cfg.get("stripe_secret_key")
            or os.environ.get("STRIPE_SECRET_KEY", "")
        )
        self.webhook_secret = (
            sub_cfg.get("stripe_webhook_secret")
            or os.environ.get("STRIPE_WEBHOOK_SECRET", "")
        )
        self.pro_price_id = (
            sub_cfg.get("stripe_pro_price_id")
            or os.environ.get("STRIPE_PRO_PRICE_ID", "")
        )
        self.enterprise_price_id = (
            sub_cfg.get("stripe_enterprise_price_id")
            or os.environ.get("STRIPE_ENTERPRISE_PRICE_ID", "")
        )

        # Available only if the secret key looks real (not a placeholder)
        self.available = bool(
            self.secret_key
            and not self.secret_key.startswith("YOUR_")
            and len(self.secret_key) > 10
        )

    def _headers(self) -> dict[str, str]:
        """Build Stripe API request headers."""
        return {
            "Authorization": f"Bearer {self.secret_key}",
            "Content-Type": "application/x-www-form-urlencoded",
        }

    def _price_id_for_tier(self, tier: str) -> str | None:
        """Map a tier name to its Stripe price ID."""
        tier_lower = tier.lower()
        if tier_lower == "pro":
            return self.pro_price_id
        elif tier_lower == "enterprise":
            return self.enterprise_price_id
        return None

    async def create_checkout_session(
        self,
        tier: str,
        wallet_address: str,
        success_url: str,
        cancel_url: str,
    ) -> dict:
        """Create a Stripe Checkout session for a subscription tier.

        Parameters
        ----------
        tier : str
            ``pro`` or ``enterprise``.
        wallet_address : str
            The wallet address to associate with the subscription.
        success_url : str
            URL to redirect to after successful payment.
        cancel_url : str
            URL to redirect to if the user cancels.

        Returns
        -------
        dict
            ``{"status": "ok", "url": "https://...", "session_id": "..."}``
            on success, or ``{"status": "error", "message": "..."}`` on failure.
        """
        if not self.available:
            return {
                "status": "not_configured",
                "message": "Stripe is not configured. Contact support to upgrade.",
            }

        price_id = self._price_id_for_tier(tier)
        if not price_id:
            return {
                "status": "error",
                "message": f"Unknown tier: {tier}. Use 'pro' or 'enterprise'.",
            }

        try:
            data = {
                "mode": "subscription",
                "line_items[0][price]": price_id,
                "line_items[0][quantity]": "1",
                "success_url": success_url,
                "cancel_url": cancel_url,
                "client_reference_id": wallet_address,
                "subscription_data[trial_period_days]": "3",
                "metadata[wallet_address]": wallet_address,
                "metadata[tier]": tier,
            }

            resp = http_requests.post(
                f"{_STRIPE_API_BASE}/checkout/sessions",
                headers=self._headers(),
                data=data,
                timeout=30,
            )

            if resp.status_code == 200:
                body = resp.json()
                return {
                    "status": "ok",
                    "url": body.get("url", ""),
                    "session_id": body.get("id", ""),
                }
            else:
                error_body = resp.json()
                msg = error_body.get("error", {}).get("message", resp.text)
                logger.error("Stripe checkout error: %s", msg)
                return {"status": "error", "message": msg}

        except Exception as exc:
            logger.error("Stripe checkout exception: %s", exc)
            return {"status": "error", "message": str(exc)}

    async def get_subscription(self, stripe_customer_id: str) -> dict:
        """Get active subscription status for a Stripe customer.

        Returns
        -------
        dict
            Subscription details or error dict.
        """
        if not self.available:
            return {"status": "not_configured", "message": "Stripe not configured."}

        try:
            resp = http_requests.get(
                f"{_STRIPE_API_BASE}/subscriptions",
                headers=self._headers(),
                params={"customer": stripe_customer_id, "status": "active", "limit": "1"},
                timeout=30,
            )

            if resp.status_code == 200:
                body = resp.json()
                subs = body.get("data", [])
                if subs:
                    sub = subs[0]
                    return {
                        "status": "ok",
                        "subscription_id": sub["id"],
                        "plan": sub.get("plan", {}).get("id", ""),
                        "current_period_end": sub.get("current_period_end"),
                        "cancel_at_period_end": sub.get("cancel_at_period_end", False),
                        "trial_end": sub.get("trial_end"),
                    }
                return {"status": "ok", "subscription_id": None}
            else:
                return {"status": "error", "message": resp.text}

        except Exception as exc:
            logger.error("Stripe subscription lookup error: %s", exc)
            return {"status": "error", "message": str(exc)}

    async def handle_webhook(self, payload: bytes, sig_header: str) -> dict:
        """Verify and process a Stripe webhook event.

        Parameters
        ----------
        payload : bytes
            The raw request body.
        sig_header : str
            The ``Stripe-Signature`` header value.

        Returns
        -------
        dict
            Parsed event with ``event_type`` and relevant data.
        """
        if not self.webhook_secret:
            return {"status": "error", "message": "Webhook secret not configured."}

        # Verify signature
        if not self._verify_webhook_signature(payload, sig_header):
            return {"status": "error", "message": "Invalid webhook signature."}

        try:
            event = json.loads(payload)
        except json.JSONDecodeError:
            return {"status": "error", "message": "Invalid JSON payload."}

        event_type = event.get("type", "")
        data_object = event.get("data", {}).get("object", {})

        result = {
            "status": "ok",
            "event_type": event_type,
            "event_id": event.get("id", ""),
        }

        if event_type in (
            "customer.subscription.created",
            "customer.subscription.updated",
        ):
            result["subscription_id"] = data_object.get("id")
            result["customer_id"] = data_object.get("customer")
            result["plan_id"] = (
                data_object.get("plan", {}).get("id")
                or data_object.get("items", {}).get("data", [{}])[0].get("plan", {}).get("id")
            )
            result["status_value"] = data_object.get("status")
            result["current_period_end"] = data_object.get("current_period_end")
            result["trial_end"] = data_object.get("trial_end")
            result["wallet_address"] = data_object.get("metadata", {}).get("wallet_address", "")
            result["tier"] = data_object.get("metadata", {}).get("tier", "")

        elif event_type == "customer.subscription.deleted":
            result["subscription_id"] = data_object.get("id")
            result["customer_id"] = data_object.get("customer")
            result["wallet_address"] = data_object.get("metadata", {}).get("wallet_address", "")
            result["cancelled"] = True

        elif event_type == "checkout.session.completed":
            result["session_id"] = data_object.get("id")
            result["customer_id"] = data_object.get("customer")
            result["wallet_address"] = (
                data_object.get("client_reference_id")
                or data_object.get("metadata", {}).get("wallet_address", "")
            )
            result["subscription_id"] = data_object.get("subscription")

        return result

    def _verify_webhook_signature(self, payload: bytes, sig_header: str) -> bool:
        """Verify Stripe webhook signature using the webhook secret."""
        if not sig_header or not self.webhook_secret:
            return False

        try:
            # Parse the signature header
            elements = {}
            for item in sig_header.split(","):
                key, _, val = item.strip().partition("=")
                elements[key] = val

            timestamp = elements.get("t", "")
            signature = elements.get("v1", "")
            if not timestamp or not signature:
                return False

            # Compute expected signature
            signed_payload = f"{timestamp}.{payload.decode('utf-8')}"
            expected = hmac.new(
                self.webhook_secret.encode("utf-8"),
                signed_payload.encode("utf-8"),
                hashlib.sha256,
            ).hexdigest()

            # Constant-time comparison
            return hmac.compare_digest(expected, signature)

        except Exception as exc:
            logger.error("Webhook signature verification error: %s", exc)
            return False
