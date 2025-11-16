# HyperYield Optimizer - Architecture Diagram

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          USER INTERFACE LAYER                            │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    React Frontend (Next.js)                       │  │
│  │                                                                    │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐    │  │
│  │  │Dashboard │  │  Deposit  │  │  Vaults  │  │  Performance │    │  │
│  │  │  Stats   │  │   Form    │  │   List   │  │   Charts     │    │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────────┘    │  │
│  │                                                                    │  │
│  │     Web3 Integration: wagmi + viem + RainbowKit                  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   │ Web3 RPC
                                   │
┌─────────────────────────────────────────────────────────────────────────┐
│                         SMART CONTRACT LAYER                             │
│                             (HyperEVM)                                   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                  HyperYieldVault (ERC-7540)                       │  │
│  │                                                                    │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐      │  │
│  │  │   Deposit    │  │   Redeem     │  │  Share Tracking  │      │  │
│  │  │   Requests   │  │   Requests   │  │  & Lock Period   │      │  │
│  │  └──────────────┘  └──────────────┘  └──────────────────────┘      │  │
│  │                                                                    │  │
│  │  Asset: USDC    │    Shares: hyUSDC    │    Lock: 1 day         │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                   │                                      │
│                                   │ Authorized                           │
│                                   │                                      │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                      VaultManager                                 │  │
│  │                                                                    │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐      │  │
│  │  │  Whitelist   │  │  Bot Auth    │  │   Rebalance      │      │  │
│  │  │  Management  │  │  System      │  │   Logic          │      │  │
│  │  └──────────────┘  └──────────────┘  └──────────────────────┘      │  │
│  │                                                                    │  │
│  │  GlueX Vaults: 5 whitelisted    │    Cooldown: 1 hour            │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   │ Bot Calls
                                   │
┌─────────────────────────────────────────────────────────────────────────┐
│                         OFF-CHAIN SERVICES                               │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │              HyperYield Optimizer Bot (Python)                    │  │
│  │                                                                    │  │
│  │  ┌──────────────────────────────────────────────────────────┐   │  │
│  │  │              Optimization Loop (every 5 min)               │   │  │
│  │  │                                                            │   │  │
│  │  │  1. Query GlueX Yields API for APY data                  │   │  │
│  │  │  2. Calculate Sharpe ratios for all vaults               │   │  │
│  │  │  3. Identify best risk-adjusted opportunity              │   │  │
│  │  │  4. Check if rebalancing threshold met                   │   │  │
│  │  │  5. Get swap route from GlueX Router API                 │   │  │
│  │  │  6. Execute rebalancing transaction                      │   │  │
│  │  │  7. Update internal state                                │   │  │
│  │  │  8. Sleep until next cycle                               │   │  │
│  │  └──────────────────────────────────────────────────────────┘   │  │
│  │                                                                    │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐      │  │
│  │  │  GlueX API   │  │  Web3 Client │  │  Transaction     │      │  │
│  │  │  Client      │  │  (web3.py)   │  │  Manager         │      │  │
│  │  └──────────────┘  └──────────────┘  └──────────────────────┘      │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   │ API Calls
                                   │
┌─────────────────────────────────────────────────────────────────────────┐
│                         EXTERNAL SERVICES                                │
│                                                                          │
│  ┌────────────────────────────┐    ┌─────────────────────────────────┐ │
│  │     GlueX Yields API       │    │     GlueX Router API             │ │
│  │                            │    │                                  │ │
│  │  • Historical APY          │    │  • Swap quotes                  │ │
│  │  • Diluted APY             │    │  • Optimal routes               │ │
│  │  • TVL data                │    │  • Transaction calldata         │ │
│  │  • Risk metrics            │    │  • Slippage protection          │ │
│  └────────────────────────────┘    └─────────────────────────────────┘ │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    Whitelisted GlueX Vaults                       │  │
│  │                                                                    │  │
│  │  1. 0xe25514992597786e07872e6c5517fe1906c0cadd                   │  │
│  │  2. 0xcdc3975df9d1cf054f44ed238edfb708880292ea                   │  │
│  │  3. 0x8f9291606862eef771a97e5b71e4b98fd1fa216a                   │  │
│  │  4. 0x9f75eac57d1c6f7248bd2aede58c95689f3827f7                   │  │
│  │  5. 0x63cf7ee583d9954febf649ad1c40c97a6493b1be                   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Deposit Flow
```
User → Frontend → HyperYieldVault.requestDeposit()
                         ↓
                  [Async Request Created]
                         ↓
                  User calls deposit()
                         ↓
                  [Shares Minted & Locked]
                         ↓
                  Bot monitors yield
```

### 2. Yield Monitoring Flow
```
Bot Timer (5 min) → Query GlueX Yields API
                           ↓
                    Get APY for all 5 vaults
                           ↓
                    Calculate Sharpe ratios
                           ↓
                    Identify best vault
                           ↓
                    Compare with current
                           ↓
                    Decision: Rebalance?
```

### 3. Rebalancing Flow
```
Bot Decision → Check cooldown period
                     ↓
               [If allowed]
                     ↓
            Get Router quote from GlueX
                     ↓
            Call VaultManager.executeRebalance()
                     ↓
            Contract withdraws from old vault
                     ↓
            Execute swap (if needed)
                     ↓
            Deposit to new vault
                     ↓
            Update allocation
                     ↓
            Emit Rebalanced event
```

### 4. Withdrawal Flow
```
User → Frontend → HyperYieldVault.requestRedeem()
                         ↓
                  [Shares Burned]
                         ↓
                  [Async Request Created]
                         ↓
                  User calls redeem()
                         ↓
                  [USDC Transferred]
```

## Key Components Interaction

```
┌─────────────┐
│    User     │
└──────┬──────┘
       │
       │ 1. Deposit
       ▼
┌─────────────────┐
│  Vault Contract │
└────────┬────────┘
         │
         │ 2. Holds funds
         ▼
    ┌────────┐
    │  USDC  │
    └────────┘
         │
         │ 3. Bot monitors
         ▼
┌──────────────────┐      4. Query      ┌──────────────┐
│  Optimizer Bot   │ ──────────────────→ │  GlueX API   │
└─────────┬────────┘                     └──────────────┘
          │
          │ 5. Better yield found
          │
          │ 6. Execute rebalance
          ▼
┌──────────────────┐
│ VaultManager     │
└─────────┬────────┘
          │
          │ 7. Move funds
          ▼
┌──────────────────┐
│  GlueX Vaults    │
│  (Whitelisted)   │
└──────────────────┘
```

## Security Architecture

```
┌────────────────────────────────────────────────┐
│           Security Layers                       │
├────────────────────────────────────────────────┤
│                                                 │
│  Layer 1: ERC-7540 Async Pattern               │
│  • Request-based flows                          │
│  • Share lock period                            │
│  • No flash loan vulnerabilities                │
│                                                 │
│  Layer 2: Access Control                        │
│  • Owner-only admin functions                   │
│  • Bot authorization system                     │
│  • Whitelist restrictions                       │
│                                                 │
│  Layer 3: Rate Limiting                         │
│  • Rebalancing cooldown (1 hour)               │
│  • Minimum rebalance amount                     │
│  • Gas cost optimization                        │
│                                                 │
│  Layer 4: Emergency Controls                    │
│  • Pausable functionality                       │
│  • Emergency withdrawal                         │
│  • Owner override capability                    │
│                                                 │
│  Layer 5: Code Quality                          │
│  • OpenZeppelin base contracts                  │
│  • Comprehensive testing                        │
│  • Reentrancy protection                        │
│  • Input validation                             │
│                                                 │
└────────────────────────────────────────────────┘
```

## Optimization Algorithm

```
┌────────────────────────────────────────────────────┐
│         Sharpe Ratio Optimization                   │
│                                                     │
│  For each vault V in WhitelistedVaults:            │
│                                                     │
│    1. Get APY(V) from GlueX Yields API             │
│    2. Get TVL(V) from GlueX Yields API             │
│    3. Calculate Risk(V) = f(APY, TVL)              │
│    4. Calculate Sharpe(V) = (APY - RFR) / Risk     │
│                                                     │
│  Best = argmax(Sharpe(V) for V in Vaults)          │
│                                                     │
│  If Sharpe(Best) - Sharpe(Current) > Threshold:    │
│    Execute Rebalance                                │
│                                                     │
│  Where:                                             │
│    RFR = Risk-Free Rate (default: 5%)              │
│    Threshold = Minimum improvement (default: 0.5%) │
│                                                     │
└────────────────────────────────────────────────────┘
```

## Technology Stack

```
┌──────────────────────────────────────────┐
│           Frontend                        │
│                                          │
│  • React 18                              │
│  • Next.js 14                            │
│  • Tailwind CSS                          │
│  • wagmi + viem                          │
│  • RainbowKit                            │
│  • Recharts                              │
│                                          │
├──────────────────────────────────────────┤
│        Smart Contracts                   │
│                                          │
│  • Solidity 0.8.20                       │
│  • Foundry                               │
│  • OpenZeppelin v4.9.3                   │
│  • ERC-7540 Standard                     │
│  • ERC-4626 Compatible Views             │
│                                          │
├──────────────────────────────────────────┤
│           Backend                        │
│                                          │
│  • Python 3.9+                           │
│  • web3.py 6.11.3                        │
│  • requests                              │
│  • eth-account                           │
│  • python-dotenv                         │
│                                          │
├──────────────────────────────────────────┤
│        Infrastructure                    │
│                                          │
│  • HyperEVM (Layer 1)                    │
│  • GlueX APIs (Yields + Router)          │
│  • Flat file structure                   │
│  • GitHub (code)                         │
│                                          │
└──────────────────────────────────────────┘
```

## Project File Structure

The project uses a **flat file structure** for simplicity:

```
gluex/
├── *.sol                  # All Solidity contracts in root
├── *.py                   # Python scripts in root  
├── pages/                 # Next.js pages
├── styles/                # CSS styles
├── public/                # Static assets
└── *.md                   # Documentation files
```

This structure makes it easy to navigate and understand the codebase while keeping all related files accessible.

## Deployment Architecture

```
┌─────────────────────────────────────────────┐
│            Production Setup                  │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  HyperEVM Mainnet                    │   │
│  │  • HyperYieldVault                   │   │
│  │  • VaultManager                      │   │
│  │  • Verified & Immutable              │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  Optimizer Bot (AWS EC2)             │   │
│  │  • High availability                 │   │
│  │  • Auto-restart on failure           │   │
│  │  • Monitoring & alerts               │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  Frontend (Vercel)                   │   │
│  │  • Next.js app                       │   │
│  │  • CDN distribution                  │   │
│  │  • Auto-scaling                      │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  Monitoring (Grafana)                │   │
│  │  • TVL tracking                      │   │
│  │  • APY monitoring                    │   │
│  │  • Bot health checks                 │   │
│  └─────────────────────────────────────┘   │
│                                             │
└─────────────────────────────────────────────┘
```

---

## Legend

- `→` : Data flow / Function call
- `↓` : Sequential step
- `┌─┐` : Component boundary
- `│ │` : Container
- `[ ]` : State / Process
- `< >` : Decision point
- `{ }` : Data structure

---

This architecture ensures:
- ✅ Security through ERC-7540 and access controls
- ✅ Efficiency through automated monitoring
- ✅ Reliability through tested code and fallbacks
- ✅ Scalability through modular design
- ✅ Transparency through on-chain operations
