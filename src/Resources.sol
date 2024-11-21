// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract Resources is ERC1155 {
    // uint256 public constant SHEEP = 0;
    // uint256 public constant BRICK = 1;
    // uint256 public constant WOOD = 2;
    // uint256 public constant STONE = 3;
    // uint256 public constant WHEAT = 4;

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
