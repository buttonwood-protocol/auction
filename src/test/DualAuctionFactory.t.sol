// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockEventEmitter} from "./mock/MockEventEmitter.sol";
import {DualAuctionFactory} from "../DualAuctionFactory.sol";
import "forge-std/Vm.sol";

contract DualAuctionTest is MockEventEmitter, DSTestPlus {
  DualAuctionFactory factory;

  Vm public constant vm = Vm(HEVM_ADDRESS);

  function testConstructorZeroAddressImplementation() public {
    vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
    factory = new DualAuctionFactory(address(0));
  }
}
