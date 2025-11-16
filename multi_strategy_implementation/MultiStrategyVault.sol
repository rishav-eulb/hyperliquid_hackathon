// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC7540Vault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title IStrategy
 * @notice Interface that all strategies must implement
 */
interface IStrategy {
    /**
     * @notice Deposit assets into the strategy
     * @param amount Amount of assets to deposit
     * @return shares Amount of strategy shares received
     */
    function deposit(uint256 amount) external returns (uint256 shares);

    /**
     * @notice Withdraw assets from the strategy
     * @param shares Amount of strategy shares to burn
     * @return amount Amount of assets received
     */
    function withdraw(uint256 shares) external returns (uint256 amount);

    /**
     * @notice Get total assets managed by strategy
     */
    function totalAssets() external view returns (uint256);

    /**
     * @notice Get balance of assets for a specific account
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Convert shares to assets
     */
    function convertToAssets(uint256 shares) external view returns (uint256);

    /**
     * @notice Convert assets to shares
     */
    function convertToShares(uint256 assets) external view returns (uint256);

    /**
     * @notice Get the underlying asset
     */
    function asset() external view returns (address);
}

/**
 * @title MultiStrategyVault
 * @notice Advanced ERC7540 vault that routes deposits to multiple yield strategies
 * @dev Implements automatic rebalancing, strategy management, and performance tracking
 */
contract MultiStrategyVault is ERC7540Vault, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============================================
    // STRUCTS
    // ============================================

    struct Strategy {
        IStrategy strategyContract;
        uint256 targetAllocation;    // Target allocation in basis points (10000 = 100%)
        uint256 currentAllocation;   // Current allocation in basis points
        uint256 totalDeposited;      // Total assets deposited to this strategy
        uint256 totalShares;         // Total strategy shares held
        uint256 minDeposit;          // Minimum deposit amount
        uint256 maxDeposit;          // Maximum deposit amount (0 = unlimited)
        bool active;
        bool acceptingDeposits;
        bool acceptingWithdrawals;
    }

    struct StrategySnapshot {
        uint256 timestamp;
        uint256 totalAssets;
        uint256 allocation;
        int256 pnl;                  // Profit/Loss since last snapshot
    }

    // ============================================
    // STATE VARIABLES
    // ============================================

    Strategy[] public strategies;
    uint256 public constant MAX_BPS = 10000;
    uint256 public constant MAX_STRATEGIES = 20;
    
    // Strategy performance tracking
    mapping(uint256 => StrategySnapshot[]) public strategyHistory;
    mapping(uint256 => uint256) public strategyPerformance; // Cumulative performance in basis points

    // Rebalancing parameters
    uint256 public rebalanceThreshold = 500; // 5% deviation triggers rebalance
    uint256 public lastRebalanceTimestamp;
    uint256 public rebalanceInterval = 1 days;

    // Emergency controls
    bool public emergencyShutdown;
    mapping(uint256 => bool) public strategyPaused;

    // Strategy withdrawal queue for redemptions
    uint256[] public withdrawalQueue;

    // Fees
    uint256 public performanceFee = 1000; // 10%
    uint256 public managementFee = 200;   // 2% annually
    address public feeRecipient;
    uint256 public lastFeeCollection;

    // Reserves
    uint256 public reserveRatio = 500; // 5% kept in vault as reserve
    uint256 public totalReserves;

    // ============================================
    // EVENTS
    // ============================================

    event StrategyAdded(
        uint256 indexed strategyId,
        address indexed strategy,
        uint256 targetAllocation
    );
    
    event StrategyRemoved(uint256 indexed strategyId);
    
    event StrategyUpdated(
        uint256 indexed strategyId,
        uint256 newAllocation,
        bool active
    );
    
    event Rebalanced(
        uint256 timestamp,
        uint256[] strategyAllocations
    );
    
    event StrategyDeposit(
        uint256 indexed strategyId,
        uint256 assets,
        uint256 shares
    );
    
    event StrategyWithdrawal(
        uint256 indexed strategyId,
        uint256 shares,
        uint256 assets
    );
    
    event EmergencyShutdown(address indexed caller);
    
    event StrategyPaused(uint256 indexed strategyId, bool paused);
    
    event FeesCollected(uint256 performanceFees, uint256 managementFees);
    
    event PerformanceRecorded(
        uint256 indexed strategyId,
        uint256 totalAssets,
        int256 pnl
    );

    // ============================================
    // ERRORS
    // ============================================

    error MaxStrategiesReached();
    error InvalidAllocation();
    error StrategyNotFound();
    error EmergencyShutdownActive();
    error StrategyInactive();
    error StrategyPausedError();
    error InsufficientReserves();
    error RebalanceTooSoon();
    error DepositBelowMinimum();
    error DepositAboveMaximum();

    // ============================================
    // CONSTRUCTOR
    // ============================================

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        address operator_,
        uint256 fulfillmentDelay_,
        address feeRecipient_
    ) 
        ERC7540Vault(asset_, name_, symbol_, operator_, fulfillmentDelay_)
        Ownable(msg.sender)
    {
        feeRecipient = feeRecipient_;
        lastFeeCollection = block.timestamp;
        lastRebalanceTimestamp = block.timestamp;
    }

    // ============================================
    // STRATEGY MANAGEMENT
    // ============================================

    /**
     * @notice Add a new strategy to the vault
     * @param strategyContract Address of the strategy contract
     * @param targetAllocation Target allocation in basis points
     * @param minDeposit Minimum deposit amount for this strategy
     * @param maxDeposit Maximum deposit amount (0 = unlimited)
     */
    function addStrategy(
        IStrategy strategyContract,
        uint256 targetAllocation,
        uint256 minDeposit,
        uint256 maxDeposit
    ) external onlyOwner {
        if (strategies.length >= MAX_STRATEGIES) revert MaxStrategiesReached();
        if (targetAllocation > MAX_BPS) revert InvalidAllocation();
        if (_getTotalTargetAllocation() + targetAllocation > MAX_BPS) {
            revert InvalidAllocation();
        }

        // Verify strategy uses same asset
        require(strategyContract.asset() == address(_asset), "Asset mismatch");

        uint256 strategyId = strategies.length;
        
        strategies.push(Strategy({
            strategyContract: strategyContract,
            targetAllocation: targetAllocation,
            currentAllocation: 0,
            totalDeposited: 0,
            totalShares: 0,
            minDeposit: minDeposit,
            maxDeposit: maxDeposit,
            active: true,
            acceptingDeposits: true,
            acceptingWithdrawals: true
        }));

        withdrawalQueue.push(strategyId);

        emit StrategyAdded(strategyId, address(strategyContract), targetAllocation);
    }

    /**
     * @notice Update strategy parameters
     */
    function updateStrategy(
        uint256 strategyId,
        uint256 newTargetAllocation,
        bool active,
        bool acceptingDeposits,
        bool acceptingWithdrawals
    ) external onlyOwner {
        if (strategyId >= strategies.length) revert StrategyNotFound();
        
        Strategy storage strategy = strategies[strategyId];
        
        // Validate new allocation
        uint256 currentTotal = _getTotalTargetAllocation();
        uint256 newTotal = currentTotal - strategy.targetAllocation + newTargetAllocation;
        if (newTotal > MAX_BPS) revert InvalidAllocation();

        strategy.targetAllocation = newTargetAllocation;
        strategy.active = active;
        strategy.acceptingDeposits = acceptingDeposits;
        strategy.acceptingWithdrawals = acceptingWithdrawals;

        emit StrategyUpdated(strategyId, newTargetAllocation, active);
    }

    /**
     * @notice Remove a strategy (must withdraw all funds first)
     */
    function removeStrategy(uint256 strategyId) external onlyOwner {
        if (strategyId >= strategies.length) revert StrategyNotFound();
        
        Strategy storage strategy = strategies[strategyId];
        require(strategy.totalShares == 0, "Strategy has active deposits");

        strategy.active = false;
        strategy.targetAllocation = 0;

        emit StrategyRemoved(strategyId);
    }

    /**
     * @notice Pause/unpause a specific strategy
     */
    function pauseStrategy(uint256 strategyId, bool paused) external onlyOwner {
        if (strategyId >= strategies.length) revert StrategyNotFound();
        strategyPaused[strategyId] = paused;
        emit StrategyPaused(strategyId, paused);
    }

    /**
     * @notice Set the withdrawal queue order
     * @dev Determines which strategies to withdraw from first during redemptions
     */
    function setWithdrawalQueue(uint256[] calldata newQueue) external onlyOwner {
        require(newQueue.length == strategies.length, "Invalid queue length");
        
        // Verify all strategy IDs are present
        for (uint256 i = 0; i < newQueue.length; i++) {
            require(newQueue[i] < strategies.length, "Invalid strategy ID");
        }
        
        withdrawalQueue = newQueue;
    }

    // ============================================
    // DEPOSIT FULFILLMENT WITH STRATEGY ALLOCATION
    // ============================================

    /**
     * @notice Fulfill deposit and automatically allocate to strategies
     * @param controller Address that controls the deposit request
     * @param assets Amount of assets to fulfill
     */
    function fulfillDepositWithStrategies(
        address controller,
        uint256 assets
    ) external nonReentrant {
        if (msg.sender != operator) revert Unauthorized();
        if (emergencyShutdown) revert EmergencyShutdownActive();

        // Standard fulfillment
        super.fulfillDeposit(controller, assets);

        // Calculate reserve amount
        uint256 reserveAmount = (assets * reserveRatio) / MAX_BPS;
        uint256 deployableAssets = assets - reserveAmount;
        totalReserves += reserveAmount;

        // Distribute remaining assets across strategies
        _distributeToStrategies(deployableAssets);
    }

    /**
     * @notice Internal function to distribute assets across strategies
     */
    function _distributeToStrategies(uint256 assets) internal {
        uint256 remainingAssets = assets;
        
        for (uint256 i = 0; i < strategies.length; i++) {
            Strategy storage strategy = strategies[i];
            
            if (!strategy.active || !strategy.acceptingDeposits || strategyPaused[i]) {
                continue;
            }

            // Calculate target amount for this strategy
            uint256 targetAmount = (assets * strategy.targetAllocation) / MAX_BPS;
            
            // Apply min/max constraints
            if (targetAmount < strategy.minDeposit) continue;
            if (strategy.maxDeposit > 0 && targetAmount > strategy.maxDeposit) {
                targetAmount = strategy.maxDeposit;
            }

            // Can't deposit more than we have
            if (targetAmount > remainingAssets) {
                targetAmount = remainingAssets;
            }

            if (targetAmount > 0) {
                _depositToStrategy(i, targetAmount);
                remainingAssets -= targetAmount;
            }

            if (remainingAssets == 0) break;
        }

        // Any remaining assets stay as reserves
        if (remainingAssets > 0) {
            totalReserves += remainingAssets;
        }
    }

    /**
     * @notice Deposit assets to a specific strategy
     */
    function _depositToStrategy(uint256 strategyId, uint256 amount) internal {
        Strategy storage strategy = strategies[strategyId];
        
        // Approve and deposit
        _asset.safeApprove(address(strategy.strategyContract), amount);
        uint256 shares = strategy.strategyContract.deposit(amount);
        
        // Update tracking
        strategy.totalDeposited += amount;
        strategy.totalShares += shares;
        
        // Update current allocation
        _updateStrategyAllocations();

        emit StrategyDeposit(strategyId, amount, shares);
    }

    // ============================================
    // REDEMPTION WITH STRATEGY WITHDRAWALS
    // ============================================

    /**
     * @notice Fulfill redemption by withdrawing from strategies
     * @param controller Address that controls the redemption request
     * @param shares Amount of vault shares to fulfill
     */
    function fulfillRedeemWithStrategies(
        address controller,
        uint256 shares
    ) external nonReentrant {
        if (msg.sender != operator) revert Unauthorized();
        if (emergencyShutdown) revert EmergencyShutdownActive();

        // Calculate assets needed
        uint256 assetsNeeded = _convertToAssets(shares, Math.Rounding.Ceil);

        // Try to use reserves first
        uint256 availableReserves = _asset.balanceOf(address(this)) - 
                                    totalPendingAssets - 
                                    totalClaimableAssets;
        
        if (availableReserves >= assetsNeeded) {
            // Can fulfill from reserves
            if (availableReserves <= totalReserves) {
                totalReserves -= assetsNeeded;
            }
        } else {
            // Need to withdraw from strategies
            uint256 amountToWithdraw = assetsNeeded - availableReserves;
            _withdrawFromStrategies(amountToWithdraw);
            
            if (availableReserves > 0 && availableReserves <= totalReserves) {
                totalReserves -= availableReserves;
            }
        }

        // Standard fulfillment
        super.fulfillRedeem(controller, shares);
    }

    /**
     * @notice Withdraw assets from strategies following the withdrawal queue
     */
    function _withdrawFromStrategies(uint256 assetsNeeded) internal {
        uint256 remainingNeeded = assetsNeeded;

        for (uint256 i = 0; i < withdrawalQueue.length; i++) {
            uint256 strategyId = withdrawalQueue[i];
            Strategy storage strategy = strategies[strategyId];

            if (!strategy.active || !strategy.acceptingWithdrawals || strategy.totalShares == 0) {
                continue;
            }

            // Get current value of strategy shares
            uint256 strategyAssets = strategy.strategyContract.convertToAssets(strategy.totalShares);
            uint256 withdrawAmount = remainingNeeded > strategyAssets ? strategyAssets : remainingNeeded;

            if (withdrawAmount > 0) {
                uint256 sharesToWithdraw = strategy.strategyContract.convertToShares(withdrawAmount);
                
                if (sharesToWithdraw > strategy.totalShares) {
                    sharesToWithdraw = strategy.totalShares;
                }

                _withdrawFromStrategy(strategyId, sharesToWithdraw);
                
                // Check actual amount received (may differ due to rounding/slippage)
                uint256 received = _asset.balanceOf(address(this));
                remainingNeeded = remainingNeeded > received ? remainingNeeded - received : 0;
            }

            if (remainingNeeded == 0) break;
        }

        if (remainingNeeded > 0) revert InsufficientReserves();
    }

    /**
     * @notice Withdraw from a specific strategy
     */
    function _withdrawFromStrategy(uint256 strategyId, uint256 shares) internal {
        Strategy storage strategy = strategies[strategyId];
        
        uint256 balanceBefore = _asset.balanceOf(address(this));
        uint256 assets = strategy.strategyContract.withdraw(shares);
        uint256 balanceAfter = _asset.balanceOf(address(this));
        
        // Verify actual amount received
        uint256 actualReceived = balanceAfter - balanceBefore;
        
        // Update tracking
        strategy.totalShares -= shares;
        if (strategy.totalDeposited >= actualReceived) {
            strategy.totalDeposited -= actualReceived;
        } else {
            strategy.totalDeposited = 0;
        }
        
        // Update current allocation
        _updateStrategyAllocations();

        emit StrategyWithdrawal(strategyId, shares, actualReceived);
    }

    // ============================================
    // REBALANCING
    // ============================================

    /**
     * @notice Rebalance strategies to match target allocations
     */
    function rebalance() external nonReentrant {
        if (msg.sender != operator && msg.sender != owner()) revert Unauthorized();
        if (emergencyShutdown) revert EmergencyShutdownActive();
        if (block.timestamp < lastRebalanceTimestamp + rebalanceInterval) {
            revert RebalanceTooSoon();
        }

        // Check if rebalancing is needed
        if (!_needsRebalancing()) {
            return;
        }

        uint256 totalVaultAssets = totalAssets();
        uint256 deployableAssets = (totalVaultAssets * (MAX_BPS - reserveRatio)) / MAX_BPS;

        // Calculate target amounts for each strategy
        uint256[] memory targetAmounts = new uint256[](strategies.length);
        uint256[] memory currentAmounts = new uint256[](strategies.length);

        for (uint256 i = 0; i < strategies.length; i++) {
            if (!strategies[i].active) continue;
            
            targetAmounts[i] = (deployableAssets * strategies[i].targetAllocation) / MAX_BPS;
            currentAmounts[i] = strategies[i].strategyContract.convertToAssets(strategies[i].totalShares);
        }

        // Execute rebalancing
        _executeRebalance(targetAmounts, currentAmounts);

        lastRebalanceTimestamp = block.timestamp;
        emit Rebalanced(block.timestamp, currentAmounts);
    }

    /**
     * @notice Check if rebalancing is needed
     */
    function _needsRebalancing() internal view returns (bool) {
        for (uint256 i = 0; i < strategies.length; i++) {
            if (!strategies[i].active) continue;
            
            uint256 currentAlloc = strategies[i].currentAllocation;
            uint256 targetAlloc = strategies[i].targetAllocation;
            
            // Check if deviation exceeds threshold
            uint256 deviation = currentAlloc > targetAlloc ? 
                currentAlloc - targetAlloc : 
                targetAlloc - currentAlloc;
            
            if (deviation > rebalanceThreshold) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Execute rebalancing by withdrawing from over-allocated strategies
     * and depositing to under-allocated ones
     */
    function _executeRebalance(
        uint256[] memory targetAmounts,
        uint256[] memory currentAmounts
    ) internal {
        // First, withdraw from over-allocated strategies
        uint256 totalWithdrawn = 0;
        
        for (uint256 i = 0; i < strategies.length; i++) {
            if (!strategies[i].active) continue;
            
            if (currentAmounts[i] > targetAmounts[i]) {
                uint256 excessAmount = currentAmounts[i] - targetAmounts[i];
                uint256 sharesToWithdraw = strategies[i].strategyContract.convertToShares(excessAmount);
                
                if (sharesToWithdraw > 0 && sharesToWithdraw <= strategies[i].totalShares) {
                    _withdrawFromStrategy(i, sharesToWithdraw);
                    totalWithdrawn += excessAmount;
                }
            }
        }

        // Then, deposit to under-allocated strategies
        for (uint256 i = 0; i < strategies.length; i++) {
            if (!strategies[i].active || !strategies[i].acceptingDeposits) continue;
            
            if (currentAmounts[i] < targetAmounts[i]) {
                uint256 deficitAmount = targetAmounts[i] - currentAmounts[i];
                
                // Can only deposit what we withdrew
                if (deficitAmount > totalWithdrawn) {
                    deficitAmount = totalWithdrawn;
                }
                
                if (deficitAmount >= strategies[i].minDeposit) {
                    _depositToStrategy(i, deficitAmount);
                    totalWithdrawn -= deficitAmount;
                }
            }
            
            if (totalWithdrawn == 0) break;
        }
    }

    // ============================================
    // PERFORMANCE TRACKING
    // ============================================

    /**
     * @notice Record strategy performance snapshot
     */
    function recordPerformance() external {
        for (uint256 i = 0; i < strategies.length; i++) {
            if (!strategies[i].active) continue;
            
            uint256 currentAssets = strategies[i].strategyContract.convertToAssets(
                strategies[i].totalShares
            );
            
            int256 pnl = int256(currentAssets) - int256(strategies[i].totalDeposited);
            
            strategyHistory[i].push(StrategySnapshot({
                timestamp: block.timestamp,
                totalAssets: currentAssets,
                allocation: strategies[i].currentAllocation,
                pnl: pnl
            }));

            emit PerformanceRecorded(i, currentAssets, pnl);
        }
    }

    /**
     * @notice Get strategy performance history
     */
    function getStrategyHistory(uint256 strategyId) 
        external 
        view 
        returns (StrategySnapshot[] memory) 
    {
        return strategyHistory[strategyId];
    }

    // ============================================
    // FEE MANAGEMENT
    // ============================================

    /**
     * @notice Collect performance and management fees
     */
    function collectFees() external {
        uint256 timeElapsed = block.timestamp - lastFeeCollection;
        uint256 totalVaultAssets = totalAssets();
        
        // Calculate management fees (annual rate)
        uint256 managementFees = (totalVaultAssets * managementFee * timeElapsed) / 
                                 (MAX_BPS * 365 days);
        
        // Calculate performance fees on gains
        uint256 performanceFees = 0;
        for (uint256 i = 0; i < strategies.length; i++) {
            if (!strategies[i].active) continue;
            
            uint256 currentValue = strategies[i].strategyContract.convertToAssets(
                strategies[i].totalShares
            );
            
            if (currentValue > strategies[i].totalDeposited) {
                uint256 profit = currentValue - strategies[i].totalDeposited;
                performanceFees += (profit * performanceFee) / MAX_BPS;
            }
        }
        
        uint256 totalFees = managementFees + performanceFees;
        
        if (totalFees > 0) {
            // Mint shares to fee recipient
            uint256 feeShares = _convertToShares(totalFees, Math.Rounding.Floor);
            _mint(feeRecipient, feeShares);
            
            lastFeeCollection = block.timestamp;
            emit FeesCollected(performanceFees, managementFees);
        }
    }

    /**
     * @notice Update fee parameters
     */
    function setFees(
        uint256 newPerformanceFee,
        uint256 newManagementFee,
        address newFeeRecipient
    ) external onlyOwner {
        require(newPerformanceFee <= 2000, "Performance fee too high"); // Max 20%
        require(newManagementFee <= 500, "Management fee too high"); // Max 5%
        
        performanceFee = newPerformanceFee;
        managementFee = newManagementFee;
        feeRecipient = newFeeRecipient;
    }

    // ============================================
    // EMERGENCY CONTROLS
    // ============================================

    /**
     * @notice Emergency shutdown - stops all deposits and triggers withdrawal from all strategies
     */
    function emergencyShutdownVault() external onlyOwner {
        emergencyShutdown = true;
        
        // Withdraw all assets from strategies
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].totalShares > 0) {
                _withdrawFromStrategy(i, strategies[i].totalShares);
            }
        }
        
        emit EmergencyShutdown(msg.sender);
    }

    /**
     * @notice Manually withdraw from a specific strategy (owner only)
     */
    function emergencyWithdrawStrategy(
        uint256 strategyId,
        uint256 shares
    ) external onlyOwner {
        _withdrawFromStrategy(strategyId, shares);
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /**
     * @notice Get all active strategies
     */
    function getActiveStrategies() external view returns (Strategy[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active) activeCount++;
        }
        
        Strategy[] memory activeStrats = new Strategy[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active) {
                activeStrats[index] = strategies[i];
                index++;
            }
        }
        
        return activeStrats;
    }

    /**
     * @notice Get strategy details
     */
    function getStrategy(uint256 strategyId) external view returns (Strategy memory) {
        require(strategyId < strategies.length, "Strategy not found");
        return strategies[strategyId];
    }

    /**
     * @notice Get total assets across all strategies
     */
    function getStrategyTotalAssets() public view returns (uint256 total) {
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active && strategies[i].totalShares > 0) {
                total += strategies[i].strategyContract.convertToAssets(
                    strategies[i].totalShares
                );
            }
        }
    }

    /**
     * @notice Override totalAssets to include strategy assets
     */
    function totalAssets() public view override returns (uint256) {
        uint256 vaultAssets = _asset.balanceOf(address(this)) - 
                              totalPendingAssets - 
                              totalClaimableAssets;
        uint256 strategyAssets = getStrategyTotalAssets();
        return vaultAssets + strategyAssets;
    }

    /**
     * @notice Get total target allocation
     */
    function _getTotalTargetAllocation() internal view returns (uint256 total) {
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active) {
                total += strategies[i].targetAllocation;
            }
        }
    }

    /**
     * @notice Update current allocations based on actual strategy values
     */
    function _updateStrategyAllocations() internal {
        uint256 totalVaultAssets = totalAssets();
        if (totalVaultAssets == 0) return;

        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active && strategies[i].totalShares > 0) {
                uint256 strategyAssets = strategies[i].strategyContract.convertToAssets(
                    strategies[i].totalShares
                );
                strategies[i].currentAllocation = (strategyAssets * MAX_BPS) / totalVaultAssets;
            } else {
                strategies[i].currentAllocation = 0;
            }
        }
    }

    /**
     * @notice Set rebalancing parameters
     */
    function setRebalanceParameters(
        uint256 newThreshold,
        uint256 newInterval
    ) external onlyOwner {
        require(newThreshold <= 1000, "Threshold too high"); // Max 10%
        rebalanceThreshold = newThreshold;
        rebalanceInterval = newInterval;
    }

    /**
     * @notice Set reserve ratio
     */
    function setReserveRatio(uint256 newRatio) external onlyOwner {
        require(newRatio <= 2000, "Reserve ratio too high"); // Max 20%
        reserveRatio = newRatio;
    }
}
