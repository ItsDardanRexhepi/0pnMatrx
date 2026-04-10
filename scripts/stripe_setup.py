"""
Stripe product and price provisioning script for 0pnMatrx.

Creates all Stripe products and their associated prices via the Stripe REST API
using raw HTTP requests. Writes the resulting price IDs to a .env.stripe file
at the repository root for downstream consumption.
"""
# Usage: STRIPE_SECRET_KEY=sk_live_xxx python scripts/stripe_setup.py

import os
import sys
import requests

STRIPE_PRODUCTS_URL = "https://api.stripe.com/v1/products"
STRIPE_PRICES_URL = "https://api.stripe.com/v1/prices"

# Each entry: (env_key_suffix, product_name, amount_cents, currency, recurring_interval or None)
CATALOG = [
    ("PRO",                        "0pnMatrx Pro",                         499, "usd", "month"),
    ("ENTERPRISE",                 "0pnMatrx Enterprise",                 1999, "usd", "month"),
    ("GROWTH_API",                 "0pnMatrx Growth API",                 4999, "usd", "month"),
    ("SCALE_API",                  "0pnMatrx Scale API",                 19999, "usd", "month"),
    ("INFRASTRUCTURE_API",         "0pnMatrx Infrastructure API",        49999, "usd", "month"),
    ("GLASSWING_AUDIT_STANDARD",   "Glasswing Audit Standard",          29900, "usd", None),
    ("GLASSWING_AUDIT_ADVANCED",   "Glasswing Audit Advanced",          59900, "usd", None),
    ("GLASSWING_AUDIT_ENTERPRISE", "Glasswing Audit Enterprise",        99900, "usd", None),
    ("GLASSWING_SECURITY_BADGE",   "Glasswing Security Badge Annual",    9900, "usd", "year"),
    ("DEV_CERTIFICATION",          "Developer Certification",           14900, "usd", None),
    ("SECURITY_AUDITOR_CERT",      "Security Auditor Certification",    24900, "usd", None),
    ("ENTERPRISE_ARCHITECT_CERT",  "Enterprise Architect Certification", 39900, "usd", None),
]


def get_secret_key():
    """Read STRIPE_SECRET_KEY from the environment or exit."""
    key = os.environ.get("STRIPE_SECRET_KEY")
    if not key:
        print("ERROR: STRIPE_SECRET_KEY environment variable is not set.")
        print("Usage: STRIPE_SECRET_KEY=sk_live_xxx python scripts/stripe_setup.py")
        sys.exit(1)
    return key


def create_product(session, name):
    """Create a Stripe product and return its ID, or None on failure."""
    try:
        resp = session.post(STRIPE_PRODUCTS_URL, data={"name": name})
        if resp.status_code == 200:
            product_id = resp.json()["id"]
            print(f"  [OK] Product created: {name} -> {product_id}")
            return product_id
        else:
            print(f"  [FAIL] Could not create product '{name}': "
                  f"{resp.status_code} {resp.text}")
            return None
    except requests.RequestException as exc:
        print(f"  [FAIL] Request error creating product '{name}': {exc}")
        return None


def create_price(session, product_id, amount_cents, currency, recurring_interval):
    """Create a Stripe price for a product and return its ID, or None on failure."""
    data = {
        "product": product_id,
        "unit_amount": amount_cents,
        "currency": currency,
    }
    if recurring_interval:
        data["recurring[interval]"] = recurring_interval
    else:
        data["type"] = "one_time"

    try:
        resp = session.post(STRIPE_PRICES_URL, data=data)
        if resp.status_code == 200:
            price_id = resp.json()["id"]
            print(f"  [OK] Price created: {price_id}")
            return price_id
        else:
            print(f"  [FAIL] Could not create price for product {product_id}: "
                  f"{resp.status_code} {resp.text}")
            return None
    except requests.RequestException as exc:
        print(f"  [FAIL] Request error creating price for product {product_id}: {exc}")
        return None


def write_env_file(price_map, repo_root):
    """Write all price IDs to .env.stripe at the repo root."""
    path = os.path.join(repo_root, ".env.stripe")
    with open(path, "w") as f:
        for env_suffix, price_id in price_map:
            f.write(f"STRIPE_{env_suffix}_PRICE_ID={price_id}\n")
    print(f"\nPrice IDs written to {path}")


def main():
    secret_key = get_secret_key()

    session = requests.Session()
    session.auth = (secret_key, "")

    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

    price_map = []
    results = []
    failures = 0

    print("=" * 60)
    print("Stripe Product & Price Setup")
    print("=" * 60)

    for env_suffix, name, amount_cents, currency, interval in CATALOG:
        print(f"\n--- {name} ---")

        product_id = create_product(session, name)
        if product_id is None:
            failures += 1
            results.append((env_suffix, name, None))
            continue

        price_id = create_price(session, product_id, amount_cents, currency, interval)
        if price_id is None:
            failures += 1
            results.append((env_suffix, name, None))
            continue

        price_map.append((env_suffix, price_id))
        results.append((env_suffix, name, price_id))

    if price_map:
        write_env_file(price_map, repo_root)

    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"{'Env Key':<42} {'Product':<42} {'Price ID'}")
    print("-" * 120)
    for env_suffix, name, price_id in results:
        key = f"STRIPE_{env_suffix}_PRICE_ID"
        status = price_id if price_id else "FAILED"
        print(f"{key:<42} {name:<42} {status}")

    print(f"\nTotal: {len(results)} | Succeeded: {len(price_map)} | Failed: {failures}")

    if failures:
        print("\nSome products/prices failed to create. Check the output above.")
        sys.exit(1)
    else:
        print("\nAll products and prices created successfully.")


if __name__ == "__main__":
    main()
