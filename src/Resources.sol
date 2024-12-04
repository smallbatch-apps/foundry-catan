// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.28;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

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
    address public bank;

    constructor(address _bank) ERC1155("") {
        bank = _bank;
        _mint(bank, uint(ResourceTypes.Sheep), MAX_RESOURCES, "");
        _mint(bank, uint(ResourceTypes.Brick), MAX_RESOURCES, "");
        _mint(bank, uint(ResourceTypes.Wood), MAX_RESOURCES, "");
        _mint(bank, uint(ResourceTypes.Stone), MAX_RESOURCES, "");
        _mint(bank, uint(ResourceTypes.Wheat), MAX_RESOURCES, "");
    }

    function setApprovalForBoard(address boardContract) external {
        require(msg.sender == bank, "Only bank can set board approval");
        setApprovalForAll(boardContract, true);
    }

    function setApprovalForPlayer(address boardContract) external {
        require(msg.sender == bank, "Only bank can set board approval");
        setApprovalForAll(boardContract, true);
    }

    function buyRoad() public {
        safeTransferFrom(msg.sender, bank, uint256(ResourceTypes.Wood), 1, "");
        safeTransferFrom(msg.sender, bank, uint256(ResourceTypes.Brick), 1, "");
    }

    function buySettlement() public {
        safeTransferFrom(msg.sender, bank, uint256(ResourceTypes.Wood), 1, "");
        safeTransferFrom(msg.sender, bank, uint256(ResourceTypes.Brick), 1, "");
        safeTransferFrom(msg.sender, bank, uint256(ResourceTypes.Wheat), 1, "");
        safeTransferFrom(msg.sender, bank, uint256(ResourceTypes.Sheep), 1, "");
    }

    function buyCity() public {
        safeTransferFrom(msg.sender, bank, uint256(ResourceTypes.Stone), 2, "");
        safeTransferFrom(msg.sender, bank, uint256(ResourceTypes.Wheat), 3, "");
    }

    function buyDevelopmentCard() public {
        safeTransferFrom(msg.sender, bank, uint256(ResourceTypes.Wheat), 1, "");
        safeTransferFrom(msg.sender, bank, uint256(ResourceTypes.Stone), 1, "");
        safeTransferFrom(msg.sender, bank, uint256(ResourceTypes.Sheep), 1, "");
    }

    function resourceFromBank(
        address to,
        ResourceTypes resource,
        uint256 amount
    ) public {
        safeTransferFrom(bank, to, uint256(resource), amount, "");
    }

    function resourceToBank(
        address to,
        ResourceTypes resource,
        uint256 amount
    ) public {
        safeTransferFrom(bank, to, uint256(resource), amount, "");
    }

    function resourcePlayerToPlayer(
        address from,
        address to,
        ResourceTypes resource,
        uint256 amount
    ) public {
        safeTransferFrom(from, to, uint256(resource), amount, "");
    }
}
