// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC4626
 * @notice Interface for ERC-4626 Tokenized Vaults
 */
interface IERC4626 {
    /* ========== EVENTS ========== */

    event Deposit(
        address indexed sender,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /* ========== ASSET MANAGEMENT ========== */

    function asset() external view returns (address);

    function totalAssets() external view returns (uint256);

    /* ========== CONVERSION FUNCTIONS ========== */

    function convertToShares(uint256 assets) external view returns (uint256);

    function convertToAssets(uint256 shares) external view returns (uint256);

    /* ========== MAX FUNCTIONS ========== */

    function maxDeposit(address receiver) external view returns (uint256);

    function maxMint(address receiver) external view returns (uint256);

    function maxWithdraw(address owner) external view returns (uint256);

    function maxRedeem(address owner) external view returns (uint256);

    /* ========== PREVIEW FUNCTIONS ========== */

    function previewDeposit(uint256 assets) external view returns (uint256);

    function previewMint(uint256 shares) external view returns (uint256);

    function previewWithdraw(uint256 assets) external view returns (uint256);

    function previewRedeem(uint256 shares) external view returns (uint256);

    /* ========== DEPOSIT/WITHDRAW FUNCTIONS ========== */

    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);
}
