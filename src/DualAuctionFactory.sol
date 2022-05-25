// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {DualAuction} from "./DualAuction.sol";
import {IAuctionFactory} from "./interfaces/IAuctionFactory.sol";
import {IAuctionFeeManager} from "./interfaces/IAuctionFeeManager.sol";

contract DualAuctionFactory is IAuctionFactory, IAuctionFeeManager, Ownable {
    using ClonesWithImmutableArgs for address;

    /// @notice Dont allow fees > 10000 bps or 100%
    uint256 constant MAX_FEE = 10000;

    /// @notice The implementation contract
    address public immutable implementation;

    /// @notice The fee in basis points to take from cleared auction tokens
    uint256 public override fee;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    /**
     * @inheritdoc IAuctionFeeManager
     */
    function setFee(uint256 _fee) external onlyOwner {
        if (_fee > MAX_FEE) revert InvalidFee();
        fee = _fee;
    }

    /**
     * @inheritdoc IAuctionFeeManager
     */
    function claimFees(address token) external onlyOwner {
        SafeTransferLib.safeTransfer(
            ERC20(token),
            owner(),
            ERC20(token).balanceOf(address(this))
        );
    }

    /**
     * @notice Creates a new auction
     * @param bidAsset The asset that bids are made with
     * @param askAsset The asset that asks are made with
     * @param minPrice The minimum allowed price in terms of bidAsset
     * @param maxPrice The maximum allowed price in terms of bidAsset
     * @param tickWidth The spacing between valid prices
     * @param endDate The timestamp at which the auction will end
     */
    function createAuction(
        address bidAsset,
        address askAsset,
        uint256 minPrice,
        uint256 maxPrice,
        uint256 tickWidth,
        uint256 endDate
    ) public returns (address) {
        bytes memory data = abi.encodePacked(
            address(this),
            bidAsset,
            askAsset,
            minPrice,
            maxPrice,
            tickWidth,
            endDate,
            ERC20(bidAsset).decimals(),
            ERC20(askAsset).decimals()
        );
        DualAuction clone = DualAuction(implementation.clone(data));

        clone.initialize();

        emit AuctionCreated(bidAsset, askAsset, endDate, msg.sender);
        return address(clone);
    }
}
