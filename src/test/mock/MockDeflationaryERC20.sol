// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

error InvalidFeeBps(uint16 feeBps);

contract MockDeflationaryERC20 is ERC20 {

    uint16 public feeBps;
    uint16 constant public FEE_BPS_DENOMINATOR = 10000;

    constructor(string memory name, string memory symbol, uint8 decimals, uint16 _feeBps) ERC20(name, symbol, decimals) {
        if (_feeBps > FEE_BPS_DENOMINATOR) revert InvalidFeeBps(_feeBps);
        feeBps = _feeBps;
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        uint256 reducedAmount = FixedPointMathLib.mulDivDown(
            amount,
            (FEE_BPS_DENOMINATOR - feeBps),
            FEE_BPS_DENOMINATOR
        );
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += reducedAmount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        uint256 reducedAmount = FixedPointMathLib.mulDivDown(
            amount,
            (FEE_BPS_DENOMINATOR - feeBps),
            FEE_BPS_DENOMINATOR
        );
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += reducedAmount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
