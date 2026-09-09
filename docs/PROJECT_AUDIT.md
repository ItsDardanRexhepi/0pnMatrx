# Project Audit — 0pnMatrx / OpenMatrix

- **Date:** 2026-09-09
- **Audited commit:** `fa28272` (`main` — "feat(real-estate): Real-Estate Escrow Engine (Component 46)")
- **Auditor:** Cloud agent (dress-rehearsal audit for Dardan, via Hoenn bus)
- **Posture during audit:** read-only inspection + local test runs only. No deploys, no spend,
  no secrets used or needed, no destructive operations. This PR adds this document and nothing else.
- **Method (URF):** prediction = the honest map below; every load-bearing claim was verified
  against code or a live check (local pytest/flake8 runs, GitHub Actions logs, registry lookups
  by subagents). ΔC corrections — places where the docs' or our own prior picture was wrong —
  are listed in §9.

---

## 1. What is NOT live (read this first)

Nothing in this repository is a live product today. Specifically:

| Surface | Claimed / implied | Actual state |
|---|---|---|
| Hosted platform | `openmatrix-ai.com`, `api.openmatrix-ai.com` referenced in `web/badge-widget.js`, `gateway/openapi.yaml`, `k8s/ingress.yaml`, `CREDENTIALS_NEEDED.md` | Root domain is a GoDaddy parking page ("Launching Soon"); `api.` subdomain does not resolve. No gateway is deployed anywhere we can verify. |
| Payments (web) | `web/privacy.html` / `web/terms.html` state "payment is processed by Stripe" as fact; audit ($299–$999) and conversion ($499–$3,999/mo) pages have checkout buttons | Stripe code was **removed** (`CHANGELOG.md` 0.6.0). `gateway/server.py:386-387` sets `audit_service = None` / `conversion_service = None` and never initializes them → the audit route returns 503; the conversion POST route doesn't exist. No payment rail is wired to any web price. |
| Marketplace | `web/marketplace.html` shows plugins with "12,430 downloads", $2.99–$9.99 prices, Install/Purchase buttons | Download counts are hardcoded HTML; Install/Purchase are `setTimeout` animations (lines ~691–703) that flip button text with no API call and no payment. |
| Money movement ("Send") | README: "Send money anywhere in the world instantly with zero fees" | No offline path moves real money. Several services return success-shaped results from in-memory dicts (see §5). On-chain paths honestly return `not_deployed` without RPC/keys. |
| Security enforcement | "Unified Rexhepi Framework governs every decision"; Morpheus gate | The private `morpheus_security` package is absent by design. `runtime/security/__init__.py` is a **noop OBSERVE** backend: every `evaluate()` returns `allow: True`. Nothing enforces fund-movement policy in this clone. This matches `SECURITY_STUB.md` — but users of the code should know: OBSERVE = log-and-allow-everything. |
| iOS app (MTRX) | Legal pages and OpenAPI describe it as existing; IAP product IDs defined | Landing footer says "iOS App (Coming May 2026)" with a dead link. No App Store listing verifiable from this repo. |
| Published SDKs | `sdk/README.md`: `pip install openmatrix-sdk`; `sdk-js/README.md`: `npm install @opnmatrx/sdk` | Neither package exists on PyPI or npm (404 at audit time). `release.yml` only creates GitHub Releases — it never publishes to a registry. |
| On-chain contracts | Config example ships Base Sepolia addresses + 19 EAS schema UIDs | EntryPoint / VerifyingPaymaster / AccountFactory addresses **do have bytecode on Base Sepolia** (real testnet deploys). Everything else under `services.*` is a `YOUR_*` placeholder. NeoSafe address is an EOA. Nothing touches mainnet. |
| CI health | README implies a tested, hardened codebase | **CI on `main` has been red since 2026-07-16.** One flake8 fatal (`F821 undefined name 'Dict'`, `gateway/service_routes.py:755`) fails the lint job, which gates every other job — so tests, the Docker smoke test, and the noop-posture check have not run in CI for any push since. Slither and the docs deploy also fail (see §4). |

The repo's *own* honest artifacts — `CREDENTIALS_NEEDED.md`, `ABI_VERIFICATION_NEEDED.md`,
`SECURITY_STUB.md`, `gateway/doctor.py`, the `not_deployed` response pattern, and the dry-run
deploy scripts — accurately describe most of this. The marketing surfaces (README feature list,
`web/*.html`, legal pages, docs) are where reality and copy diverge.

---

## 2. Repo map

~474 Python files (~103k lines), 57 test files, 212 registered gateway routes, 17 Solidity
contracts + 13 Foundry test files, 5 GitHub Actions workflows. Single Python package tree
(no monorepo tooling); one iOS app and one security package live in separate private repos.

| Area | Path(s) | One-line description |
|---|---|---|
| Gateway (main app) | `gateway/` | aiohttp REST + WebSocket server, 212 routes, middleware (auth, rate-limit, request-id, timeout), serves `web/` pages. `doctor.py` = posture self-check. |
| Agent runtime | `runtime/` (28 subpackages), `agents/`, `hivemind/` | ReAct loop, model router (Ollama default; OpenAI/Anthropic/NVIDIA/Gemini), protocol stack (heuristic engines), memory, notifications, capability catalog (221 entries), hivemind orchestrator. `agents/*/identity.md` are persona prompts only. |
| Blockchain services | `runtime/blockchain/` | `ServiceDispatcher` + 45 services in `services/registry.py`, `web3_manager.py`, wallet abstraction, legacy modules in `runtime/blockchain/*.py` (parallel older stack, still imported). |
| Security seam | `runtime/security/` | Interface + **noop backend**; private `Morpheus-Security-System` not vendored (by design, enforced by CI job `noop-posture`). |
| Contracts | `contracts/` (flat `*.sol` + `test/*.t.sol`) | 17 contracts, Foundry config in `foundry.toml`; `lib/` submodules (forge-std, OpenZeppelin, account-abstraction) **not initialized** in this checkout. |
| Web UI | `web/` | 13 static HTML pages served by the gateway: landing, chat, social feed, marketplace, learn, audit, glasswing, badges, conversion, privacy, terms. |
| SDKs / CLI | `sdk/` (Python), `sdk-js/` (TS), `cli/` | Thin HTTP clients + local ops CLI. Unpublished (see §1). |
| Bridge | `bridge/` + `gateway/bridge.py` | iOS-app-facing `/bridge/v1/*` routes (11), mobile converter, approval gate, sanitizer. |
| CI/CD | `.github/workflows/` | `ci.yml` (lint→test/docker/noop-posture), `slither.yml`, `docs.yml` (Pages), `release.yml` (GitHub Release only), `changelog.yml`. |
| Deploy | `Dockerfile`, `docker-compose*.yml`, `Caddyfile`, `k8s/`, `Procfile`, `railway.toml`, `install.sh`, `start.sh` | Local Docker path is real; k8s/Caddy are templates; ingress hardcodes the parked domain. |
| Scripts | `scripts/` | `deploy_all.py` (9 contracts, testnet-default, **no mainnet guard**), dry-run AA/EAS prep scripts (refuse to broadcast — good), `generate_route_table.py` + `verify_abis.py` (CI posture checks). |
| Docs | `docs/` (11 files) + root MDs | API reference, ROUTES.md (generated), architecture, capability map, URF, ops. Honesty registers: `CREDENTIALS_NEEDED.md`, `ABI_VERIFICATION_NEEDED.md`, `SECURITY_STUB.md`. |
| Env samples | `.env.example`, `openmatrix.config.json.example`, `k8s/secret.example.yaml` | Placeholder-only. **No committed secrets found** (scanned for key/token patterns). |
| Education / examples | `education/` (3 courses, substantive markdown), `examples/` (9 scripts), `demo.py` | Content is real; examples degrade to demo IDs on failure (see §6.3). |
| Misc | `migration/` (7 importers), `extensions/`, `skills/`, `setup*.py` | Implemented code; `setup.py` is a first-boot wizard, not packaging. |

---

## 3. Verified checks (run 2026-09-09 on this checkout)

| Check | Result |
|---|---|
| `pytest tests/` (Python 3.12) | **797 passed**, 1 warning, 10.5s |
| `flake8 --select=E9,F63,F7,F82` (CI's fatal set) | **1 error** — `gateway/service_routes.py:755:18: F821 undefined name 'Dict'` (the CI blocker; harmless at runtime because of `from __future__ import annotations`) |
| `scripts/generate_route_table.py --check` | Pass — `docs/ROUTES.md` up to date (212 routes) |
| `scripts/verify_abis.py --strict` | Pass — no doc/source drift on UNVERIFIED ABIs |
| `python -m gateway.doctor` | Consistent: everything UNCONFIGURED / no-op; security backend = STUB (noop); 212 routes (33 public) |
| Capability catalog | `len(CAPABILITIES) == 221`, 21 category labels (one — `security` — has 0 entries), **57/221 marked `available: False`** |
| Secret scan | No live private keys / API tokens found in tracked files |
| Foundry tests | **Not runnable in this checkout** — submodules uninitialized, `forge` not installed; CI never runs them either |

---

## 4. CI reality

`main` is red. Last push (2026-07-16) failed all three triggered workflows:

1. **CI** — `lint` fails on the single F821 above; because `typecheck`, `docstrings`, `test`,
   `security`, `noop-posture`, and `docker` all `need: lint`, **none of them have run in CI
   since the error landed**. The suite itself is green (verified locally).
2. **Slither** — `slither-action` tries a Foundry compile; the checkout has no submodules and
   no `forge` → `FileNotFoundError: 'forge'`, no SARIF produced.
3. **API Docs** — pdoc build succeeds but Pages deployment 404s: **GitHub Pages is not enabled**
   on the repository.

Also worth knowing about `ci.yml` even when green: `mypy`, `interrogate`, `pip-audit`, and
`bandit` all end in `|| true` (advisory only — a red result never fails the build), and the
Foundry contract tests advertised in the README are not run by any workflow.

---

## 5. Inventory: implemented vs stubbed vs unwired

### 5.1 Gateway

- **Implemented:** aiohttp server + middleware chain, 212 routes, chat/WS, SIWE, SSE event
  broadcaster, paymaster digest crypto, Apple/IAP verification code, static page serving,
  rate limiting, `doctor` posture tool, honest `501` stubs for ~37 unbuilt legs.
- **Empty-gateway posture (verified):** with no secrets/RPC, `doctor` reports every subsystem
  UNCONFIGURED/no-op; paymaster, Apple auth, and IAP routes **fail closed (503)**. Caveat:
  `load_config()` (`gateway/server.py:217-219`) **exits the process** if
  `openmatrix.config.json` is missing — "empty" means empty *values*, not zero files.
- **Auth caveat:** if no `gateway.api_key` / `OPENMATRIX_API_KEY` is set, API-key auth is
  **disabled entirely** and all 212 routes are open (fail-open default). 33 routes are public
  by design even with a key.
- **Unwired route bugs:** three HTTP legs pass wrong kwarg names into their services and can
  never succeed — `POST /api/v1/stablecoin/transfer` (`sender/recipient` vs `from_addr/to_addr`),
  `POST /api/v1/crossborder/send` (`source_currency` vs `from_currency`),
  `POST /api/v1/payments/create` (`payer/payee` vs `agent_id/recipient/purpose`).
  Untested, hence unnoticed.

### 5.2 "Send" / money movement

- **On-chain path** (`runtime/blockchain/payments.py`, service ND gates): honest — returns
  `not_deployed` without RPC + keys. When configured it is a **platform-key (custodial) send**,
  which contradicts the "server never signs user funds" invariant stated in
  `CREDENTIALS_NEEDED.md`; only the iOS AA path is non-custodial.
- **Simulated paths (the big honesty gap):** ~22 of 45 registered services have **no**
  `not_deployed` gate and run in-memory state machines that return success offline:
  - `cross_border/service.py:137` — `send_payment` → `"status": "completed"`, no settlement.
  - `stablecoin/service.py:172` — `transfer` → `"status": "completed"` + `tx_…` id from process memory.
  - `x402_payments/service.py:424-432` — labels `"0x"+sha256(...)` as `on_chain_hash`.
  - Same pattern (success-shaped UUID records, no chain): `gaming`, `fundraising`, `governance`,
    `marketplace`, `loyalty`, `cashback`, `brand_rewards`, `subscriptions`, `social`,
    `did_identity`, `agent_identity`, `supply_chain`, `privacy`, `dispute_resolution`,
    `securities_exchange`, `dashboard`, `oracle_gateway`, and others.
  - This **falsifies the README's** "All 50+ blockchain services return `not_deployed` … no
    fabricated transaction hashes" claim as written. (~23/45 services do gate honestly.)
- Because the dispatcher publishes successful actions to the social feed, simulated successes
  can populate the "Live Activity" feed — a compounding fake-live effect.

### 5.3 OBSERVE / security seam

- `runtime/security/__init__.py`: `SECURITY_BACKEND = "noop"`; `evaluate()` always returns
  `allow: True, mode: "observe", backend: "noop"`. OTP/App Attest/owner-verify are soft no-ops.
- `OPNMATRX_MORPHEUS_MODE` is documented in `CREDENTIALS_NEEDED.md` but **no Python in this
  repo reads it** — the mode switch lives entirely in the private package.
- What *does* enforce in this clone: the public per-agent tool ACL (`runtime/access_policy.py`)
  and fail-closed 503s on credential-gated auth routes. Nothing gates value movement.
- `/api/v1/security/preflight` returns `{"allow": true}` under noop — could be misread as a
  passed security check.
- CI's `noop-posture` job (when it runs) correctly asserts the private package is not vendored
  and the seam degrades to noop.

### 5.4 Auth

- **Fail closed (good):** Apple Sign-In without `auth.apple.bundle_id` → 503; IAP verify/ASN
  without `iap.bundle_id` → 503; paymaster without signer → 503. Real JWKS / x5c-chain
  verification code exists behind those gates (pinned Apple Root G3).
- **Fail open / soft (risky):** no API key configured → all routes open; OTP request/verify
  return **HTTP 200** with `sent/verified: false` under noop (easy to misread as working);
  compliance `verify_address` stamps `verified: True` with no provider.
- No hardcoded production secrets found in auth modules.

### 5.5 Deploy

- **Real:** Dockerfile (multi-stage, non-root, tini, healthcheck), docker-compose (needs a
  real `openmatrix.config.json`), CI Docker smoke test (when lint passes).
- **Templates:** k8s manifests (ingress hardcodes the parked `api.openmatrix-ai.com`),
  Caddy TLS overlay, Procfile/railway.toml.
- **Risky:** `scripts/deploy_all.py` has **no mainnet guard** (deploys to whatever
  RPC/chain-id it's given); `scripts/deploy_and_configure.sh` uses a mainnet RPC in its example,
  falls back to chain-id 8453, health-checks the **parked domain**, and passes the deployer
  private key through inline shell → argv.
- **Blocked:** Foundry compile (`scripts/build-contracts.sh` skips installing libs because the
  empty submodule dirs exist, and it never installs `account-abstraction` at all).
- **Good:** `prepare_aa_deploy.py` and `register_eas_schemas.py` are dry-run-only and refuse
  to broadcast.

---

## 6. Risks and honesty gaps (ranked)

### Critical — sells or simulates something that cannot happen

1. **Web checkout theater.** Audit ($299–$999) and conversion ($499+) pages collect intent and
   imply payment; backends are `None`, Stripe is removed, one route doesn't exist.
2. **Legal pages assert Stripe processing as current fact** (`web/privacy.html:95,132,154`,
   `web/terms.html:137-153`). A privacy policy that misstates data flows is a legal risk, not
   just a marketing one.
3. **Marketplace fake traction and fake install/purchase** (hardcoded download counts,
   `setTimeout` success).
4. **In-memory services returning `completed`/`active`/pseudo-tx-ids** (§5.2) — the deepest
   fake-live surface because it's in the API layer, not just the UI, and it feeds the
   "Live Activity" feed.

### High

5. **CI red on `main` since July** while the README presents a tested, hardened project; most
   quality gates are advisory (`|| true`) even when CI is green; Foundry tests never run in CI.
6. **Unpublished SDKs with `pip install` / `npm install` instructions**; JS SDK also calls
   `/subscription/checkout|status` routes that don't exist on the gateway.
7. **Parked/unresolvable domains** hardcoded across badge widget, OpenAPI servers, k8s ingress,
   and a deploy script's health check.
8. **Fail-open API default** (no key configured → every route open) combined with a public
   posture that looks security-forward.
9. **No mainnet guard in `deploy_all.py`** + mainnet examples in `deploy_and_configure.sh` —
   one bad env var from a mainnet deploy in a repo whose constraint is "testnet only."
10. **README overclaims**: "$10,000 DeFi loans", "zero fees forever", "trade securities 24/7",
    "329 Tests Passing" (actual local run: 797 — stale in the *other* direction), "all 221
    capabilities free" (57/221 are `available: False`; `security` category is empty).

### Medium

11. Examples invent `demo-loan-001`-style IDs and print green success lines after soft failures.
12. Glasswing page promises manual expert review, 48-hour PDF delivery, and $99/yr badge renewal —
    none of which have code.
13. `NFTService.mint` crashes with `KeyError` on the honest `not_deployed` path instead of
    returning it (`runtime/blockchain/services/nft_services/service.py:~165`).
14. Hardcoded fallback market data (ETH $3200, BTC $68000 in `protocol_abstraction/data_aggregator.py`)
    can be rendered without a "stale/fallback" label.
15. Version skew: pyproject 0.5.0, CHANGELOG 0.6.0, sdk 1.0.0, JS sdk 1.0.0, chat UI v0.1.
16. `docs/OPS.md` points at a `Matrix/deploy/` tree that isn't in this repo; DEPLOYMENT_GUIDE
    still lists the wrong (Ethereum Sepolia) EAS address that the config example explicitly warns about.
17. Legacy duplicate service stack (`runtime/blockchain/*.py` alongside `services/`) — drift risk.
18. "Courses/certs with prices" but no purchase path; Discord/office-hours promised with no invite.

### Missing tests (biggest gaps)

- **~23 of 45 blockchain services have no dedicated tests** — exactly the in-memory simulators
  in §5.2 (which is why the three broken HTTP legs and the honesty regressions went unnoticed):
  `advanced_governance, auctions, brand_rewards, cashback, ccip, creator_platforms, cross_border,
  did_identity, fundraising, gaming, kyc, loyalty, mpc, nft_lending, oracles_plus,
  payment_channels, restaking, rwa_tokenization, securities_exchange, social_protocols,
  stablecoin, subscriptions, supply_chain, x402_payments`.
- Near-zero tests: `runtime/a2a`, `runtime/agents`, `runtime/capabilities`, `runtime/marketplace`,
  `runtime/plugins`, `runtime/protocols`.
- No test asserts "no service returns `completed` without a chain" — the invariant the README
  claims. This test would currently fail, which is the point.
- Foundry tests exist for 12/17 contracts (missing: `OpenMatrixAccountFactory` among others)
  but are unrunnable here and never run in CI.
- `sdk-js` declares `jest` with no config and no test files.

---

## 7. Prioritized fix backlog

Small, reversible, PR-sized slices. Buses: **Kanto** = UI/demo, **Johto** = product/roadmap,
**Hoenn** = infra/research/hard spikes. Nothing below requires spend, secrets, or irreversible ops
except where flagged "needs owner".

### P0 — truth and safety (do first)

| # | Bus | Slice | Notes |
|---|---|---|---|
| P0-1 | Hoenn | Fix `F821 Dict` import in `gateway/service_routes.py` (1-line) to unblock all of CI | Smallest possible PR; restores test/docker/posture gates on every push |
| P0-2 | Kanto | Rewrite `web/privacy.html` + `web/terms.html` payment sections to match reality (no Stripe; IAP-only-when-live) | Legal-facing; pure copy change |
| P0-3 | Kanto | Marketplace: remove hardcoded download counts and fake Install/Purchase success; disable buttons or label "demo — not functional" | One HTML file |
| P0-4 | Kanto | Audit + conversion pages: replace checkout buttons with "not yet available / join waitlist" states; remove `checkout_url` expectation | Matches the 503 the backend already returns |
| P0-5 | Johto | README truth pass: fix the falsified `not_deployed` claim, "329 tests", "all free / 221 available", loan/securities promises → "designed for / on roadmap" | Docs only |
| P0-6 | Hoenn | Add mainnet guard to `scripts/deploy_all.py` (refuse chain-id 8453 without `--i-know-this-is-mainnet`) and fix `deploy_and_configure.sh` (Sepolia example RPC, drop parked-domain health check, no key in argv) | Small script diffs; prevents the one irreversible accident this repo could cause |
| P0-7 | Hoenn | Add an "honesty invariant" test: iterate all 45 services offline, assert no write path returns `completed/active/sent` without chain config — initially with an allowlist of known offenders so it lands green, then shrink the allowlist | The regression fence for everything in §5.2 |

### P1 — make the simulators honest, wire what's cheap

| # | Bus | Slice | Notes |
|---|---|---|---|
| P1-1 | Hoenn | Convert the ~22 in-memory services to return `"status": "simulated"` (or ND-gate them) — one PR per 3–4 related services, shrinking the P0-7 allowlist each time | ~6 small PRs; cross_border + stablecoin + x402 first (money-shaped) |
| P1-2 | Hoenn | Rename `x402` `on_chain_hash` → `record_digest` (it's a sha256, not a tx) | Tiny, high honesty value |
| P1-3 | Hoenn | Fix the 3 param-mismatched routes (stablecoin/crossborder/payments) + add route-level tests | Currently dead endpoints |
| P1-4 | Hoenn | Fix `NFTService.mint` KeyError on the ND path | 5-line fix + test |
| P1-5 | Kanto | Feed/social pages: label simulated-source events; rename "Live Activity" → "Activity" until a chain is configured | Prevents simulator → feed fake-live loop |
| P1-6 | Johto | SDK READMEs: replace registry install commands with git/source install until actually published; remove dead `/subscription/*` calls from JS SDK | Or publish for real — owner call |
| P1-7 | Hoenn | Fix `build-contracts.sh` (detect *empty* lib dirs, install account-abstraction) + add a CI job that initializes submodules and runs `forge test`; fix `slither.yml` submodule checkout | Makes the 13 `.t.sol` files real again |
| P1-8 | Johto | Decide fail-open vs fail-closed default for API-key auth; at minimum log a loud startup warning when auth is disabled | One-line behavior, product decision |
| P1-9 | Johto | Single source of truth for version (pyproject ⇄ CHANGELOG ⇄ SDKs ⇄ UI footer) | Small script or manual sync |
| P1-10 | Hoenn | Make CI advisory gates real one at a time: promote `bandit`, then `pip-audit`, from `\|\| true` to blocking with a baseline file | One PR each |

### P2 — polish, docs, roadmap hygiene

| # | Bus | Slice | Notes |
|---|---|---|---|
| P2-1 | Kanto | Landing stats from a build-time script (real test count, real capability availability split) | Kills stale numbers permanently |
| P2-2 | Kanto | Glasswing page: scope copy to what exists (static scan + badge registry); move PDF/human-review/renewal to "planned" | Copy + layout |
| P2-3 | Johto | Domain strategy: either provision `api.openmatrix-ai.com` (needs owner: DNS + hosting spend) or strip it from widget/openapi/k8s defaults in favor of a configurable base URL | Config-default PR is the reversible half |
| P2-4 | Johto | `docs/OPS.md` and `contracts/DEPLOYMENT_GUIDE.md` corrections (remove `Matrix/deploy/` refs; fix EAS address) | Docs only |
| P2-5 | Hoenn | Delete or quarantine the legacy `runtime/blockchain/*.py` duplicate stack | Needs an import-graph check first |
| P2-6 | Hoenn | Tests for untested runtime packages (`a2a`, `capabilities`, `marketplace`, `plugins`, `protocols`) — one package per PR | Steady-state debt paydown |
| P2-7 | Johto | Examples: make soft-failure paths print an explicit `SIMULATED — nothing happened on-chain` banner instead of green demo IDs | Small diffs per example |
| P2-8 | Johto | Enable GitHub Pages (needs owner: repo settings) or disable `docs.yml` deploy step | Settings toggle, not code |
| P2-9 | Kanto | Fix broken nav (`/pricing` links with no route; marketplace submit posts to wrong path) | Small HTML/route fixes |
| P2-10 | Hoenn | Label fallback market data as stale/fallback at the API boundary | data_aggregator + consumers |

---

## 8. What is genuinely good here

Credit where due — these were verified working today, offline, with zero credentials:

- 797-test suite, green in ~10s; route table and ABI-drift checks are generated and CI-enforced.
- `gateway/doctor` and the ND/503/501 patterns are a real, unusually honest "empty gateway" design.
- The public/private security boundary is cleanly executed (noop seam + CI assertion that the
  private package is never vendored).
- Real code, not vapor: ReAct loop, model router with Ollama default, SQLite memory/feed/badges,
  contract-conversion pipeline, notification dispatcher, 9 example scripts, 3 substantive courses.
- Dry-run deploy scripts that refuse to broadcast; placeholder-only config samples; no committed
  secrets found.
- Three of the AA addresses in the config example are real deployed bytecode on Base Sepolia.

---

## 9. ΔC — corrections recorded during this audit

Where the prior map (docs or our initial predictions) was wrong, per URF:

1. **Predicted** "services honestly return `not_deployed`" (per README) → **falsified**: ~22/45
   simulate success in memory. AUDIT reflects the split.
2. **Predicted** CI green (repo looks well-tooled) → **falsified**: red on `main` since 2026-07-16
   from a single lint fatal; downstream jobs never ran.
3. **Predicted** "329 Tests Passing" stale-high → actually stale-**low**: local run is 797 passed.
4. **Predicted** config-example addresses were placeholders → partially wrong: EntryPoint,
   VerifyingPaymaster, and AccountFactory have real bytecode on Base Sepolia.
5. **Predicted** `OPNMATRX_MORPHEUS_MODE=observe` toggles behavior in this repo → wrong: nothing
   here reads it; OBSERVE is simply what the noop backend hardcodes.

## 10. Blockers encountered

None requiring owner action to complete this audit. No spend, secrets, or irreversible operations
were needed or performed. Items in the backlog marked "needs owner" (DNS/hosting, GitHub Pages
setting, registry publishing) are decisions, not blockers to the audit itself.
