// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC7540Vault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice Simple mock ERC20 token for testing
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title ERC7540VaultTest
 * @notice Example usage and test scenarios for ERC7540Vault
 */
contract ERC7540VaultTest {
    ERC7540Vault public vault;
    MockERC20 public asset;
    
    address public user1;
    address public user2;
    address public operator;

    constructor() {
        // Deploy mock asset
        asset = new MockERC20("Test Token", "TEST");
        
        // Deploy vault with 1 hour fulfillment delay
        operator = address(this);
        vault = new ERC7540Vault(
            IERC20(address(asset)),
            "Test Vault",
            "vTEST",
            operator,
            1 hours
        );

        // Setup test users
        user1 = address(0x1);
        user2 = address(0x2);
        
        // Mint tokens to users
        asset.mint(user1, 10000 * 10**18);
        asset.mint(user2, 10000 * 10**18);
    }

    /**
     * @notice Example 1: Basic Async Deposit Flow
     */
    function testAsyncDeposit() external {
        uint256 depositAmount = 1000 * 10**18;
        
        // Step 1: User approves vault
        vm.prank(user1);
        asset.approve(address(vault), depositAmount);
        
        // Step 2: User requests deposit
        vm.prank(user1);
        uint256 requestId = vault.requestDeposit(depositAmount, user1, user1);
        
        // Check pending request
        uint256 pending = vault.pendingDepositRequest(requestId, user1);
        require(pending == depositAmount, "Incorrect pending amount");
        
        // Step 3: Operator fulfills request after delay
        vm.warp(block.timestamp + 1 hours + 1);
        vault.fulfillDeposit(user1, depositAmount);
        
        // Check claimable request
        uint256 claimable = vault.claimableDepositRequest(requestId, user1);
        require(claimable == depositAmount, "Incorrect claimable amount");
        
        // Step 4: User claims shares
        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount, user1);
        
        require(vault.balanceOf(user1) == shares, "Incorrect shares balance");
    }

    /**
     * @notice Example 2: Basic Async Redemption Flow
     */
    function testAsyncRedemption() external {
        // First deposit some shares (assuming user has shares)
        uint256 depositAmount = 1000 * 10**18;
        
        // Setup: Give user1 some shares
        vm.prank(user1);
        asset.approve(address(vault), depositAmount);
        vm.prank(user1);
        vault.requestDeposit(depositAmount, user1, user1);
        vm.warp(block.timestamp + 1 hours + 1);
        vault.fulfillDeposit(user1, depositAmount);
        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount, user1);
        
        // Step 1: User requests redemption
        vm.prank(user1);
        uint256 requestId = vault.requestRedeem(shares, user1, user1);
        
        // Check pending request
        uint256 pending = vault.pendingRedeemRequest(requestId, user1);
        require(pending == shares, "Incorrect pending shares");
        
        // Step 2: Operator fulfills request after delay
        vm.warp(block.timestamp + 1 hours + 1);
        vault.fulfillRedeem(user1, shares);
        
        // Check claimable request
        uint256 claimable = vault.claimableRedeemRequest(requestId, user1);
        require(claimable == shares, "Incorrect claimable shares");
        
        // Step 3: User claims assets
        vm.prank(user1);
        uint256 assets = vault.redeem(shares, user1);
        
        require(asset.balanceOf(user1) >= assets, "Incorrect asset balance");
    }

    /**
     * @notice Example 3: Using Operators
     */
    function testOperator() external {
        uint256 depositAmount = 1000 * 10**18;
        
        // User approves another address as operator
        vm.prank(user1);
        vault.setOperator(user2, true);
        
        // Approve vault to spend tokens
        vm.prank(user1);
        asset.approve(address(vault), depositAmount);
        
        // Operator (user2) requests deposit on behalf of user1
        vm.prank(user2);
        vault.requestDeposit(depositAmount, user1, user1);
        
        // Fulfill request
        vm.warp(block.timestamp + 1 hours + 1);
        vault.fulfillDeposit(user1, depositAmount);
        
        // Operator claims on behalf of user1
        vm.prank(user2);
        vault.deposit(depositAmount, user1, user1);
        
        require(vault.balanceOf(user1) > 0, "No shares received");
    }

    /**
     * @notice Example 4: Batch Fulfillment
     */
    function testBatchFulfillment() external {
        uint256 depositAmount = 1000 * 10**18;
        
        // Multiple users request deposits
        vm.prank(user1);
        asset.approve(address(vault), depositAmount);
        vm.prank(user1);
        vault.requestDeposit(depositAmount, user1, user1);
        
        vm.prank(user2);
        asset.approve(address(vault), depositAmount);
        vm.prank(user2);
        vault.requestDeposit(depositAmount, user2, user2);
        
        // Batch fulfill
        vm.warp(block.timestamp + 1 hours + 1);
        
        address[] memory controllers = new address[](2);
        controllers[0] = user1;
        controllers[1] = user2;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = depositAmount;
        amounts[1] = depositAmount;
        
        vault.batchFulfillDeposits(controllers, amounts);
        
        // Both users can now claim
        vm.prank(user1);
        vault.deposit(depositAmount, user1);
        
        vm.prank(user2);
        vault.deposit(depositAmount, user2);
        
        require(vault.balanceOf(user1) > 0, "User1 no shares");
        require(vault.balanceOf(user2) > 0, "User2 no shares");
    }

    /**
     * @notice Example 5: Partial Claims
     */
    function testPartialClaim() external {
        uint256 depositAmount = 1000 * 10**18;
        
        // Request deposit
        vm.prank(user1);
        asset.approve(address(vault), depositAmount);
        vm.prank(user1);
        vault.requestDeposit(depositAmount, user1, user1);
        
        // Fulfill request
        vm.warp(block.timestamp + 1 hours + 1);
        vault.fulfillDeposit(user1, depositAmount);
        
        // Claim only half
        vm.prank(user1);
        vault.deposit(depositAmount / 2, user1);
        
        // Check remaining claimable
        uint256 remaining = vault.claimableDepositRequest(0, user1);
        require(remaining == depositAmount / 2, "Incorrect remaining");
        
        // Claim the rest
        vm.prank(user1);
        vault.deposit(depositAmount / 2, user1);
        
        require(vault.claimableDepositRequest(0, user1) == 0, "Should be fully claimed");
    }
}

// Mock vm for testing (in actual tests, use Foundry's vm)
contract vm {
    function prank(address) external {}
    function warp(uint256) external {}
}
