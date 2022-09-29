// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {AuctionUser} from "./mock/users/AuctionUser.sol";
import {AuctionConversions} from "../utils/AuctionConversions.sol";
import {DualAuctionFactory} from "../DualAuctionFactory.sol";
import {DualAuction} from "../DualAuction.sol";
import "forge-std/Vm.sol";

contract AuctionConversionsTest is DSTestPlus {
    AuctionConversions auctionConversions;
    MockERC20 bidAsset;
    MockERC20 askAsset;
    uint256 initialTimestamp;

    Vm public constant vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        bidAsset = new MockERC20("Bid", "BID", 18);
        askAsset = new MockERC20("Ask", "ASK", 18);
        DualAuction implementation = new DualAuction();
        DualAuctionFactory factory = new DualAuctionFactory(
            address(implementation)
        );
        initialTimestamp = block.timestamp;

        auctionConversions = AuctionConversions(
            address(
                factory.createAuction(
                    address(bidAsset),
                    address(askAsset),
                    10**16,
                    10**18,
                    10**16,
                    initialTimestamp + 1 days
                )
            )
        );
    }

    function testInstantiation() public {
        assertEq(address(auctionConversions.bidAsset()), address(bidAsset));
        assertEq(address(auctionConversions.askAsset()), address(askAsset));
        assertEq(auctionConversions.minPrice(), 10**16);
        assertEq(auctionConversions.maxPrice(), 10**18);
        assertEq(auctionConversions.tickWidth(), 10**16);
        assertEq(auctionConversions.endDate(), initialTimestamp + 1 days);
        assertEq(auctionConversions.bidAssetDecimals(), 18);
        assertEq(auctionConversions.askAssetDecimals(), 18);
    }

    function testToBidTokenId(uint256 price) public {
        uint256 bidLimit = uint256(
            0x8000000000000000000000000000000000000000000000000000000000000000
        );
        vm.assume(price < bidLimit);
        assertEq(auctionConversions.toBidTokenId(price), price);
    }

    function testCannotToBidTokenIdPriceTooHigh() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidPrice()"));
        uint256 price = uint256(
            0x8000000000000000000000000000000000000000000000000000000000000000
        );
        auctionConversions.toBidTokenId(price);
    }

    function testToAskTokenId(uint256 price) public {
        uint256 askLimit = uint256(
            0x8000000000000000000000000000000000000000000000000000000000000000
        );
        vm.assume(price < askLimit);
        assertEq(auctionConversions.toAskTokenId(price), askLimit + price);
    }

    function testCannotToAskTokenIdPriceTooHigh() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidPrice()"));
        uint256 price = uint256(
            0x8000000000000000000000000000000000000000000000000000000000000000
        );
        auctionConversions.toAskTokenId(price);
    }

    function testIsBidTokenId(uint256 tokenId) public {
        assertTrue(
            auctionConversions.isBidTokenId(tokenId) ==
                ((tokenId & (2**255)) == 0)
        );
    }

    function testToPrice(uint256 tokenId) public {
        uint256 tokenIdLowerLimit = uint256(
            0x8000000000000000000000000000000000000000000000000000000000000000
        );
        vm.assume(tokenId > tokenIdLowerLimit);
        assertEq(auctionConversions.toPrice(tokenId), tokenId & (2**255 - 1));
    }

    function testBidToAsk(uint256 bidTokens, uint256 price) public {
        // Ensuring that the overflow won't happen in the mulDivDown
        vm.assume(type(uint256).max / (10**bidAsset.decimals()) >= bidTokens);
        vm.assume(price > uint256(0));
        assertEq(
            auctionConversions.bidToAsk(bidTokens, price),
            (bidTokens * (10**18)) / price
        );
    }

    function testCannotBidToAskOverflow(uint256 bidTokens, uint256 price)
        public
    {
        vm.assume(price > uint256(0));
        // Ensuring that the overflow will happen in the mulDivDown
        vm.assume(type(uint256).max / (10**bidAsset.decimals()) < bidTokens);
        vm.expectRevert();
        auctionConversions.bidToAsk(bidTokens, price);
    }

    // AskToBid does not have same zeroPrice condition
    function testCannotBidToAskZeroPrice(uint256 bidTokens) public {
        uint256 price = uint256(0);
        vm.expectRevert(abi.encodeWithSignature("InvalidPrice()"));
        auctionConversions.bidToAsk(bidTokens, price);
    }

    function testAskToBid(uint256 askTokens, uint256 price) public {
        // Ensuring that the overflow won't happen in the mulDivDown (also that 1/price does not revert in next line)
        vm.assume(price > uint256(0));
        vm.assume(type(uint256).max / price >= askTokens);
        assertEq(
            auctionConversions.askToBid(askTokens, price),
            (askTokens * price) / (10**18)
        );
    }

    function testCannotAskToBidOverflow(uint256 askTokens, uint256 price)
    public
    {
        vm.assume(price > uint256(0));
        // Ensuring that the overflow will happen in the mulDivDown
        vm.assume(type(uint256).max / price < askTokens);
        vm.expectRevert();
        auctionConversions.askToBid(askTokens, price);
    }
}
