// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/console2.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import {ERC1155SupplyUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {Clone} from "clones-with-immutable-args/Clone.sol";
import {IDualAuction} from "./interfaces/IDualAuction.sol";
import {AuctionImmutableArgs} from "./utils/AuctionImmutableArgs.sol";
import {AuctionConversions} from "./utils/AuctionConversions.sol";

/**
 * @notice DualAuction contract
 */
contract DualAuction is
    ERC1155SupplyUpgradeable,
    OwnableUpgradeable,
    Clone,
    ReentrancyGuardUpgradeable,
    AuctionImmutableArgs,
    AuctionConversions,
    IDualAuction
{
    /// @notice the maximum allowed price is 2^255 because we save the top bit for
    /// differentiating between bids and asks in the token id
    uint256 internal constant MAXIMUM_ALLOWED_PRICE = 2**255 - 1;

    /// @notice The highest bid received so far
    uint256 public maxBid;

    /// @notice The lowest ask received so far
    uint256 public minAsk;

    /// @notice The clearing bid price of the auction, set after settlement
    uint256 public clearingBidPrice;

    /// @notice The clearing ask price of the auction, set after settlement
    uint256 public clearingAskPrice;

    /// @notice The number of bid tokens cleared at the clearing price
    /// @dev needed to help calculate partial tick clears
    uint256 public bidTokensCleared;

    /// @notice The number of ask tokens cleared at the clearing price
    /// @dev needed to help calculate partial tick clears
    uint256 public askTokensCleared;

    /// @notice True if the auction has been settled, else false
    bool public settled;

    /**
     * @notice Ensures that the given price is valid
     * validity is defined as in range (minPrice, maxPrice) and
     * on a valid tick
     */
    modifier onlyValidPrice(uint256 price) {
        if (price < minPrice() || price > maxPrice()) revert InvalidPrice();
        if ((price - minPrice()) % tickWidth() != 0) revert InvalidPrice();
        _;
    }

    /**
     * @notice Ensures that the auction is active
     */
    modifier onlyAuctionActive() {
        if (block.timestamp > endDate()) revert AuctionEnded();
        _;
    }

    /**
     * @notice Ensures that the auction is finalized
     */
    modifier onlyAuctionEnded() {
        if (block.timestamp < endDate()) revert AuctionActive();
        _;
    }

    /**
     * @notice Ensures that the auction has been settled
     */
    modifier onlyAuctionSettled() {
        if (!settled) revert AuctionNotSettled();
        _;
    }

    /**
     * @notice Initializes the auction, should be called by DualAuctionFactory
     */
    function initialize() external initializer {
        __Ownable_init();
        __ERC1155_init("");
        __ERC1155Supply_init();
        __ReentrancyGuard_init();
        if (bidAsset() == askAsset()) revert InvalidAsset();
        if (
            address(bidAsset()) == address(0) ||
            address(askAsset()) == address(0)
        ) revert InvalidAsset();
        if (minPrice() == 0) revert InvalidPrice();
        if (minPrice() >= maxPrice()) revert InvalidPrice();
        if (maxPrice() > MAXIMUM_ALLOWED_PRICE) revert InvalidPrice();
        if ((maxPrice() - minPrice()) % tickWidth() != 0) revert InvalidPrice();
        if (endDate() < block.timestamp) revert AuctionEnded();
        minAsk = type(uint256).max;
    }

    /**
     * @inheritdoc IDualAuction
     */
    function bid(uint256 amountIn, uint256 price)
        external
        onlyValidPrice(price)
        onlyAuctionActive
        nonReentrant
        returns (uint256)
    {
        if (amountIn == 0) revert InvalidAmount();
        if (price > maxBid) maxBid = price;
        SafeTransferLib.safeTransferFrom(
            bidAsset(),
            msg.sender,
            address(this),
            amountIn
        );
        console2.log(0, amountIn, price);
        _mint(msg.sender, price, amountIn, "");
        emit Bid(msg.sender, amountIn, amountIn, price);
        return amountIn;
    }

    /**
     * @inheritdoc IDualAuction
     */
    function ask(uint256 amountIn, uint256 price)
        external
        onlyValidPrice(price)
        onlyAuctionActive
        nonReentrant
        returns (uint256)
    {
        if (amountIn == 0) revert InvalidAmount();
        if (minAsk == 0 || price < minAsk) minAsk = price;
        SafeTransferLib.safeTransferFrom(
            askAsset(),
            msg.sender,
            address(this),
            amountIn
        );
        console2.log(1, amountIn, price);
        _mint(msg.sender, toAskTokenId(price), amountIn, "");
        emit Ask(msg.sender, amountIn, amountIn, price);
        return amountIn;
    }

    /**
     * @inheritdoc IDualAuction
     */
    function settle() external onlyAuctionEnded returns (uint256) {
        if (settled) revert AuctionSettled();
        uint256 currentBid = maxBid;
        uint256 currentAsk = minAsk;
        uint256 lowBid = currentBid;
        uint256 highAsk = currentAsk;

        settled = true;
        // no overlap, nothing will be cleared
        if (currentBid < currentAsk) return 0;

        uint256 currentAskTokens = totalSupply(toAskTokenId(currentAsk));
        uint256 currentDesiredAskTokens = bidToAsk(
            totalSupply(currentBid),
            currentBid
        );
        uint256 lastBidClear;
        uint256 lastAskClear;

        while (
            currentBid >= currentAsk &&
            currentBid >= minPrice() &&
            currentAsk <= maxPrice()
        ) {
            uint256 cleared = min(currentAskTokens, currentDesiredAskTokens);
            currentAskTokens -= cleared;
            currentDesiredAskTokens -= cleared;

            if (cleared > 0) {
                lastAskClear += cleared;
                lastBidClear += cleared;
                console2.log("setting last clear", lastBidClear, lastAskClear, cleared);
            }

            if (currentAskTokens == 0) {
                currentAsk += tickWidth();
                currentAskTokens = totalSupply(toAskTokenId(currentAsk));
                if (currentAskTokens > 0) highAsk = currentAsk;
            }

            if (currentDesiredAskTokens == 0) {
                currentBid -= tickWidth();
                currentDesiredAskTokens = bidToAsk(
                    totalSupply(currentBid),
                    currentBid
                );
                if (currentDesiredAskTokens > 0) lowBid = currentBid;
            }
        }

        console2.log("low high", lowBid, highAsk);
        clearingBidPrice = lowBid;
        clearingAskPrice = highAsk;
        uint256 _clearingPrice = clearingPrice();
        console2.log("clearing price", _clearingPrice);
        askTokensCleared = lastAskClear;
        bidTokensCleared = askToBid(lastBidClear, _clearingPrice);
        console2.log("cleared ask, bid", askTokensCleared, lastBidClear, bidTokensCleared);

        return _clearingPrice;
    }

    /**
     * @inheritdoc IDualAuction
     */
    function redeem(uint256 tokenId, uint256 amount)
        external
        onlyAuctionSettled
        nonReentrant
        returns (uint256 bidTokens, uint256 askTokens)
    {
        if (amount == 0) revert InvalidAmount();
        uint256 price = toPrice(tokenId);
        (bidTokens, askTokens) = shareValue(amount, tokenId);

        if (toBidTokenId(tokenId) == tokenId && price == clearingBidPrice) {
            console2.log("Decreasing ask tokens");
            askTokensCleared -= askTokens;
        } else if (toAskTokenId(tokenId) == tokenId && price == clearingAskPrice) {
            console2.log("Decreasing bid tokens");
            bidTokensCleared -= bidTokens;
        }

        _burn(msg.sender, tokenId, amount);

        if (bidTokens > 0) {
            console2.log("bid redeem", bidAsset().balanceOf(address(this)), bidTokens, price);
            console2.log(clearingBidPrice, bidTokensCleared, clearingAskPrice, askTokensCleared);
            SafeTransferLib.safeTransfer(bidAsset(), msg.sender, bidTokens);
        }

        if (askTokens > 0) {
            console2.log("ask redeem", askAsset().balanceOf(address(this)), askTokens, price);
            console2.log(clearingBidPrice, bidTokensCleared, clearingAskPrice, askTokensCleared);
            SafeTransferLib.safeTransfer(askAsset(), msg.sender, askTokens);
        }
    }

    /**
     * @inheritdoc IDualAuction
     */
    function clearingPrice() public view override returns (uint256) {
        uint256 _clearingBid = clearingBidPrice;
        uint256 _clearingAsk = clearingAskPrice;
        if (_clearingBid == _clearingAsk) {
            return _clearingBid;
        } else {
            return (_clearingBid + _clearingAsk) / 2;
        }
    }

    /**
     * @dev returns the value of the shares after settlement
     * @param shareAmount The number of bid/ask slips to check
     * @param tokenId The token id of the share
     * @return bidTokens The number of bid tokens the share tokens are worth
     * @return askTokens The number of ask tokens the share tokens are worth
     */
    function shareValue(uint256 shareAmount, uint256 tokenId)
        internal
        view
        returns (uint256 bidTokens, uint256 askTokens)
    {
        uint256 price = toPrice(tokenId);
        uint256 _clearingPrice = clearingPrice();

        if (toBidTokenId(tokenId) == tokenId) {
            uint256 _clearingBid = clearingBidPrice;
            // not cleared at all
            if (_clearingPrice == 0 || price < _clearingBid)
                return (shareAmount, 0);

            uint256 cleared = price > _clearingBid
                ? bidToAsk(shareAmount, _clearingPrice) // fully cleared
                : (shareAmount * askTokensCleared) / totalSupply(price); // partial clear

            // extra conversions for numerical stability
            // otherwise floor rounding errors in cleared tokens in extra uncleared
            uint256 notCleared = askToBid(
                bidToAsk(shareAmount, _clearingPrice) - cleared,
                _clearingPrice
            );
            console2.log("bid cleared", cleared, notCleared, notCleared + askToBid(cleared, price));
            return (notCleared, cleared);
        } else {
            uint256 _clearingAsk = clearingAskPrice;
            // not cleared at all
            if (_clearingPrice == 0 || price > _clearingAsk)
                return (0, shareAmount);

            uint256 cleared = price < _clearingAsk
                ? askToBid(shareAmount, _clearingPrice) // fully cleared
                : (shareAmount * bidTokensCleared) / // partial clear
                    totalSupply(toAskTokenId(price));

            // extra conversions for numerical stability
            // otherwise floor rounding errors in cleared tokens in extra uncleared
            uint256 notCleared = bidToAsk(
                askToBid(shareAmount, _clearingPrice) - cleared,
                _clearingPrice
            );
            return (cleared, notCleared);
        }
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
