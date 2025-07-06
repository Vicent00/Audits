// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title L1Vault
/// @author Boss Bridge Peeps
/// @notice This contract is responsible for locking & unlocking tokens on the L1 or L2
/// @notice It will approve the bridge to move money in and out of this contract
/// @notice It's owner should be the bridge
contract L1Vault is Ownable {
    IERC20 public token;

    // @audit-info A great centralization if msg.sender is vulnerable all money is lost

    constructor(IERC20 _token) Ownable(msg.sender) {
        token = _token;
    }

    // @audit-info Lack of checks for the target address and amount
    function approveTo(address target, uint256 amount) external onlyOwner {
        token.approve(target, amount);
    }

    // @audit-info Lack of emergency withdraw function
}
