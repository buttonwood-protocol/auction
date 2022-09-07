// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;
import {IDualAuction} from "../../../interfaces/IDualAuction.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC1155Holder} from "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract AuctionUser is ERC1155Holder {
    IDualAuction private auction;

    constructor(IDualAuction _auction) {
        auction = IDualAuction(_auction);
    }

    function approve(address asset, uint256 amount) external {
        IERC20(asset).approve(address(auction), amount);
    }

    function bid(uint256 amount, uint256 price) external returns (uint256) {
        return auction.bid(amount, price);
    }

    function ask(uint256 amount, uint256 price) external returns (uint256) {
        return auction.ask(amount, price);
    }

    function redeem(uint256 tokenId, uint256 amount) external returns (uint256, uint256) {
        return auction.redeem(tokenId, amount);
    }
}
