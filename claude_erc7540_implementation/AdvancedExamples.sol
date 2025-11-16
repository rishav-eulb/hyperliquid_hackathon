// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC7540Vault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title VaultRouter
 * @notice Helper contract for seamless interaction with ERC7540 vaults
 * @dev Provides convenience functions for common vault operations
 */
contract VaultRouter {
    using SafeERC20 for IERC20;

    /**
     * @notice Request deposit and track request
     * @dev Helper that combines approval and request in one transaction
     */
    function requestDepositFor(
        ERC7540Vault vault,
        uint256 assets,
        address controller
    ) external returns (uint256 requestId) {
        IERC20 asset = IERC20(vault.asset());
        
        // Transfer assets from user to this router
        asset.safeTransferFrom(msg.sender, address(this), assets);
        
        // Approve vault
        asset.approve(address(vault), assets);
        
        // Request deposit
        requestId = vault.requestDeposit(assets, controller, address(this));
        
        return requestId;
    }

    /**
     * @notice Check if a request is ready to claim
     */
    function isClaimable(
        ERC7540Vault vault,
        uint256 requestId,
        address controller,
        bool isDeposit
    ) external view returns (bool) {
        if (isDeposit) {
            return vault.claimableDepositRequest(requestId, controller) > 0;
        } else {
            return vault.claimableRedeemRequest(requestId, controller) > 0;
        }
    }

    /**
     * @notice Claim all available deposits for a user
     */
    function claimAllDeposits(
        ERC7540Vault vault,
        address receiver
    ) external returns (uint256 shares) {
        uint256 claimable = vault.claimableDepositRequest(0, msg.sender);
        if (claimable == 0) return 0;
        
        return vault.deposit(claimable, receiver, msg.sender);
    }

    /**
     * @notice Claim all available redemptions for a user
     */
    function claimAllRedemptions(
        ERC7540Vault vault,
        address receiver
    ) external returns (uint256 assets) {
        uint256 claimable = vault.claimableRedeemRequest(0, msg.sender);
        if (claimable == 0) return 0;
        
        return vault.redeem(claimable, receiver, msg.sender);
    }
}

/**
 * @title AutoCompoundVault
 * @notice Example vault that automatically reinvests yield
 * @dev Extends ERC7540Vault with auto-compounding functionality
 */
contract AutoCompoundVault is ERC7540Vault {
    using SafeERC20 for IERC20;

    uint256 public lastHarvestTimestamp;
    uint256 public harvestInterval = 1 days;
    address public yieldSource;

    event YieldHarvested(uint256 amount, uint256 timestamp);

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        address operator_,
        uint256 fulfillmentDelay_,
        address yieldSource_
    ) ERC7540Vault(asset_, name_, symbol_, operator_, fulfillmentDelay_) {
        yieldSource = yieldSource_;
        lastHarvestTimestamp = block.timestamp;
    }

    /**
     * @notice Harvest yield and distribute to vault
     * @dev Can be called by anyone after interval
     */
    function harvest() external {
        require(
            block.timestamp >= lastHarvestTimestamp + harvestInterval,
            "Too early to harvest"
        );

        // Example: Pull yield from external source
        // In production, this would interact with lending protocols, etc.
        uint256 yield = _getYieldFromSource();
        
        if (yield > 0) {
            lastHarvestTimestamp = block.timestamp;
            emit YieldHarvested(yield, block.timestamp);
        }
    }

    function _getYieldFromSource() internal returns (uint256) {
        // Implementation specific to yield source
        // This is just a placeholder
        return 0;
    }

    /**
     * @notice Modified totalAssets to include pending yield
     */
    function totalAssets() public view override returns (uint256) {
        return super.totalAssets() + _getPendingYield();
    }

    function _getPendingYield() internal view returns (uint256) {
        // Calculate pending yield
        return 0; // Placeholder
    }
}

/**
 * @title MultiStrategyVault
 * @notice Example vault that routes deposits to multiple strategies
 * @dev Shows how to implement complex fulfillment logic
 */
contract MultiStrategyVault is ERC7540Vault {
    using SafeERC20 for IERC20;

    struct Strategy {
        address strategyAddress;
        uint256 allocationPercent; // Out of 10000 (100%)
        bool active;
    }

    Strategy[] public strategies;
    uint256 public constant MAX_BPS = 10000;

    event StrategyAdded(address indexed strategy, uint256 allocation);
    event StrategyRemoved(address indexed strategy);
    event AllocationUpdated(address indexed strategy, uint256 newAllocation);

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        address operator_,
        uint256 fulfillmentDelay_
    ) ERC7540Vault(asset_, name_, symbol_, operator_, fulfillmentDelay_) {}

    /**
     * @notice Add a new strategy
     */
    function addStrategy(
        address strategyAddress,
        uint256 allocationPercent
    ) external {
        require(msg.sender == operator, "Only operator");
        require(_getTotalAllocation() + allocationPercent <= MAX_BPS, "Over-allocated");
        
        strategies.push(Strategy({
            strategyAddress: strategyAddress,
            allocationPercent: allocationPercent,
            active: true
        }));

        emit StrategyAdded(strategyAddress, allocationPercent);
    }

    /**
     * @notice Custom fulfillment that distributes across strategies
     */
    function fulfillDepositWithStrategies(
        address controller,
        uint256 assets
    ) external {
        require(msg.sender == operator, "Only operator");
        
        // Standard fulfillment
        super.fulfillDeposit(controller, assets);
        
        // Distribute assets across strategies
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active) {
                uint256 strategyAmount = (assets * strategies[i].allocationPercent) / MAX_BPS;
                if (strategyAmount > 0) {
                    _depositToStrategy(i, strategyAmount);
                }
            }
        }
    }

    function _depositToStrategy(uint256 strategyIndex, uint256 amount) internal {
        // Implementation specific to strategy
        // Could be lending protocols, yield farms, etc.
    }

    function _getTotalAllocation() internal view returns (uint256 total) {
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active) {
                total += strategies[i].allocationPercent;
            }
        }
    }
}

/**
 * @title VaultAggregator
 * @notice Manages deposits across multiple ERC7540 vaults
 * @dev Useful for protocols that want to diversify across multiple vaults
 */
contract VaultAggregator {
    using SafeERC20 for IERC20;

    struct VaultAllocation {
        ERC7540Vault vault;
        uint256 allocationPercent; // Out of 10000
        bool active;
    }

    IERC20 public immutable asset;
    VaultAllocation[] public vaults;
    uint256 public constant MAX_BPS = 10000;

    mapping(address => mapping(uint256 => uint256)) public userRequestAmounts;

    event DepositDistributed(address indexed user, uint256 totalAmount);
    event VaultAdded(address indexed vault, uint256 allocation);

    constructor(IERC20 asset_) {
        asset = asset_;
    }

    /**
     * @notice Request deposit across all vaults
     */
    function requestDepositAcrossVaults(uint256 totalAssets) external {
        asset.safeTransferFrom(msg.sender, address(this), totalAssets);

        for (uint256 i = 0; i < vaults.length; i++) {
            if (vaults[i].active) {
                uint256 vaultAmount = (totalAssets * vaults[i].allocationPercent) / MAX_BPS;
                
                if (vaultAmount > 0) {
                    asset.approve(address(vaults[i].vault), vaultAmount);
                    vaults[i].vault.requestDeposit(vaultAmount, msg.sender, address(this));
                    userRequestAmounts[msg.sender][i] = vaultAmount;
                }
            }
        }

        emit DepositDistributed(msg.sender, totalAssets);
    }

    /**
     * @notice Claim from all vaults
     */
    function claimFromAllVaults() external {
        for (uint256 i = 0; i < vaults.length; i++) {
            if (vaults[i].active) {
                uint256 claimable = vaults[i].vault.claimableDepositRequest(0, msg.sender);
                if (claimable > 0) {
                    vaults[i].vault.deposit(claimable, msg.sender, msg.sender);
                }
            }
        }
    }

    /**
     * @notice Add a vault to the aggregator
     */
    function addVault(ERC7540Vault vault, uint256 allocationPercent) external {
        require(_getTotalAllocation() + allocationPercent <= MAX_BPS, "Over-allocated");
        
        vaults.push(VaultAllocation({
            vault: vault,
            allocationPercent: allocationPercent,
            active: true
        }));

        emit VaultAdded(address(vault), allocationPercent);
    }

    function _getTotalAllocation() internal view returns (uint256 total) {
        for (uint256 i = 0; i < vaults.length; i++) {
            if (vaults[i].active) {
                total += vaults[i].allocationPercent;
            }
        }
    }
}

/**
 * @title RequestQueue
 * @notice FIFO queue system for vault requests
 * @dev Example of implementing fair ordering for request fulfillment
 */
contract RequestQueue {
    struct QueuedRequest {
        address controller;
        uint256 amount;
        uint256 timestamp;
        bool isDeposit;
    }

    QueuedRequest[] public queue;
    uint256 public head;
    
    event RequestQueued(address indexed controller, uint256 amount, bool isDeposit);
    event RequestProcessed(address indexed controller, uint256 amount);

    function enqueue(
        address controller,
        uint256 amount,
        bool isDeposit
    ) external {
        queue.push(QueuedRequest({
            controller: controller,
            amount: amount,
            timestamp: block.timestamp,
            isDeposit: isDeposit
        }));

        emit RequestQueued(controller, amount, isDeposit);
    }

    function dequeue() external returns (QueuedRequest memory) {
        require(head < queue.length, "Queue empty");
        
        QueuedRequest memory request = queue[head];
        head++;

        emit RequestProcessed(request.controller, request.amount);
        return request;
    }

    function getQueueLength() external view returns (uint256) {
        return queue.length - head;
    }

    function peek() external view returns (QueuedRequest memory) {
        require(head < queue.length, "Queue empty");
        return queue[head];
    }
}
