# HyperYield Optimizer - Technical Documentation

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Smart Contracts](#smart-contracts)
3. [Backend Service](#backend-service)
4. [Frontend Application](#frontend-application)
5. [GlueX Integration](#gluex-integration)
6. [Security Considerations](#security-considerations)
7. [Testing Guide](#testing-guide)
8. [Deployment Guide](#deployment-guide)

## Architecture Overview

HyperYield Optimizer is a decentralized yield optimization protocol that combines:

- **ERC-7540 Async Vault**: Secure custody with async deposit/redemption flows
- **GlueX Yields API**: Real-time APY monitoring across lending protocols
- **GlueX Router API**: Optimal swap execution for rebalancing
- **Off-chain Optimizer Bot**: Monitors yields and triggers rebalancing

### Components

```
┌─────────────────────────────────────────────────────────┐
│                 User Interface (React)                   │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ Web3 Connection
                     │
┌────────────────────▼────────────────────────────────────┐
│           HyperYieldVault (ERC-7540)                     │
│  - Async Deposits/Redemptions                            │
│  - Share Lock Period (1 day)                             │
│  - Pausable Emergency Controls                           │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ Rebalancing
                     │
┌────────────────────▼────────────────────────────────────┐
│              VaultManager Contract                       │
│  - Whitelist Management                                  │
│  - Rebalancing Logic                                     │
│  - Cooldown Periods                                      │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ Bot Authorization
                     │
┌────────────────────▼────────────────────────────────────┐
│           Optimizer Bot (Python)                         │
│  - Yield Monitoring                                      │
│  - GlueX API Integration                                 │
│  - Sharpe Ratio Calculation                              │
│  - Transaction Execution                                 │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ API Calls
                     │
┌────────────────────▼────────────────────────────────────┐
│              GlueX Protocol                              │
│  - Yields API (APY Data)                                 │
│  - Router API (Swap Execution)                           │
└──────────────────────────────────────────────────────────┘
```

## Smart Contracts

### HyperYieldVault.sol

**Purpose**: Main vault contract implementing ERC-7540 standard

**Key Features**:
- Asynchronous deposit requests with ERC-7540 compliance
- Asynchronous redemption requests
- Share lock period (1 day) to prevent flash loan attacks
- ERC-4626 compatibility for core vault functions
- Emergency pause mechanism

**State Variables**:
```solidity
IERC20 public immutable asset;        // Underlying asset (USDC)
address public vaultManager;           // Authorized rebalancer
uint256 public requestNonce;           // Request ID counter
uint256 public constant SHARE_LOCK_PERIOD = 1 days;
```

**Key Functions**:

1. **requestDeposit(uint256 assets, address controller, address owner)**
   - Creates an async deposit request
   - Transfers assets from owner to vault
   - Returns unique requestId
   - Emits DepositRequested event

2. **deposit(uint256 assets, address receiver, address controller)**
   - Claims a claimable deposit request
   - Mints shares to receiver
   - Applies share lock period
   - Emits DepositClaimed event

3. **requestRedeem(uint256 shares, address controller, address owner)**
   - Creates an async redemption request
   - Burns shares from owner
   - Returns unique requestId
   - Emits RedeemRequested event

4. **redeem(uint256 shares, address receiver, address controller)**
   - Claims a claimable redemption request
   - Transfers assets to receiver
   - Emits RedeemClaimed event

### VaultManager.sol

**Purpose**: Manages vault whitelisting and rebalancing operations

**Key Features**:
- Whitelist of approved vaults (includes 5 GlueX vaults)
- Bot authorization system
- Rebalancing cooldown (1 hour)
- Minimum rebalance amount (1000 USDC)
- Emergency withdrawal

**State Variables**:
```solidity
HyperYieldVault public immutable hyperYieldVault;
mapping(address => bool) public whitelistedVaults;
address[] public gluexVaults;              // 5 GlueX vaults
VaultAllocation public currentAllocation;
uint256 public constant MIN_REBALANCE_AMOUNT = 1000e6;
uint256 public constant REBALANCE_COOLDOWN = 1 hours;
```

**Key Functions**:

1. **executeRebalance(...)**
   - Executed by authorized bots
   - Withdraws from current vault
   - Executes swap via GlueX Router (if needed)
   - Deposits into target vault
   - Updates allocation tracking

2. **whitelistVault(address vault)**
   - Owner-only function
   - Adds vault to whitelist
   - Prevents duplicate entries

3. **authorizeBot(address bot)**
   - Owner-only function
   - Authorizes bot to execute rebalancing

## Backend Service

### Architecture

The Python backend consists of three main modules:

1. **gluex_client.py**: GlueX API client
2. **optimizer.py**: Main optimization logic
3. **yield_monitor.py**: Continuous yield monitoring (optional)

### GlueXClient Class

**Methods**:

1. **get_historical_apy(lp_token_address, chain)**
   - Fetches historical APY data
   - Returns APY, TVL, and other metrics

2. **get_diluted_apy(lp_token_address, amount, chain)**
   - Calculates diluted APY for given deposit amount
   - Accounts for liquidity impact

3. **get_router_quote(...)**
   - Gets swap quote from GlueX Router
   - Returns optimal route and calldata

4. **find_best_yield_opportunity(vault_addresses, amount, optimize_for)**
   - Compares yields across multiple vaults
   - Calculates Sharpe ratios
   - Returns best opportunity

### HyperYieldOptimizer Class

**Optimization Cycle**:

```
1. Get current allocation from contract
   ↓
2. Query GlueX Yields API for all vaults
   ↓
3. Calculate Sharpe ratios
   ↓
4. Identify best opportunity
   ↓
5. Check if rebalancing is worthwhile
   ↓
6. Execute rebalancing transaction
   ↓
7. Wait for cooldown period
   ↓
8. Repeat
```

**Decision Logic**:

```python
def should_rebalance(current_vault, current_apy, new_vault, new_apy):
    # Don't rebalance to same vault
    if current_vault == new_vault:
        return False
    
    # Check APY improvement threshold
    if (new_apy - current_apy) < MIN_APY_DIFF:
        return False
    
    # Check cooldown period
    if not can_rebalance():
        return False
    
    return True
```

**Sharpe Ratio Calculation**:

```python
sharpe_ratio = (apy - risk_free_rate) / risk_score
```

Where:
- `apy`: Annual percentage yield
- `risk_free_rate`: Baseline return (default: 5%)
- `risk_score`: Calculated from TVL and APY volatility

## Frontend Application

### Technology Stack

- **Framework**: React 18 / Next.js 14
- **Web3**: wagmi + viem + RainbowKit
- **Styling**: Tailwind CSS
- **Charts**: Recharts
- **Icons**: Lucide React

### Key Components

1. **Dashboard.jsx**
   - Main application view
   - Displays TVL, APY, earnings
   - Vault opportunity cards

2. **DepositForm.jsx**
   - Handles user deposits
   - Connects to wallet
   - Creates async deposit requests

3. **VaultList.jsx**
   - Shows whitelisted vaults
   - Real-time APY data
   - Risk indicators

4. **HistoryView.jsx**
   - Rebalancing history
   - Performance charts
   - Transaction logs

## GlueX Integration

### Yields API

**Endpoint**: `POST https://yield-api.gluex.xyz/historical-apy`

**Request**:
```json
{
  "lp_token_address": "0xe25514992597786e07872e6c5517fe1906c0cadd",
  "chain": "hyperevm"
}
```

**Response**:
```json
{
  "apy": 12.5,
  "tvl": 5200000,
  "timestamp": 1700000000
}
```

### Router API

**Endpoint**: `POST https://router-api.gluex.xyz/quote`

**Request**:
```json
{
  "chain": "hyperevm",
  "inputToken": "0x...",
  "outputToken": "0x...",
  "inputAmount": "1000000000",
  "inputSender": "0x...",
  "outputReceiver": "0x...",
  "slippage": 0.5
}
```

**Response**:
```json
{
  "statusCode": 200,
  "result": {
    "outputAmount": "998500000",
    "minOutputAmount": "995500000",
    "router": "0x...",
    "calldata": "0x..."
  }
}
```

## Security Considerations

### Smart Contract Security

1. **ERC-7540 Async Pattern**
   - Prevents flash loan attacks
   - Share lock period adds time buffer
   - Request-based flows avoid reentrancy

2. **Access Control**
   - Owner-only admin functions
   - Bot authorization system
   - Vault whitelist restrictions

3. **Emergency Controls**
   - Pausable functionality
   - Emergency withdrawal
   - Owner can revoke bot access

4. **Rate Limiting**
   - Rebalancing cooldown (1 hour)
   - Minimum rebalance amount
   - Prevents excessive gas costs

### Backend Security

1. **Private Key Management**
   - Environment variables only
   - Never commit to repository
   - Consider hardware wallet/HSM in production

2. **API Security**
   - HMAC signature verification
   - Rate limiting
   - Input validation

3. **Error Handling**
   - Graceful failure recovery
   - Transaction retry logic
   - Monitoring and alerts

## Testing Guide

### Smart Contract Tests

```bash
cd contracts
forge test -vv
```

**Test Coverage**:
- Deposit request flow
- Redemption request flow
- Rebalancing logic
- Access control
- Edge cases

### Backend Tests

```bash
cd backend
pytest tests/ -v
```

**Test Coverage**:
- GlueX API client
- Yield calculations
- Sharpe ratio logic
- Transaction building

### Integration Tests

```bash
npm run test:integration
```

**Test Scenarios**:
- End-to-end deposit flow
- Rebalancing trigger
- Multi-vault comparison
- Error handling

## Deployment Guide

### Step 1: Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install Node.js dependencies
cd frontend && npm install

# Install Python dependencies
cd backend && pip install -r requirements.txt
```

### Step 2: Configure Environment

```bash
cp .env.example .env
# Edit .env with your values
```

### Step 3: Deploy Contracts

```bash
cd contracts
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $HYPEREVM_RPC_URL \
  --broadcast \
  --verify
```

### Step 4: Update Configuration

Add deployed addresses to `.env`:
```
VAULT_ADDRESS=0x...
MANAGER_ADDRESS=0x...
```

### Step 5: Start Services

```bash
# Terminal 1: Backend
cd backend && python optimizer.py

# Terminal 2: Frontend
cd frontend && npm run dev
```

### Step 6: Verify Deployment

1. Check vault is deployed correctly
2. Verify GlueX vaults are whitelisted
3. Confirm bot authorization
4. Test deposit flow

## Monitoring and Maintenance

### Key Metrics to Monitor

1. **Vault Metrics**
   - Total Value Locked (TVL)
   - Current APY
   - Number of depositors

2. **Performance Metrics**
   - Rebalancing frequency
   - APY improvements
   - Gas costs
   - Sharpe ratio trend

3. **Operational Metrics**
   - Bot uptime
   - API success rate
   - Transaction success rate

### Maintenance Tasks

1. **Daily**
   - Check bot logs
   - Verify rebalancing execution
   - Monitor gas costs

2. **Weekly**
   - Review performance metrics
   - Analyze yield opportunities
   - Update whitelisted vaults if needed

3. **Monthly**
   - Security audit review
   - Update dependencies
   - Optimize parameters

## Troubleshooting

### Common Issues

**Issue**: Bot not rebalancing
- Check cooldown period
- Verify APY difference threshold
- Confirm bot authorization
- Check RPC connection

**Issue**: Transactions failing
- Check gas price
- Verify contract approval
- Check account balance
- Review error logs

**Issue**: Low APY
- Verify GlueX vault addresses
- Check API connectivity
- Review yield data sources

## Future Improvements

1. **Multi-Asset Support**: Extend beyond USDC
2. **Advanced Strategies**: Leverage farming, delta-neutral
3. **Social Features**: Leaderboards, performance sharing
4. **Mobile App**: Native iOS/Android apps
5. **DAO Governance**: Community-driven parameter updates

## References

- [ERC-7540 Standard](https://eips.ethereum.org/EIPS/eip-7540)
- [GlueX Documentation](https://docs.gluex.xyz)
- [Hyperliquid Docs](https://hyperliquid.gitbook.io)
- [BoringVault Architecture](https://github.com/Se7en-Seas/boring-vault)
