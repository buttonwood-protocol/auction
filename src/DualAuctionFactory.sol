// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import {IERC20MetadataUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {DualAuction} from "./DualAuction.sol";
import {IDualAuction} from "./interfaces/IDualAuction.sol";
import {IAuctionFactory} from "./interfaces/IAuctionFactory.sol";

contract DualAuctionFactory is IAuctionFactory {
    using ClonesWithImmutableArgs for address;

    address public immutable implementation;

    constructor(address _implementation) {
        if (_implementation == address(0)) revert InvalidParams();
        implementation = _implementation;
    }

    /**
     * @inheritdoc IAuctionFactory
     */
    function createAuction(
        address bidAsset,
        address askAsset,
        uint128 minPrice,
        uint128 maxPrice,
        uint128 tickWidth,
        uint128 priceDenominator,
        uint256 endDate
    ) public returns (IDualAuction) {
        bytes memory data = abi.encodePacked(
            bidAsset,
            askAsset,
            minPrice,
            maxPrice,
            tickWidth,
            priceDenominator,
            endDate
        );
        DualAuction clone = DualAuction(implementation.clone(data));

        clone.initialize();

        emit AuctionCreated(bidAsset, askAsset, endDate, msg.sender, address(clone));
        return clone;
    }
}
