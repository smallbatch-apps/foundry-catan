// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;


import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";


contract Resource is ERC20, AccessControl {
    constructor(
        string memory name,
        string memory symbol,
        address bank
    ) ERC20(name, symbol) {
        _mint(bank, 19);
    }
}
