# Ethereum Foundation Ecosystem Support Program (ESP) Application

**Project Name:** 0pnMatrx (OpenMatrix)

**Applicant:** Dardan Rexhepi

**Date:** April 10, 2026

**Requested Amount:** $75,000

**Category:** Community and Education / Developer Tooling

**Website:** https://github.com/ItsDardanRexhepi/0pnMatrx

**License:** MIT

---

## 1. Project Summary

0pnMatrx is a free, open-source AI agent platform that makes Ethereum's blockchain financial services accessible to people who have never used a wallet, written a transaction, or understood what gas means. Three AI agents translate natural-language requests into on-chain operations across 30 blockchain services running on Base (Ethereum L2). Everything is MIT-licensed. There is no token. There is no paywall. The default model provider is Ollama, which runs locally and costs nothing.

---

## 2. Public Good Case

### 2.1 What makes 0pnMatrx a public good

**Free and open source, permanently.** The entire platform -- gateway, runtime, 30 blockchain services, three AI agents, nine cognitive protocols, security architecture, test suite, deployment manifests, and documentation -- is MIT-licensed and published on GitHub. Anyone can fork it, run it, modify it, or build on it without permission or payment.

**No token, no rent-seeking.** 0pnMatrx does not have a governance token, a utility token, or any form of tokenized value capture from users. Revenue from platform fees routes to a transparent NeoSafe multisig (0x46fF491D7054A6F500026B3E81f358190f8d8Ec5) and funds infrastructure, not profit extraction.

**Gas sponsorship.** An ERC-4337 paymaster sponsors every user transaction. End users never pay gas. This removes the single largest friction point for non-crypto-native users entering the Ethereum ecosystem.

**Local-first AI.** The default model provider is Ollama, a free, local inference engine. Users are not required to send data to any external API. They can run the entire platform on their own hardware with zero ongoing cost.

**Graceful degradation.** Every service returns a well-formed response even when the blockchain is not configured. This means the platform works as an educational sandbox with no chain access, lowering the barrier for developers learning Ethereum.

### 2.2 What makes this a contribution to the Ethereum ecosystem

0pnMatrx is not a consumer product that happens to use Ethereum. It is an Ethereum access layer. Every user who sends a cross-border payment through Trinity, converts a rental agreement into a smart contract through natural language, or mints an NFT with automatic royalty enforcement is interacting with Ethereum infrastructure on Base -- they just do not need to know that.

The platform brings users to Ethereum who would otherwise never arrive. These are users who do not know what Solidity is, who have never installed MetaMask, who do not understand the difference between L1 and L2. They are the 1.7 billion unbanked adults, the freelancers without access to escrow, the creators without royalty enforcement, the small businesses without affordable governance tooling.

Every one of them becomes an Ethereum user the moment they open the MTRX app.

---

## 3. Alignment with ESP Values

### Strengthening Ethereum's ecosystem

0pnMatrx adds 30 production-grade services to the Ethereum ecosystem on Base. Each service is modular, tested (329 tests passing), and open source. Other developers can integrate individual services into their own projects, fork the entire platform, or use the gateway as a reference implementation for AI-to-blockchain interaction patterns.

### Improving Ethereum's usability

The entire point of 0pnMatrx is usability. The platform translates "Convert this rental agreement into a smart contract: monthly rent $2,000, 12-month term, $4,000 deposit, $100 late fee after 5 days" into compiled, audited, deployable Solidity. That is the usability improvement Ethereum needs to reach the next billion users.

### Increasing Ethereum's resilience

The platform supports five model providers (Ollama, OpenAI, Anthropic, NVIDIA, Gemini) and degrades gracefully when any external dependency is unavailable. This multi-provider, offline-capable architecture demonstrates how Ethereum tooling can be built to survive provider outages, API deprecations, and network disruptions.

### Advancing Ethereum's values

- **Decentralization.** Local-first architecture. No required cloud dependency.
- **Openness.** MIT license. No proprietary components in the public repository.
- **Accessibility.** Natural language interface. Gas-free transactions. Mobile-first design.
- **Permissionlessness.** No KYC, no credit check, no geographic restriction on platform access.

---

## 4. Technical Scope

### What has been built

- **Gateway:** REST and WebSocket API with rate limiting, structured logging, graceful shutdown, and OpenTelemetry integration.
- **30 Blockchain Services:** Agent Identity, Attestation, Brand Rewards, Cashback, Contract Conversion, Cross-Border Payments, DAO Management, Dashboard, DeFi, DEX, DID Identity, Dispute Resolution, Fundraising, Gaming, Governance, Insurance, IP Royalties, Loyalty, Marketplace, NFT Services, Oracle Gateway, Privacy, RWA Tokenization, Securities Exchange, Social, Stablecoin, Staking, Subscriptions, Supply Chain, x402 Payments.
- **3 AI Agents:** Neo (execution), Trinity (conversation), Morpheus (guidance).
- **9 Cognitive Protocols:** Jarvis, Ultron, Friday, Vision, Trajectory, Outcome Learning, Morpheus Triggers, Rexhepi Gate, Omega.
- **Security:** Glasswing 12-point audit layer, environment-only secrets, placeholder stripping, production validation.
- **Infrastructure:** Docker Compose, Kubernetes manifests, Caddy TLS proxy, Foundry contract tests, CI pipeline.
- **Test Suite:** 329 tests passing across 22 test files covering end-to-end flows, dispatch integration, graceful degradation, gateway, WebSocket, lifecycle, logging, metrics, and more.
- **Documentation:** README, ROADMAP, CONTRIBUTING, CHANGELOG, API reference, runbook.

### What the grant funds

| Item | Amount | Description |
|------|--------|-------------|
| Base mainnet deployment | $20,000 | Contract deployment, third-party security audit, paymaster funding |
| Developer education | $15,000 | Tutorial series, video walkthroughs, workshop materials showing how to build on Ethereum using 0pnMatrx as a reference |
| Community infrastructure | $10,000 | Documentation hosting, community forum, contributor onboarding |
| iOS launch support | $15,000 | App Store launch for MTRX, the mobile gateway to Ethereum for non-technical users |
| Operational sustainability | $15,000 | 12 months of hosting, RPC access, monitoring, and maintenance |

---

## 5. Educational Value

0pnMatrx serves as a comprehensive reference implementation for:

- **AI-to-blockchain interaction patterns.** The ReAct loop, tool-use architecture, and service dispatcher demonstrate how to build AI agents that interact with smart contracts safely and predictably.
- **Graceful degradation in blockchain applications.** Every service shows how to handle unconfigured chains, missing contracts, and network failures without breaking the user experience.
- **ERC-4337 paymaster integration.** The gas sponsorship implementation is a working example of account abstraction for gasless user transactions.
- **Multi-provider AI architecture.** Supporting Ollama, OpenAI, Anthropic, NVIDIA, and Gemini demonstrates how to build provider-agnostic AI systems.
- **Production deployment patterns.** Docker, Kubernetes, Caddy, structured logging, OpenTelemetry, and rate limiting provide a template for shipping Ethereum applications to production.

The nine example scripts in the repository walk developers through complete workflows: contract conversion, DeFi lending, NFT minting with royalties, parametric insurance, marketplace escrow, EAS attestation chains, revenue routing, oracle routing, and full user journeys.

---

## 6. Metrics

| Metric | Current |
|--------|---------|
| Tests passing | 329 |
| Blockchain services | 30 |
| Platform actions | 136 |
| AI agents | 3 |
| Cognitive protocols | 9 |
| Model providers | 5 |
| Build time (solo) | ~40 days |
| iOS launch | May 21, 2026 |

---

## 7. Team

**Dardan Rexhepi** -- sole builder. Designed and built every component of 0pnMatrx in approximately 40 days, including the gateway, runtime, all 30 blockchain services, three AI agents, nine cognitive protocols, test suite, CI pipeline, deployment infrastructure, and documentation.

---

## 8. Contact

**Dardan Rexhepi**
GitHub: [@ItsDardanRexhepi](https://github.com/ItsDardanRexhepi)

---

## 9. Links

| Resource | URL |
|----------|-----|
| GitHub | https://github.com/ItsDardanRexhepi/0pnMatrx |
| License | MIT |
| NeoSafe | 0x46fF491D7054A6F500026B3E81f358190f8d8Ec5 |
| MTRX iOS | Launching May 21, 2026 |

---

*0pnMatrx exists so that the technology built to democratize finance actually reaches the people it was designed for.*
