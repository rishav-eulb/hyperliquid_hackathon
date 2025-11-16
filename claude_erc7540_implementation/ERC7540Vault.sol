// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @title ERC7540Vault
 * @dev Implementation of EIP-7540 Asynchronous ERC-4626 Tokenized Vault
 * @notice This vault supports both asynchronous deposits and redemptions
 */
contract ERC7540Vault is ERC20, ERC165, IERC4626 {
    using SafeERC20 for IERC20;

    // ============================================
    // STATE VARIABLES
    // ============================================

    IERC20 private immutable _asset;
    uint8 private immutable _underlyingDecimals;

    // Operator approvals: controller => operator => approved
    mapping(address => mapping(address => bool)) public isOperator;

    // Pending deposit requests: controller => assets
    mapping(address => uint256) public pendingDepositRequest;

    // Claimable deposit requests: controller => assets
    mapping(address => uint256) public claimableDepositRequest;

    // Pending redeem requests: controller => shares
    mapping(address => uint256) public pendingRedeemRequest;

    // Claimable redeem requests: controller => shares
    mapping(address => uint256) public claimableRedeemRequest;

    // Total pending assets waiting to be fulfilled
    uint256 public totalPendingAssets;

    // Total claimable assets ready to be claimed
    uint256 public totalClaimableAssets;

    // Total pending shares waiting to be fulfilled
    uint256 public totalPendingShares;

    // Total claimable shares ready to be claimed
    uint256 public totalClaimableShares;

    // Request fulfillment parameters
    address public operator; // Address authorized to fulfill requests
    uint256 public fulfillmentDelay; // Minimum delay before fulfillment

    // Request timestamps for delay tracking
    mapping(address => uint256) public depositRequestTimestamp;
    mapping(address => uint256) public redeemRequestTimestamp;

    // ============================================
    // EVENTS
    // ============================================

    event DepositRequest(
        address indexed controller,
        address indexed owner,
        uint256 indexed requestId,
        address sender,
        uint256 assets
    );

    event RedeemRequest(
        address indexed controller,
        address indexed owner,
        uint256 indexed requestId,
        address sender,
        uint256 shares
    );

    event OperatorSet(
        address indexed controller,
        address indexed operator,
        bool approved
    );

    event RequestFulfilled(
        address indexed controller,
        bool isDeposit,
        uint256 amount
    );

    // ============================================
    // ERRORS
    // ============================================

    error Unauthorized();
    error ZeroAmount();
    error InsufficientClaimable();
    error RequestNotReady();
    error PreviewUnsupported();

    // ============================================
    // CONSTRUCTOR
    // ============================================

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        address operator_,
        uint256 fulfillmentDelay_
    ) ERC20(name_, symbol_) {
        _asset = asset_;
        _underlyingDecimals = ERC20(address(asset_)).decimals();
        operator = operator_;
        fulfillmentDelay = fulfillmentDelay_;
    }

    // ============================================
    // ERC-4626 VIEW FUNCTIONS
    // ============================================

    function asset() public view virtual override returns (address) {
        return address(_asset);
    }

    function totalAssets() public view virtual override returns (uint256) {
        return _asset.balanceOf(address(this)) - totalPendingAssets - totalClaimableAssets;
    }

    function convertToShares(uint256 assets) public view virtual override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    function convertToAssets(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    function maxDeposit(address controller) public view virtual override returns (uint256) {
        return claimableDepositRequest[controller];
    }

    function maxMint(address controller) public view virtual override returns (uint256) {
        uint256 claimableAssets = claimableDepositRequest[controller];
        return _convertToShares(claimableAssets, Math.Rounding.Floor);
    }

    function maxWithdraw(address controller) public view virtual override returns (uint256) {
        uint256 claimableShares = claimableRedeemRequest[controller];
        return _convertToAssets(claimableShares, Math.Rounding.Floor);
    }

    function maxRedeem(address controller) public view virtual override returns (uint256) {
        return claimableRedeemRequest[controller];
    }

    // Preview functions must revert for async flows per EIP-7540
    function previewDeposit(uint256) public pure virtual override returns (uint256) {
        revert PreviewUnsupported();
    }

    function previewMint(uint256) public pure virtual override returns (uint256) {
        revert PreviewUnsupported();
    }

    function previewWithdraw(uint256) public pure virtual override returns (uint256) {
        revert PreviewUnsupported();
    }

    function previewRedeem(uint256) public pure virtual override returns (uint256) {
        revert PreviewUnsupported();
    }

    // ============================================
    // ERC-7540 REQUEST FUNCTIONS
    // ============================================

    /**
     * @notice Request an asynchronous deposit
     * @param assets Amount of assets to deposit
     * @param controller Address that will control the request
     * @param owner Address that owns the assets
     * @return requestId The request ID (0 in this implementation)
     */
    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) external virtual returns (uint256 requestId) {
        if (assets == 0) revert ZeroAmount();
        if (owner != msg.sender && !isOperator[owner][msg.sender]) {
            revert Unauthorized();
        }

        // Transfer assets from owner to vault
        _asset.safeTransferFrom(owner, address(this), assets);

        // Update pending request
        pendingDepositRequest[controller] += assets;
        totalPendingAssets += assets;
        depositRequestTimestamp[controller] = block.timestamp;

        emit DepositRequest(controller, owner, 0, msg.sender, assets);
        return 0; // requestId = 0 for simplified implementation
    }

    /**
     * @notice Request an asynchronous redemption
     * @param shares Amount of shares to redeem
     * @param controller Address that will control the request
     * @param owner Address that owns the shares
     * @return requestId The request ID (0 in this implementation)
     */
    function requestRedeem(
        uint256 shares,
        address controller,
        address owner
    ) external virtual returns (uint256 requestId) {
        if (shares == 0) revert ZeroAmount();
        
        // Check approval: either owner is msg.sender, or msg.sender is approved operator
        // or msg.sender has ERC20 allowance
        if (owner != msg.sender) {
            if (!isOperator[owner][msg.sender]) {
                uint256 allowed = allowance(owner, msg.sender);
                if (allowed != type(uint256).max) {
                    _approve(owner, msg.sender, allowed - shares);
                }
            }
        }

        // Burn shares immediately
        _burn(owner, shares);

        // Update pending request
        pendingRedeemRequest[controller] += shares;
        totalPendingShares += shares;
        redeemRequestTimestamp[controller] = block.timestamp;

        emit RedeemRequest(controller, owner, 0, msg.sender, shares);
        return 0; // requestId = 0 for simplified implementation
    }

    // ============================================
    // ERC-7540 VIEW FUNCTIONS
    // ============================================

    function pendingDepositRequest(
        uint256 /* requestId */,
        address controller
    ) external view virtual returns (uint256 assets) {
        return pendingDepositRequest[controller];
    }

    function claimableDepositRequest(
        uint256 /* requestId */,
        address controller
    ) external view virtual returns (uint256 assets) {
        return claimableDepositRequest[controller];
    }

    function pendingRedeemRequest(
        uint256 /* requestId */,
        address controller
    ) external view virtual returns (uint256 shares) {
        return pendingRedeemRequest[controller];
    }

    function claimableRedeemRequest(
        uint256 /* requestId */,
        address controller
    ) external view virtual returns (uint256 shares) {
        return claimableRedeemRequest[controller];
    }

    // ============================================
    // ERC-7540 OPERATOR FUNCTIONS
    // ============================================

    function setOperator(address _operator, bool approved) external virtual returns (bool) {
        isOperator[msg.sender][_operator] = approved;
        emit OperatorSet(msg.sender, _operator, approved);
        return true;
    }

    // ============================================
    // ERC-4626 CLAIM FUNCTIONS (MODIFIED)
    // ============================================

    /**
     * @notice Claim a deposit request (ERC-4626 deposit with controller)
     * @param assets Amount of assets to claim
     * @param receiver Address to receive shares
     * @param controller Address that controls the request
     * @return shares Amount of shares minted
     */
    function deposit(
        uint256 assets,
        address receiver,
        address controller
    ) public virtual returns (uint256 shares) {
        if (controller != msg.sender && !isOperator[controller][msg.sender]) {
            revert Unauthorized();
        }

        uint256 claimable = claimableDepositRequest[controller];
        if (assets > claimable) revert InsufficientClaimable();

        // Calculate shares at current rate
        shares = _convertToShares(assets, Math.Rounding.Floor);

        // Update state
        claimableDepositRequest[controller] -= assets;
        totalClaimableAssets -= assets;

        // Mint shares to receiver
        _mint(receiver, shares);

        emit Deposit(controller, receiver, assets, shares);
        return shares;
    }

    /**
     * @notice Claim a deposit request (standard ERC-4626 deposit)
     */
    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override returns (uint256) {
        return deposit(assets, receiver, msg.sender);
    }

    /**
     * @notice Claim a deposit request by specifying shares (ERC-4626 mint with controller)
     * @param shares Amount of shares to mint
     * @param receiver Address to receive shares
     * @param controller Address that controls the request
     * @return assets Amount of assets consumed
     */
    function mint(
        uint256 shares,
        address receiver,
        address controller
    ) public virtual returns (uint256 assets) {
        if (controller != msg.sender && !isOperator[controller][msg.sender]) {
            revert Unauthorized();
        }

        // Calculate assets needed at current rate
        assets = _convertToAssets(shares, Math.Rounding.Ceil);

        uint256 claimable = claimableDepositRequest[controller];
        if (assets > claimable) revert InsufficientClaimable();

        // Update state
        claimableDepositRequest[controller] -= assets;
        totalClaimableAssets -= assets;

        // Mint shares to receiver
        _mint(receiver, shares);

        emit Deposit(controller, receiver, assets, shares);
        return assets;
    }

    /**
     * @notice Claim a deposit request (standard ERC-4626 mint)
     */
    function mint(
        uint256 shares,
        address receiver
    ) public virtual override returns (uint256) {
        return mint(shares, receiver, msg.sender);
    }

    /**
     * @notice Claim a redemption request (ERC-4626 withdraw with controller)
     * @param assets Amount of assets to withdraw
     * @param receiver Address to receive assets
     * @param controller Address that controls the request
     * @return shares Amount of shares burned
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address controller
    ) public virtual returns (uint256 shares) {
        if (controller != msg.sender && !isOperator[controller][msg.sender]) {
            revert Unauthorized();
        }

        // Calculate shares needed at current rate
        shares = _convertToShares(assets, Math.Rounding.Ceil);

        uint256 claimable = claimableRedeemRequest[controller];
        if (shares > claimable) revert InsufficientClaimable();

        // Update state
        claimableRedeemRequest[controller] -= shares;
        totalClaimableShares -= shares;

        // Transfer assets to receiver
        _asset.safeTransfer(receiver, assets);

        emit Withdraw(controller, receiver, controller, assets, shares);
        return shares;
    }

    /**
     * @notice Claim a redemption request (standard ERC-4626 withdraw)
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        return withdraw(assets, receiver, owner);
    }

    /**
     * @notice Claim a redemption request (ERC-4626 redeem with controller)
     * @param shares Amount of shares to redeem
     * @param receiver Address to receive assets
     * @param controller Address that controls the request
     * @return assets Amount of assets transferred
     */
    function redeem(
        uint256 shares,
        address receiver,
        address controller
    ) public virtual returns (uint256 assets) {
        if (controller != msg.sender && !isOperator[controller][msg.sender]) {
            revert Unauthorized();
        }

        uint256 claimable = claimableRedeemRequest[controller];
        if (shares > claimable) revert InsufficientClaimable();

        // Calculate assets at current rate
        assets = _convertToAssets(shares, Math.Rounding.Floor);

        // Update state
        claimableRedeemRequest[controller] -= shares;
        totalClaimableShares -= shares;

        // Transfer assets to receiver
        _asset.safeTransfer(receiver, assets);

        emit Withdraw(controller, receiver, controller, assets, shares);
        return assets;
    }

    /**
     * @notice Claim a redemption request (standard ERC-4626 redeem)
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        return redeem(shares, receiver, owner);
    }

    // ============================================
    // FULFILLMENT FUNCTIONS (OPERATOR ONLY)
    // ============================================

    /**
     * @notice Fulfill pending deposit requests for a controller
     * @param controller Address whose request to fulfill
     * @param assets Amount of assets to make claimable
     */
    function fulfillDeposit(address controller, uint256 assets) external virtual {
        if (msg.sender != operator) revert Unauthorized();
        if (block.timestamp < depositRequestTimestamp[controller] + fulfillmentDelay) {
            revert RequestNotReady();
        }

        uint256 pending = pendingDepositRequest[controller];
        if (assets > pending) assets = pending;

        pendingDepositRequest[controller] -= assets;
        claimableDepositRequest[controller] += assets;
        totalPendingAssets -= assets;
        totalClaimableAssets += assets;

        emit RequestFulfilled(controller, true, assets);
    }

    /**
     * @notice Fulfill pending redemption requests for a controller
     * @param controller Address whose request to fulfill
     * @param shares Amount of shares to make claimable
     */
    function fulfillRedeem(address controller, uint256 shares) external virtual {
        if (msg.sender != operator) revert Unauthorized();
        if (block.timestamp < redeemRequestTimestamp[controller] + fulfillmentDelay) {
            revert RequestNotReady();
        }

        uint256 pending = pendingRedeemRequest[controller];
        if (shares > pending) shares = pending;

        pendingRedeemRequest[controller] -= shares;
        claimableRedeemRequest[controller] += shares;
        totalPendingShares -= shares;
        totalClaimableShares += shares;

        emit RequestFulfilled(controller, false, shares);
    }

    /**
     * @notice Batch fulfill multiple deposit requests
     */
    function batchFulfillDeposits(
        address[] calldata controllers,
        uint256[] calldata amounts
    ) external virtual {
        if (msg.sender != operator) revert Unauthorized();
        require(controllers.length == amounts.length, "Length mismatch");

        for (uint256 i = 0; i < controllers.length; i++) {
            address controller = controllers[i];
            uint256 assets = amounts[i];

            if (block.timestamp < depositRequestTimestamp[controller] + fulfillmentDelay) {
                continue;
            }

            uint256 pending = pendingDepositRequest[controller];
            if (assets > pending) assets = pending;

            pendingDepositRequest[controller] -= assets;
            claimableDepositRequest[controller] += assets;
            totalPendingAssets -= assets;
            totalClaimableAssets += assets;

            emit RequestFulfilled(controller, true, assets);
        }
    }

    /**
     * @notice Batch fulfill multiple redemption requests
     */
    function batchFulfillRedeems(
        address[] calldata controllers,
        uint256[] calldata amounts
    ) external virtual {
        if (msg.sender != operator) revert Unauthorized();
        require(controllers.length == amounts.length, "Length mismatch");

        for (uint256 i = 0; i < controllers.length; i++) {
            address controller = controllers[i];
            uint256 shares = amounts[i];

            if (block.timestamp < redeemRequestTimestamp[controller] + fulfillmentDelay) {
                continue;
            }

            uint256 pending = pendingRedeemRequest[controller];
            if (shares > pending) shares = pending;

            pendingRedeemRequest[controller] -= shares;
            claimableRedeemRequest[controller] += shares;
            totalPendingShares -= shares;
            totalClaimableShares += shares;

            emit RequestFulfilled(controller, false, shares);
        }
    }

    // ============================================
    // INTERNAL HELPERS
    // ============================================

    function _convertToShares(
        uint256 assets,
        Math.Rounding rounding
    ) internal view virtual returns (uint256) {
        uint256 supply = totalSupply();
        return (assets == 0 || supply == 0)
            ? assets
            : assets.mulDiv(supply, totalAssets(), rounding);
    }

    function _convertToAssets(
        uint256 shares,
        Math.Rounding rounding
    ) internal view virtual returns (uint256) {
        uint256 supply = totalSupply();
        return (supply == 0)
            ? shares
            : shares.mulDiv(totalAssets(), supply, rounding);
    }

    function _decimalsOffset() internal view virtual returns (uint8) {
        return 0;
    }

    function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
        return _underlyingDecimals + _decimalsOffset();
    }

    // ============================================
    // ERC-165 SUPPORT
    // ============================================

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == 0xe3bc4e65 || // ERC7540 operator methods
            interfaceId == 0x2f0a18c5 || // ERC7575 interface
            interfaceId == 0xce3bbe50 || // Async deposit
            interfaceId == 0x620ee8e4 || // Async redemption
            super.supportsInterface(interfaceId);
    }

    // ============================================
    // ERC7575 SUPPORT
    // ============================================

    function share() external view returns (address) {
        return address(this);
    }
}

// Math library for safe arithmetic operations
library Math {
    enum Rounding {
        Floor,
        Ceil,
        Trunc,
        Expand
    }

    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            let prod0 := mul(x, y)
            let prod1 := sub(sub(mul(x, y), prod0), lt(mulmod(x, y, not(0)), prod0))

            if iszero(denominator) {
                revert(0, 0)
            }

            if iszero(prod1) {
                z := div(prod0, denominator)
                leave
            }

            if iszero(gt(denominator, prod1)) {
                revert(0, 0)
            }

            let remainder := mulmod(x, y, denominator)
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)

            let twos := and(sub(0, denominator), denominator)
            denominator := div(denominator, twos)
            prod0 := div(prod0, twos)
            twos := add(div(sub(0, twos), twos), 1)

            prod0 := or(prod0, mul(prod1, twos))

            uint256 inv := (3 * denominator) ^ 2;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;

            z := mul(prod0, inv)
        }
    }

    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}
