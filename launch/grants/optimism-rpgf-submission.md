# Optimism Retroactive Public Goods Funding -- Nomination Form

**Status:** Ready for submission
**Date prepared:** April 10, 2026
**Category:** Developer Tooling + End User Applications

---

## Field: What is it?

0pnMatrx (OpenMatrix) is a free, open-source AI agent platform with 30 blockchain financial services built on Base (Ethereum L2). Three AI agents -- Neo (execution), Trinity (conversation), and Morpheus (guidance) -- let anyone access DeFi, NFTs, insurance, governance, cross-border payments, and more through natural language. No wallet setup. No gas fees. No technical knowledge required. MIT-licensed. No token. The MTRX iOS app launches May 21, 2026.

Built by one person -- Dardan Rexhepi -- in approximately 40 days.

---

## Field: What was delivered?

This is not a proposal. This is a record of what already exists, is published, and is verifiable on GitHub today.

### Platform Core

- **Gateway** -- production-grade REST and WebSocket API with rate limiting, structured JSON logging, request ID propagation, graceful shutdown, and OpenTelemetry integration. Running. Tested.
- **3 AI Agents** -- Neo (autonomous execution engine), Trinity (conversational interface), Morpheus (high-stakes guidance). All operational with full ReAct loop, tool use, and session memory.
- **9 Cognitive Protocols** -- Jarvis (identity), Ultron (strategy), Friday (proactive monitoring), Vision (pattern recognition), Trajectory (outcome prediction), Outcome Learning (feedback), Morpheus Triggers (intervention), Rexhepi Gate (execution gate), Omega (synthesis). All wired into the agent runtime.

### 30 Blockchain Services on Base

Every service is built, wired through `ServiceDispatcher`, tested in CI, and returns a well-formed degradation response when the chain is not configured. Nothing is stubbed. Nothing is mocked in production paths.

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

- 329 automated tests passing across 22 test files
- End-to-end flow tests, dispatch integration tests, graceful degradation tests
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

### Documentation and Education

- README, ROADMAP, CONTRIBUTING, CHANGELOG, API reference, operational runbook
- 9 example scripts: contract conversion, DeFi lending, NFT minting with royalties, parametric insurance, marketplace escrow, EAS attestation chains, revenue routing, oracle routing, full user journeys

### iOS App

- MTRX iOS app launching May 21, 2026 on the App Store
- Free, no subscription, no token gate
- Bridge layer (`/bridge/v1/`) connecting the app to the gateway

---

## Field: Impact

### By the numbers

| Metric | Value |
|--------|-------|
| Automated tests passing | **329** |
| Blockchain services on Base | **30** |
| Platform actions wired | **136** |
| AI agents operational | **3** |
| Cognitive protocols | **9** |
| Model providers supported | **5** (Ollama, OpenAI, Anthropic, NVIDIA, Gemini) |
| Default model provider | **Ollama** (free, local, no API key) |
| Example scripts | **9** end-to-end flows |
| Build time (solo builder) | **~40 days** |
| License | **MIT** (permanent, irrevocable open source) |
| Token | **None** (no governance token, no utility token, no plan to create one) |
| Gas cost to users | **$0** (ERC-4337 paymaster sponsors all transactions) |
| iOS app launch | **May 21, 2026** |
| NeoSafe multisig | **0x46fF491D7054A6F500026B3E81f358190f8d8Ec5** |

### Impact as a public good

**Free.** MIT-licensed. No subscription. No freemium tier. No token gate. A user can clone the repository, run `python setup.py`, and have access to 30 blockchain financial services without paying anything to anyone.

**Open source.** Every line of the platform code is on GitHub. The gateway, runtime, services, agents, protocols, tests, deployment manifests, and documentation are all public. Anyone can fork, modify, and redistribute.

**Gas sponsored.** An ERC-4337 paymaster sponsors all user transactions. Users never see a gas prompt. This is a structural commitment: the platform pays gas so users do not have to.

**Accessible to non-crypto-native users.** Natural language interface. Mobile-first design. Gas-free. Graceful degradation. Five model providers including a free local option.

### Impact as developer tooling

0pnMatrx is a reference implementation for AI-to-blockchain interaction on Ethereum L2. Developers can:

- Study 30 service implementations as patterns for their own projects
- Fork the gateway as a starting point for any AI agent platform on Base
- Use the graceful degradation patterns in their own blockchain applications
- Reference the ERC-4337 paymaster integration for gasless transaction architectures
- Build plugins and extensions using the SDK layer

### Impact as an end-user application

- MTRX iOS app provides a mobile interface to all 30 services
- Natural language removes every technical barrier
- Gas sponsorship removes every financial barrier
- The platform serves unbanked and underserved populations directly

---

## Field: Links

| Resource | URL |
|----------|-----|
| GitHub | https://github.com/ItsDardanRexhepi/0pnMatrx |
| License | MIT -- https://github.com/ItsDardanRexhepi/0pnMatrx/blob/main/LICENSE |
| NeoSafe Multisig | 0x46fF491D7054A6F500026B3E81f358190f8d8Ec5 |
| MTRX iOS App | Launching May 21, 2026 on the App Store |
| Roadmap | https://github.com/ItsDardanRexhepi/0pnMatrx/blob/main/ROADMAP.md |
| Contributing Guide | https://github.com/ItsDardanRexhepi/0pnMatrx/blob/main/CONTRIBUTING.md |
| Changelog | https://github.com/ItsDardanRexhepi/0pnMatrx/blob/main/CHANGELOG.md |

---

## Field: Builder

**Dardan Rexhepi** -- sole builder. Designed and built every component in approximately 40 days. Gateway, runtime, 30 blockchain services, three AI agents, nine cognitive protocols, security layer, 329-test suite, CI pipeline, Docker and Kubernetes deployment, iOS bridge, and all documentation. One person.

GitHub: [@ItsDardanRexhepi](https://github.com/ItsDardanRexhepi)

---

*What has been delivered is verifiable. What has been built is free. What has been created is open. That is the public good case.*
