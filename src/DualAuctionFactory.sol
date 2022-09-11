// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import {IERC20MetadataUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {DualAuction} from "./DualAuction.sol";
import {IAuctionFactory} from "./interfaces/IAuctionFactory.sol";

contract DualAuctionFactory is IAuctionFactory {
    using ClonesWithImmutableArgs for address;

    address public immutable implementation;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    /**
     * @notice Creates a new auction
     * @param bidAsset The asset that bids are made with
     * @param askAsset The asset that asks are made with
     * @param minPrice The minimum allowed price in terms of bidAsset
     * @param maxPrice The maximum allowed price in terms of bidAsset
     * @param tickWidth The spacing between valid prices
     * @param endDate The timestamp at which the auction will end
     * @return auction The address of the new auction
     */
    function createAuction(
        address bidAsset,
        address askAsset,
        uint256 minPrice,
        uint256 maxPrice,
        uint256 tickWidth,
        uint256 endDate
    ) public returns (address) {
        bytes memory data = abi.encodePacked(
            bidAsset,
            askAsset,
            minPrice,
            maxPrice,
            tickWidth,
            endDate,
            IERC20MetadataUpgradeable(bidAsset).decimals(),
            IERC20MetadataUpgradeable(askAsset).decimals()
        );
        DualAuction clone = DualAuction(implementation.clone(data));

        clone.initialize();

        emit AuctionCreated(bidAsset, askAsset, endDate, msg.sender, address(clone));
        return address(clone);
    }
}
