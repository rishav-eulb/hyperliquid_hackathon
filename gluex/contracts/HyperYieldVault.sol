// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IERC7540.sol";
import "./interfaces/IERC4626.sol";

/**
 * @title HyperYieldVault
 * @notice ERC-7540 compliant async vault for yield optimization on HyperEVM
 * @dev Implements asynchronous deposit and redemption flows with GlueX integration
 * @dev Does not fully implement IERC4626 as it uses async flows (ERC-7540) instead of synchronous
 */
contract HyperYieldVault is ERC20, IERC7540, ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IERC20 public immutable asset;  // Underlying asset (e.g., USDC)
    address public vaultManager;     // Address authorized to rebalance
    
    uint256 public requestNonce;     // Current request ID
    uint256 public constant SHARE_LOCK_PERIOD = 1 days;  // Lock period for new shares
    
    // Request tracking
    struct DepositRequest {
        address controller;
        uint256 assets;
        uint256 timestamp;
        bool claimed;
    }
    
    struct RedeemRequest {
        address controller;
        uint256 shares;
        uint256 timestamp;
        bool claimed;
    }
    
    mapping(uint256 => DepositRequest) public depositRequests;
    mapping(uint256 => RedeemRequest) public redeemRequests;
    mapping(address => uint256) public shareUnlockTime;  // When user's shares unlock
    
    // Request ID tracking per user
    mapping(address => uint256[]) public userDepositRequests;
    mapping(address => uint256[]) public userRedeemRequests;

    /* ========== EVENTS ========== */

    event DepositRequested(
        address indexed controller,
        address indexed owner,
        uint256 indexed requestId,
        uint256 assets
    );
    
    event RedeemRequested(
        address indexed controller,
        address indexed owner,
        uint256 indexed requestId,
        uint256 shares
    );
    
    event DepositClaimed(
        address indexed controller,
        uint256 indexed requestId,
        uint256 assets,
        uint256 shares
    );
    
    event RedeemClaimed(
        address indexed controller,
        uint256 indexed requestId,
        uint256 shares,
        uint256 assets
    );
    
    event VaultManagerUpdated(address indexed oldManager, address indexed newManager);

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _asset,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable() {
        require(_asset != address(0), "Invalid asset");
        asset = IERC20(_asset);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyVaultManager() {
        require(msg.sender == vaultManager, "Only vault manager");
        _;
    }

    /* ========== ERC-4626 VIEW FUNCTIONS ========== */

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    function maxDeposit(address) public pure returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public pure returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }

    function maxRedeem(address owner) public view returns (uint256) {
        return balanceOf(owner);
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : (shares * totalAssets() + supply - 1) / supply;
    }

    function previewWithdraw(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets : (assets * supply + totalAssets() - 1) / totalAssets();
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    /* ========== ERC-7540 ASYNC DEPOSIT FUNCTIONS ========== */

    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) external whenNotPaused nonReentrant returns (uint256 requestId) {
        require(assets > 0, "Zero assets");
        require(controller != address(0), "Invalid controller");
        
        // Transfer assets from owner to vault
        asset.safeTransferFrom(owner, address(this), assets);
        
        // Create deposit request
        requestId = ++requestNonce;
        depositRequests[requestId] = DepositRequest({
            controller: controller,
            assets: assets,
            timestamp: block.timestamp,
            claimed: false
        });
        
        userDepositRequests[controller].push(requestId);
        
        emit DepositRequested(controller, owner, requestId, assets);
        
        return requestId;
    }

    function pendingDepositRequest(
        uint256 requestId,
        address controller
    ) external view returns (bool isPending, uint256 assets) {
        DepositRequest memory request = depositRequests[requestId];
        if (request.controller == controller && !request.claimed) {
            return (true, request.assets);
        }
        return (false, 0);
    }

    function claimableDepositRequest(
        uint256 requestId,
        address controller
    ) external view returns (bool isClaimable, uint256 shares) {
        DepositRequest memory request = depositRequests[requestId];
        if (request.controller == controller && !request.claimed) {
            shares = convertToShares(request.assets);
            return (true, shares);
        }
        return (false, 0);
    }

    function deposit(
        uint256 assets,
        address receiver,
        address controller
    ) external nonReentrant returns (uint256 shares) {
        // Find matching unclaimed request
        uint256[] memory requests = userDepositRequests[controller];
        uint256 matchedRequestId = 0;
        
        for (uint256 i = 0; i < requests.length; i++) {
            DepositRequest storage request = depositRequests[requests[i]];
            if (!request.claimed && request.assets == assets && request.controller == controller) {
                matchedRequestId = requests[i];
                break;
            }
        }
        
        require(matchedRequestId != 0, "No matching request");
        
        DepositRequest storage request = depositRequests[matchedRequestId];
        require(!request.claimed, "Already claimed");
        
        // Calculate shares
        shares = convertToShares(assets);
        require(shares > 0, "Zero shares");
        
        // Mark as claimed
        request.claimed = true;
        
        // Mint shares to receiver
        _mint(receiver, shares);
        
        // Lock shares for SHARE_LOCK_PERIOD
        shareUnlockTime[receiver] = block.timestamp + SHARE_LOCK_PERIOD;
        
        emit DepositClaimed(controller, matchedRequestId, assets, shares);
        
        return shares;
    }

    /* ========== ERC-7540 ASYNC REDEEM FUNCTIONS ========== */

    function requestRedeem(
        uint256 shares,
        address controller,
        address owner
    ) external whenNotPaused nonReentrant returns (uint256 requestId) {
        require(shares > 0, "Zero shares");
        require(shares <= balanceOf(owner), "Insufficient shares");
        require(block.timestamp >= shareUnlockTime[owner], "Shares locked");
        
        // Burn shares from owner
        _burn(owner, shares);
        
        // Create redeem request
        requestId = ++requestNonce;
        redeemRequests[requestId] = RedeemRequest({
            controller: controller,
            shares: shares,
            timestamp: block.timestamp,
            claimed: false
        });
        
        userRedeemRequests[controller].push(requestId);
        
        emit RedeemRequested(controller, owner, requestId, shares);
        
        return requestId;
    }

    function pendingRedeemRequest(
        uint256 requestId,
        address controller
    ) external view returns (bool isPending, uint256 shares) {
        RedeemRequest memory request = redeemRequests[requestId];
        if (request.controller == controller && !request.claimed) {
            return (true, request.shares);
        }
        return (false, 0);
    }

    function claimableRedeemRequest(
        uint256 requestId,
        address controller
    ) external view returns (bool isClaimable, uint256 assets) {
        RedeemRequest memory request = redeemRequests[requestId];
        if (request.controller == controller && !request.claimed) {
            assets = convertToAssets(request.shares);
            return (true, assets);
        }
        return (false, 0);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address controller
    ) external nonReentrant returns (uint256 assets) {
        // Find matching unclaimed request
        uint256[] memory requests = userRedeemRequests[controller];
        uint256 matchedRequestId = 0;
        
        for (uint256 i = 0; i < requests.length; i++) {
            RedeemRequest storage request = redeemRequests[requests[i]];
            if (!request.claimed && request.shares == shares && request.controller == controller) {
                matchedRequestId = requests[i];
                break;
            }
        }
        
        require(matchedRequestId != 0, "No matching request");
        
        RedeemRequest storage request = redeemRequests[matchedRequestId];
        require(!request.claimed, "Already claimed");
        
        // Calculate assets
        assets = convertToAssets(shares);
        require(assets > 0, "Zero assets");
        require(assets <= asset.balanceOf(address(this)), "Insufficient liquidity");
        
        // Mark as claimed
        request.claimed = true;
        
        // Transfer assets to receiver
        asset.safeTransfer(receiver, assets);
        
        emit RedeemClaimed(controller, matchedRequestId, shares, assets);
        
        return assets;
    }

    /* ========== VAULT MANAGER FUNCTIONS ========== */

    function setVaultManager(address _vaultManager) external onlyOwner {
        require(_vaultManager != address(0), "Invalid manager");
        emit VaultManagerUpdated(vaultManager, _vaultManager);
        vaultManager = _vaultManager;
    }

    /**
     * @notice Transfer funds to VaultManager for rebalancing
     * @dev Only callable by the authorized VaultManager
     * @param amount Amount of assets to transfer for rebalancing
     */
    function transferForRebalance(uint256 amount) 
        external 
        onlyVaultManager 
        whenNotPaused 
        nonReentrant 
        returns (bool)
    {
        require(amount > 0, "Zero amount");
        require(amount <= asset.balanceOf(address(this)), "Insufficient balance");
        
        // Transfer assets to VaultManager for rebalancing execution
        asset.safeTransfer(vaultManager, amount);
        
        return true;
    }
    
    /**
     * @notice Receive funds back from VaultManager after rebalancing
     * @dev Only callable by the authorized VaultManager
     */
    function receiveFromRebalance() external onlyVaultManager returns (bool) {
        // VaultManager transfers funds back to this vault
        // No need to do anything here as the transfer happens externally
        return true;
    }

    /* ========== EMERGENCY FUNCTIONS ========== */

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /* ========== ERC-20 OVERRIDES ========== */

    function transfer(address to, uint256 amount) public override returns (bool) {
        require(block.timestamp >= shareUnlockTime[msg.sender], "Shares locked");
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(block.timestamp >= shareUnlockTime[from], "Shares locked");
        return super.transferFrom(from, to, amount);
    }

    /* ========== NOT IMPLEMENTED (SYNCHRONOUS ERC-4626) ========== */

    function mint(uint256, address) external pure returns (uint256) {
        revert("Use async deposit flow");
    }

    function withdraw(uint256, address, address) external pure returns (uint256) {
        revert("Use async redeem flow");
    }
}
