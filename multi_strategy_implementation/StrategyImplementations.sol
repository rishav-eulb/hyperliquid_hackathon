// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BaseStrategy
 * @notice Abstract base contract for all strategies
 */
abstract contract BaseStrategy is ERC20, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    address public vault;

    modifier onlyVault() {
        require(msg.sender == vault, "Only vault");
        _;
    }

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        address vault_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        asset = asset_;
        vault = vault_;
    }

    function deposit(uint256 amount) external virtual onlyVault returns (uint256 shares);
    function withdraw(uint256 shares) external virtual onlyVault returns (uint256 amount);
    function totalAssets() external view virtual returns (uint256);

    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply();
        return (assets == 0 || supply == 0) ? assets : (assets * supply) / totalAssets();
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply();
        return (supply == 0) ? shares : (shares * totalAssets()) / supply;
    }
}

/**
 * @title MockLendingStrategy
 * @notice Simple lending strategy that simulates lending to a protocol
 * @dev In production, this would interact with Aave, Compound, etc.
 */
contract MockLendingStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    uint256 public yieldRate = 500; // 5% APY in basis points
    uint256 public lastYieldTimestamp;
    uint256 public accumulatedYield;

    event YieldAccrued(uint256 amount, uint256 timestamp);

    constructor(
        IERC20 asset_,
        address vault_
    ) BaseStrategy(asset_, "Lending Strategy Shares", "LSS", vault_) {
        lastYieldTimestamp = block.timestamp;
    }

    function deposit(uint256 amount) external override onlyVault returns (uint256 shares) {
        require(amount > 0, "Zero deposit");

        // Accrue yield before deposit
        _accrueYield();

        // Calculate shares
        uint256 supply = totalSupply();
        uint256 currentAssets = totalAssets();
        
        shares = (supply == 0) ? amount : (amount * supply) / currentAssets;

        // Transfer assets from vault
        asset.safeTransferFrom(msg.sender, address(this), amount);

        // Mint shares to vault
        _mint(msg.sender, shares);

        return shares;
    }

    function withdraw(uint256 shares) external override onlyVault returns (uint256 amount) {
        require(shares > 0, "Zero withdrawal");
        require(balanceOf(msg.sender) >= shares, "Insufficient shares");

        // Accrue yield before withdrawal
        _accrueYield();

        // Calculate assets to return
        amount = convertToAssets(shares);

        // Burn shares
        _burn(msg.sender, shares);

        // Transfer assets to vault
        asset.safeTransfer(msg.sender, amount);

        return amount;
    }

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this)) + _pendingYield();
    }

    function _accrueYield() internal {
        uint256 yield = _pendingYield();
        if (yield > 0) {
            accumulatedYield += yield;
            lastYieldTimestamp = block.timestamp;
            emit YieldAccrued(yield, block.timestamp);
        }
    }

    function _pendingYield() internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastYieldTimestamp;
        uint256 principal = asset.balanceOf(address(this));
        return (principal * yieldRate * timeElapsed) / (10000 * 365 days);
    }

    function setYieldRate(uint256 newRate) external onlyOwner {
        _accrueYield();
        yieldRate = newRate;
    }
}

/**
 * @title MockStakingStrategy
 * @notice Strategy that simulates staking tokens for rewards
 * @dev In production, this would interact with staking protocols
 */
contract MockStakingStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    uint256 public rewardRate = 800; // 8% APY
    uint256 public lockupPeriod = 7 days;
    uint256 public lastRewardTimestamp;
    
    mapping(address => uint256) public depositTimestamp;

    event Staked(address indexed user, uint256 amount, uint256 shares);
    event Unstaked(address indexed user, uint256 shares, uint256 amount);
    event RewardsHarvested(uint256 amount);

    constructor(
        IERC20 asset_,
        address vault_
    ) BaseStrategy(asset_, "Staking Strategy Shares", "SSS", vault_) {
        lastRewardTimestamp = block.timestamp;
    }

    function deposit(uint256 amount) external override onlyVault returns (uint256 shares) {
        require(amount > 0, "Zero deposit");

        // Harvest rewards before deposit
        _harvestRewards();

        uint256 supply = totalSupply();
        uint256 currentAssets = totalAssets();
        
        shares = (supply == 0) ? amount : (amount * supply) / currentAssets;

        asset.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, shares);

        depositTimestamp[msg.sender] = block.timestamp;

        emit Staked(msg.sender, amount, shares);
        return shares;
    }

    function withdraw(uint256 shares) external override onlyVault returns (uint256 amount) {
        require(shares > 0, "Zero withdrawal");
        require(balanceOf(msg.sender) >= shares, "Insufficient shares");
        require(
            block.timestamp >= depositTimestamp[msg.sender] + lockupPeriod,
            "Lockup period not ended"
        );

        _harvestRewards();

        amount = convertToAssets(shares);
        _burn(msg.sender, shares);
        asset.safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, shares, amount);
        return amount;
    }

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this)) + _pendingRewards();
    }

    function _harvestRewards() internal {
        uint256 rewards = _pendingRewards();
        if (rewards > 0) {
            lastRewardTimestamp = block.timestamp;
            emit RewardsHarvested(rewards);
        }
    }

    function _pendingRewards() internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastRewardTimestamp;
        uint256 stakedAmount = asset.balanceOf(address(this));
        return (stakedAmount * rewardRate * timeElapsed) / (10000 * 365 days);
    }

    function setRewardRate(uint256 newRate) external onlyOwner {
        _harvestRewards();
        rewardRate = newRate;
    }

    function setLockupPeriod(uint256 newPeriod) external onlyOwner {
        lockupPeriod = newPeriod;
    }
}

/**
 * @title MockYieldFarmStrategy
 * @notice Strategy that simulates yield farming
 * @dev In production, would interact with AMM protocols
 */
contract MockYieldFarmStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    uint256 public farmYield = 1200; // 12% APY
    uint256 public harvestInterval = 1 days;
    uint256 public lastHarvest;
    uint256 public totalHarvested;
    
    // Simulated impermanent loss
    uint256 public impermanentLossRate = 50; // 0.5%

    event Farmed(uint256 amount, uint256 shares);
    event Harvested(uint256 yield, uint256 loss);

    constructor(
        IERC20 asset_,
        address vault_
    ) BaseStrategy(asset_, "Yield Farm Strategy Shares", "YFS", vault_) {
        lastHarvest = block.timestamp;
    }

    function deposit(uint256 amount) external override onlyVault returns (uint256 shares) {
        require(amount > 0, "Zero deposit");

        _maybeHarvest();

        uint256 supply = totalSupply();
        uint256 currentAssets = totalAssets();
        
        shares = (supply == 0) ? amount : (amount * supply) / currentAssets;

        asset.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, shares);

        emit Farmed(amount, shares);
        return shares;
    }

    function withdraw(uint256 shares) external override onlyVault returns (uint256 amount) {
        require(shares > 0, "Zero withdrawal");

        _maybeHarvest();

        amount = convertToAssets(shares);
        
        // Apply impermanent loss
        uint256 loss = (amount * impermanentLossRate) / 10000;
        amount = amount - loss;

        _burn(msg.sender, shares);
        asset.safeTransfer(msg.sender, amount);

        return amount;
    }

    function totalAssets() public view override returns (uint256) {
        uint256 baseAssets = asset.balanceOf(address(this));
        uint256 pendingYield = _calculatePendingYield();
        return baseAssets + pendingYield;
    }

    function _maybeHarvest() internal {
        if (block.timestamp >= lastHarvest + harvestInterval) {
            uint256 yield = _calculatePendingYield();
            uint256 loss = (yield * impermanentLossRate) / 10000;
            
            totalHarvested += (yield - loss);
            lastHarvest = block.timestamp;
            
            emit Harvested(yield, loss);
        }
    }

    function _calculatePendingYield() internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastHarvest;
        uint256 principal = asset.balanceOf(address(this));
        return (principal * farmYield * timeElapsed) / (10000 * 365 days);
    }

    function setFarmYield(uint256 newYield) external onlyOwner {
        farmYield = newYield;
    }

    function setImpermanentLossRate(uint256 newRate) external onlyOwner {
        require(newRate <= 1000, "Loss rate too high");
        impermanentLossRate = newRate;
    }
}

/**
 * @title ConservativeStrategy
 * @notice Low-risk, low-yield strategy
 */
contract ConservativeStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    uint256 public yieldRate = 200; // 2% APY
    uint256 public lastUpdate;

    constructor(
        IERC20 asset_,
        address vault_
    ) BaseStrategy(asset_, "Conservative Strategy", "CONS", vault_) {
        lastUpdate = block.timestamp;
    }

    function deposit(uint256 amount) external override onlyVault returns (uint256 shares) {
        require(amount > 0, "Zero deposit");
        
        uint256 supply = totalSupply();
        shares = (supply == 0) ? amount : (amount * supply) / totalAssets();
        
        asset.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, shares);
        
        return shares;
    }

    function withdraw(uint256 shares) external override onlyVault returns (uint256 amount) {
        amount = convertToAssets(shares);
        _burn(msg.sender, shares);
        asset.safeTransfer(msg.sender, amount);
        return amount;
    }

    function totalAssets() public view override returns (uint256) {
        uint256 principal = asset.balanceOf(address(this));
        uint256 timeElapsed = block.timestamp - lastUpdate;
        uint256 yield = (principal * yieldRate * timeElapsed) / (10000 * 365 days);
        return principal + yield;
    }
}

/**
 * @title AggressiveStrategy
 * @notice High-risk, high-yield strategy
 */
contract AggressiveStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    uint256 public yieldRate = 2000; // 20% APY
    uint256 public volatility = 500; // 5% volatility
    uint256 public lastUpdate;

    constructor(
        IERC20 asset_,
        address vault_
    ) BaseStrategy(asset_, "Aggressive Strategy", "AGGR", vault_) {
        lastUpdate = block.timestamp;
    }

    function deposit(uint256 amount) external override onlyVault returns (uint256 shares) {
        require(amount > 0, "Zero deposit");
        
        uint256 supply = totalSupply();
        shares = (supply == 0) ? amount : (amount * supply) / totalAssets();
        
        asset.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, shares);
        
        return shares;
    }

    function withdraw(uint256 shares) external override onlyVault returns (uint256 amount) {
        amount = convertToAssets(shares);
        
        // Simulate volatility (random loss/gain)
        uint256 volatilityImpact = (amount * volatility) / 10000;
        // Simple pseudo-random: use block data
        if (uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 2 == 0) {
            amount += volatilityImpact;
        } else {
            amount = amount > volatilityImpact ? amount - volatilityImpact : amount / 2;
        }
        
        _burn(msg.sender, shares);
        asset.safeTransfer(msg.sender, amount);
        return amount;
    }

    function totalAssets() public view override returns (uint256) {
        uint256 principal = asset.balanceOf(address(this));
        uint256 timeElapsed = block.timestamp - lastUpdate;
        uint256 yield = (principal * yieldRate * timeElapsed) / (10000 * 365 days);
        return principal + yield;
    }
}
