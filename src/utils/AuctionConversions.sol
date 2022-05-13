// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {AuctionImmutableArgs} from "./AuctionImmutableArgs.sol";

/**
 * @notice Defines some helper conversion functions for dual auctions
 */
contract AuctionConversions is AuctionImmutableArgs {
    /**
     * @notice Transforms a price into an ask token id
     * @dev ask token ids are just the price, with the top bit equal to 1
     */
    function toAskTokenId(uint256 price) public pure returns (uint256) {
        // 0x10000000... | price
        // sets the top bit to 1, leaving the rest unchanged
        return price | (2**255);
    }

    /**
     * @notice Transforms a price into a bid token id
     * @dev bid token ids are just the price, with the top bit equal to 0
     */
    function toBidTokenId(uint256 price) public pure returns (uint256) {
        // 0x01111111... & price
        // sets the top bit to 0, leaving the rest unchanged
        return price & (2**255 - 1);
    }

    /**
     * @notice Transforms a tokenId into a normal price
     */
    function toPrice(uint256 tokenId) public pure returns (uint256) {
        return toBidTokenId(tokenId);
    }

    /**
     * @notice helper to translate ask tokens to bid tokens at a given price
     * @param askTokens The number of ask tokens to calculate
     * @param price The price, denominated in bidAssetDecimals
     * @return The equivalent value of bid tokens
     */
    function askToBid(uint256 askTokens, uint256 price)
        public
        pure
        returns (uint256)
    {
        return
            FixedPointMathLib.mulDivDown(
                askTokens,
                price,
                10**bidAssetDecimals()
            );
    }

    /**
     * @notice helper to translate bid tokens to ask tokens at a given price
     * @param bidTokens The number of bid tokens to calculate
     * @param price The price, denominated in bidAssetDecimals
     * @return The equivalent value of ask tokens
     */
    function bidToAsk(uint256 bidTokens, uint256 price)
        public
        pure
        returns (uint256)
    {
        if (price == 0) return 0;
        return
            FixedPointMathLib.mulDivDown(
                bidTokens,
                10**bidAssetDecimals(),
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
