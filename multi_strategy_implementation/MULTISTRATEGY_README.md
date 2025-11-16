# MultiStrategyVault - EIP-7540 Implementation

A production-ready, advanced implementation of EIP-7540 (Asynchronous ERC-4626) that automatically distributes deposits across multiple yield-generating strategies with automatic rebalancing, performance tracking, and comprehensive risk management.

## 🎯 What is MultiStrategyVault?

MultiStrategyVault extends the basic ERC7540 vault to support **multiple yield strategies**, allowing vault operators to:

- **Diversify risk** across different protocols and strategies
- **Optimize yields** by allocating to the best-performing strategies
- **Automatically rebalance** when allocations drift from targets
- **Track performance** with detailed metrics and history
- **Manage fees** with performance and management fee structures
- **Control risk** with reserves, emergency controls, and withdrawal queues

## 📦 Package Contents

```
📁 MultiStrategyVault Implementation
├── 📄 MultiStrategyVault.sol           # Main vault contract (29KB)
├── 📄 StrategyImplementations.sol       # Example strategies (13KB)
├── 📄 MultiStrategyVaultTest.sol        # Comprehensive tests (18KB)
├── 📄 MULTISTRATEGY_GUIDE.md           # Complete usage guide (17KB)
├── 📜 scripts/deploy-multistrategy.js   # Deployment script
└── 📄 README.md                         # This file
```

## 🚀 Quick Start

### 1. Installation

```bash
npm install @openzeppelin/contracts
```

### 2. Deploy the Vault

```javascript
// Deploy vault
const vault = await MultiStrategyVault.deploy(
    assetAddress,           // USDC, DAI, etc.
    "Multi-Strategy Vault", // Vault name
    "msVault",             // Symbol
    operatorAddress,       // Who can fulfill requests
    3600,                  // 1 hour fulfillment delay
    feeRecipientAddress    // Treasury/DAO address
);
```

### 3. Add Strategies

```javascript
// Add a lending strategy with 40% allocation
await vault.addStrategy(
    lendingStrategyAddress,
    4000,              // 40% allocation (4000 basis points)
    parseEther("100"), // Minimum 100 tokens per deposit
    0                  // No maximum (unlimited)
);

// Add a staking strategy with 30% allocation
await vault.addStrategy(
    stakingStrategyAddress,
    3000,              // 30% allocation
    parseEther("100"),
    0
);
```

### 4. User Deposits (Async Flow)

```javascript
// Step 1: User requests deposit
await asset.approve(vault.address, amount);
await vault.requestDeposit(amount, userAddress, userAddress);

// Step 2: Operator fulfills (allocates to strategies)
await vault.fulfillDepositWithStrategies(userAddress, amount);
// This automatically:
// - Keeps 5% as reserves
// - Distributes to strategies by target allocation
// - Lends 38% to lending strategy
// - Stakes 28.5% to staking strategy
// - Keeps 5% liquid for withdrawals

// Step 3: User claims shares
await vault.deposit(amount, userAddress);
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  MultiStrategyVault                     │
│                                                         │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Deposits  │  │  Redemptions │  │  Rebalancing │ │
│  │   (Async)   │  │    (Async)   │  │   (Auto)     │ │
│  └──────┬──────┘  └──────┬───────┘  └──────┬───────┘ │
│         │                │                  │          │
│         └────────────────┴──────────────────┘          │
│                          │                             │
│                ┌─────────▼─────────┐                  │
│                │  Strategy Manager │                  │
│                │  - Allocations    │                  │
│                │  - Performance    │                  │
│                │  - Withdrawals    │                  │
│                └─────────┬─────────┘                  │
└──────────────────────────┼────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
┌───────▼────────┐ ┌───────▼────────┐ ┌──────▼─────────┐
│ Strategy A     │ │ Strategy B     │ │ Strategy C     │
│ (Lending)      │ │ (Staking)      │ │ (Farming)      │
│                │ │                │ │                │
│ APY: 5%        │ │ APY: 8%        │ │ APY: 12%       │
│ Risk: Low      │ │ Risk: Medium   │ │ Risk: High     │
│ Alloc: 40%     │ │ Alloc: 30%     │ │ Alloc: 20%     │
└────────────────┘ └────────────────┘ └────────────────┘
```

## 🎮 Core Features

### 1. Multi-Strategy Management

Add up to 20 strategies with individual configurations:

```solidity
struct Strategy {
    IStrategy strategyContract;  // Strategy implementation
    uint256 targetAllocation;    // Target % (in basis points)
    uint256 currentAllocation;   // Actual current %
    uint256 totalDeposited;      // Total assets deposited
    uint256 totalShares;         // Strategy shares held
    uint256 minDeposit;          // Minimum deposit size
    uint256 maxDeposit;          // Maximum deposit size
    bool active;                 // Is strategy active?
    bool acceptingDeposits;      // Accepting new deposits?
    bool acceptingWithdrawals;   // Accepting withdrawals?
}
```

### 2. Automatic Allocation

When deposits are fulfilled, assets are automatically distributed:

```javascript
// Deposit 10,000 tokens with:
// Strategy 1: 40% target → receives 3,800 tokens
// Strategy 2: 30% target → receives 2,850 tokens  
// Strategy 3: 20% target → receives 1,900 tokens
// Reserves:    5% ratio  → keeps 500 tokens
// = 9,050 deployed + 500 reserves = 9,550 (10,000 - 450 deployed elsewhere)
```

### 3. Smart Rebalancing

Automatically rebalances when allocations drift:

```javascript
// Set rebalancing parameters
await vault.setRebalanceParameters(
    500,   // 5% deviation triggers rebalance
    86400  // Can rebalance once per day
);

// Trigger rebalance (manual or automated)
await vault.rebalance();
```

**Rebalancing Logic:**
1. Check if any strategy deviates >5% from target
2. Withdraw excess from over-allocated strategies
3. Deposit to under-allocated strategies
4. Update allocations

### 4. Performance Tracking

Track strategy performance over time:

```javascript
// Record performance snapshot
await vault.recordPerformance();

// Get historical data
const history = await vault.getStrategyHistory(strategyId);

// Each snapshot includes:
// - Timestamp
// - Total assets
// - Current allocation %
// - Profit/Loss since last snapshot
```

### 5. Fee Management

Two types of fees:
- **Performance Fees** (default 10%): Charged on profits
- **Management Fees** (default 2% annual): Charged on AUM

```javascript
// Collect fees (mints shares to fee recipient)
await vault.collectFees();

// Update fee parameters
await vault.setFees(
    1500,              // 15% performance fee
    250,               // 2.5% management fee  
    feeRecipientAddr   // Treasury address
);
```

### 6. Risk Management

Multiple safety mechanisms:

```javascript
// 1. Reserve Ratio - Keep % liquid
await vault.setReserveRatio(1000); // 10% reserves

// 2. Withdrawal Queue - Order for withdrawals
await vault.setWithdrawalQueue([2, 1, 0]); // Withdraw from strategy 2 first

// 3. Emergency Shutdown - Withdraw everything
await vault.emergencyShutdownVault();

// 4. Pause Individual Strategy
await vault.pauseStrategy(strategyId, true);
```

## 📊 Example Strategies

The package includes 5 example strategy implementations:

### 1. MockLendingStrategy
- **Type**: Lending/Fixed Income
- **APY**: 5%
- **Risk**: Low
- **Use Case**: Aave, Compound-style lending

### 2. MockStakingStrategy
- **Type**: Staking
- **APY**: 8%
- **Risk**: Medium
- **Lockup**: 7 days
- **Use Case**: Liquid staking tokens

### 3. MockYieldFarmStrategy
- **Type**: Yield Farming
- **APY**: 12%
- **Risk**: Higher
- **Features**: Impermanent loss simulation
- **Use Case**: AMM liquidity provision

### 4. ConservativeStrategy
- **Type**: Low Risk
- **APY**: 2%
- **Use Case**: Capital preservation

### 5. AggressiveStrategy
- **Type**: High Risk
- **APY**: 20%
- **Volatility**: 5%
- **Use Case**: Maximizing returns

## 💼 Real-World Usage Example

```javascript
// Scenario: Treasury Management for a DAO

// 1. Deploy vault for USDC
const vault = await deployMultiStrategyVault({
    asset: USDC_ADDRESS,
    name: "DAO Treasury Vault",
    operator: TREASURY_MULTISIG,
    feeRecipient: DAO_TREASURY
});

// 2. Add diversified strategies
await vault.addStrategy(aaveStrategy, 3000, minAmount, 0);     // 30% Aave
await vault.addStrategy(compoundStrategy, 2000, minAmount, 0); // 20% Compound  
await vault.addStrategy(stakingStrategy, 2000, minAmount, 0);  // 20% Staking
await vault.addStrategy(farmStrategy, 2000, minAmount, 0);     // 20% Farming
// 10% kept as reserves

// 3. Deposit treasury funds
await usdc.approve(vault.address, treasuryAmount);
await vault.requestDeposit(treasuryAmount, dao, dao);

// 4. Operator fulfills (distributes to strategies)
await vault.fulfillDepositWithStrategies(dao, treasuryAmount);

// 5. DAO claims shares
await vault.deposit(treasuryAmount, dao);

// 6. Auto-rebalance weekly
// Set up keeper/automation:
setInterval(async () => {
    if (await needsRebalancing()) {
        await vault.rebalance();
    }
}, 7 * 24 * 60 * 60 * 1000); // Weekly

// 7. Collect fees monthly
setInterval(async () => {
    await vault.collectFees();
}, 30 * 24 * 60 * 60 * 1000); // Monthly
```

## 🔧 Strategy Interface

All strategies must implement `IStrategy`:

```solidity
interface IStrategy {
    function deposit(uint256 amount) external returns (uint256 shares);
    function withdraw(uint256 shares) external returns (uint256 amount);
    function totalAssets() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function asset() external view returns (address);
}
```

### Creating a Custom Strategy

```solidity
contract MyStrategy is BaseStrategy {
    constructor(
        IERC20 asset_,
        address vault_
    ) BaseStrategy(asset_, "My Strategy", "MYS", vault_) {}

    function deposit(uint256 amount) 
        external 
        override 
        onlyVault 
        returns (uint256 shares) 
    {
        // 1. Transfer assets from vault
        asset.safeTransferFrom(msg.sender, address(this), amount);
        
        // 2. Deploy to your protocol
        // ... your logic ...
        
        // 3. Calculate and mint shares
        shares = calculateShares(amount);
        _mint(msg.sender, shares);
        
        return shares;
    }

    function withdraw(uint256 shares) 
        external 
        override 
        onlyVault 
        returns (uint256 amount) 
    {
        // 1. Burn shares
        _burn(msg.sender, shares);
        
        // 2. Withdraw from your protocol
        // ... your logic ...
        
        // 3. Transfer assets back to vault
        amount = calculateAssets(shares);
        asset.safeTransfer(msg.sender, amount);
        
        return amount;
    }

    function totalAssets() public view override returns (uint256) {
        // Return total value in strategy
        return calculateTotalValue();
    }
}
```

## 📈 Monitoring & Analytics

### Key Metrics to Track

```javascript
// 1. Total Value Locked
const tvl = await vault.totalAssets();

// 2. Strategy Allocations
for (let i = 0; i < numStrategies; i++) {
    const strategy = await vault.getStrategy(i);
    console.log(`Strategy ${i}: ${strategy.currentAllocation / 100}%`);
}

// 3. Performance
const totalStrategyAssets = await vault.getStrategyTotalAssets();
const profitLoss = totalStrategyAssets - initialDeposits;

// 4. Share Price
const sharePrice = tvl / await vault.totalSupply();

// 5. Fee Revenue
const feeShares = await vault.balanceOf(feeRecipient);
const feeValue = feeShares * sharePrice;
```

### Events to Monitor

```javascript
vault.on("StrategyAdded", (strategyId, strategy, allocation) => {
    console.log(`New strategy ${strategyId} added with ${allocation/100}% allocation`);
});

vault.on("Rebalanced", (timestamp, allocations) => {
    console.log("Vault rebalanced at", new Date(timestamp * 1000));
});

vault.on("StrategyDeposit", (strategyId, assets, shares) => {
    console.log(`Deposited ${formatEther(assets)} to strategy ${strategyId}`);
});

vault.on("EmergencyShutdown", (caller) => {
    // CRITICAL ALERT
    sendAlert("EMERGENCY: Vault shutdown by " + caller);
});
```

## 🛡️ Security Features

### 1. Access Control
- Owner: Add/remove strategies, update parameters
- Operator: Fulfill requests, trigger rebalancing
- Users: Request deposits/redemptions, claim assets

### 2. Emergency Controls
- Per-strategy pause
- Full vault emergency shutdown
- Manual strategy withdrawals

### 3. Validation
- Strategy asset matching
- Allocation limits (max 100%)
- Minimum/maximum deposit constraints
- Slippage protection

### 4. Reentrancy Protection
- NonReentrant modifiers on critical functions
- Checks-Effects-Interactions pattern

## 🧪 Testing

Run the comprehensive test suite:

```bash
# Using Foundry
forge test

# Using Hardhat  
npx hardhat test

# Specific test file
npx hardhat test test/MultiStrategyVault.test.js
```

**Test Coverage:**
- ✅ Strategy management (add/update/remove)
- ✅ Deposit flow with allocation
- ✅ Redemption with withdrawals
- ✅ Multi-user deposits
- ✅ Rebalancing logic
- ✅ Fee collection
- ✅ Performance tracking
- ✅ Emergency shutdown
- ✅ Reserve management
- ✅ Partial redemptions
- ✅ Withdrawal queue
- ✅ Edge cases and error handling

## 📋 Deployment Checklist

- [ ] Deploy underlying asset (or identify existing)
- [ ] Deploy MultiStrategyVault
- [ ] Deploy all strategies
- [ ] Add strategies to vault with allocations
- [ ] Set rebalancing parameters
- [ ] Set fee parameters
- [ ] Configure withdrawal queue
- [ ] Set reserve ratio
- [ ] Transfer ownership to multisig
- [ ] Verify contracts on Etherscan
- [ ] Set up monitoring/alerts
- [ ] Document for users
- [ ] Audit contracts (recommended)

## 🔗 Integration Guide

### For Protocols

```javascript
// Integrate vault into your protocol
contract MyProtocol {
    MultiStrategyVault public vault;
    
    function depositToVault(uint256 amount) external {
        // 1. Take user's assets
        asset.transferFrom(msg.sender, address(this), amount);
        
        // 2. Request deposit on their behalf
        asset.approve(address(vault), amount);
        vault.requestDeposit(amount, msg.sender, address(this));
        
        // 3. Store request ID for later claiming
        // ... your logic ...
    }
}
```

### For Frontends

```javascript
// Get vault state for UI
async function getVaultState() {
    const [
        totalAssets,
        totalSupply,
        reserveRatio,
        strategies
    ] = await Promise.all([
        vault.totalAssets(),
        vault.totalSupply(),
        vault.reserveRatio(),
        vault.getActiveStrategies()
    ]);
    
    return {
        tvl: formatEther(totalAssets),
        sharePrice: totalAssets.div(totalSupply),
        reserveRatio: reserveRatio / 100,
        strategies: strategies.map(s => ({
            address: s.strategyContract,
            allocation: s.targetAllocation / 100,
            deployed: formatEther(s.totalDeposited),
            active: s.active
        }))
    };
}
```

## 📚 Additional Resources

- [EIP-7540 Specification](https://eips.ethereum.org/EIPS/eip-7540)
- [EIP-4626 Specification](https://eips.ethereum.org/EIPS/eip-4626)
- [Complete Implementation Guide](./MULTISTRATEGY_GUIDE.md)
- [Strategy Implementations](./StrategyImplementations.sol)
- [Test Suite](./MultiStrategyVaultTest.sol)

## 🤝 Contributing

Contributions welcome! Areas for improvement:
- Additional strategy implementations
- Gas optimizations
- Enhanced rebalancing algorithms
- More sophisticated fee structures
- Integration examples

## ⚠️ Disclaimer

This is a reference implementation for educational and development purposes. It has not been audited. Use at your own risk. Always conduct thorough testing and obtain professional audits before deploying to mainnet with real funds.

## 📄 License

MIT License - see LICENSE file for details

---

**Built with ❤️ for the Ethereum community**
