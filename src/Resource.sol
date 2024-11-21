// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract Resource is ERC20, AccessControl {
    constructor(
        string memory name,
        string memory symbol,
        address bank
    ) ERC20(name, symbol) {
        _mint(bank, 19);
    }
}
