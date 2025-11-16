// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC7540
 * @notice Interface for ERC-7540 Asynchronous Tokenized Vaults
 * @dev Extends ERC-4626 with async deposit and redemption flows
 */
interface IERC7540 {
    /* ========== EVENTS ========== */

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

    /* ========== ASYNC DEPOSIT FUNCTIONS ========== */

    /**
     * @notice Request a deposit of assets
     * @param assets Amount of assets to deposit
     * @param controller Address that can manage this request
     * @param owner Address providing the assets
     * @return requestId Unique identifier for this request
     */
    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) external returns (uint256 requestId);

    /**
     * @notice Check if a deposit request is pending
     * @param requestId The request identifier
     * @param controller The controller address
     * @return isPending Whether the request is pending
     * @return assets Amount of assets in the request
     */
    function pendingDepositRequest(
        uint256 requestId,
        address controller
    ) external view returns (bool isPending, uint256 assets);

    /**
     * @notice Check if a deposit request is claimable
     * @param requestId The request identifier
     * @param controller The controller address
     * @return isClaimable Whether the request can be claimed
     * @return shares Amount of shares that will be received
     */
    function claimableDepositRequest(
        uint256 requestId,
        address controller
    ) external view returns (bool isClaimable, uint256 shares);

    /**
     * @notice Claim a deposit request and receive shares
     * @param assets Amount of assets to claim (must match request)
     * @param receiver Address to receive the shares
     * @param controller Address that controls the request
     * @return shares Amount of shares minted
     */
    function deposit(
        uint256 assets,
        address receiver,
        address controller
    ) external returns (uint256 shares);

    /* ========== ASYNC REDEEM FUNCTIONS ========== */

    /**
     * @notice Request a redemption of shares
     * @param shares Amount of shares to redeem
     * @param controller Address that can manage this request
     * @param owner Address providing the shares
     * @return requestId Unique identifier for this request
     */
    function requestRedeem(
        uint256 shares,
        address controller,
        address owner
    ) external returns (uint256 requestId);

    /**
     * @notice Check if a redeem request is pending
     * @param requestId The request identifier
     * @param controller The controller address
     * @return isPending Whether the request is pending
     * @return shares Amount of shares in the request
     */
    function pendingRedeemRequest(
        uint256 requestId,
        address controller
    ) external view returns (bool isPending, uint256 shares);

    /**
     * @notice Check if a redeem request is claimable
     * @param requestId The request identifier
     * @param controller The controller address
     * @return isClaimable Whether the request can be claimed
     * @return assets Amount of assets that will be received
     */
    function claimableRedeemRequest(
        uint256 requestId,
        address controller
    ) external view returns (bool isClaimable, uint256 assets);

    /**
     * @notice Claim a redeem request and receive assets
     * @param shares Amount of shares to redeem (must match request)
     * @param receiver Address to receive the assets
     * @param controller Address that controls the request
     * @return assets Amount of assets received
     */
    function redeem(
        uint256 shares,
        address receiver,
        address controller
    ) external returns (uint256 assets);
}
