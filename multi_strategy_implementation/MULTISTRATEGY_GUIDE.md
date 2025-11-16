# MultiStrategyVault - Complete Implementation Guide

## Overview

The MultiStrategyVault is an advanced ERC7540 vault that automatically distributes deposits across multiple yield-generating strategies. It includes automatic rebalancing, performance tracking, fee management, and emergency controls.

## Table of Contents

1. [Architecture](#architecture)
2. [Key Features](#key-features)
3. [Setup & Deployment](#setup--deployment)
4. [Strategy Management](#strategy-management)
5. [Usage Examples](#usage-examples)
6. [Rebalancing](#rebalancing)
7. [Fee Management](#fee-management)
8. [Emergency Controls](#emergency-controls)
9. [Advanced Features](#advanced-features)

## Architecture

```
                    ┌─────────────────────────┐
                    │  MultiStrategyVault     │
                    │  (ERC7540 + Strategies) │
                    └───────────┬─────────────┘
                                │
                    ┌───────────┴───────────┐
                    │   Strategy Manager    │
                    │  - Add/Remove         │
                    │  - Allocations        │
                    │  - Rebalancing        │
                    └───────────┬───────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
┌───────▼───────┐      ┌───────▼───────┐      ┌───────▼───────┐
│  Strategy 1   │      │  Strategy 2   │      │  Strategy 3   │
│  Lending      │      │  Staking      │      │  Yield Farm   │
│  APY: 5%      │      │  APY: 8%      │      │  APY: 12%     │
└───────────────┘      └───────────────┘      └───────────────┘
```

## Key Features

### 1. Multi-Strategy Support
- Support for up to 20 strategies
- Configurable target allocations
- Automatic distribution on deposits
- Smart withdrawal ordering

### 2. Automatic Rebalancing
- Threshold-based rebalancing (default: 5% deviation)
- Configurable rebalance interval
- Gas-efficient batch operations
- Minimizes slippage

### 3. Performance Tracking
- Historical snapshots
- Per-strategy P&L tracking
- Allocation history
- Performance metrics

### 4. Fee Management
- Performance fees (default: 10%)
- Management fees (default: 2% annual)
- Configurable fee recipient
- Automatic fee collection

### 5. Risk Management
- Reserve ratio (5% kept liquid)
- Emergency shutdown
- Per-strategy pause
- Withdrawal queue system

## Setup & Deployment

### Prerequisites

```bash
npm install @openzeppelin/contracts
```

### Deployment Script

```javascript
const { ethers } = require("hardhat");

async function main() {
    // Deploy underlying asset (or use existing)
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const asset = await MockERC20.deploy("USD Coin", "USDC");
    await asset.deployed();
    
    // Deploy MultiStrategyVault
    const MultiStrategyVault = await ethers.getContractFactory("MultiStrategyVault");
    const vault = await MultiStrategyVault.deploy(
        asset.address,           // underlying asset
        "Multi-Strategy Vault",  // name
        "msVault",              // symbol
        operatorAddress,        // operator for fulfillment
        3600,                   // 1 hour fulfillment delay
        feeRecipientAddress     // fee recipient
    );
    await vault.deployed();
    
    console.log("Vault deployed to:", vault.address);
    
    // Deploy strategies
    const LendingStrategy = await ethers.getContractFactory("MockLendingStrategy");
    const lendingStrategy = await LendingStrategy.deploy(asset.address, vault.address);
    await lendingStrategy.deployed();
    
    const StakingStrategy = await ethers.getContractFactory("MockStakingStrategy");
    const stakingStrategy = await StakingStrategy.deploy(asset.address, vault.address);
    await stakingStrategy.deployed();
    
    // Add strategies to vault
    await vault.addStrategy(
        lendingStrategy.address,
        4000,  // 40% allocation
        1000,  // 1000 wei minimum deposit
        0      // no maximum
    );
    
    await vault.addStrategy(
        stakingStrategy.address,
        3000,  // 30% allocation
        1000,
        0
    );
    
    console.log("Strategies added successfully");
}

main();
```

## Strategy Management

### Adding a Strategy

```solidity
// Add a new strategy with 30% allocation
await vault.addStrategy(
    strategyAddress,
    3000,           // 30% of deposits (3000 basis points)
    1000 * 10**18,  // Minimum 1000 tokens
    0               // No maximum (0 = unlimited)
);
```

### Updating Strategy Parameters

```solidity
// Update strategy allocation and status
await vault.updateStrategy(
    strategyId,     // Strategy index
    4000,           // New allocation: 40%
    true,           // Active
    true,           // Accepting deposits
    true            // Accepting withdrawals
);
```

### Removing a Strategy

```solidity
// First, withdraw all funds from the strategy
await vault.emergencyWithdrawStrategy(strategyId, totalShares);

// Then remove it
await vault.removeStrategy(strategyId);
```

### Setting Withdrawal Queue

The withdrawal queue determines which strategies to withdraw from first during redemptions:

```solidity
// Prioritize withdrawing from strategy 2, then 1, then 0
uint256[] memory queue = [2, 1, 0];
await vault.setWithdrawalQueue(queue);
```

## Usage Examples

### Example 1: Basic Deposit Flow

```solidity
// 1. User approves vault
await asset.approve(vault.address, ethers.utils.parseEther("10000"));

// 2. User requests deposit
await vault.requestDeposit(
    ethers.utils.parseEther("10000"),
    userAddress,
    userAddress
);

// 3. Operator fulfills and allocates to strategies
await vault.fulfillDepositWithStrategies(
    userAddress,
    ethers.utils.parseEther("10000")
);
// This automatically:
// - Keeps 5% as reserves
// - Distributes remaining to strategies based on target allocations
// - Strategy 1 (40%): 3,800 tokens
// - Strategy 2 (30%): 2,850 tokens
// - Reserves (5%): 500 tokens

// 4. User claims shares
await vault.deposit(ethers.utils.parseEther("10000"), userAddress);
```

### Example 2: Redemption Flow

```solidity
// 1. User requests redemption
const shares = await vault.balanceOf(userAddress);
await vault.requestRedeem(shares, userAddress, userAddress);

// 2. Operator fulfills redemption
// This automatically withdraws from strategies following the withdrawal queue
await vault.fulfillRedeemWithStrategies(userAddress, shares);

// 3. User claims assets
await vault.redeem(shares, userAddress, userAddress);
```

### Example 3: Using Multiple Strategies

```solidity
// Setup: 3 strategies with different risk profiles
const conservative = await ConservativeStrategy.deploy(asset.address, vault.address);
const moderate = await MockLendingStrategy.deploy(asset.address, vault.address);
const aggressive = await AggressiveStrategy.deploy(asset.address, vault.address);

// Add strategies with balanced allocation
await vault.addStrategy(conservative.address, 3000, 100, 0); // 30% - Low risk
await vault.addStrategy(moderate.address, 4000, 100, 0);     // 40% - Medium risk
await vault.addStrategy(aggressive.address, 3000, 100, 0);   // 30% - High risk

// Deposit 10,000 tokens
await vault.fulfillDepositWithStrategies(user, ethers.utils.parseEther("10000"));

// Automatic distribution:
// Conservative: 2,850 tokens (30% of 9,500 deployable)
// Moderate:     3,800 tokens (40% of 9,500 deployable)
// Aggressive:   2,850 tokens (30% of 9,500 deployable)
// Reserves:     500 tokens (5% reserve ratio)
```

### Example 4: Manual Strategy Deposit

```solidity
// Operator can manually deposit to specific strategy
const strategyId = 0;
const amount = ethers.utils.parseEther("1000");

// Get strategy details first
const strategy = await vault.getStrategy(strategyId);
console.log("Strategy address:", strategy.strategyContract);
console.log("Current allocation:", strategy.currentAllocation);

// Note: Manual deposits should be done through the vault's
// internal functions by the operator
```

## Rebalancing

### Automatic Rebalancing

The vault can automatically rebalance when allocations drift from targets:

```solidity
// Rebalancing parameters
await vault.setRebalanceParameters(
    500,      // 5% deviation threshold
    86400     // 1 day interval
);

// Trigger rebalance (can be called by operator or owner)
await vault.rebalance();
```

### How Rebalancing Works

1. **Threshold Check**: Compares current allocation vs target for each strategy
2. **Withdraw**: Removes excess from over-allocated strategies
3. **Deposit**: Adds to under-allocated strategies
4. **Update**: Records new allocations

Example:
```
Before Rebalancing:
Strategy 1: Target 40%, Current 50% → Over-allocated by 10%
Strategy 2: Target 30%, Current 25% → Under-allocated by 5%
Strategy 3: Target 30%, Current 25% → Under-allocated by 5%

After Rebalancing:
Strategy 1: 40% (withdrew 10%)
Strategy 2: 30% (added 5%)
Strategy 3: 30% (added 5%)
```

### Manual Rebalance Trigger

```javascript
// Check if rebalancing is needed
const needsRebalancing = await vault.callStatic.rebalance();

if (needsRebalancing) {
    // Execute rebalance
    const tx = await vault.rebalance();
    await tx.wait();
    console.log("Rebalanced successfully");
}
```

## Fee Management

### Fee Types

1. **Performance Fees**: Charged on profits (default 10%)
2. **Management Fees**: Annual fee on AUM (default 2%)

### Collecting Fees

```solidity
// Fees are collected as vault shares minted to fee recipient
await vault.collectFees();

// Check fee recipient balance
const feeShares = await vault.balanceOf(feeRecipient);
console.log("Fee shares:", feeShares.toString());
```

### Updating Fee Parameters

```solidity
await vault.setFees(
    1500,              // 15% performance fee
    250,               // 2.5% management fee
    newFeeRecipient    // New fee recipient address
);
```

### Fee Calculation Example

```
Scenario:
- Vault TVL: $1,000,000
- Time elapsed: 6 months
- Total profit: $100,000

Management Fee:
($1,000,000 * 2% * 0.5 years) = $10,000

Performance Fee:
($100,000 profit * 10%) = $10,000

Total Fees: $20,000 (minted as shares to fee recipient)
```

## Performance Tracking

### Recording Performance

```solidity
// Record performance snapshot for all strategies
await vault.recordPerformance();

// Get historical data for a strategy
const history = await vault.getStrategyHistory(strategyId);

for (const snapshot of history) {
    console.log("Timestamp:", snapshot.timestamp);
    console.log("Total Assets:", snapshot.totalAssets);
    console.log("Allocation:", snapshot.allocation);
    console.log("P&L:", snapshot.pnl);
}
```

### Viewing Current Performance

```solidity
// Get total assets across all strategies
const totalStrategyAssets = await vault.getStrategyTotalAssets();

// Get individual strategy details
const strategy = await vault.getStrategy(0);
console.log("Total Deposited:", strategy.totalDeposited);
console.log("Total Shares:", strategy.totalShares);
console.log("Current Value:", 
    await strategy.strategyContract.convertToAssets(strategy.totalShares)
);

// Calculate P&L
const currentValue = await strategy.strategyContract.convertToAssets(strategy.totalShares);
const pnl = currentValue - strategy.totalDeposited;
console.log("Profit/Loss:", pnl);
```

## Emergency Controls

### Emergency Shutdown

Immediately withdraws all assets from strategies and stops new deposits:

```solidity
await vault.emergencyShutdownVault();
// This will:
// 1. Set emergencyShutdown = true
// 2. Withdraw all assets from all strategies
// 3. Keep assets in vault for redemptions
```

### Pause Individual Strategy

```solidity
// Pause strategy 0
await vault.pauseStrategy(0, true);

// Resume strategy 0
await vault.pauseStrategy(0, false);
```

### Emergency Withdrawal from Strategy

```solidity
// Owner can manually withdraw from any strategy
await vault.emergencyWithdrawStrategy(
    strategyId,
    sharesAmount
);
```

## Advanced Features

### 1. Custom Strategy Implementation

```solidity
contract MyCustomStrategy is BaseStrategy {
    // Your custom yield logic
    
    function deposit(uint256 amount) external override onlyVault returns (uint256 shares) {
        // Deposit to your protocol
        // Return shares
    }
    
    function withdraw(uint256 shares) external override onlyVault returns (uint256 amount) {
        // Withdraw from your protocol
        // Return assets
    }
    
    function totalAssets() public view override returns (uint256) {
        // Return total assets in strategy
    }
}
```

### 2. Monitoring and Alerts

```javascript
// Listen for rebalancing events
vault.on("Rebalanced", (timestamp, allocations) => {
    console.log("Vault rebalanced at:", timestamp);
    console.log("New allocations:", allocations);
});

// Listen for strategy deposits
vault.on("StrategyDeposit", (strategyId, assets, shares) => {
    console.log(`Strategy ${strategyId} received ${assets} assets`);
});

// Monitor for emergency shutdown
vault.on("EmergencyShutdown", (caller) => {
    console.log("ALERT: Emergency shutdown triggered by:", caller);
    // Send notifications, trigger alerts, etc.
});
```

### 3. Integration with Frontend

```javascript
// Get vault overview
async function getVaultOverview() {
    const totalAssets = await vault.totalAssets();
    const totalSupply = await vault.totalSupply();
    const sharePrice = totalAssets.div(totalSupply);
    
    const strategies = await vault.getActiveStrategies();
    
    return {
        totalAssets: ethers.utils.formatEther(totalAssets),
        totalSupply: ethers.utils.formatEther(totalSupply),
        sharePrice: ethers.utils.formatEther(sharePrice),
        strategiesCount: strategies.length,
        strategies: strategies.map((s, i) => ({
            id: i,
            address: s.strategyContract,
            allocation: s.targetAllocation / 100, // Convert to percentage
            totalDeposited: ethers.utils.formatEther(s.totalDeposited),
            active: s.active
        }))
    };
}
```

### 4. Batch Operations

```javascript
// Batch fulfill multiple deposit requests
async function batchFulfillDeposits(users, amounts) {
    for (let i = 0; i < users.length; i++) {
        await vault.fulfillDepositWithStrategies(users[i], amounts[i]);
    }
}

// Batch record performance for all strategies
async function updateAllPerformance() {
    await vault.recordPerformance();
}
```

## Best Practices

### 1. Strategy Selection
- Diversify across different protocols
- Mix risk profiles (conservative, moderate, aggressive)
- Consider liquidity needs
- Monitor strategy health regularly

### 2. Allocation Management
- Start conservative, increase gradually
- Keep reserves for withdrawals (5-10%)
- Rebalance regularly but not too frequently
- Monitor deviation thresholds

### 3. Risk Management
- Set appropriate min/max deposits per strategy
- Implement circuit breakers
- Have emergency procedures
- Regular audits

### 4. Operations
- Automate rebalancing with monitoring
- Collect fees regularly
- Track performance metrics
- Maintain proper documentation

## Security Considerations

1. **Strategy Risk**: Each strategy introduces its own risks
2. **Rebalancing Costs**: Consider gas costs vs benefits
3. **Slippage**: Large rebalances may incur slippage
4. **Oracle Dependence**: If using price oracles, ensure reliability
5. **Admin Keys**: Use multi-sig for owner operations

## Gas Optimization

- Use batch operations where possible
- Limit number of active strategies (< 10 recommended)
- Set appropriate rebalance intervals
- Consider gas costs in allocation decisions

## Troubleshooting

### Common Issues

**Issue**: Rebalance fails with "RebalanceTooSoon"
**Solution**: Wait for rebalanceInterval to pass or adjust interval

**Issue**: Strategy deposit fails
**Solution**: Check strategy is active, accepting deposits, and not paused

**Issue**: Withdrawal fails with "InsufficientReserves"
**Solution**: Increase reserve ratio or trigger rebalance to free up assets

## Conclusion

The MultiStrategyVault provides a production-ready solution for multi-strategy yield optimization with ERC7540 async flows. It's designed for flexibility, safety, and ease of use while maintaining compatibility with the broader DeFi ecosystem.

For more information:
- Read the EIP-7540 specification
- Review the contract code and comments
- Test thoroughly in a development environment
- Consider a professional audit before mainnet deployment
