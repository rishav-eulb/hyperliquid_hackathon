// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IGlueXRouter
 * @notice Interface for GlueX Router interactions
 */
interface IGlueXRouter {
    /**
     * @notice Execute a swap through GlueX Router
     * @param inputToken Address of input token
     * @param outputToken Address of output token
     * @param inputAmount Amount of input tokens
     * @param minOutputAmount Minimum output amount (slippage protection)
     * @param recipient Address to receive output tokens
     * @return outputAmount Actual amount of output tokens received
     */
    function swap(
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 minOutputAmount,
        address recipient
    ) external returns (uint256 outputAmount);

    /**
     * @notice Get a quote for a potential swap
     * @param inputToken Address of input token
     * @param outputToken Address of output token
     * @param inputAmount Amount of input tokens
     * @return outputAmount Expected output amount
     * @return router Router address to use
     */
    function getQuote(
        address inputToken,
        address outputToken,
        uint256 inputAmount
    ) external view returns (uint256 outputAmount, address router);
}
