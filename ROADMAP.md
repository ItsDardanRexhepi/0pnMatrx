# Roadmap

0pnMatrx is actively being built. Here is what is coming.

---

## Now in progress

- ~~Glasswing security audit layer~~ ✓ — 12-point vulnerability scanning on all contracts
- ~~Managed agent orchestration~~ ✓ — event-driven coordination, session lifecycle, hooks
- ~~Contract Conversion pipeline~~ ✓ — pseudocode/Solidity/Vyper → optimised Solidity → audit → compile → on-chain deploy → EAS attestation
- ~~Subscription tiers~~ ✓ — Free / Pro ($4.99) / Enterprise ($19.99) with Stripe integration, usage tracking, and feature gating
- ~~Plugin marketplace~~ ✓ — developer plugin store with 90/10 revenue split, submissions, purchases, and download tracking
- ~~Web interface~~ ✓ — landing, chat, pricing, audit, marketplace, and conversion service pages
- ~~Professional services~~ ✓ — Glasswing audit ($299+) and contract conversion ($499+) as paid tiers
- ~~A2A commerce~~ ✓ — agent-to-agent service registry and discovery protocol
- ~~JavaScript SDK~~ ✓ — `@opnmatrx/sdk` npm package with TypeScript support
- ~~Social media integration~~ ✓ — Twitter and Discord automated announcements
- ~~GitHub Sponsors infrastructure~~ ✓ — FUNDING.yml, sponsor tiers ($5-$2,500/mo), activation guide
- ~~Open Collective infrastructure~~ ✓ — corporate sponsor tiers ($500-$5,000/mo), transparent fund allocation
- ~~Referral program~~ ✓ — referral codes, credit granting, self-referral prevention, conversion tracking
- ~~Metered API pricing~~ ✓ — Growth/Scale/Infrastructure tiers with overage billing above Enterprise
- ~~Protocol referral fees~~ ✓ — Uniswap V3 interface fees, Aave referrals, 1inch referrals to NeoSafe
- ~~Glasswing security badges~~ ✓ — verifiable audit badges with EAS attestation, embeddable widget, annual renewal
- ~~Certification program~~ ✓ — Developer ($149), Auditor ($249), Enterprise Architect ($399) with real exams
- ~~Educational content~~ ✓ — three courses (Intro, Security, DeFi), Gumroad listings, community guide
- ~~Revenue dashboard~~ ✓ — admin MRR/ARR tracking across all 14 revenue streams
- Unified Rexhepi Framework — full deployment
- Consumer Layer — public-facing protocol
- Local LLM support expansion
- Distributed agent coordination — remote agent support, cross-node HiveMind

## Revenue

All revenue flows through the NeoSafe multisig at `0x46fF491D7054A6F500026B3E81f358190f8d8Ec5`.

- **Subscriptions** — Free / Pro ($4.99/mo) / Enterprise ($19.99/mo) via Stripe
- **On-chain platform fees** — transparent, visible on-chain, disclosed before first transaction
- **Plugin marketplace** — 10% platform commission (developers keep 90%)
- **Professional services** — Glasswing audit ($299+), contract conversion ($499+)
- **Solidity template packs** — DeFi, Creator, Business packs via Gumroad ($49 each, $119 bundle)
- **Grants** — Base Ecosystem Fund, Ethereum Foundation ESP, Optimism RPGF, Gitcoin Grants
- **GitHub Sponsors** — individual tiers $5-$2,500/mo
- **Open Collective** — corporate tiers $500-$5,000/mo with invoices and tax receipts
- **Referral program** — free months for referrers, extended trials for referred users
- **Metered API** — Growth ($49.99) / Scale ($199.99) / Infrastructure ($499.99) with overage
- **Protocol referrals** — Uniswap, Aave, 1inch integrator fees routed to NeoSafe
- **Glasswing badges** — $99/year renewal for verified security badges
- **Certifications** — Developer ($149) / Auditor ($249) / Enterprise Architect ($399)
- **Educational content** — three Gumroad courses ($49-$79 each, $149 bundle)

14 total revenue streams. See `docs/REVENUE_STREAMS.md` for the complete mapping.

## Blockchain Activation

The full execution layer is wired and tested in offline mode — every one
of the 30 blockchain services returns a standardised
`{"status": "not_deployed", ...}` dict with a deployment guide when the
chain is not configured. To go live:

1. **Configure the chain.** Set `blockchain.rpc_url`,
   `blockchain.chain_id`, and the deployer key (`paymaster_private_key`)
   in `openmatrix.config.json`.
2. **Deploy the platform contracts.** Each service reads its contract
   address from config (`defi.lending_pool_address`,
   `nft_services.factory_address`, `staking.staking_contract_address`,
   etc.). Until the address is set or it equals a `YOUR_*` placeholder,
   the service short-circuits to `not_deployed`.
3. **Enable contract conversion auto-deploy.** Set
   `contract_conversion.auto_deploy = true` to compile and deploy
   converted contracts in the same call.
4. **Fund the paymaster.** The platform sponsors all gas via ERC-4337;
   the paymaster wallet needs ETH on the target chain.
5. **Verify NeoSafe routing.** The canonical NeoSafe multisig is
   `0x46fF491D7054A6F500026B3E81f358190f8d8Ec5`. Once live, every
   `NeoSafeRouter.route_revenue` call sends ETH and creates an EAS
   attestation.

The `tests/test_e2e_flows.py` and `tests/test_dispatch_integration.py`
suites verify this entire chain runs without raising in offline mode —
they are the gate that proves Phase-by-Phase activation is safe.

## Q2 2026

- Full ETH Blockchain Integration
- 30-Component Blockchain Infrastructure
- App Store on 0pnMatrx
- 5 Gaps Protocol
- GitHub Release Protocol

## May 21, 2026

- **MTRX iOS App** — launch on the App Store. Free. Built by Neo.

  Scope note: the iOS app lives in a **separate repository**
  (`MTRX-iOS`, not yet public). It is intentionally out of scope for
  this Python gateway repo. Work that belongs in that repo:

  - Swift / SwiftUI client code and UI assets
  - APNs (Apple Push Notification service) credentials and signing
  - TestFlight / App Store CI (Xcode Cloud or fastlane)
  - In-app purchase / StoreKit integration

  This repo (`0pnMatrx`) ships only the gateway, runtime, and
  blockchain services that the iOS app talks to over `/chat`,
  `/chat/stream`, and `/ws`. API contract changes that affect MTRX
  iOS are flagged in `CHANGELOG.md` so the mobile team can pin the
  matching gateway version.

## Post-launch

- Android app
- Full autonomy mode — Neo operates independently, no required human input
- Developer SDK public release

---

This roadmap is directional. Dates are targets, not guarantees. The build is live and moving every day.
