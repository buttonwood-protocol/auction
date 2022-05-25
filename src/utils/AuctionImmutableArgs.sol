// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Clone} from "clones-with-immutable-args/Clone.sol";
import {IAuctionFeeManager} from "../interfaces/IAuctionFeeManager.sol";

/**
 * @notice Defines the immutable arguments for a dual auction
 * @dev using the clones-with-immutable-args library
 * we fetch args from the code section
 */
contract AuctionImmutableArgs is Clone {
    /**
     * @notice The fee manager address
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The fee manager address
     */
    function feeManager() public pure returns (IAuctionFeeManager) {
        return IAuctionFeeManager(_getArgAddress(0));
    }

    /**
     * @notice The asset being used to make bids
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function bidAsset() public pure returns (ERC20) {
        return ERC20(_getArgAddress(20));
    }

    /**
     * @notice The asset being used to make asks
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make asks
     */
    function askAsset() public pure returns (ERC20) {
        return ERC20(_getArgAddress(40));
    }

    /**
     * @notice The minimum allowed price
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The minimum allowed price
     */
    function minPrice() public pure returns (uint256) {
        return _getArgUint256(60);
    }

    /**
     * @notice The maximum allowed price
     * @dev prices are denominated in terms of bidAsset per askAsset
     *  i.e. if bidAsset is USDC and askAsset is ETH, price might be
     *  3000000000 for 3000 USDC per ETH
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The maximum allowed price
     */
    function maxPrice() public pure returns (uint256) {
        return _getArgUint256(92);
    }

    /**
     * @notice The width of ticks i.e. allowed prices
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The width of ticks
     */
    function tickWidth() public pure returns (uint256) {
        return _getArgUint256(124);
    }

    /**
     * @notice The timestamp at which the auction will end
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The timestamp at which the auction will end
     */
    function endDate() public pure returns (uint256) {
        return _getArgUint256(156);
    }

    /**
     * @notice The number of dceimals for the bid asset
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The number of decimals for the bid asset
     */
    function bidAssetDecimals() public pure returns (uint256) {
        return _getArgUint8(188);
    }

    /**
     * @notice The number of decimals for the ask asset
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The number of decimals for the ask asset
     */
    function askAssetDecimals() public pure returns (uint256) {
        return _getArgUint8(189);
    }
}
