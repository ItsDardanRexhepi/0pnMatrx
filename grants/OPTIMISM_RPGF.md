# Optimism Retroactive Public Goods Funding (RPGF) Nomination

**Project Name:** 0pnMatrx (OpenMatrix)

**Builder:** Dardan Rexhepi

**Date:** April 10, 2026

**Category:** Developer Tooling + End User Applications

**GitHub:** https://github.com/ItsDardanRexhepi/0pnMatrx

**License:** MIT

---

## 1. What is 0pnMatrx

0pnMatrx is a free, open-source AI agent platform with 30 blockchain financial services built on Base (Ethereum L2). Three AI agents -- Neo, Trinity, and Morpheus -- let anyone access DeFi, NFTs, insurance, governance, cross-border payments, and more through natural language. No wallet setup, no gas fees, no technical knowledge required.

---

## 2. What Has Already Been Delivered

This is not a proposal. This is a record of what already exists, is published, and is verifiable on GitHub today.

### Platform Core

- **Gateway** -- production-grade REST and WebSocket API with rate limiting, structured JSON logging, request ID propagation, graceful shutdown, and OpenTelemetry integration. Running. Tested.
- **Three AI Agents** -- Neo (autonomous execution engine), Trinity (conversational interface), Morpheus (high-stakes guidance). All operational with full ReAct loop, tool use, and session memory.
- **Nine Cognitive Protocols** -- Jarvis (identity), Ultron (strategy), Friday (proactive monitoring), Vision (pattern recognition), Trajectory (outcome prediction), Outcome Learning (feedback), Morpheus Triggers (intervention), Rexhepi Gate (execution gate), Omega (synthesis). All wired into the agent runtime.

### 30 Blockchain Services on Base

Every service listed below is built, wired through `ServiceDispatcher`, tested in the CI pipeline, and returns a well-formed degradation response when the chain is not configured. Nothing is stubbed. Nothing is mocked in production paths.

1. Agent Identity
2. Attestation (EAS with batch processing and proof generation)
3. Brand Rewards (ZKP-powered targeting)
4. Cashback
5. Contract Conversion (plain English to audited Solidity to deployment)
6. Cross-Border Payments (compliance-checked)
7. DAO Management
8. Dashboard (aggregated portfolio)
9. DeFi (P2P lending, collateral, reputation)
10. DEX (pool management, swap routing)
11. DID Identity (selective disclosure, ZKP)
12. Dispute Resolution
13. Fundraising (milestone verification, vesting, refunds)
14. Gaming (SDK, revenue sharing)
15. Governance (anti-manipulation, quorum)
16. Insurance (parametric triggers, claims, reserves)
17. IP Royalties (registry, distribution, enforcement)
18. Loyalty (ZKP eligibility)
19. Marketplace (escrow, compliance, appeals)
20. NFT Services
21. Oracle Gateway (multi-source, fallback, aggregation)
22. Privacy
23. RWA Tokenization
24. Securities Exchange
25. Social
26. Stablecoin
27. Staking
28. Subscriptions
29. Supply Chain
30. x402 Payments

### Testing and Quality

- **329 automated tests passing** across 22 test files
- End-to-end flow tests (`test_e2e_flows.py`)
- Dispatch integration tests (`test_dispatch_integration.py`)
- Graceful degradation tests (`test_graceful_degradation.py`)
- Gateway, WebSocket, lifecycle, logging, metrics, audit, backup, config validation, database migration, events, memory, orchestrator, OpenTelemetry, and Sentry tests
- Full CI pipeline

### Security

- Glasswing 12-point vulnerability scanning on all contract conversions
- Closed-source security layer governing all agent behavior
- Environment-only secrets with placeholder stripping
- Production validation that refuses to start with missing or placeholder credentials

### Production Infrastructure

- Docker Compose with Caddy reverse proxy (automatic HTTPS via Let's Encrypt)
- Kubernetes manifests (namespace, configmap, secrets, PVC, deployment with liveness/readiness/startup probes, service, ingress)
- Foundry contract test suite pinned to solc 0.8.20
- OpenTelemetry OTLP push exporter

### Documentation

- README, ROADMAP, CONTRIBUTING, CHANGELOG
- API reference
- Operational runbook
- 9 example scripts covering contract conversion, DeFi, NFTs, insurance, marketplace, attestation, revenue routing, oracle routing, and full user journeys

### iOS App

- MTRX iOS app launching May 21, 2026 on the App Store
- Free
- Bridge layer (`/bridge/v1/`) connecting the app to the gateway

---

## 3. Public Good Case

### Free

0pnMatrx is free. MIT-licensed. No subscription. No freemium tier. No token gate. The default model provider is Ollama, which runs locally at zero cost. A user can clone the repository, run `python setup.py`, and have access to 30 blockchain financial services without paying anything to anyone.

### Open Source

Every line of the platform code is on GitHub. The gateway, runtime, services, agents, protocols, tests, deployment manifests, and documentation are all public. Anyone can fork, modify, and redistribute.

### No Token

There is no 0pnMatrx token. There is no governance token. There is no utility token. There is no plan to create one. The platform does not extract value from users through token mechanics.

### Gas Sponsorship

An ERC-4337 paymaster sponsors all user transactions. Users never see a gas prompt. This is not a "first N transactions free" scheme. It is a structural commitment: the platform pays gas so users do not have to.

### Accessible to Non-Crypto-Native Users

The entire platform is designed for people who have never used a blockchain:

- Natural language interface (no CLI, no ABI, no contract addresses)
- Mobile-first design (MTRX iOS app)
- Gas-free transactions (paymaster)
- Graceful degradation (nothing breaks, ever)
- Five model providers including a free, local option (Ollama)

---

## 4. Impact Evidence

| Evidence | Detail |
|----------|--------|
| 329 tests passing | Verified in CI, covering every service and integration point |
| 30 blockchain services | Each individually testable, each with graceful degradation |
| 3 AI agents | Operational with tool use, session memory, and cognitive protocol stack |
| 136 platform actions | Wired through ServiceDispatcher |
| 9 cognitive protocols | Governing agent reasoning and behavior |
| ~40 days build time | Solo builder, from zero to production-ready |
| MIT license | Permanent, irrevocable open source |
| 5 model providers | No vendor lock-in, including free local option |
| iOS app launching | May 21, 2026 -- App Store, free |
| Production deployment | Docker, Kubernetes, Caddy, OpenTelemetry -- ready today |
| NeoSafe multisig | 0x46fF491D7054A6F500026B3E81f358190f8d8Ec5 |

---

## 5. Category Justification

### Developer Tooling

0pnMatrx is a reference implementation for AI-to-blockchain interaction on Ethereum L2. Developers can:

- Study 30 service implementations as patterns for their own projects
- Fork the gateway as a starting point for any AI agent platform on Base
- Use the graceful degradation patterns in their own blockchain applications
- Reference the ERC-4337 paymaster integration for gasless transaction architectures
- Build plugins and extensions using the SDK layer

### End User Applications

0pnMatrx is simultaneously a consumer product:

- MTRX iOS app provides a mobile interface to all 30 services
- Natural language removes every technical barrier
- Gas sponsorship removes every financial barrier
- The platform serves unbanked and underserved populations directly

The project belongs in both categories because it was designed from the start to serve both audiences.

---

## 6. Builder

**Dardan Rexhepi** -- sole builder. Designed and built every component in approximately 40 days. Gateway, runtime, 30 blockchain services, three AI agents, nine cognitive protocols, security layer, test suite, CI pipeline, deployment infrastructure, iOS bridge, and documentation. All one person.

---

## 7. Links

| Resource | URL |
|----------|-----|
| GitHub | https://github.com/ItsDardanRexhepi/0pnMatrx |
| License | MIT |
| NeoSafe | 0x46fF491D7054A6F500026B3E81f358190f8d8Ec5 |
| MTRX iOS | Launching May 21, 2026 |

---

*What has been delivered is verifiable. What has been built is free. What has been created is open. That is the public good case.*
