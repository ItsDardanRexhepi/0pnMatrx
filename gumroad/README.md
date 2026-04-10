# 0pnMatrx Solidity Template Packs

Production-ready, security-audited Solidity smart contract templates. Each contract is complete, well-documented, and ready to deploy.

## Packs

### DeFi Primitives Pack
Core decentralized finance building blocks:
- **CollateralizedLoan.sol** — Lending with liquidation mechanics
- **RevenueSharing.sol** — Automatic revenue splits
- **Vesting.sol** — Token vesting with cliff and linear release
- **P2PLending.sol** — Peer-to-peer lending with reputation
- **YieldAggregator.sol** — Yield routing across strategies

### Creator Economy Pack
Tools for digital creators and communities:
- **RoyaltyNFT.sol** — ERC-721 with enforced EIP-2981 royalties
- **CreatorDAO.sol** — Fan community governance
- **IPRegistry.sol** — On-chain intellectual property registration
- **ContentSubscription.sol** — Recurring content payments
- **Crowdfund.sol** — Milestone-based crowdfunding

### Business Infrastructure Pack
Enterprise-grade smart contracts:
- **MultiSigEscrow.sol** — N-of-M multi-party escrow
- **ServiceAgreement.sol** — Milestone-based service contracts
- **RealEstateEscrow.sol** — Property sale with legal bridge
- **SupplyChainRegistry.sol** — Product provenance tracking
- **EmploymentContract.sol** — On-chain employment with auto-pay

## Deployment

All contracts are compatible with Hardhat, Foundry, or Remix.

### With Hardhat

```bash
npm install --save-dev hardhat @openzeppelin/contracts
npx hardhat compile
npx hardhat deploy --network base
```

### With Foundry

```bash
forge install OpenZeppelin/openzeppelin-contracts
forge build
forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/Contract.sol:ContractName
```

## License

MIT License — commercial use permitted. Built by 0pnMatrx.
