// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Resources} from "../src/Resources.sol";

contract ResourcesTest is Test {
    Resources resources;
    address bank;
    address player;

    uint256 constant SHEEP = uint256(Resources.ResourceTypes.Sheep);
    uint256 constant BRICK = uint256(Resources.ResourceTypes.Brick);
    uint256 constant WOOD = uint256(Resources.ResourceTypes.Wood);
    uint256 constant STONE = uint256(Resources.ResourceTypes.Stone);
    uint256 constant WHEAT = uint256(Resources.ResourceTypes.Wheat);

    function setUp() public {
        bank = makeAddr("bank");
        player = makeAddr("player");
        resources = new Resources(bank);

        vm.prank(bank);
        resources.setApprovalForPlayer(address(this));

        resources.safeTransferFrom(bank, player, SHEEP, 5, "");
        resources.safeTransferFrom(bank, player, BRICK, 5, "");
        resources.safeTransferFrom(bank, player, WOOD, 5, "");
        resources.safeTransferFrom(bank, player, STONE, 5, "");
        resources.safeTransferFrom(bank, player, WHEAT, 5, "");
    }

    function testResourceBalance() public view {
        assertEq(
            resources.balanceOf(bank, uint256(Resources.ResourceTypes.Wood)),
            14,
            "Bank should have 14 wood"
        );
    }

    function testBuyRoad() public {
        vm.prank(player);
        resources.buyRoad();
        assertEq(
            resources.balanceOf(player, uint256(Resources.ResourceTypes.Wood)),
            4,
            "Player should have 4 wood"
        );
        assertEq(
            resources.balanceOf(player, uint256(Resources.ResourceTypes.Brick)),
            4,
            "Player should have 4 brick"
        );
        assertEq(
            resources.balanceOf(bank, uint256(Resources.ResourceTypes.Wood)),
            15,
            "Bank should have 1 wood"
        );
        assertEq(
            resources.balanceOf(bank, uint256(Resources.ResourceTypes.Brick)),
            15,
            "Bank should have 1 brick"
        );
    }
}
