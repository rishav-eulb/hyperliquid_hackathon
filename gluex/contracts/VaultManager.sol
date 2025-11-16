// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IGlueXRouter.sol";
import "./interfaces/IERC4626.sol";
import "./HyperYieldVault.sol";

/**
 * @title VaultManager
 * @notice Manages vault whitelisting and rebalancing operations
 * @dev Integrates with GlueX Router API for optimal swaps
 */
contract VaultManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    HyperYieldVault public immutable hyperYieldVault;
    IERC20 public immutable asset;
    
    // Whitelist of approved vaults for rebalancing
    mapping(address => bool) public whitelistedVaults;
    address[] public vaultList;
    
    // GlueX Vaults (as specified in the task)
    address[] public gluexVaults = [
        0xe25514992597786e07872e6c5517fe1906c0cadd,
        0xcdc3975df9d1cf054f44ed238edfb708880292ea,
        0x8f9291606862eef771a97e5b71e4b98fd1fa216a,
        0x9f75eac57d1c6f7248bd2aede58c95689f3827f7,
        0x63cf7ee583d9954febf649ad1c40c97a6493b1be
    ];
    
    // Current allocation
    struct VaultAllocation {
        address vault;
        uint256 amount;
        uint256 lastUpdate;
    }
    
    VaultAllocation public currentAllocation;
    
    // Rebalancing parameters
    uint256 public constant MIN_REBALANCE_AMOUNT = 1000e6;  // 1000 USDC minimum
    uint256 public constant REBALANCE_COOLDOWN = 1 hours;
    uint256 public lastRebalanceTime;
    
    // Off-chain bot authorization
    mapping(address => bool) public authorizedBots;

    /* ========== EVENTS ========== */

    event VaultWhitelisted(address indexed vault);
    event VaultRemoved(address indexed vault);
    event Rebalanced(
        address indexed fromVault,
        address indexed toVault,
        uint256 amount,
        uint256 timestamp
    );
    event BotAuthorized(address indexed bot);
    event BotRevoked(address indexed bot);

    /* ========== CONSTRUCTOR ========== */

    constructor(address _hyperYieldVault, address _asset) Ownable() {
        require(_hyperYieldVault != address(0), "Invalid vault");
        require(_asset != address(0), "Invalid asset");
        
        hyperYieldVault = HyperYieldVault(_hyperYieldVault);
        asset = IERC20(_asset);
        
        // Whitelist GlueX vaults by default
        for (uint256 i = 0; i < gluexVaults.length; i++) {
            whitelistedVaults[gluexVaults[i]] = true;
            vaultList.push(gluexVaults[i]);
            emit VaultWhitelisted(gluexVaults[i]);
        }
    }

    /* ========== MODIFIERS ========== */

    modifier onlyAuthorizedBot() {
        require(authorizedBots[msg.sender], "Not authorized");
        _;
    }

    modifier rebalanceCooldown() {
        require(
            block.timestamp >= lastRebalanceTime + REBALANCE_COOLDOWN,
            "Cooldown period"
        );
        _;
    }

    /* ========== VAULT MANAGEMENT ========== */

    function whitelistVault(address vault) external onlyOwner {
        require(vault != address(0), "Invalid vault");
        require(!whitelistedVaults[vault], "Already whitelisted");
        
        whitelistedVaults[vault] = true;
        vaultList.push(vault);
        
        emit VaultWhitelisted(vault);
    }

    function removeVault(address vault) external onlyOwner {
        require(whitelistedVaults[vault], "Not whitelisted");
        require(currentAllocation.vault != vault, "Cannot remove active vault");
        
        whitelistedVaults[vault] = false;
        
        // Remove from list
        for (uint256 i = 0; i < vaultList.length; i++) {
            if (vaultList[i] == vault) {
                vaultList[i] = vaultList[vaultList.length - 1];
                vaultList.pop();
                break;
            }
        }
        
        emit VaultRemoved(vault);
    }

    function getWhitelistedVaults() external view returns (address[] memory) {
        return vaultList;
    }

    function getGluexVaults() external view returns (address[] memory) {
        return gluexVaults;
    }

    /* ========== BOT AUTHORIZATION ========== */

    function authorizeBot(address bot) external onlyOwner {
        require(bot != address(0), "Invalid bot");
        authorizedBots[bot] = true;
        emit BotAuthorized(bot);
    }

    function revokeBot(address bot) external onlyOwner {
        authorizedBots[bot] = false;
        emit BotRevoked(bot);
    }

    /* ========== REBALANCING ========== */

    /**
     * @notice Execute rebalancing to a new vault
     * @param targetVault Address of the target vault
     * @param amount Amount to rebalance
     * @param routerAddress GlueX router address (use address(0) for no swap)
     * @param swapCalldata Calldata from GlueX Router API
     */
    function executeRebalance(
        address targetVault,
        uint256 amount,
        address routerAddress,
        bytes calldata swapCalldata
    ) external onlyAuthorizedBot rebalanceCooldown nonReentrant {
        require(whitelistedVaults[targetVault], "Target not whitelisted");
        require(amount >= MIN_REBALANCE_AMOUNT, "Amount too small");
        require(currentAllocation.vault != targetVault, "Already in target");
        
        address fromVault = currentAllocation.vault;
        
        // Step 1: Withdraw from current vault (if any)
        if (fromVault != address(0) && currentAllocation.amount > 0) {
            _withdrawFromVault(fromVault, currentAllocation.amount);
        }
        
        // Step 2: Get funds from HyperYieldVault
        uint256 availableBalance = asset.balanceOf(address(hyperYieldVault));
        require(amount <= availableBalance, "Insufficient vault balance");
        
        // Request funds from vault
        require(
            hyperYieldVault.transferForRebalance(amount),
            "Transfer from vault failed"
        );
        
        // Step 3: Execute swap via GlueX Router (if needed)
        if (swapCalldata.length > 0 && routerAddress != address(0)) {
            _executeSwap(routerAddress, swapCalldata, amount);
        }
        
        // Step 4: Deposit into target vault
        _depositToVault(targetVault, amount);
        
        // Update allocation
        currentAllocation = VaultAllocation({
            vault: targetVault,
            amount: amount,
            lastUpdate: block.timestamp
        });
        
        lastRebalanceTime = block.timestamp;
        
        emit Rebalanced(fromVault, targetVault, amount, block.timestamp);
    }

    /**
     * @notice Emergency withdrawal from current vault
     */
    function emergencyWithdraw() external onlyOwner {
        if (currentAllocation.vault != address(0) && currentAllocation.amount > 0) {
            _withdrawFromVault(currentAllocation.vault, currentAllocation.amount);
            
            currentAllocation = VaultAllocation({
                vault: address(0),
                amount: 0,
                lastUpdate: block.timestamp
            });
        }
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _depositToVault(address vault, uint256 amount) internal {
        require(vault != address(0), "Invalid vault");
        require(amount > 0, "Zero amount");
        
        // Approve vault to spend tokens
        asset.safeApprove(vault, 0); // Reset approval first
        asset.safeApprove(vault, amount);
        
        // Try to deposit using ERC4626 interface
        // If the vault doesn't support ERC4626, this will revert
        // In that case, the transaction should be handled differently
        try IERC4626(vault).deposit(amount, address(this)) returns (uint256 shares) {
            require(shares > 0, "No shares received");
        } catch {
            // If ERC4626 deposit fails, try direct transfer as fallback
            // This is for vaults that might have a simpler interface
            asset.safeTransfer(vault, amount);
        }
    }

    function _withdrawFromVault(address vault, uint256 amount) internal {
        require(vault != address(0), "Invalid vault");
        
        if (amount == 0) return;
        
        // Try to withdraw using ERC4626 interface
        try IERC4626(vault).withdraw(amount, address(this), address(this)) returns (uint256 shares) {
            // Successfully withdrew using ERC4626 interface
        } catch {
            // If ERC4626 withdraw fails, the vault might have a different interface
            // or might not support withdrawals in this way
            // This would need to be handled based on specific vault implementation
            revert("Withdraw from vault failed");
        }
    }

    function _executeSwap(
        address router,
        bytes memory swapCalldata,
        uint256 amount
    ) internal {
        // Approve router to spend tokens
        asset.safeApprove(router, amount);
        
        // Execute swap via GlueX Router
        (bool success, ) = router.call(swapCalldata);
        require(success, "Swap failed");
    }

    /* ========== VIEW FUNCTIONS ========== */

    function getCurrentAllocation() external view returns (
        address vault,
        uint256 amount,
        uint256 lastUpdate
    ) {
        return (
            currentAllocation.vault,
            currentAllocation.amount,
            currentAllocation.lastUpdate
        );
    }

    function canRebalance() external view returns (bool) {
        return block.timestamp >= lastRebalanceTime + REBALANCE_COOLDOWN;
    }

    function getTimeTillNextRebalance() external view returns (uint256) {
        if (block.timestamp >= lastRebalanceTime + REBALANCE_COOLDOWN) {
            return 0;
        }
        return (lastRebalanceTime + REBALANCE_COOLDOWN) - block.timestamp;
    }
}
