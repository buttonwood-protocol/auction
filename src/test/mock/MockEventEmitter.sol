// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {IAuctionFactory} from "../../interfaces/IAuctionFactory.sol";
import {IDualAuction} from "../../interfaces/IDualAuction.sol";
import "forge-std/Vm.sol";

contract MockEventEmitter is IDualAuction, IAuctionFactory {
    function maxBid() external view returns (uint256){
        return 0;
    }

    function minAsk() external view returns (uint256){
        return 0;
    }

    function clearingPrice() external view returns (uint256){
        return 0;
    }

    function settled() external view returns (bool){
        return false;
    }

    function bid(uint256 amountIn, uint256 price) external returns (uint256){
        return 0;
    }

    function ask(uint256 amountIn, uint256 price) external returns (uint256){
        return 0;
    }

    function settle() external returns (uint256){
        return 0;
    }

    function redeem(uint256 tokenId, uint256 amount) external returns (uint256, uint256){
        return (0,0);
    }

    function createAuction(
        address bidAsset,
        address askAsset,
        uint256 minPrice,
        uint256 maxPrice,
        uint256 tickWidth,
        uint256 endDate
    ) external returns (IDualAuction) {
        return IDualAuction(address(0));
    }
}
