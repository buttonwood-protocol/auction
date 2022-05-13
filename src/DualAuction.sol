// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

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

    uint256 public bidFringeMissing;
    uint256 public askFringeMissing;
    uint256 public bidFringeCleared;
    uint256 public askFringeCleared;

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
        uint256 amountOut = bidToAsk(amountIn, price);
        _mint(msg.sender, price, amountOut, "");
        emit Bid(msg.sender, amountIn, amountOut, price);
        return amountOut;
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
        uint256 currentDesiredAskTokens = totalSupply(currentBid);
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
            }

            if (currentAskTokens == 0) {
                currentAsk += tickWidth();
                currentAskTokens = totalSupply(toAskTokenId(currentAsk));
                if (currentAskTokens > 0) {
                    highAsk = currentAsk;
                    lastAskClear = 0;
                }
            }

            if (currentDesiredAskTokens == 0) {
                currentBid -= tickWidth();
                currentDesiredAskTokens = totalSupply(currentBid);

                if (currentDesiredAskTokens > 0) {
                    lowBid = currentBid;
                    lastBidClear = 0;
                }
            }
        }

        clearingBidPrice = lowBid;
        clearingAskPrice = highAsk;
        uint256 _clearingPrice = clearingPrice();
        askFringeMissing = totalSupply(toAskTokenId(highAsk)) - lastAskClear;
        bidFringeMissing = totalSupply(lowBid) - lastBidClear;
        askFringeCleared = lastAskClear;
        bidFringeCleared = lastBidClear;

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
        (bidTokens, askTokens) = shareValue(amount, tokenId);

        _burn(msg.sender, tokenId, amount);

        if (bidTokens > 0) {
            SafeTransferLib.safeTransfer(bidAsset(), msg.sender, bidTokens);
        }

        if (askTokens > 0) {
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
                return (askToBid(shareAmount, price), 0);

            // fully cleared
            if (price > _clearingBid) {
                uint256 cleared = shareAmount;
                // extra conversions for numerical stability
                // otherwise floor rounding errors in cleared tokens in extra uncleared
                uint256 bidInput = askToBid(shareAmount, price);
                uint256 notCleared = bidInput -
                    askToBid(cleared, _clearingPrice);
                return (notCleared, cleared);
                // partially cleared
            } else {
                uint256 cleared = (shareAmount * bidFringeCleared) /
                    totalSupply(price);
                uint256 bidInput = askToBid(shareAmount, price);
                uint256 notCleared = bidInput -
                    askToBid(cleared, _clearingPrice);
                return (notCleared, cleared);
            }
        } else {
            uint256 _clearingAsk = clearingAskPrice;
            // not cleared at all
            if (_clearingPrice == 0 || price > _clearingAsk)
                return (0, shareAmount);

            if (price < _clearingAsk) {
                uint256 cleared = askToBid(shareAmount, _clearingPrice);
                // extra conversions for numerical stability
                // otherwise floor rounding errors in cleared tokens in extra uncleared
                uint256 notCleared = roundingError(shareAmount, _clearingPrice) -
                    bidToAsk(cleared, _clearingPrice);
                return (cleared, notCleared);
            } else {
                uint256 cleared = askToBid(
                    (shareAmount * askFringeCleared) /
                        totalSupply(toAskTokenId(price)),
                    _clearingPrice
                );
                uint256 clearedAskValue = bidToAsk(cleared, _clearingPrice);
                uint256 notCleared = roundingError(shareAmount, _clearingPrice) - clearedAskValue;
                return (cleared, notCleared);
            }
        }
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function roundingError(uint256 a, uint256 price) internal pure returns (uint256) {
        return bidToAsk(askToBid(a, price), price);
    }
}
