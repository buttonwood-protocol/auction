// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {MockDeflationaryERC20} from "./mock/MockDeflationaryERC20.sol";
import {AuctionUser} from "./mock/users/AuctionUser.sol";
import {DualAuctionFactory} from "../DualAuctionFactory.sol";
import {DualAuction} from "../DualAuction.sol";
import "forge-std/Vm.sol";

contract DualAuctionTest is DSTestPlus {
    DualAuctionFactory factory;
    DualAuction auction;
    MockERC20 bidAsset;
    MockERC20 askAsset;
    AuctionUser user;
    uint256 initialTimestamp;

    Vm public constant vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        bidAsset = new MockERC20("Bid", "BID", 18);
        askAsset = new MockERC20("Ask", "ASK", 18);
        DualAuction implementation = new DualAuction();
        factory = new DualAuctionFactory(address(implementation));
        initialTimestamp = block.timestamp;

        auction = DualAuction(
            factory.createAuction(
                address(bidAsset),
                address(askAsset),
                10**16,
                10**18,
                10**16,
                initialTimestamp + 1 days
            )
        );
        user = new AuctionUser(address(auction));
    }

    function testInstantiationExactEndDateExpectAuctionEnded() public {
        vm.expectRevert(abi.encodeWithSignature("AuctionEnded()"));
        DualAuction(
            factory.createAuction(
                address(bidAsset),
                address(askAsset),
                10**16,
                10**18,
                10**16,
                initialTimestamp
            )
        );
    }

    function testInstantiation() public {
        assertEq(address(auction.bidAsset()), address(bidAsset));
        assertEq(address(auction.askAsset()), address(askAsset));
        assertEq(auction.minPrice(), 10**16);
        assertEq(auction.maxPrice(), 10**18);
        assertEq(auction.tickWidth(), 10**16);
        assertEq(auction.endDate(), initialTimestamp + 1 days);
        assertEq(auction.maxBid(), 0);
        assertEq(auction.minAsk(), type(uint256).max);
        assertEq(auction.clearingPrice(), 0);
        assertEq(auction.bidAssetDecimals(), 18);
        assertEq(auction.askAssetDecimals(), 18);
    }

    function testFailInstantiationInvalidBidAsset() public {
        factory.createAuction(
            address(0),
            address(askAsset),
            0,
            10**18,
            10**16,
            initialTimestamp + 1 days
        );
    }

    function testFailInstantiationInvalidAskAsset() public {
        factory.createAuction(
            address(bidAsset),
            address(0),
            0,
            10**18,
            10**16,
            initialTimestamp + 1 days
        );
    }

    function testFailInstantiationInvalidAssets() public {
        factory.createAuction(
            address(bidAsset),
            address(bidAsset),
            0,
            10**18,
            10**16,
            initialTimestamp + 1 days
        );
    }

    function testFailInstantiationInvalidPrices() public {
        factory.createAuction(
            address(bidAsset),
            address(askAsset),
            10**18,
            10**16,
            10**16,
            initialTimestamp + 1 days
        );
    }

    function testFailInstantiationInvalidMaxPrice() public {
        factory.createAuction(
            address(bidAsset),
            address(askAsset),
            0,
            2**255,
            10**16,
            initialTimestamp + 1 days
        );
    }

    function testFailInstantiationEndDate() public {
        factory.createAuction(
            address(bidAsset),
            address(askAsset),
            0,
            10**18,
            10**16,
            initialTimestamp - 1 days
        );
    }

    // BID

    function testBidBasic() public {
        // 1 for 1
        uint256 amount = 10**18;
        uint256 price = 10**18;

        bidAsset.mint(address(user), amount);
        assertEq(
            auction.balanceOf(address(user), auction.toBidTokenId(price)),
            0
        );

        user.approve(address(bidAsset), amount);
        uint256 output = user.bid(amount, price);
        assertEq(output, amount);

        assertEq(
            auction.balanceOf(address(user), auction.toBidTokenId(price)),
            amount
        );
        assertEq(bidAsset.balanceOf(address(user)), 0);
        assertEq(bidAsset.balanceOf(address(auction)), amount);
    }

    function testBid(uint256 price, uint128 amount) public {
        if (amount == 0) amount = 1;
        price = coercePrice(price);

        bidAsset.mint(address(user), amount);
        assertEq(
            auction.balanceOf(address(user), auction.toBidTokenId(price)),
            0
        );

        user.approve(address(bidAsset), amount);
        user.bid(amount, price);

        assertEq(
            auction.balanceOf(address(user), auction.toBidTokenId(price)),
            amount
        );
        assertEq(bidAsset.balanceOf(address(user)), 0);
        assertEq(bidAsset.balanceOf(address(auction)), amount);
    }

    function testMaxBid(uint128 amount) public {
        if (amount == 0) amount = 1;
        assertEq(auction.maxBid(), 0);
        uint256 price = 10**16 * 2;
        bidAsset.mint(address(user), uint256(amount) * 3);
        user.approve(address(bidAsset), uint256(amount) * 3);
        user.bid(amount, price);
        assertEq(auction.maxBid(), price);

        price = 10**16 * 3;
        user.bid(amount, price);
        assertEq(auction.maxBid(), price);

        price = 10**16;
        user.bid(amount, price);
        assertEq(auction.maxBid(), price * 3);
    }

    function testFailBidZeroAmount() public {
        user.bid(0, 10**16);
    }

    function testFailBidNotOnTick(uint128 amount) public {
        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        user.bid(amount, 10**16 + 10**15);
    }

    function testBidExpectAuctionEnded(uint128 amount) public {
        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        hevm.warp(initialTimestamp + 2 days);
        vm.expectRevert(abi.encodeWithSignature("AuctionEnded()"));
        user.bid(amount, 10**16);
    }

    function testBidExactEndDateExpectAuctionEnded(uint128 amount) public {
        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        hevm.warp(auction.endDate());
        vm.expectRevert(abi.encodeWithSignature("AuctionEnded()"));
        user.bid(amount, 10**16);
    }

    function testFailBidPriceTooHigh(uint128 amount) public {
        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        user.bid(amount, 10**18 + 1);
    }

    function testFailBidNoApprove(uint128 amount) public {
        bidAsset.mint(address(user), amount);
        user.bid(amount, 10**16);
    }

    function testFailBidPriceTooLow(uint128 amount) public {
        DualAuction newAuction = DualAuction(
            factory.createAuction(
                address(bidAsset),
                address(askAsset),
                2 * 10**16,
                10**18,
                10**16,
                initialTimestamp + 1 days
            )
        );
        AuctionUser newUser = new AuctionUser(address(newAuction));

        bidAsset.mint(address(newUser), amount);
        newUser.approve(address(bidAsset), amount);
        newUser.bid(amount, 10**16);
    }

    function testBidDeflationary() public {
        uint16 feeBps = 1;
        MockDeflationaryERC20 bidDeflationaryAsset = new MockDeflationaryERC20(
            "BidDeflationary",
            "BID-DEF",
            18,
            feeBps
        );

        DualAuction auctionDeflationary = DualAuction(
            factory.createAuction(
                address(bidDeflationaryAsset),
                address(askAsset),
                10**16,
                10**18,
                10**16,
                initialTimestamp + 1 days
            )
        );
        AuctionUser userDeflationary = new AuctionUser(
            address(auctionDeflationary)
        );

        // 1 for 1
        uint256 amount = 10**18;
        uint256 price = 10**18;

        uint256 expectedBidAmount = (amount * (10000 - feeBps)) / 10000;

        bidDeflationaryAsset.mint(address(userDeflationary), amount);
        assertEq(
            auctionDeflationary.balanceOf(
                address(userDeflationary),
                auctionDeflationary.toBidTokenId(price)
            ),
            0
        );

        userDeflationary.approve(address(bidDeflationaryAsset), amount);
        uint256 output = userDeflationary.bid(amount, price);
        assertEq(output, amount);

        assertEq(
            auctionDeflationary.balanceOf(
                address(userDeflationary),
                auctionDeflationary.toBidTokenId(price)
            ),
            expectedBidAmount
        );
        assertEq(bidDeflationaryAsset.balanceOf(address(userDeflationary)), 0);
        assertEq(
            bidDeflationaryAsset.balanceOf(address(auctionDeflationary)),
            expectedBidAmount
        );
    }

    // ASK

    function testAskBasic() public {
        // 1 token at 1:1 price
        uint256 amount = 10**18;
        uint256 price = 10**18;

        askAsset.mint(address(user), amount);
        assertEq(
            auction.balanceOf(address(user), auction.toAskTokenId(price)),
            0
        );

        user.approve(address(askAsset), amount);
        uint256 output = user.ask(amount, price);
        assertEq(output, amount);

        assertEq(
            auction.balanceOf(address(user), auction.toAskTokenId(price)),
            amount
        );
        assertEq(askAsset.balanceOf(address(auction)), amount);
    }

    function testAsk(uint256 price, uint128 amount) public {
        if (amount == 0) amount = 1;
        price = coercePrice(price);
        askAsset.mint(address(user), amount);
        assertEq(
            auction.balanceOf(address(user), auction.toAskTokenId(price)),
            0
        );

        user.approve(address(askAsset), amount);
        user.ask(amount, price);

        assertEq(
            auction.balanceOf(address(user), auction.toAskTokenId(price)),
            amount
        );
        assertEq(askAsset.balanceOf(address(auction)), amount);
    }

    function testMinAsk(uint128 amount) public {
        if (amount == 0) amount = 1;
        uint256 price = 10**16 * 3;
        askAsset.mint(address(user), uint256(amount) * 3);
        user.approve(address(askAsset), uint256(amount) * 3);
        assertEq(auction.minAsk(), type(uint256).max);
        user.ask(amount, price);

        assertEq(auction.minAsk(), price);
        price = 10**16;
        user.ask(amount, price);
        assertEq(auction.minAsk(), price);
        price = 10**16 * 2;
        user.ask(amount, price);
        assertEq(auction.minAsk(), 10**16);
    }

    function testFailAskZeroAmount() public {
        user.ask(0, 10**16);
    }

    function testFailAskNotOnTick(uint128 amount) public {
        askAsset.mint(address(user), amount);
        user.approve(address(askAsset), amount);
        user.ask(amount, 10**16 + 10**15);
    }

    function testAskExpectAuctionEnded(uint128 amount) public {
        askAsset.mint(address(user), amount);
        user.approve(address(askAsset), amount);
        hevm.warp(initialTimestamp + 2 days);
        vm.expectRevert(abi.encodeWithSignature("AuctionEnded()"));
        user.ask(amount, 10**16);
    }

    function testAskExactEndDateExpectAuctionEnded(uint128 amount) public {
        askAsset.mint(address(user), amount);
        user.approve(address(askAsset), amount);
        hevm.warp(auction.endDate());
        vm.expectRevert(abi.encodeWithSignature("AuctionEnded()"));
        user.ask(amount, 10**16);
    }

    function testFailAskPriceTooHigh(uint128 amount) public {
        askAsset.mint(address(user), amount);
        user.approve(address(askAsset), amount);
        user.ask(amount, 10**18 + 1);
    }

    function testFailAskNoApprove(uint128 amount) public {
        askAsset.mint(address(user), amount);
        user.ask(amount, 10**16);
    }

    function testFailAskPriceTooLow(uint128 amount) public {
        DualAuction newAuction = DualAuction(
            factory.createAuction(
                address(bidAsset),
                address(askAsset),
                2 * 10**16,
                10**18,
                10**16,
                initialTimestamp + 1 days
            )
        );
        AuctionUser newUser = new AuctionUser(address(newAuction));

        askAsset.mint(address(newUser), amount);
        newUser.approve(address(askAsset), amount);
        newUser.ask(amount, 10**16);
    }

    function testAskDeflationary() public {
        uint16 feeBps = 1;
        MockDeflationaryERC20 askDeflationaryAsset = new MockDeflationaryERC20(
            "AskDeflationary",
            "ASK-DEF",
            18,
            feeBps
        );

        DualAuction auctionDeflationary = DualAuction(
            factory.createAuction(
                address(bidAsset),
                address(askDeflationaryAsset),
                10**16,
                10**18,
                10**16,
                initialTimestamp + 1 days
            )
        );
        AuctionUser userDeflationary = new AuctionUser(
            address(auctionDeflationary)
        );

        // 1 token at 1:1 price
        uint256 amount = 10**18;
        uint256 price = 10**18;

        uint256 expectedAskAmount = (amount * (10000 - feeBps)) / 10000;

        askDeflationaryAsset.mint(address(userDeflationary), amount);
        assertEq(
            auctionDeflationary.balanceOf(
                address(userDeflationary),
                auctionDeflationary.toAskTokenId(price)
            ),
            0
        );

        userDeflationary.approve(address(askDeflationaryAsset), amount);
        uint256 output = userDeflationary.ask(amount, price);
        assertEq(output, amount);

        assertEq(
            auctionDeflationary.balanceOf(
                address(userDeflationary),
                auctionDeflationary.toAskTokenId(price)
            ),
            expectedAskAmount
        );
        assertEq(
            askDeflationaryAsset.balanceOf(address(auctionDeflationary)),
            expectedAskAmount
        );
    }

    // SETTLE

    function testSettleOnlyBid(uint256 price, uint128 amount) public {
        if (amount == 0) amount = 1;
        price = coercePrice(price);

        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        user.bid(amount, price);

        hevm.warp(initialTimestamp + 2 days);
        auction.settle();
        assertTrue(auction.settled());
        assertEq(auction.clearingPrice(), 0);
    }

    function testSettleOnlyAsk(uint256 price, uint128 amount) public {
        if (amount == 0) amount = 1;
        price = coercePrice(price);

        askAsset.mint(address(user), amount);
        user.approve(address(askAsset), amount);
        user.ask(amount, price);

        hevm.warp(initialTimestamp + 2 days);
        auction.settle();
        assertTrue(auction.settled());
        assertEq(auction.clearingPrice(), 0);
    }

    function testSettleBidAskNoOverlap(uint128 amount) public {
        if (amount == 0) amount = 1;

        uint256 bidPrice = 10**16;
        uint256 askPrice = 10**16 * 2;
        askAsset.mint(address(user), amount);
        user.approve(address(askAsset), amount);
        user.ask(amount, askPrice);
        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        user.bid(amount, bidPrice);

        hevm.warp(initialTimestamp + 2 days);
        auction.settle();
        assertTrue(auction.settled());
        assertEq(auction.clearingPrice(), 0);
    }

    function testSettleBidAskSamePrice() public {
        uint256 amount = 10**18;
        uint256 price = 10**18;

        askAsset.mint(address(user), amount);
        user.approve(address(askAsset), amount);
        user.ask(amount, price);
        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        user.bid(amount, price);

        hevm.warp(initialTimestamp + 2 days);
        auction.settle();
        assertTrue(auction.settled());
        assertEq(auction.clearingPrice(), 10**18);
    }

    function testSettleBidAskSamePriceWithExtraBid() public {
        uint256 amount = 10**18;
        uint256 price = 10**18;

        askAsset.mint(address(user), amount);
        user.approve(address(askAsset), amount);
        user.ask(amount, price);

        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        user.bid(amount, price);

        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        user.bid(amount, price - auction.tickWidth());

        hevm.warp(initialTimestamp + 2 days);
        auction.settle();
        assertTrue(auction.settled());
        assertEq(auction.clearingPrice(), 10**18);
        assertEq(auction.clearingBidPrice(), 10**18);
        assertEq(auction.clearingAskPrice(), 10**18);
    }

    function testSettleBidAskOverlap(uint128 amount) public {
        if (amount == 0) amount = 1;

        uint256 bidPrice = 10**16 * 2;
        uint256 askPrice = 10**16;
        askAsset.mint(address(user), amount);
        user.approve(address(askAsset), amount);
        user.ask(amount, askPrice);
        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        user.bid(amount, bidPrice);

        hevm.warp(initialTimestamp + 2 days);
        auction.settle();
        assertTrue(auction.settled());
        assertEq(auction.clearingPrice(), (10**16 * 3) / 2);
    }

    function testSettleBidAskMoreAsk() public {
        uint256 bidAmount = 10**18;
        uint256 askAmount = 10**18 * 100;
        uint256 bidPrice = 10**16 * 4;
        uint256 askPrice = 10**16 * 2;
        askAsset.mint(address(user), askAmount);
        user.approve(address(askAsset), askAmount);
        user.ask(askAmount, askPrice);
        bidAsset.mint(address(user), bidAmount);
        user.approve(address(bidAsset), bidAmount);
        user.bid(bidAmount, bidPrice);

        hevm.warp(initialTimestamp + 2 days);
        auction.settle();
        assertTrue(auction.settled());
        assertEq(auction.clearingPrice(), 10**16 * 3);
    }

    function testSettleBidAskMoreBid() public {
        uint256 bidAmount = 10**18 * 100;
        uint256 askAmount = 10**18;
        uint256 bidPrice = 10**16 * 4;
        uint256 askPrice = 10**16 * 2;
        askAsset.mint(address(user), askAmount);
        user.approve(address(askAsset), askAmount);
        user.ask(askAmount, askPrice);
        bidAsset.mint(address(user), bidAmount);
        user.approve(address(bidAsset), bidAmount);
        user.bid(bidAmount, bidPrice);

        hevm.warp(initialTimestamp + 2 days);
        auction.settle();
        assertTrue(auction.settled());
        assertEq(auction.clearingPrice(), 10**16 * 3);
    }

    function testSettleTwoEach() public {
        askAsset.mint(address(user), 10**18 * 2);
        user.approve(address(askAsset), 10**18 * 2);
        user.ask(10**18, 10**16);
        user.ask(10**18, 10**16 * 2);
        bidAsset.mint(address(user), 10**18 * 2);
        user.approve(address(bidAsset), 10**18 * 2);
        user.bid(10**18, 10**16 * 3);
        user.bid(10**16, 10**16 * 4);

        hevm.warp(initialTimestamp + 2 days);
        auction.settle();
        assertTrue(auction.settled());
        assertEq(auction.clearingPrice(), (10**16 * 5) / 2);
    }

    function testFailSettleTwice(uint256 price, uint128 amount) public {
        if (amount == 0) amount = 1;
        price = coercePrice(price);

        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        user.bid(amount, price);

        hevm.warp(initialTimestamp + 2 days);
        auction.settle();
        auction.settle();
    }

    function testFailSettleBeforeEnd(uint256 price, uint128 amount) public {
        if (amount == 0) amount = 1;
        price = coercePrice(price);

        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        user.bid(amount, price);

        auction.settle();
    }

    function testRedeemBasic() public {
        uint256 amount = 10**18;
        uint256 price = 10**18;
        askAsset.mint(address(user), amount);
        user.approve(address(askAsset), amount);
        uint256 askShares = user.ask(amount, price);
        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        uint256 bidShares = user.bid(amount, price);
        hevm.warp(initialTimestamp + 2 days);
        auction.settle();

        assertEq(askAsset.balanceOf(address(user)), 0);
        (uint256 bidReceived, uint256 askReceived) = user.redeem(
            auction.toBidTokenId(price),
            bidShares
        );
        assertEq(bidReceived, 0);
        assertEq(askReceived, 10**18);
        assertEq(askAsset.balanceOf(address(user)), amount);

        assertEq(bidAsset.balanceOf(address(user)), 0);
        (bidReceived, askReceived) = user.redeem(
            auction.toAskTokenId(price),
            askShares
        );
        assertEq(bidReceived, 10**18);
        assertEq(askReceived, 0);
        assertEq(bidAsset.balanceOf(address(user)), amount);
        assertEq(bidAsset.balanceOf(address(auction)), 0);
        assertEq(askAsset.balanceOf(address(auction)), 0);
    }

    function testRedeemDifferentPrices() public {
        uint256 amount = 10**18;
        uint256 bidPrice = 10**16 * 4;
        uint256 askPrice = 10**16;
        askAsset.mint(address(user), amount);
        user.approve(address(askAsset), amount);
        uint256 askShares = user.ask(amount, askPrice);
        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        uint256 bidShares = user.bid(amount, bidPrice);
        hevm.warp(initialTimestamp + 2 days);
        auction.settle();
        assertEq(auction.clearingPrice(), (10**16 * 5) / 2);

        assertEq(askAsset.balanceOf(address(user)), 0);
        (uint256 bidReceived, uint256 askReceived) = user.redeem(
            auction.toBidTokenId(bidPrice),
            bidShares
        );
        assertEq(bidReceived, amount - (10**16 * 5) / 2);
        assertEq(askReceived, amount);

        (bidReceived, askReceived) = user.redeem(
            auction.toAskTokenId(askPrice),
            askShares
        );
        assertEq(bidReceived, (10**16 * 5) / 2);
        assertEq(askReceived, 0);
        assertEq(askAsset.balanceOf(address(auction)), 0);
        assertEq(bidAsset.balanceOf(address(auction)), 0);
    }

    function testRedeemTwoBidsAndAsks() public {
        uint256 amount = 10**18;
        AuctionUser lowBidder = new AuctionUser(address(auction));
        bidAsset.mint(address(lowBidder), amount);
        lowBidder.approve(address(bidAsset), amount);
        uint256 lowBidderShares = lowBidder.bid(amount, 10**16 * 20);

        AuctionUser highBidder = new AuctionUser(address(auction));
        bidAsset.mint(address(highBidder), amount);
        highBidder.approve(address(bidAsset), amount);
        uint256 highBidderShares = highBidder.bid(amount, 10**16 * 60);

        AuctionUser lowAsker = new AuctionUser(address(auction));
        askAsset.mint(address(lowAsker), amount);
        lowAsker.approve(address(askAsset), amount);
        uint256 lowAskerShares = lowAsker.ask(amount, 10**16 * 40);

        AuctionUser highAsker = new AuctionUser(address(auction));
        askAsset.mint(address(highAsker), amount);
        highAsker.approve(address(askAsset), amount);
        uint256 highAskerShares = highAsker.ask(amount, 10**16 * 70);

        hevm.warp(initialTimestamp + 2 days);
        auction.settle();
        assertEq(auction.clearingPrice(), 10**16 * 50);

        (uint256 bidReceived, uint256 askReceived) = lowBidder.redeem(
            auction.toBidTokenId(10**16 * 20),
            lowBidderShares
        );
        // not cleared at all
        assertEq(bidReceived, amount);
        assertEq(askReceived, 0);

        (bidReceived, askReceived) = highBidder.redeem(
            auction.toBidTokenId(10**16 * 60),
            highBidderShares
        );
        assertEqThreshold(bidReceived, amount / 2, 2);
        assertEq(askReceived, amount);

        (bidReceived, askReceived) = lowAsker.redeem(
            auction.toAskTokenId(10**16 * 40),
            lowAskerShares
        );
        // fully cleared at 0.50
        assertEq(bidReceived, amount / 2);
        assertEq(askReceived, 0);

        (bidReceived, askReceived) = highAsker.redeem(
            auction.toAskTokenId(10**16 * 70),
            highAskerShares
        );
        // not cleared at all
        assertEq(bidReceived, 0);
        assertEq(askReceived, amount);
        assertEqThreshold(askAsset.balanceOf(address(auction)), 0, 2);
        assertEqThreshold(bidAsset.balanceOf(address(auction)), 0, 2);
    }

    function testRedeemBidNotCleared() public {
        uint256 amount = 10**18;
        uint256 price = 10**18;
        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        uint256 bidShares = user.bid(amount, price);
        hevm.warp(initialTimestamp + 2 days);
        auction.settle();

        (uint256 bidReceived, uint256 askReceived) = user.redeem(
            auction.toBidTokenId(price),
            bidShares
        );
        assertEq(bidReceived, amount);
        assertEq(askReceived, 0);
        assertEq(askAsset.balanceOf(address(user)), 0);
        assertEq(bidAsset.balanceOf(address(user)), amount);
        assertEq(bidAsset.balanceOf(address(auction)), 0);
        assertEq(askAsset.balanceOf(address(auction)), 0);
    }

    function testRedeemAskNotCleared() public {
        uint256 amount = 10**18;
        uint256 price = 10**18;
        askAsset.mint(address(user), amount);
        user.approve(address(askAsset), amount);
        uint256 askShares = user.ask(amount, price);
        hevm.warp(initialTimestamp + 2 days);
        auction.settle();

        (uint256 bidReceived, uint256 askReceived) = user.redeem(
            auction.toAskTokenId(price),
            askShares
        );
        assertEq(bidReceived, 0);
        assertEq(askReceived, amount);
        assertEq(askAsset.balanceOf(address(user)), amount);
        assertEq(bidAsset.balanceOf(address(user)), 0);
        assertEq(bidAsset.balanceOf(address(auction)), 0);
        assertEq(askAsset.balanceOf(address(auction)), 0);
    }

    function testFailRedeemZero() public {
        uint256 amount = 10**18;
        uint256 price = 10**18;
        askAsset.mint(address(user), amount);
        user.approve(address(askAsset), amount);
        user.ask(amount, price);
        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        user.bid(amount, price);
        hevm.warp(initialTimestamp + 2 days);
        auction.settle();

        user.redeem(auction.toBidTokenId(price), 0);
    }

    function testFailRedeemTooMany() public {
        uint256 amount = 10**18;
        uint256 price = 10**18;
        askAsset.mint(address(user), amount);
        user.approve(address(askAsset), amount);
        user.ask(amount, price);
        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        uint256 bidShares = user.bid(amount, price);
        hevm.warp(initialTimestamp + 2 days);
        auction.settle();

        user.redeem(auction.toBidTokenId(price), bidShares + 1);
    }

    function testFailRedeemTwice() public {
        uint256 amount = 10**18;
        uint256 price = 10**18;
        askAsset.mint(address(user), amount);
        user.approve(address(askAsset), amount);
        user.ask(amount, price);
        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        uint256 bidShares = user.bid(amount, price);
        hevm.warp(initialTimestamp + 2 days);
        auction.settle();

        user.redeem(auction.toBidTokenId(price), bidShares);

        user.redeem(auction.toBidTokenId(price), bidShares);
    }

    // vm.expectRevert() can't catch AuctionNotSettled() error due to forge limitations on functions that return structs
    // Defaulting to just `testFail`
    function testFailRedeemAuctionNotSettled() public {
        uint256 amount = 10**18;
        uint256 price = 10**18;
        askAsset.mint(address(user), amount);
        user.approve(address(askAsset), amount);
        user.ask(amount, price);
        bidAsset.mint(address(user), amount);
        user.approve(address(bidAsset), amount);
        uint256 bidShares = user.bid(amount, price);
        hevm.warp(initialTimestamp + 2 days);

        user.redeem(auction.toBidTokenId(price), bidShares);
    }

    // found during fuzzing of random bids and asks
    function testDoubleBidCounterexample() public {
        uint256 amount = 10**18;
        AuctionUser bidder = new AuctionUser(address(auction));
        bidAsset.mint(address(bidder), amount);
        bidder.approve(address(bidAsset), amount);
        uint256 bidderShares = bidder.bid(amount, 10**16 * 60);

        AuctionUser otherBidder = new AuctionUser(address(auction));
        bidAsset.mint(address(otherBidder), amount);
        otherBidder.approve(address(bidAsset), amount);
        uint256 otherBidderShares = otherBidder.bid(amount, 10**16 * 60);

        AuctionUser asker = new AuctionUser(address(auction));
        askAsset.mint(address(asker), amount);
        asker.approve(address(askAsset), amount);
        uint256 askerShares = asker.ask(amount, 10**16 * 40);

        hevm.warp(initialTimestamp + 2 days);
        auction.settle();
        assertEq(auction.clearingPrice(), 10**16 * 50);

        (uint256 bidReceived, uint256 askReceived) = bidder.redeem(
            auction.toBidTokenId(10**16 * 60),
            bidderShares
        );
        assertEq(bidReceived, 10**16 * 75);
        assertEq(askReceived, 10**16 * 50);

        (bidReceived, askReceived) = asker.redeem(
            auction.toAskTokenId(10**16 * 40),
            askerShares
        );

        assertEq(bidReceived, 10**16 * 50);
        assertEq(askReceived, 0);

        (bidReceived, askReceived) = otherBidder.redeem(
            auction.toBidTokenId(10**16 * 60),
            otherBidderShares
        );
        // fully cleared at 0.50
        assertEq(bidReceived, 10**16 * 75);
        assertEq(askReceived, 10**16 * 50);

        assertEq(askAsset.balanceOf(address(auction)), 0);
        assertEq(bidAsset.balanceOf(address(auction)), 0);
    }

    // found during fuzzing of random bids and asks
    function testOversubscriptionCounterexample() public {
        uint256 amount = 10**18;
        AuctionUser bidder = new AuctionUser(address(auction));
        bidAsset.mint(address(bidder), amount);
        bidder.approve(address(bidAsset), amount);
        uint256 bidderShares = bidder.bid(amount, 10**16 * 50);

        AuctionUser lowAsker = new AuctionUser(address(auction));
        askAsset.mint(address(lowAsker), amount);
        lowAsker.approve(address(askAsset), amount);
        uint256 lowAskerShares = lowAsker.ask(amount, 10**16 * 20);

        AuctionUser highAsker = new AuctionUser(address(auction));
        askAsset.mint(address(highAsker), amount);
        highAsker.approve(address(askAsset), amount);
        uint256 highAskerShares = highAsker.ask(amount, 10**16 * 70);

        AuctionUser midAsker = new AuctionUser(address(auction));
        askAsset.mint(address(midAsker), amount);
        midAsker.approve(address(askAsset), amount);
        uint256 midAskerShares = midAsker.ask(amount, 10**16 * 30);

        hevm.warp(initialTimestamp + 2 days);
        auction.settle();
        assertEq(auction.clearingPrice(), 10**16 * 40);

        (uint256 bidReceived, uint256 askReceived) = bidder.redeem(
            auction.toBidTokenId(10**16 * 50),
            bidderShares
        );
        assertEq(bidReceived, (10**18 * 2) / 10);
        assertEq(askReceived, 10**18 * 2);

        (bidReceived, askReceived) = lowAsker.redeem(
            auction.toAskTokenId(10**16 * 20),
            lowAskerShares
        );
        // fully cleared at 0.50
        assertEq(bidReceived, 10**17 * 4);
        assertEq(askReceived, 0);

        (bidReceived, askReceived) = highAsker.redeem(
            auction.toAskTokenId(10**16 * 70),
            highAskerShares
        );
        // not cleared at all
        assertEq(bidReceived, 0);
        assertEq(askReceived, amount);

        (bidReceived, askReceived) = midAsker.redeem(
            auction.toAskTokenId(10**16 * 30),
            midAskerShares
        );
        // fully cleared at 0.50
        assertEq(bidReceived, (10**18 * 4) / 10);
        assertEq(askReceived, 0);

        assertEq(askAsset.balanceOf(address(auction)), 0);
        assertEq(bidAsset.balanceOf(address(auction)), 0);
    }

    function testRandomBidsAsks(uint128 seed) public {
        // note: can parameterize count or change it, but runs very slow at high values
        uint8 count = 4;
        uint256[] memory tokenIds = new uint256[](count);
        uint256[] memory amounts = new uint256[](count);

        for (uint8 i = 0; i < count; i++) {
            if (seed + i == type(uint128).max) seed = 0;
            uint256 runSeed = uint256(keccak256(abi.encode(seed + i)));
            uint256 amount = uint256(keccak256(abi.encode(runSeed)));
            if (amount > 2**126 - 1) amount = (amount % 2**126) - 1;
            uint256 price = coercePrice(
                uint256(keccak256(abi.encode(runSeed + 1)))
            );
            bool isBid = uint256(keccak256(abi.encode(runSeed + 2))) % 2 == 0;

            if (isBid) {
                bidAsset.mint(address(user), amount);
                user.approve(address(bidAsset), amount);
                uint256 bidShares = user.bid(amount, price);
                tokenIds[i] = auction.toBidTokenId(price);
                amounts[i] = bidShares;
            } else {
                askAsset.mint(address(user), amount);
                user.approve(address(askAsset), amount);
                uint256 askShares = user.ask(amount, price);
                tokenIds[i] = auction.toAskTokenId(price);
                amounts[i] = askShares;
            }
        }
        hevm.warp(initialTimestamp + 2 days);
        auction.settle();

        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 amount = amounts[i];
            user.redeem(tokenId, amount);
        }

        // some floor rounding is bound to happen
        assertEqThreshold(bidAsset.balanceOf(address(auction)), 0, 20);
        assertEqThreshold(askAsset.balanceOf(address(auction)), 0, 20);
    }

    function coercePrice(uint256 price) internal view returns (uint256) {
        if (price > auction.maxPrice())
            return
                coercePrice(
                    auction.minPrice() +
                        (price % (auction.maxPrice() - auction.minPrice()))
                );
        if (price < auction.minPrice()) price = auction.minPrice();
        if ((price - auction.minPrice()) % auction.tickWidth() != 0)
            price -= uint64((price - auction.minPrice()) % auction.tickWidth());
        return price;
    }

    function assertEqThreshold(
        uint256 a,
        uint256 b,
        uint256 threshold
    ) internal {
        uint256 diff = a > b ? a - b : b - a;
        assertLt(diff, threshold);
    }
}
