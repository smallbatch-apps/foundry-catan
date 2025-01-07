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

    function testCreateResourceBytes5() public view {
        // Test each resource type with different amounts

        // Sheep (first position)
        bytes5 sevenSheep = resources.createResourceBytes5(
            Resources.ResourceTypes.Sheep,
            7
        );
        assertEq(uint8(bytes1(sevenSheep[0])), 7); // First byte should be 7
        assertEq(uint8(bytes1(sevenSheep[1])), 0); // Rest should be 0
        assertEq(uint8(bytes1(sevenSheep[2])), 0);
        assertEq(uint8(bytes1(sevenSheep[3])), 0);
        assertEq(uint8(bytes1(sevenSheep[4])), 0);

        // Brick (second position)
        bytes5 tenBrick = resources.createResourceBytes5(
            Resources.ResourceTypes.Brick,
            10
        );
        assertEq(uint8(bytes1(tenBrick[0])), 0);
        assertEq(uint8(bytes1(tenBrick[1])), 10); // Second byte should be 10
        assertEq(uint8(bytes1(tenBrick[2])), 0);
        assertEq(uint8(bytes1(tenBrick[3])), 0);
        assertEq(uint8(bytes1(tenBrick[4])), 0);

        // Test max value (255)
        bytes5 maxWood = resources.createResourceBytes5(
            Resources.ResourceTypes.Wood,
            255
        );
        assertEq(uint8(bytes1(maxWood[0])), 0);
        assertEq(uint8(bytes1(maxWood[1])), 0);
        assertEq(uint8(bytes1(maxWood[2])), 255); // Third byte should be 255
        assertEq(uint8(bytes1(maxWood[3])), 0);
        assertEq(uint8(bytes1(maxWood[4])), 0);

        // Test zero amount
        bytes5 zeroStone = resources.createResourceBytes5(
            Resources.ResourceTypes.Stone,
            0
        );
        assertEq(uint8(bytes1(zeroStone[0])), 0);
        assertEq(uint8(bytes1(zeroStone[1])), 0);
        assertEq(uint8(bytes1(zeroStone[2])), 0);
        assertEq(uint8(bytes1(zeroStone[3])), 0);
        assertEq(uint8(bytes1(zeroStone[4])), 0);

        // Test Unknown resource type
        bytes5 unknown = resources.createResourceBytes5(
            Resources.ResourceTypes.Unknown,
            5
        );
        assertEq(uint8(bytes1(unknown[0])), 0);
        assertEq(uint8(bytes1(unknown[1])), 0);
        assertEq(uint8(bytes1(unknown[2])), 0);
        assertEq(uint8(bytes1(unknown[3])), 0);
        assertEq(uint8(bytes1(unknown[4])), 0);
    }

    // Test combining multiple resources
    function testCombineResourceBytes5() public view {
        bytes5 twoSheep = resources.createResourceBytes5(
            Resources.ResourceTypes.Sheep,
            2
        );
        bytes5 threeBrick = resources.createResourceBytes5(
            Resources.ResourceTypes.Brick,
            3
        );

        // Combine using OR
        bytes5 combined = twoSheep | threeBrick;

        assertEq(uint8(bytes1(combined[0])), 2); // Sheep
        assertEq(uint8(bytes1(combined[1])), 3); // Brick
        assertEq(uint8(bytes1(combined[2])), 0);
        assertEq(uint8(bytes1(combined[3])), 0);
        assertEq(uint8(bytes1(combined[4])), 0);
    }
}
