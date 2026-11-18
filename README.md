# Agent ID Mint Guardian

A verification-first safety registry for BSC free mints, gated entirely by
Binance Agent ID. Only Agent ID holders can submit a safety report
(Safe / Risky / Scam) about a free mint or endorse another holder's report.
Anyone can read the reports.

- **Live dApp:** https://mint-guardian.netlify.app
- **Contract (BSC mainnet):** `0xEF4318fB3fDc9de236E8Fdc9C1Bdd2AA67e272F2`
- **BscScan (verified, Exact Match):** https://bscscan.com/address/0xEF4318fB3fDc9de236E8Fdc9C1Bdd2AA67e272F2#code

## How Agent ID gating works

Agent ID is an ERC721 on BNB Chain at
`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`. A wallet holds an Agent ID iff
`balanceOf(wallet) > 0`. The `MintGuardian` contract takes the Agent ID
registry address as a constructor argument and enforces the gate on-chain:

- `submitReport(mintContract, name, verdict, evidenceURI)` — Agent ID
  holders only, one report per holder per mint.
- `endorse(reportId)` — holders only, one per holder per report, no
  self-endorse.
- Reads are open to everyone: `reportsCount`, `getReport`,
  `reportsByMint`, `isAgentHolder`, `hasReported`, `hasEndorsed`.

No token, no payments, no minting — registry only.

## Why this exists

The registry is seeded from real verification work: 7,500+ BSC free mints
checked receipt-by-receipt since October 2026, including decoded scam
mechanics (non-standard ERC20, retained admin, fee splitters) and paid mints
falsely advertised as free. Every report links its evidence on BscScan.

## Repo layout

- `contracts/MintGuardian.sol` — the registry contract (Solidity 0.8.19,
  optimizer on, 200 runs). Deployed on BSC mainnet; owner is the Agent ID
  wallet `0xDAee9eF06d9f51254DDdcd592eF53A3BF1836383` (Agent ID `yako.ai`).
- `contracts/MockAgentId.sol` — mock Agent ID registry for local tests
  ONLY. Never deploy it to mainnet.
- `frontend/index.html` — the dApp page (self-contained). It checks Agent ID
  live over BSC public RPC and reads the on-chain registry. Serve it with any
  static host.

## Hackathon

Built for the Binance Wallet x BNB Chain Agent ID Hackathon (Nov–Dec 2026):
Best Agent ID dApp track. Submission deadline 9 Dec 2026.

## License

MIT. See `LICENSE`.
