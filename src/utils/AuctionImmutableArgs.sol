// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Clone} from "clones-with-immutable-args/Clone.sol";

/**
 * @notice Defines the immutable arguments for a dual auction
 * @dev using the clones-with-immutable-args library
 * we fetch args from the code section
 */
contract AuctionImmutableArgs is Clone {

    /// @notice Reads an immutable arg with type uint128
    /// @param argOffset The offset of the arg in the packed data
    /// @return arg The arg value
    function _getArgUint128(uint256 argOffset)
    internal
    pure
    returns (uint64 arg)
    {
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            arg := shr(0x80, calldataload(add(offset, argOffset)))
        }
    }

    /**
     * @notice The asset being used to make bids
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make bids
     */
    function bidAsset() public pure returns (ERC20) {
        return ERC20(_getArgAddress(0));
    }

    /**
     * @notice The asset being used to make asks
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The asset being used to make asks
     */
    function askAsset() public pure returns (ERC20) {
        return ERC20(_getArgAddress(20));
    }

    /**
     * @notice The minimum allowed price
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The minimum allowed price
     */
    function minPrice() public pure returns (uint128) {
        return _getArgUint128(40);
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
    function maxPrice() public pure returns (uint128) {
        return _getArgUint128(56);
    }

    /**
     * @notice The width of ticks i.e. allowed prices
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The width of ticks
     */
    function tickWidth() public pure returns (uint128) {
        return _getArgUint128(72);
    }

    /**
     * @notice The denominator used to calculate the prices
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The denominator of the prices
     */
    function priceDenominator() public pure returns (uint128) {
        return _getArgUint128(88);
    }

    /**
     * @notice The timestamp at which the auction will end
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return The timestamp at which the auction will end
     */
    function endDate() public pure returns (uint256) {
        return _getArgUint256(104);
    }
}
