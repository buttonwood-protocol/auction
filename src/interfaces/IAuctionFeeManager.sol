// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.10;

/**
 * @notice Interface for the auction fee manager
 */
interface IAuctionFeeManager {
    /// @notice The given fee is too high
    error InvalidFee();

    /**
     * @notice Get the current fee in basis points
     * @dev to be taken out of tokens cleared by the auction
     * @return The current fee in basis points
     */
    function fee() external view returns (uint256);

    /**
     * @notice Set the fee in basis points
     * @param _fee The new fee in basis points
     */
    function setFee(uint256 _fee) external;

    /**
     * @notice Claim any fees collected
     * @param token The ERC20 token to claim fees for
     */
    function claimFees(address token) external;
}
