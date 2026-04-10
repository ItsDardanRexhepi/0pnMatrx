# Ethereum Foundation ESP -- Submission Form

**Status:** Ready for submission
**Date prepared:** April 10, 2026

---

## Field: Project Summary

*(~200 words | ESP limit: 200 words)*

0pnMatrx is a free, open-source AI agent platform that makes Ethereum's blockchain financial services accessible to people who have never used a wallet, written a transaction, or understood what gas means. Three AI agents -- Neo (execution), Trinity (conversation), and Morpheus (guidance) -- translate natural-language requests into on-chain operations across 30 blockchain services running on Base (Ethereum L2).

Everything is MIT-licensed. There is no token. There is no paywall. The default model provider is Ollama, which runs locally and costs nothing. An ERC-4337 paymaster sponsors every user transaction so no one ever pays gas.

The companion MTRX iOS app launches May 21, 2026, providing a single mobile interface to every service. One builder designed and built the entire platform -- gateway, runtime, 30 services, 3 agents, 9 cognitive protocols, 329-test suite, deployment infrastructure, and documentation -- in approximately 40 days.

0pnMatrx is not a consumer product that happens to use Ethereum. It is an Ethereum access layer. Every user who interacts with the platform becomes an Ethereum user without needing to know what Ethereum is.

---

## Field: Category

Community and Education / Developer Tooling

---

## Field: Requested Amount

$75,000

---

## Field: Public Good Case

*(~400 words | ESP limit: 500 words)*

### What makes 0pnMatrx a public good

**Free and open source, permanently.** The entire platform -- gateway, runtime, 30 blockchain services, three AI agents, nine cognitive protocols, security architecture, test suite, deployment manifests, and documentation -- is MIT-licensed and published on GitHub. Anyone can fork it, run it, modify it, or build on it without permission or payment.

**No token, no rent-seeking.** 0pnMatrx does not have a governance token, a utility token, or any form of tokenized value capture from users. Revenue from platform fees routes to a transparent NeoSafe multisig (0x46fF491D7054A6F500026B3E81f358190f8d8Ec5) and funds infrastructure, not profit extraction.

**Gas sponsorship.** An ERC-4337 paymaster sponsors every user transaction. End users never pay gas. This removes the single largest friction point for non-crypto-native users entering the Ethereum ecosystem.

**Local-first AI.** The default model provider is Ollama, a free, local inference engine. Users are not required to send data to any external API. They can run the entire platform on their own hardware with zero ongoing cost.

**Graceful degradation.** Every service returns a well-formed response even when the blockchain is not configured. This means the platform works as an educational sandbox with no chain access, lowering the barrier for developers learning Ethereum.

### What makes this a contribution to the Ethereum ecosystem

0pnMatrx brings users to Ethereum who would otherwise never arrive. These are users who do not know what Solidity is, who have never installed MetaMask, who do not understand the difference between L1 and L2. They are the 1.7 billion unbanked adults, the freelancers without access to escrow, the creators without royalty enforcement, the small businesses without affordable governance tooling. Every one of them becomes an Ethereum user the moment they open the MTRX app.

### Alignment with ESP values

- **Strengthening Ethereum's ecosystem.** 30 production-grade, modular, tested (329 tests), open-source services added to the ecosystem on Base.
- **Improving Ethereum's usability.** Natural language translates "Convert this rental agreement into a smart contract" into compiled, audited, deployable Solidity.
- **Increasing Ethereum's resilience.** Five model providers, offline-capable, graceful degradation -- built to survive provider outages and network disruptions.
- **Advancing Ethereum's values.** Decentralization (local-first). Openness (MIT). Accessibility (natural language, gas-free, mobile-first). Permissionlessness (no KYC, no credit check, no geographic restriction).

---

## Field: Technical Description

*(~350 words | ESP limit: 500 words)*

### What has been built

- **Gateway:** REST and WebSocket API with rate limiting, structured JSON logging, request ID propagation, graceful shutdown, and OpenTelemetry integration.
- **30 Blockchain Services:** Agent Identity, Attestation (EAS with batch processing and proof generation), Brand Rewards (ZKP-powered), Cashback, Contract Conversion (plain English to audited Solidity, compile, deploy), Cross-Border Payments (compliance-checked), DAO Management, Dashboard, DeFi (P2P lending, collateral, reputation scoring), DEX (pool management, swap routing), DID Identity (selective disclosure, ZKP), Dispute Resolution, Fundraising (milestone verification, vesting, refund protection), Gaming (SDK, revenue sharing), Governance (anti-manipulation, quorum enforcement), Insurance (parametric triggers, claims, reserve management), IP Royalties (registry, distribution, enforcement), Loyalty (ZKP eligibility), Marketplace (escrow, compliance, appeals), NFT Services, Oracle Gateway (multi-source, fallback, aggregation), Privacy, RWA Tokenization, Securities Exchange, Social, Stablecoin, Staking, Subscriptions, Supply Chain, x402 Payments.
- **3 AI Agents:** Neo (autonomous execution), Trinity (conversational interface), Morpheus (high-stakes guidance). Full ReAct loop, tool use, and session memory.
- **9 Cognitive Protocols:** Jarvis, Ultron, Friday, Vision, Trajectory, Outcome Learning, Morpheus Triggers, Rexhepi Gate, Omega. Governing agent reasoning and behavior.
- **Security:** Glasswing 12-point audit layer, environment-only secrets, placeholder stripping, production validation.
- **Infrastructure:** Docker Compose with Caddy reverse proxy (automatic HTTPS), Kubernetes manifests (namespace, configmap, secrets, PVC, deployment with probes, service, ingress), Foundry contract tests pinned to solc 0.8.20, OpenTelemetry OTLP exporter, full CI pipeline.
- **Test Suite:** 329 tests passing across 22 test files.
- **Documentation:** README, ROADMAP, CONTRIBUTING, CHANGELOG, API reference, operational runbook, 9 example scripts.

### Educational value

0pnMatrx serves as a comprehensive reference implementation for: AI-to-blockchain interaction patterns (ReAct loop, tool-use architecture, service dispatcher); graceful degradation in blockchain applications; ERC-4337 paymaster integration for gasless transactions; multi-provider AI architecture; and production deployment patterns (Docker, Kubernetes, Caddy, OpenTelemetry, rate limiting). Nine example scripts walk developers through complete end-to-end workflows.

---

## Field: Team

*(~100 words | ESP limit: 150 words)*

**Dardan Rexhepi** -- sole builder. Designed and built every component of 0pnMatrx in approximately 40 days, including the gateway, runtime, all 30 blockchain services, three AI agents, nine cognitive protocols, test suite, CI pipeline, deployment infrastructure, and documentation. No team. No contractors. No outside code contributions.

GitHub: [@ItsDardanRexhepi](https://github.com/ItsDardanRexhepi)

---

## Field: Milestones

*(~200 words)*

| Milestone | Timeline | Deliverable | Verification |
|-----------|----------|-------------|--------------|
| M1: Security Audit | Month 1 | Third-party security audit of all 30 service contracts completed | Audit report published to GitHub |
| M2: Base Mainnet Deployment | Month 2 | All 30 contracts deployed to Base mainnet, paymaster funded | On-chain contract addresses published |
| M3: iOS Launch | Month 3 | MTRX iOS app live on the App Store (May 21, 2026) | App Store link |
| M4: Developer Education | Month 3-6 | Tutorial series, video walkthroughs, and workshop materials published | Content published on GitHub and documentation site |
| M5: Community Growth | Month 6 | 5,000 monthly active users, community forum operational, contributor onboarding complete | Analytics dashboard, forum URL, contributor count on GitHub |
| M6: Sustainability Report | Month 12 | Public report on usage, impact, and operational sustainability | Report published to GitHub |

---

## Field: Budget

*(~150 words | ESP limit: 200 words)*

**Total request: $75,000**

| Item | Amount | Description |
|------|--------|-------------|
| Base mainnet deployment | $20,000 | Contract deployment, third-party security audit, paymaster funding |
| Developer education | $15,000 | Tutorial series, video walkthroughs, workshop materials showing how to build on Ethereum using 0pnMatrx as a reference |
| Community infrastructure | $10,000 | Documentation hosting, community forum, contributor onboarding |
| iOS launch support | $15,000 | App Store launch for MTRX, the mobile gateway to Ethereum for non-technical users |
| Operational sustainability | $15,000 | 12 months of hosting, RPC access, monitoring, and maintenance |

---

## Field: Impact

*(~150 words | ESP limit: 200 words)*

### Current metrics

| Metric | Value |
|--------|-------|
| Tests passing | 329 |
| Blockchain services | 30 |
| Platform actions | 136 |
| AI agents | 3 |
| Cognitive protocols | 9 |
| Model providers | 5 (including free local option) |
| Build time (solo) | ~40 days |
| License | MIT |
| iOS launch | May 21, 2026 |

### Post-funding targets (12 months)

- 25,000 monthly active users interacting with Ethereum via natural language
- 500,000 cumulative transactions on Base
- 500 smart contracts converted from plain English and deployed
- 30+ countries with active users
- 50 open-source contributors
- Developer tutorial series with 10+ walkthroughs
- Android app launch (Q4 2026)

---

## Field: Links

| Resource | URL |
|----------|-----|
| GitHub | https://github.com/ItsDardanRexhepi/0pnMatrx |
| License | MIT |
| NeoSafe | 0x46fF491D7054A6F500026B3E81f358190f8d8Ec5 |
| MTRX iOS | Launching May 21, 2026 |

---

## Field: Contact

**Dardan Rexhepi**
GitHub: [@ItsDardanRexhepi](https://github.com/ItsDardanRexhepi)

---

*0pnMatrx exists so that the technology built to democratize finance actually reaches the people it was designed for.*
