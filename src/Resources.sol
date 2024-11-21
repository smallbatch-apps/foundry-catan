// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.28;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract Resources is ERC1155 {
    
    enum ResourceTypes {
        Unknown,
        Sheep,
        Brick,
        Wood,
        Stone,
        Wheat,
        Desert
    }

    uint256 public constant MAX_RESOURCES = 19;
    address public _bank;

    constructor(address bank) ERC1155("") {
        _bank = bank;
        _mint(bank, uint(ResourceTypes.Sheep), MAX_RESOURCES, "");
        _mint(bank, uint(ResourceTypes.Brick), MAX_RESOURCES, "");
        _mint(bank, uint(ResourceTypes.Wood), MAX_RESOURCES, "");
        _mint(bank, uint(ResourceTypes.Stone), MAX_RESOURCES, "");
        _mint(bank, uint(ResourceTypes.Wheat), MAX_RESOURCES, "");
    }
}
