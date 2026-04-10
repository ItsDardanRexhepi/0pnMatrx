"""Referral program -- reward users for bringing friends to the platform.

Referrers earn free subscription months when their referrals convert
to paid tiers. Developers keep 90% of plugin revenue; the referral
program covers subscription credits only.
"""

from runtime.referrals.referral_manager import ReferralManager

__all__ = ["ReferralManager"]
