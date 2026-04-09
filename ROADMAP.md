# Roadmap

0pnMatrx is actively being built. Here is what is coming.

---

## Now in progress

- ~~Glasswing security audit layer~~ ✓ — 12-point vulnerability scanning on all contracts
- ~~Managed agent orchestration~~ ✓ — event-driven coordination, session lifecycle, hooks
- ~~Contract Conversion pipeline~~ ✓ — pseudocode/Solidity/Vyper → optimised Solidity → audit → compile → on-chain deploy → EAS attestation
- Unified Rexhepi Framework — full deployment
- Consumer Layer — public-facing protocol
- Local LLM support expansion
- Distributed agent coordination — remote agent support, cross-node HiveMind

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

## Post-launch

- Android app
- Full autonomy mode — Neo operates independently, no required human input
- Developer SDK public release

---

This roadmap is directional. Dates are targets, not guarantees. The build is live and moving every day.
