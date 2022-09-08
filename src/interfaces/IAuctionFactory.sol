// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

/**
 * @notice Interface for Auction factory contracts
 */
interface IAuctionFactory {
    event AuctionCreated(
        address indexed bidAsset,
        address indexed askAsset,
        uint256 endDate,
        address indexed creator
    );

    /// @notice Some parameters are invalid
    error InvalidParams();
}
