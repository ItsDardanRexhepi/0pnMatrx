# CREDENTIALS_NEEDED — the owner's go-live checklist

Everything in the three repos is built to a **credential-ready, deploy-ready** point.
The only remaining work is *you* supplying the credentials/accounts below and running
the deploy. Nothing here ships with real secrets — every value is an env-var / config
placeholder. Default network is **Base Sepolia (testnet, chain 84532)**; nothing
touches mainnet, and the security layer stays in **OBSERVE** until you review it
(see `Morpheus-Security-System/ENFORCEMENT.md`).

Status legend used across the final report: **WORKING** (tested, runs) ·
**CREDENTIAL-GATED** (code complete, needs the secret to function) · **UNVERIFIED**
(built, provable only after deploy/review).

---

## 0. Repos & where config lives

| Repo | Visibility | Config source |
|---|---|---|
| `MTRX` (iOS app) | private | `Config/PendingCredentials.swift` (all blank by default) |
| `0pnMatrx` (platform) | public | `openmatrix.config.json` (copy from `.example`) + env vars |
| `Morpheus-Security-System` (security core) | private | env vars only (never committed) |

---

## 1. Chain core — unlocks ALL on-chain features (app + platform)

| Credential | Set in | Unlocks |
|---|---|---|
| **Base Sepolia RPC URL** | app `Network.rpcURL` · platform `blockchain.rpc_url` (env `OPENMATRIX_RPC_URL` / `BASE_RPC_URL`) | Every on-chain read/write, chain-id validation, balance reads. Get from Alchemy/Infura/QuickNode. |
| **Chain ID = 84532** | app `Network.chainID` · platform `blockchain.chain_id` (env `OPENMATRIX_CHAIN_ID`) | Chain validation; must match the RPC. (8453 = Base mainnet — leave on 84532 for testnet.) |
| **Deploy wallet private key** (funded with Sepolia ETH) | platform `blockchain.private_key` (env `OPENMATRIX_PRIVATE_KEY`) | `scripts/deploy_all.py` — deploying the platform contracts. |
| **Platform / NeoSafe wallet address** | platform `blockchain.platform_wallet` (env `OPENMATRIX_NEOSAFE_ADDRESS`) | Fee routing + EAS attestation recipient. |
| EAS contract | already defaulted to `0x4200000000000000000000000000000000000021` (Base predeploy) | On-chain attestations. No action unless you use a custom registry. |
| EAS schema UID | platform `blockchain.eas_schema` (env `OPENMATRIX_EAS_SCHEMA_UID`) | The attestation schema. Register once on Base Sepolia. |

> The app's Secure Enclave signs the **user's** wallet ops; the platform key only
> signs **platform-level** ops (deploys, sponsorship, attestations). The server never
> signs or moves user funds — non-custodial invariant.

## 2. Account abstraction / gas sponsorship — unlocks app on-chain execution (ERC-4337)

| Credential | Set in (MTRX `PendingCredentials`) | Unlocks |
|---|---|---|
| **Bundler URL** | `AccountAbstraction.bundlerURL` | `eth_sendUserOperation` submission. Blank → every Part-1 on-chain action returns "needs config". Pimlico/Alchemy/Stackup/Biconomy. |
| **EntryPoint address** | `AccountAbstraction.entryPointAddress` | UserOperation validation + submission. |
| **Account factory address** | `AccountAbstraction.accountFactoryAddress` | CREATE2 account deployment + counterfactual address. Must verify P-256/RIP-7212 (Secure Enclave signs secp256r1). |
| Paymaster address | `AccountAbstraction.paymasterAddress` | Gas sponsorship (optional — blank = user pays gas). |
| Paymaster signature endpoint | `AccountAbstraction.paymasterSignatureEndpoint` | Server-signed paymaster data. Blank = unsponsored (honest). |

## 3. Platform gateway + AI

| Credential | Set in | Unlocks |
|---|---|---|
| **Gateway API key** | platform `gateway.api_key` (env `OPENMATRIX_API_KEY` / `MTRX_API_KEY`) | Bearer auth for `/api/v1/*`. The app sends this. |
| **Anthropic API key** | env `ANTHROPIC_API_KEY` | The agents' model (Claude). Required for the ReAct loop to run. |
| OpenAI API key | env `OPENAI_API_KEY` | Optional fallback model. |
| App → gateway base URL | app `Backend.gatewayURL` → `https://api.openmatrix-ai.com` | Live service data + OTP endpoints. Blank = app demo data. |

## 4. The 14 protocol services (Part 2A) — each CREDENTIAL-GATED until its key is set

Set under `services.<name>.*` in `openmatrix.config.json`. Each service returns a
`not_deployed` response naming its exact missing key until configured.

| Service | Required key(s) | Unlocks |
|---|---|---|
| payment_channels | `services.payment_channels.endpoint` (Raiden node) + `.token_address` (+ `.contract_address` for on-chain fallback) | L2 state-channel open/route/close |
| compute | `services.compute.endpoint` + `.api_key` (Akash/Render/Gensyn) | Compute job submit, device rental, reward claim |
| mpc | `services.mpc.module_address` or `.endpoint` | Threshold sign / recovery / session keys |
| social_protocols | `services.social_protocols.{lens,farcaster,push}_*` keys | Lens/Farcaster/Push + token launches |
| advanced_governance | `services.advanced_governance.*_address` + Snapshot hub | veToken, quadratic vote, RetroPGF, bribes, delegation |
| oracles_plus | `services.oracles_plus.pyth_contract` (Base `0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a`) + hermes endpoint; RedStone/API3 keys | Pyth/RedStone/API3 feeds, Keeper jobs |
| tba | `services.tba.account_implementation` (registry is canonical `0x000000006551c19487814612e58FE06813775758`) | ERC-6551 token-bound accounts |
| storage | `services.storage.api_key` + `.endpoint` (Lighthouse/Ceramic) | Filecoin/Ceramic/OrbitDB |
| creator_platforms | `services.creator_platforms.{sound,mirror,paragraph}_api_key` | Sound/Mirror/Paragraph |
| kyc | `services.kyc.api_key` + `.secret_key` (Sumsub/Persona) | KYC/AML start, risk check, credential issue |
| restaking | `services.restaking.{eigenlayer,symbiotic,karak,lido,rocketpool}_*` addresses | Restaking + liquid staking |
| nft_lending | `services.nft_lending.pool_address` (BendDAO/NFTfi/Arcade) | NFT-backed loans |
| ccip | `services.ccip.router_address` (Base Sepolia CCIP router) + per-bridge addresses | CCIP/Hyperlane/Wormhole/Axelar/Stargate |
| auctions | `services.auctions.auction_address` + `.orderbook_address` | Dutch/English/sealed-bid + orderbook |

## 5. Security layer (private `Morpheus-Security-System`) — env only, never committed

| Credential | Env var | Unlocks |
|---|---|---|
| Owner Apple ID | `OWNER_APPLE_ID` | Owner verification (Apple ID + wallet + OTP). |
| Owner wallet | `OWNER_WALLET` | Owner verification (bound wallet). |
| Owner phone | `OWNER_PHONE_NUMBER` | Owner OTP delivery + breach alerts. |
| Twilio account SID | `TWILIO_ACCOUNT_SID` | SMS channel (OTP + breach alerts). |
| Twilio auth token | `TWILIO_AUTH_TOKEN` | SMS channel. |
| Twilio from number | `TWILIO_FROM_NUMBER` | SMS sender. |
| On-chain sink flag | `OPNMATRX_SECURITY_CHAIN_ENABLED` (default off) | Writes bans/breach as EAS attestations (reuses the chain-core signer). |
| Gate mode | `OPNMATRX_MORPHEUS_MODE` (default `observe`) | **Leave on `observe`.** ENFORCE only after human review — see `ENFORCEMENT.md`. |

## 6. Deploy assembly key — co-install public + private

| Credential | Where | Unlocks |
|---|---|---|
| Deploy key / fine-grained PAT with read on `Morpheus-Security-System` | deploy CI / image build | `pip install git+ssh://…/Morpheus-Security-System` so the seam binds real enforcement. Absent → platform runs with `SECURITY_BACKEND=noop` (safe, inert). See `Morpheus-Security-System/DEPLOY_ASSEMBLY.md`. |

## 7. Per-component contract addresses (app) — fill AFTER `deploy_all.py`

`scripts/deploy_all.py` deploys the platform contracts and writes
`deployment_manifest.json`. Copy each deployed address into the matching
`PendingCredentials.Components.*` field (nft, dao, stablecoin, identity,
agentIdentity, agenticPayments, rwa, oracle, privacy, contractConversion,
marketplace, deFiLending, …). Blank fields keep that component in honest
"needs config" mode.

---

## First testnet transaction — exact runbook (do this once credentials are in)

The full chain is wired in code: **app → gateway → agent → dispatcher → security
gate → tool → chain**. To exercise it end-to-end on Base Sepolia:

1. **Install both layers together** (per `DEPLOY_ASSEMBLY.md`): check out `0pnMatrx`,
   then `pip install -e .` of `Morpheus-Security-System` alongside it (deploy key).
   Confirm `python -c "import runtime.security as s; print(s.SECURITY_BACKEND)"`
   prints `morpheus_security` (not `noop`).
2. **Set the env** (sections 1, 3, 5): RPC, chain 84532, deploy key, platform wallet,
   `ANTHROPIC_API_KEY`, `OPENMATRIX_API_KEY`, owner + Twilio. Keep
   `OPNMATRX_MORPHEUS_MODE=observe`.
3. **Deploy the contracts:** `python -m scripts.deploy_all` (or `python scripts/deploy_all.py`).
   It compiles, deploys to Base Sepolia, attests each via EAS, and writes
   `deployment_manifest.json`. Copy addresses into `services.*` + the app's
   `PendingCredentials.Components.*`.
4. **Start the gateway:** it serves on `:18790` (front it with the
   `api.openmatrix-ai.com` ingress). `GET /health` to confirm.
5. **Fill the app config** (sections 1, 2, 3) in `PendingCredentials.swift`, build,
   run on a device (Secure Enclave) or simulator.
6. **First tx, two paths:**
   - *App-signed (non-custodial):* in the app, trigger a Part-1 action (e.g. an NFT
     mint or a stablecoin transfer of your own balance). It builds a UserOperation,
     Face ID signs in the Secure Enclave, the bundler submits. You get a real
     `userOpHash` — verify it on `sepolia.basescan.org`.
   - *Agent-routed:* `POST /chat` as Trinity with a read request → returns data.
     Ask for an execution → Trinity calls `request_execution` → the Morpheus gate
     evaluates (OBSERVE: logs, allows) → Neo executes via the service dispatcher →
     EAS attestation is written. Inspect the gateway logs for the
     `trinity->morpheus->neo` hand-off and the attestation tx.
7. **Confirm the boundary:** a `/chat` as Trinity asking to run a state-changing
   `platform_action` directly returns `[DENIED]` (she must use the hand-off) — proof
   the per-agent boundary is live.

> Everything above is **CREDENTIAL-GATED / UNVERIFIED** until you complete these
> steps: the code is connected, but a real end-to-end testnet transaction can only be
> confirmed after credentials are in and the gateway is deployed. The security-critical
> paths additionally need the human review in `ENFORCEMENT.md` before ENFORCE is set.
