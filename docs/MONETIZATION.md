# 0pnMatrx Monetization Model

How 0pnMatrx generates revenue while keeping the free tier genuinely useful.

## Philosophy

The free tier is real. It will always exist and will always provide genuine access
to all 30 blockchain services with reasonable limits. We believe that making
blockchain accessible to everyone is more important than maximising revenue.

Revenue funds continued development, infrastructure costs, and the team.

## Revenue Streams

### 1. Subscription Tiers

| Tier | Price | Target |
|------|-------|--------|
| Free | $0/month | Everyone — personal use, learning, small projects |
| Pro | $4.99/month | Power users, small businesses, developers |
| Enterprise | $19.99/month | Teams, agencies, enterprises |

The free tier includes all 30 services with monthly limits (5 contract conversions,
3 NFT mints, $5k DeFi volume, etc.). Pro raises limits significantly. Enterprise
removes them entirely and adds team features.

A 3-day free trial is available for both paid tiers.

### 2. On-Chain Platform Fees

Small, transparent fees are applied to certain on-chain transactions (NFT mints,
contract deployments, marketplace sales). These fees:

- Are fully visible on-chain
- Route to the NeoSafe multisig at `0x46fF491D7054A6F500026B3E81f358190f8d8Ec5`
- Fund platform development, infrastructure, and contract audits
- Are disclosed to users before their first transaction of each type

### 3. Professional Services

- **Glasswing Security Audit** — $299 / $599 / $999 per contract
  Automated + manual smart contract security auditing

- **Smart Contract Conversion** — $499 one-time / $1,499/month (5) / $3,999/month unlimited
  Professional plain-English to Solidity conversion with audit included

### 4. Plugin Marketplace

Third-party developers can sell plugins that extend the platform. Revenue split:
**developers keep 90%, platform takes 10%**. Free plugins are always welcome.

### 5. Solidity Template Packs (Gumroad)

Pre-built, production-ready smart contract templates sold as digital products:
- DeFi Primitives Pack — $49
- Creator Economy Pack — $49
- Business Infrastructure Pack — $49
- All Three Packs — $119

### 6. Grants

The platform applies for ecosystem grants to fund public-good development:
- Base Ecosystem Fund
- Ethereum Foundation ESP
- Optimism RPGF
- Gitcoin Grants

### 7. GitHub Sponsors

Individual and corporate sponsorship tiers from $5/month to $2,500/month.
Sponsors get recognition, community access, and roadmap influence
proportional to their tier. All sponsorship income keeps the free tier
free forever.

**Expected at scale:** $500-5,000/month depending on community size.

### 8. Open Collective (Corporate Sponsors)

Transparent corporate sponsorship via Open Collective with invoices and
tax receipts. Tiers: Bronze ($500/mo), Silver ($1,000/mo), Gold ($2,500/mo),
Platinum ($5,000/mo).

Fund allocation: 40% infrastructure, 30% development, 20% iOS app, 10% community.

**Expected at scale:** $500-5,000/month.

### 9. Referral Program

Users earn free subscription months for referring friends:
- 1 month free per Pro referral
- 2 months free per Enterprise referral
- Referred users get an extended trial

This is a growth mechanism that reduces customer acquisition cost, not a
direct revenue stream. It increases lifetime value by bringing in users
who convert at higher rates.

### 10. Metered API Pricing

Usage-based pricing for high-volume API consumers above Enterprise tier:
- Growth ($49.99/mo + $0.005/call overage, 10k included)
- Scale ($199.99/mo + $0.002/call overage, 100k included)
- Infrastructure ($499.99/mo + $0.001/call overage, 500k included)

**Expected at scale:** $1,000-25,000/month from 5-50 metered customers.

### 11. Protocol Referral Fees

DeFi protocols pay integrators who route transactions through them:
- Uniswap V3: 25bps (0.25%) interface fee on swaps
- Aave V3: referral rewards on loans
- 1inch: referral program on aggregated swaps

These fees are collected automatically when users make DeFi transactions
through the platform, routed to the NeoSafe multisig. Only active when
blockchain is deployed and configured.

**Expected at scale:** Scales with DeFi volume. At $1M monthly volume: ~$2,500/month.

### 12. Glasswing Security Badges

Verifiable proof that a smart contract passed a Glasswing audit:
- First year included with Enterprise audit ($999)
- Annual renewal: $99/year
- On-chain verification via EAS attestation
- Embeddable widget for project websites

**Expected at scale:** $400-5,000/month from 50-600 active badges.

### 13. Certification Program

Professional certifications backed by on-chain attestations:
- Certified Developer ($149, valid 2 years)
- Certified Security Auditor ($249, valid 1 year)
- Enterprise Architect ($399, valid 2 years)

Proves real expertise with timed exams and substantive questions.

**Expected at scale:** $1,000-5,000/month.

### 14. Educational Content (Gumroad)

Three comprehensive courses sold as digital products:
- Introduction to 0pnMatrx ($49)
- Smart Contract Security ($79)
- DeFi from Scratch ($49)
- All three bundle ($149)

Course content is open source; the guided learning experience is the
paid value.

**Expected at scale:** $500-3,000/month.

## Total Revenue Projections

| Users | Conservative MRR | Projected ARR |
|-------|-----------------|---------------|
| 1,000 | $9,328 | $111,936 |
| 10,000 | $50,000-80,000 | $600,000-960,000 |

See `docs/REVENUE_STREAMS.md` for the complete per-stream breakdown.

## Ownership & Revenue Routing

All revenue routes through the NeoSafe multisig wallet. The multisig ensures
transparent fund management with on-chain accountability.

**NeoSafe Address:** `0x46fF491D7054A6F500026B3E81f358190f8d8Ec5`

## What Will Never Change

1. The free tier will always exist
2. Core functionality will never be paywalled
3. The platform will always be open source (MIT)
4. Platform fees will always be transparent and on-chain
5. No token, no speculative asset, no ICO
