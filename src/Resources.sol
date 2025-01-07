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

    uint256 public constant SHEEP = uint256(ResourceTypes.Sheep);
    uint256 public constant BRICK = uint256(ResourceTypes.Brick);
    uint256 public constant WOOD = uint256(ResourceTypes.Wood);
    uint256 public constant STONE = uint256(ResourceTypes.Stone);
    uint256 public constant WHEAT = uint256(ResourceTypes.Wheat);

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

    function batchResourcesPlayerToPlayer(
        address fromPlayer,
        address toPlayer,
        bytes5 tradeResources
    ) public {
        require(
            checkPlayerHasResourcesForTrade(fromPlayer, tradeResources),
            "Player does not have resources for trade"
        );

        batchTransfers(fromPlayer, toPlayer, tradeResources);
    }

    function batchResourcesToBank(
        address fromPlayer,
        bytes5 tradeResources
    ) public {
        require(
            checkPlayerHasResourcesForTrade(fromPlayer, tradeResources),
            "Player does not have resources for trade"
        );

        batchTransfers(fromPlayer, bank, tradeResources);
    }

    function batchResourcesFromBank(
        address toPlayer,
        bytes5 tradeResources
    ) public {
        require(
            checkPlayerHasResourcesForTrade(bank, tradeResources),
            "Bank does not have resources for trade"
        );

        batchTransfers(toPlayer, bank, tradeResources);
    }

    function batchTransfers(address from, address to, bytes5 resources) public {
        uint256[] memory tradesSplit = splitTradeResources(resources);

        for (uint256 i = 0; i < tradesSplit.length; i++) {
            if (i == 0 || tradesSplit[i] == 0) {
                continue;
            }
            safeTransferFrom(from, to, i, tradesSplit[i], "");
        }
    }

    function splitTradeResources(
        bytes5 tradeResources
    ) public pure returns (uint256[] memory) {
        uint256[] memory resources = new uint256[](6);
        resources[0] = 0;
        resources[SHEEP] = byteToUint(tradeResources[0]);
        resources[BRICK] = byteToUint(tradeResources[1]);
        resources[WOOD] = byteToUint(tradeResources[2]);
        resources[STONE] = byteToUint(tradeResources[3]);
        resources[WHEAT] = byteToUint(tradeResources[4]);
        return resources;
    }

    function checkPlayerHasResourcesForTrade(
        address player,
        bytes5 tradeResources
    ) public view returns (bool) {
        uint256 sheepBalance = balanceOf(player, SHEEP);
        uint256 brickBalance = balanceOf(player, BRICK);
        uint256 woodBalance = balanceOf(player, WOOD);
        uint256 stoneBalance = balanceOf(player, STONE);
        uint256 wheatBalance = balanceOf(player, WHEAT);

        uint256 sheepAmount = byteToUint(tradeResources[0]);
        uint256 brickAmount = byteToUint(tradeResources[1]);
        uint256 woodAmount = byteToUint(tradeResources[2]);
        uint256 stoneAmount = byteToUint(tradeResources[3]);
        uint256 wheatAmount = byteToUint(tradeResources[4]);
        return
            sheepBalance >= sheepAmount &&
            brickBalance >= brickAmount &&
            woodBalance >= woodAmount &&
            stoneBalance >= stoneAmount &&
            wheatBalance >= wheatAmount;
    }

    function byteToUint(bytes1 b) internal pure returns (uint8) {
        return uint8(bytes1(b));
    }

    function getPlayerResources() public view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](5);
        balances[0] = balanceOf(msg.sender, uint256(ResourceTypes.Sheep));
        balances[1] = balanceOf(msg.sender, uint256(ResourceTypes.Brick));
        balances[2] = balanceOf(msg.sender, uint256(ResourceTypes.Wood));
        balances[3] = balanceOf(msg.sender, uint256(ResourceTypes.Stone));
        balances[4] = balanceOf(msg.sender, uint256(ResourceTypes.Wheat));

        return balances;
    }

    function getPlayerResourcesAsBytes5(
        address player
    ) public view returns (bytes5) {
        bytes5 resources;
        uint8 amount;

        amount = uint8(balanceOf(player, uint256(ResourceTypes.Sheep)));
        resources |= createResourceBytes5(ResourceTypes.Sheep, amount);

        amount = uint8(balanceOf(player, uint256(ResourceTypes.Brick)));
        resources |= createResourceBytes5(ResourceTypes.Brick, amount);

        amount = uint8(balanceOf(player, uint256(ResourceTypes.Wood)));
        resources |= createResourceBytes5(ResourceTypes.Wood, amount);

        amount = uint8(balanceOf(player, uint256(ResourceTypes.Stone)));
        resources |= createResourceBytes5(ResourceTypes.Stone, amount);

        amount = uint8(balanceOf(player, uint256(ResourceTypes.Wheat)));
        resources |= createResourceBytes5(ResourceTypes.Wheat, amount);

        return resources;
    }

    function createResourceBytes5(
        ResourceTypes resourceType,
        uint8 amount
    ) public pure returns (bytes5) {
        if (resourceType == ResourceTypes.Sheep)
            return bytes5(bytes5(uint40(amount)) << 32);
        if (resourceType == ResourceTypes.Brick)
            return bytes5(bytes5(uint40(amount)) << 24);
        if (resourceType == ResourceTypes.Wood)
            return bytes5(bytes5(uint40(amount)) << 16);
        if (resourceType == ResourceTypes.Stone)
            return bytes5(bytes5(uint40(amount)) << 8);
        if (resourceType == ResourceTypes.Wheat)
            return bytes5(bytes5(uint40(amount)));
        return bytes5(0); // Unknown or error case
    }

    function bankAddress() public view returns (address) {
        return bank;
    }
}
