pragma solidity 0.8.10;

import {DualAuctionFactory} from "../../../DualAuctionFactory.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC1155Holder} from "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract AuctionFactoryAdmin {
    DualAuctionFactory private factory;

    constructor(address _factory) {
        factory = DualAuctionFactory(_factory);
    }

    function setFee(uint256 fee) external {
        factory.setFee(fee);
    }
}
