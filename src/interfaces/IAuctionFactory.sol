// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.10;

/**
 * @notice Interface for Auction factory contracts
 */
interface IAuctionFactory {
    event AuctionCreated(
        address bidAsset,
        address askAsset,
        uint256 endDate,
        address creator
    );

    /// @notice Some parameters are invalid
    error InvalidParams();
}
