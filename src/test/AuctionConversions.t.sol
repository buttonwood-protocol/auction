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
        DualAuctionFactory factory = new DualAuctionFactory(address(implementation));
        initialTimestamp = block.timestamp;

        auctionConversions = AuctionConversions(
            factory.createAuction(
                address(bidAsset),
                address(askAsset),
                10**16,
                10**18,
                10**16,
                initialTimestamp + 1 days
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

    function testBidToAsk(uint256 bidTokens, uint256 price) public {
        vm.assume(bidTokens < uint256(0x100000000000000000000000000000000));
        vm.assume(price < uint256(0x100000000000000000000000000000000));
        vm.assume(price > uint128(0));
        assertEq(auctionConversions.bidToAsk(bidTokens, price), (bidTokens * (10**18)) / price);
    }

    function testCannotBidToAsk(uint256 bidTokens) public {
        vm.assume(bidTokens < uint256(0x800000000000000000));
        uint256 price = uint256(0);
        vm.expectRevert('Price must be non-zero');

        auctionConversions.bidToAsk(bidTokens, price);
    }
}
