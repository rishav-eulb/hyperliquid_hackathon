const hre = require("hardhat");

/**
 * MultiStrategyVault Deployment Script
 * 
 * This script deploys:
 * 1. MultiStrategyVault
 * 2. Multiple strategy implementations
 * 3. Configures strategies with allocations
 */

async function main() {
  console.log("🚀 Deploying MultiStrategyVault System...\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString(), "\n");

  // Configuration
  const config = {
    // Vault configuration
    vaultName: "Multi-Strategy USDC Vault",
    vaultSymbol: "msUSDC",
    operator: deployer.address, // In production, use a separate operator address
    fulfillmentDelay: 3600, // 1 hour
    feeRecipient: deployer.address, // In production, use treasury address
    
    // Strategy allocations (must sum to <= 10000)
    strategyAllocations: {
      lending: 4000,     // 40%
      staking: 3000,     // 30%
      farming: 2000,     // 20%
      // Remaining 10% stays as reserves (5%) + buffer (5%)
    },
    
    // Underlying asset
    assetAddress: process.env.ASSET_ADDRESS || "0x...", // Replace with actual USDC or other asset
  };

  // ============================================
  // Deploy Asset (for testing) or use existing
  // ============================================
  
  let asset;
  if (process.env.DEPLOY_MOCK_ASSET === "true") {
    console.log("📄 Deploying mock asset...");
    const MockERC20 = await hre.ethers.getContractFactory("MockERC20");
    asset = await MockERC20.deploy("Mock USDC", "USDC");
    await asset.deployed();
    console.log("✅ Mock Asset deployed to:", asset.address, "\n");
  } else {
    console.log("📄 Using existing asset at:", config.assetAddress);
    asset = await hre.ethers.getContractAt("IERC20", config.assetAddress);
  }

  // ============================================
  // Deploy MultiStrategyVault
  // ============================================
  
  console.log("📦 Deploying MultiStrategyVault...");
  const MultiStrategyVault = await hre.ethers.getContractFactory("MultiStrategyVault");
  const vault = await MultiStrategyVault.deploy(
    asset.address,
    config.vaultName,
    config.vaultSymbol,
    config.operator,
    config.fulfillmentDelay,
    config.feeRecipient
  );
  await vault.deployed();
  console.log("✅ MultiStrategyVault deployed to:", vault.address, "\n");

  // ============================================
  // Deploy Strategies
  // ============================================
  
  console.log("📦 Deploying strategies...");
  
  // 1. Lending Strategy
  console.log("  - Deploying Lending Strategy...");
  const LendingStrategy = await hre.ethers.getContractFactory("MockLendingStrategy");
  const lendingStrategy = await LendingStrategy.deploy(
    asset.address,
    vault.address
  );
  await lendingStrategy.deployed();
  console.log("    ✅ Lending Strategy deployed to:", lendingStrategy.address);
  
  // 2. Staking Strategy
  console.log("  - Deploying Staking Strategy...");
  const StakingStrategy = await hre.ethers.getContractFactory("MockStakingStrategy");
  const stakingStrategy = await StakingStrategy.deploy(
    asset.address,
    vault.address
  );
  await stakingStrategy.deployed();
  console.log("    ✅ Staking Strategy deployed to:", stakingStrategy.address);
  
  // 3. Yield Farming Strategy
  console.log("  - Deploying Yield Farming Strategy...");
  const FarmStrategy = await hre.ethers.getContractFactory("MockYieldFarmStrategy");
  const farmStrategy = await FarmStrategy.deploy(
    asset.address,
    vault.address
  );
  await farmStrategy.deployed();
  console.log("    ✅ Yield Farming Strategy deployed to:", farmStrategy.address);
  console.log();

  // ============================================
  // Configure Strategies in Vault
  // ============================================
  
  console.log("⚙️  Configuring strategies in vault...");
  
  // Add Lending Strategy
  console.log("  - Adding Lending Strategy (40% allocation)...");
  let tx = await vault.addStrategy(
    lendingStrategy.address,
    config.strategyAllocations.lending,
    hre.ethers.utils.parseEther("1000"), // Min 1000 tokens
    0 // No max
  );
  await tx.wait();
  console.log("    ✅ Lending Strategy added");
  
  // Add Staking Strategy
  console.log("  - Adding Staking Strategy (30% allocation)...");
  tx = await vault.addStrategy(
    stakingStrategy.address,
    config.strategyAllocations.staking,
    hre.ethers.utils.parseEther("1000"),
    0
  );
  await tx.wait();
  console.log("    ✅ Staking Strategy added");
  
  // Add Farming Strategy
  console.log("  - Adding Yield Farming Strategy (20% allocation)...");
  tx = await vault.addStrategy(
    farmStrategy.address,
    config.strategyAllocations.farming,
    hre.ethers.utils.parseEther("1000"),
    0
  );
  await tx.wait();
  console.log("    ✅ Yield Farming Strategy added");
  console.log();

  // ============================================
  // Set Rebalancing Parameters
  // ============================================
  
  console.log("⚙️  Setting rebalancing parameters...");
  tx = await vault.setRebalanceParameters(
    500,    // 5% deviation threshold
    86400   // 1 day rebalance interval
  );
  await tx.wait();
  console.log("✅ Rebalance parameters set\n");

  // ============================================
  // Verify Configuration
  // ============================================
  
  console.log("✅ Deployment Complete!\n");
  console.log("=" .repeat(60));
  console.log("📋 DEPLOYMENT SUMMARY");
  console.log("=" .repeat(60));
  console.log("\n📄 Contracts:");
  console.log("  Asset:", asset.address);
  console.log("  Vault:", vault.address);
  console.log("  Lending Strategy:", lendingStrategy.address);
  console.log("  Staking Strategy:", stakingStrategy.address);
  console.log("  Farming Strategy:", farmStrategy.address);
  
  console.log("\n⚙️  Configuration:");
  console.log("  Operator:", config.operator);
  console.log("  Fee Recipient:", config.feeRecipient);
  console.log("  Fulfillment Delay:", config.fulfillmentDelay, "seconds");
  console.log("  Reserve Ratio:", await vault.reserveRatio() / 100, "%");
  
  console.log("\n📊 Strategy Allocations:");
  console.log("  Lending:", config.strategyAllocations.lending / 100, "%");
  console.log("  Staking:", config.strategyAllocations.staking / 100, "%");
  console.log("  Farming:", config.strategyAllocations.farming / 100, "%");
  console.log("  Reserves:", (10000 - config.strategyAllocations.lending - 
    config.strategyAllocations.staking - config.strategyAllocations.farming) / 100, "%");
  
  console.log("\n🔍 Verification Commands:");
  console.log("  npx hardhat verify --network <network> " + vault.address + 
    ' "' + asset.address + '" "' + config.vaultName + '" "' + config.vaultSymbol + 
    '" ' + config.operator + ' ' + config.fulfillmentDelay + ' ' + config.feeRecipient);
  
  console.log("\n" + "=".repeat(60));
  
  // ============================================
  // Save Deployment Info
  // ============================================
  
  const deploymentInfo = {
    network: hre.network.name,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      asset: asset.address,
      vault: vault.address,
      strategies: {
        lending: lendingStrategy.address,
        staking: stakingStrategy.address,
        farming: farmStrategy.address,
      }
    },
    configuration: config
  };
  
  const fs = require('fs');
  const path = require('path');
  const deploymentsDir = path.join(__dirname, '..', 'deployments');
  
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }
  
  const filename = `deployment-${hre.network.name}-${Date.now()}.json`;
  fs.writeFileSync(
    path.join(deploymentsDir, filename),
    JSON.stringify(deploymentInfo, null, 2)
  );
  
  console.log("\n💾 Deployment info saved to:", filename);
  
  return {
    vault: vault.address,
    strategies: {
      lending: lendingStrategy.address,
      staking: stakingStrategy.address,
      farming: farmStrategy.address,
    }
  };
}

// ============================================
// Helper Functions for Post-Deployment
// ============================================

/**
 * Fund the vault with initial assets (for testing)
 */
async function fundVault(vaultAddress, assetAddress, amount) {
  console.log("\n💰 Funding vault with test assets...");
  
  const asset = await hre.ethers.getContractAt("IERC20", assetAddress);
  const tx = await asset.transfer(vaultAddress, amount);
  await tx.wait();
  
  console.log("✅ Funded vault with", hre.ethers.utils.formatEther(amount), "tokens");
}

/**
 * Perform a test deposit
 */
async function testDeposit(vaultAddress, assetAddress, amount) {
  console.log("\n🧪 Performing test deposit...");
  
  const vault = await hre.ethers.getContractAt("MultiStrategyVault", vaultAddress);
  const asset = await hre.ethers.getContractAt("IERC20", assetAddress);
  
  // Approve
  let tx = await asset.approve(vaultAddress, amount);
  await tx.wait();
  console.log("✅ Approved vault");
  
  // Request deposit
  const [signer] = await hre.ethers.getSigners();
  tx = await vault.requestDeposit(amount, signer.address, signer.address);
  await tx.wait();
  console.log("✅ Deposit requested");
  
  // Wait for fulfillment delay
  console.log("⏳ Waiting for fulfillment delay...");
  await new Promise(resolve => setTimeout(resolve, 3700000)); // 1+ hour
  
  // Fulfill deposit
  tx = await vault.fulfillDepositWithStrategies(signer.address, amount);
  await tx.wait();
  console.log("✅ Deposit fulfilled and allocated to strategies");
  
  // Claim shares
  tx = await vault.deposit(amount, signer.address);
  const receipt = await tx.wait();
  console.log("✅ Shares claimed");
  
  // Check balance
  const shares = await vault.balanceOf(signer.address);
  console.log("💎 Received shares:", hre.ethers.utils.formatEther(shares));
}

// ============================================
// Execute Deployment
// ============================================

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = { main, fundVault, testDeposit };
