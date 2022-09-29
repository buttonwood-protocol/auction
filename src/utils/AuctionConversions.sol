// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {AuctionImmutableArgs} from "./AuctionImmutableArgs.sol";
import {IAuctionConversions} from "../interfaces/IAuctionConversions.sol";

/**
 * @notice Defines some helper conversion functions for dual auctions
 */

contract AuctionConversions is IAuctionConversions, AuctionImmutableArgs {
    /**
     * @notice Transforms a price into an ask token id
     * @dev ask token ids are 256-bits in the sequence of: (1, numerator, denominator)
     */
    function toAskTokenId(uint128 price) public pure returns (uint256) {
        if (price >= 2**127) revert InvalidPrice();
        // 0b10000000... | price
        // sets the top bit to 1, leaving the rest unchanged

        return (2**255) | uint256(uint128 (price)) << 128 | priceDenominator();
    }

    /**
     * @notice Transforms a price into a bid token id
     * @dev bid token ids are 256-bits in the sequence of: (0, numerator, denominator)
     */
    function toBidTokenId(uint128 price) public pure returns (uint256) {
        if (price >= 2**127) revert InvalidPrice();
        // Price is required to be less than 2**127, so don't need to zero the top bit
        return uint256(price) << 128 | priceDenominator();
    }

    /**
     * @notice Checks if tokenId is a bid token id
     */
    function isBidTokenId(uint256 tokenId) public pure returns (bool) {
        // Top bit is 0
        return (tokenId >> 255) == 0;
    }

    /**
     * @notice Transforms a tokenId into a normal price
     */
    function toPrice(uint256 tokenId) public pure returns (uint128) {
        // Bit-shifting up and then back down to clear the top bit to 0
        // Shifting down another 128 to clear the priceDenominator
        return uint128((tokenId << 1) >> 129);
    }

    /**
     * @notice helper to translate ask tokens to bid tokens at a given price
     * @param askTokens The number of ask tokens to calculate
     * @param price The price, denominated in bidAssetDecimals
     * @return The equivalent value of bid tokens
     */
    function askToBid(uint256 askTokens, uint128 price)
        public
        pure
        returns (uint256)
    {
        return
            FixedPointMathLib.mulDivDown(
                askTokens,
                price,
                priceDenominator()
            );
    }

    /**
     * @notice helper to translate bid tokens to ask tokens at a given price
     * @param bidTokens The number of bid tokens to calculate
     * @param price The price, denominated in bidAssetDecimals
     * @return The equivalent value of ask tokens
     */
    function bidToAsk(uint256 bidTokens, uint128 price)
        public
        pure
        returns (uint256)
    {
        if (price == 0) revert InvalidPrice();
        return
            FixedPointMathLib.mulDivDown(
                bidTokens,
                priceDenominator(),
                price
            );
    }

    /**
     * @notice determine the max of two numbers
     * @param a the first number
     * @param a the second number
     * @return the maximum of the two numbers
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @notice determine the min of two numbers
     * @param a the first number
     * @param a the second number
     * @return the minimum of the two numbers
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
