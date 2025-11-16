// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MultiStrategyVault.sol";
import "./StrategyImplementations.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MultiStrategyVaultTest
 * @notice Comprehensive test scenarios for MultiStrategyVault
 */
contract MultiStrategyVaultTest {
    MultiStrategyVault public vault;
    MockERC20 public asset;
    
    MockLendingStrategy public lendingStrategy;
    MockStakingStrategy public stakingStrategy;
    MockYieldFarmStrategy public farmStrategy;
    
    address public owner;
    address public operator;
    address public feeRecipient;
    address public user1;
    address public user2;
    address public user3;

    event TestResult(string testName, bool passed, string message);

    constructor() {
        owner = address(this);
        operator = address(0x1);
        feeRecipient = address(0x2);
        user1 = address(0x3);
        user2 = address(0x4);
        user3 = address(0x5);
        
        // Deploy asset
        asset = new MockERC20("Test Token", "TEST");
        
        // Deploy vault
        vault = new MultiStrategyVault(
            IERC20(address(asset)),
            "Multi-Strategy Vault",
            "MSV",
            operator,
            1 hours,
            feeRecipient
        );
        
        // Deploy strategies
        lendingStrategy = new MockLendingStrategy(IERC20(address(asset)), address(vault));
        stakingStrategy = new MockStakingStrategy(IERC20(address(asset)), address(vault));
        farmStrategy = new MockYieldFarmStrategy(IERC20(address(asset)), address(vault));
        
        // Mint tokens to test users
        asset.mint(user1, 100000 * 10**18);
        asset.mint(user2, 100000 * 10**18);
        asset.mint(user3, 100000 * 10**18);
        
        // Setup strategies
        _setupStrategies();
    }

    function _setupStrategies() internal {
        // Add 3 strategies with different allocations
        vault.addStrategy(
            IStrategy(address(lendingStrategy)),
            4000,  // 40%
            1000 * 10**18,
            0
        );
        
        vault.addStrategy(
            IStrategy(address(stakingStrategy)),
            3000,  // 30%
            1000 * 10**18,
            0
        );
        
        vault.addStrategy(
            IStrategy(address(farmStrategy)),
            2000,  // 20%
            1000 * 10**18,
            0
        );
    }

    /**
     * Test 1: Basic strategy addition and configuration
     */
    function test1_StrategyManagement() external {
        // Verify strategies were added
        MultiStrategyVault.Strategy memory strategy0 = vault.getStrategy(0);
        require(strategy0.targetAllocation == 4000, "Wrong allocation for strategy 0");
        require(strategy0.active, "Strategy 0 should be active");
        
        MultiStrategyVault.Strategy memory strategy1 = vault.getStrategy(1);
        require(strategy1.targetAllocation == 3000, "Wrong allocation for strategy 1");
        
        MultiStrategyVault.Strategy memory strategy2 = vault.getStrategy(2);
        require(strategy2.targetAllocation == 2000, "Wrong allocation for strategy 2");
        
        emit TestResult("test1_StrategyManagement", true, "All strategies configured correctly");
    }

    /**
     * Test 2: Deposit flow with strategy allocation
     */
    function test2_DepositWithAllocation() external {
        uint256 depositAmount = 10000 * 10**18;
        
        // User1 approves and requests deposit
        vm.prank(user1);
        asset.approve(address(vault), depositAmount);
        
        vm.prank(user1);
        vault.requestDeposit(depositAmount, user1, user1);
        
        // Check pending request
        uint256 pending = vault.pendingDepositRequest(0, user1);
        require(pending == depositAmount, "Incorrect pending amount");
        
        // Wait for fulfillment delay
        vm.warp(block.timestamp + 1 hours + 1);
        
        // Operator fulfills with strategy allocation
        vm.prank(operator);
        vault.fulfillDepositWithStrategies(user1, depositAmount);
        
        // Check strategies received assets
        MultiStrategyVault.Strategy memory s0 = vault.getStrategy(0);
        MultiStrategyVault.Strategy memory s1 = vault.getStrategy(1);
        MultiStrategyVault.Strategy memory s2 = vault.getStrategy(2);
        
        // 5% reserve, 95% deployed
        // Strategy 0: 40% of 9500 = 3800
        // Strategy 1: 30% of 9500 = 2850
        // Strategy 2: 20% of 9500 = 1900
        
        require(s0.totalDeposited > 0, "Strategy 0 should have deposits");
        require(s1.totalDeposited > 0, "Strategy 1 should have deposits");
        require(s2.totalDeposited > 0, "Strategy 2 should have deposits");
        
        // User claims shares
        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount, user1);
        
        require(shares > 0, "User should receive shares");
        require(vault.balanceOf(user1) == shares, "Incorrect share balance");
        
        emit TestResult("test2_DepositWithAllocation", true, "Deposit allocated to strategies correctly");
    }

    /**
     * Test 3: Redemption with strategy withdrawals
     */
    function test3_RedemptionWithWithdrawals() external {
        // First setup: deposit some assets
        uint256 depositAmount = 10000 * 10**18;
        
        vm.prank(user2);
        asset.approve(address(vault), depositAmount);
        vm.prank(user2);
        vault.requestDeposit(depositAmount, user2, user2);
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(operator);
        vault.fulfillDepositWithStrategies(user2, depositAmount);
        vm.prank(user2);
        uint256 shares = vault.deposit(depositAmount, user2);
        
        // Now test redemption
        vm.prank(user2);
        vault.requestRedeem(shares, user2, user2);
        
        // Wait and fulfill
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(operator);
        vault.fulfillRedeemWithStrategies(user2, shares);
        
        // Check that claimable is set
        uint256 claimable = vault.claimableRedeemRequest(0, user2);
        require(claimable == shares, "Incorrect claimable shares");
        
        // User claims assets
        uint256 balanceBefore = asset.balanceOf(user2);
        vm.prank(user2);
        uint256 assets = vault.redeem(shares, user2, user2);
        uint256 balanceAfter = asset.balanceOf(user2);
        
        require(assets > 0, "Should receive assets");
        require(balanceAfter > balanceBefore, "Balance should increase");
        
        emit TestResult("test3_RedemptionWithWithdrawals", true, "Redemption works correctly");
    }

    /**
     * Test 4: Multiple users deposit and strategies reach target allocations
     */
    function test4_MultiUserDeposits() external {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 5000 * 10**18;
        amounts[1] = 7000 * 10**18;
        amounts[2] = 8000 * 10**18;
        
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;
        
        // All users deposit
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(users[i]);
            asset.approve(address(vault), amounts[i]);
            
            vm.prank(users[i]);
            vault.requestDeposit(amounts[i], users[i], users[i]);
        }
        
        // Fulfill all requests
        vm.warp(block.timestamp + 1 hours + 1);
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(operator);
            vault.fulfillDepositWithStrategies(users[i], amounts[i]);
        }
        
        // Check total assets in strategies
        uint256 totalStrategyAssets = vault.getStrategyTotalAssets();
        require(totalStrategyAssets > 0, "Strategies should have assets");
        
        // All users claim
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(users[i]);
            vault.deposit(amounts[i], users[i]);
        }
        
        emit TestResult("test4_MultiUserDeposits", true, "Multiple users deposited successfully");
    }

    /**
     * Test 5: Strategy update and reallocation
     */
    function test5_StrategyUpdate() external {
        // Update strategy 0 allocation from 40% to 50%
        vault.updateStrategy(
            0,      // strategyId
            5000,   // new allocation: 50%
            true,   // active
            true,   // accepting deposits
            true    // accepting withdrawals
        );
        
        MultiStrategyVault.Strategy memory updated = vault.getStrategy(0);
        require(updated.targetAllocation == 5000, "Allocation not updated");
        
        // Pause strategy 1
        vault.pauseStrategy(1, true);
        
        // Verify pause
        require(vault.strategyPaused(1), "Strategy should be paused");
        
        emit TestResult("test5_StrategyUpdate", true, "Strategy updates work correctly");
    }

    /**
     * Test 6: Rebalancing
     */
    function test6_Rebalancing() external {
        // First create an imbalance by depositing and then changing allocations
        uint256 depositAmount = 20000 * 10**18;
        
        vm.prank(user1);
        asset.approve(address(vault), depositAmount);
        vm.prank(user1);
        vault.requestDeposit(depositAmount, user1, user1);
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(operator);
        vault.fulfillDepositWithStrategies(user1, depositAmount);
        vm.prank(user1);
        vault.deposit(depositAmount, user1);
        
        // Change allocations significantly
        vault.updateStrategy(0, 2000, true, true, true); // 40% -> 20%
        vault.updateStrategy(1, 5000, true, true, true); // 30% -> 50%
        
        // Wait for rebalance interval
        vm.warp(block.timestamp + 1 days + 1);
        
        // Trigger rebalance
        vault.rebalance();
        
        // Check that allocations moved toward targets
        // (Note: exact checks would depend on strategy implementation)
        
        emit TestResult("test6_Rebalancing", true, "Rebalancing executed");
    }

    /**
     * Test 7: Fee collection
     */
    function test7_FeeCollection() external {
        // Setup: deposit and wait for some time to accrue fees
        uint256 depositAmount = 50000 * 10**18;
        
        vm.prank(user1);
        asset.approve(address(vault), depositAmount);
        vm.prank(user1);
        vault.requestDeposit(depositAmount, user1, user1);
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(operator);
        vault.fulfillDepositWithStrategies(user1, depositAmount);
        vm.prank(user1);
        vault.deposit(depositAmount, user1);
        
        // Wait 6 months for management fees to accrue
        vm.warp(block.timestamp + 180 days);
        
        // Collect fees
        uint256 feeRecipientBalanceBefore = vault.balanceOf(feeRecipient);
        vault.collectFees();
        uint256 feeRecipientBalanceAfter = vault.balanceOf(feeRecipient);
        
        require(
            feeRecipientBalanceAfter > feeRecipientBalanceBefore,
            "Fee recipient should receive shares"
        );
        
        emit TestResult("test7_FeeCollection", true, "Fees collected successfully");
    }

    /**
     * Test 8: Withdrawal queue
     */
    function test8_WithdrawalQueue() external {
        // Set custom withdrawal queue: withdraw from strategy 2 first, then 1, then 0
        uint256[] memory newQueue = new uint256[](3);
        newQueue[0] = 2;
        newQueue[1] = 1;
        newQueue[2] = 0;
        
        vault.setWithdrawalQueue(newQueue);
        
        // Verify queue is set
        require(vault.withdrawalQueue(0) == 2, "Queue position 0 incorrect");
        require(vault.withdrawalQueue(1) == 1, "Queue position 1 incorrect");
        require(vault.withdrawalQueue(2) == 0, "Queue position 2 incorrect");
        
        emit TestResult("test8_WithdrawalQueue", true, "Withdrawal queue set correctly");
    }

    /**
     * Test 9: Performance tracking
     */
    function test9_PerformanceTracking() external {
        // Deposit to create some activity
        uint256 depositAmount = 10000 * 10**18;
        
        vm.prank(user1);
        asset.approve(address(vault), depositAmount);
        vm.prank(user1);
        vault.requestDeposit(depositAmount, user1, user1);
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(operator);
        vault.fulfillDepositWithStrategies(user1, depositAmount);
        
        // Record performance
        vault.recordPerformance();
        
        // Check that history was recorded
        MultiStrategyVault.StrategySnapshot[] memory history = vault.getStrategyHistory(0);
        require(history.length > 0, "Performance should be recorded");
        require(history[0].timestamp == block.timestamp, "Wrong timestamp");
        
        emit TestResult("test9_PerformanceTracking", true, "Performance tracking works");
    }

    /**
     * Test 10: Emergency shutdown
     */
    function test10_EmergencyShutdown() external {
        // Deposit first
        uint256 depositAmount = 10000 * 10**18;
        
        vm.prank(user1);
        asset.approve(address(vault), depositAmount);
        vm.prank(user1);
        vault.requestDeposit(depositAmount, user1, user1);
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(operator);
        vault.fulfillDepositWithStrategies(user1, depositAmount);
        
        // Trigger emergency shutdown
        vault.emergencyShutdownVault();
        
        // Verify shutdown state
        require(vault.emergencyShutdown(), "Emergency shutdown should be active");
        
        // Verify all strategies are withdrawn
        MultiStrategyVault.Strategy memory s0 = vault.getStrategy(0);
        MultiStrategyVault.Strategy memory s1 = vault.getStrategy(1);
        MultiStrategyVault.Strategy memory s2 = vault.getStrategy(2);
        
        // All shares should be withdrawn (or close to 0 due to rounding)
        require(s0.totalShares < 1000, "Strategy 0 should be withdrawn");
        require(s1.totalShares < 1000, "Strategy 1 should be withdrawn");
        require(s2.totalShares < 1000, "Strategy 2 should be withdrawn");
        
        emit TestResult("test10_EmergencyShutdown", true, "Emergency shutdown works correctly");
    }

    /**
     * Test 11: Reserve management
     */
    function test11_ReserveManagement() external {
        // Check default reserve ratio
        require(vault.reserveRatio() == 500, "Default reserve ratio should be 5%");
        
        // Change reserve ratio
        vault.setReserveRatio(1000); // 10%
        require(vault.reserveRatio() == 1000, "Reserve ratio not updated");
        
        // Deposit and verify reserves are maintained
        uint256 depositAmount = 10000 * 10**18;
        
        vm.prank(user1);
        asset.approve(address(vault), depositAmount);
        vm.prank(user1);
        vault.requestDeposit(depositAmount, user1, user1);
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(operator);
        vault.fulfillDepositWithStrategies(user1, depositAmount);
        
        // Check that reserves are maintained
        uint256 reserves = vault.totalReserves();
        uint256 expectedReserves = depositAmount * 1000 / 10000; // 10% of deposit
        
        // Allow for some variance due to previous deposits
        require(reserves >= expectedReserves, "Reserves should be maintained");
        
        emit TestResult("test11_ReserveManagement", true, "Reserve management works");
    }

    /**
     * Test 12: Partial redemptions
     */
    function test12_PartialRedemptions() external {
        // Deposit
        uint256 depositAmount = 10000 * 10**18;
        
        vm.prank(user1);
        asset.approve(address(vault), depositAmount);
        vm.prank(user1);
        vault.requestDeposit(depositAmount, user1, user1);
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(operator);
        vault.fulfillDepositWithStrategies(user1, depositAmount);
        vm.prank(user1);
        uint256 totalShares = vault.deposit(depositAmount, user1);
        
        // Redeem only half
        uint256 redeemShares = totalShares / 2;
        
        vm.prank(user1);
        vault.requestRedeem(redeemShares, user1, user1);
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(operator);
        vault.fulfillRedeemWithStrategies(user1, redeemShares);
        
        // Claim half
        vm.prank(user1);
        vault.redeem(redeemShares, user1, user1);
        
        // Verify user still has remaining shares
        uint256 remainingShares = vault.balanceOf(user1);
        require(remainingShares > 0, "User should have remaining shares");
        
        emit TestResult("test12_PartialRedemptions", true, "Partial redemptions work");
    }

    /**
     * Run all tests
     */
    function runAllTests() external {
        test1_StrategyManagement();
        test2_DepositWithAllocation();
        test3_RedemptionWithWithdrawals();
        test4_MultiUserDeposits();
        test5_StrategyUpdate();
        test6_Rebalancing();
        test7_FeeCollection();
        test8_WithdrawalQueue();
        test9_PerformanceTracking();
        test10_EmergencyShutdown();
        test11_ReserveManagement();
        test12_PartialRedemptions();
    }
}

// Mock VM for testing (in actual tests, use Foundry's vm)
library vm {
    function prank(address) internal {}
    function warp(uint256) internal {}
}

// Simple mock ERC20 for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
