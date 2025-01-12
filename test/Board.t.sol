// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Roads} from "../src/Roads.sol";
import {Board} from "../src/Board.sol";
import {Resources} from "../src/Resources.sol";

contract BoardTest is Test {
    Board board;
    Roads roads;
    address bank;
    uint256 public seed;

    function setUp() public {
        string[] memory cmds = new string[](1);
        cmds[0] = "./generate_seed.sh";
        bytes memory result = vm.ffi(cmds);

        vm.prevrandao(bytes32(result));

        bank = makeAddr("bank");
        board = new Board(true);
        roads = new Roads();
        board.setDependencies(address(roads), address(0));
        vm.prank(bank);
    }

    function testInitialState() public view {}

    function testGenerateTerrainDistribution() public view {
        // First distribution

        Resources.ResourceTypes[] memory terrains = board
            .generateTerrainDistribution();

        assertEq(terrains.length, 19);

        uint256[7] memory counts = countTerrainTypes(terrains);

        assertEq(counts[0], 0, "Incorrect number of desert hexes");
        assertEq(counts[1], 4, "Incorrect number of wood hexes");
        assertEq(counts[2], 3, "Incorrect number of sheep hexes");
        assertEq(counts[3], 4, "Incorrect number of wheat hexes");
        assertEq(counts[4], 3, "Incorrect number of brick hexes");
        assertEq(counts[5], 4, "Incorrect number of stone hexes");
        assertEq(counts[6], 1, "Incorrect number of desert hexes");
    }

    function countTerrainTypes(
        Resources.ResourceTypes[] memory terrains
    ) internal pure returns (uint256[7] memory counts) {
        for (uint i = 0; i < terrains.length; i++) {
            counts[uint(terrains[i])]++;
        }
        return counts;
    }

    function testAssignedResources() public view {
        Board.Hex memory hex1 = board.getHex(bytes6(0x1d222327282c));

        assertFalse(
            hex1.resourceType == Resources.ResourceTypes.Unknown,
            "Hex 1 is unknown"
        );
        Board.Hex memory hex2 = board.getHex(bytes6(0x01040508090d));
        assertFalse(
            hex2.resourceType == Resources.ResourceTypes.Unknown,
            "Hex 2 is unknown"
        );
        Board.Hex memory hex3 = board.getHex(bytes6(0x292d2e313235));
        assertFalse(
            hex3.resourceType == Resources.ResourceTypes.Unknown,
            "Hex 3 is unknown"
        );
    }

    function testHexAdjacency() public view {
        // Test adjacent hexes (e.g., center hex and one next to it)
        assertTrue(
            board.checkAdjacency(
                0x1217181d1e23, // (0,0,0)
                0x1318191e1f24 // (1,0,-1)
            ),
            "Hexes should be adjacent"
        );

        // Test non-adjacent hexes (e.g., opposite corners)
        assertFalse(
            board.checkAdjacency(
                0x00030407080c, // (0,-2,2)
                0x292d2e313235 // (0,2,-2)
            ),
            "Hexes should not be adjacent"
        );
    }

    function testCriticalNumberPlacement() public {
        board.generateRolls();

        uint count6 = 0;
        uint count8 = 0;

        Board.Hex[] memory hexes = board.getAllHexes();

        for (uint i = 0; i < 19; i++) {
            if (hexes[i].resourceType == Resources.ResourceTypes.Desert)
                continue;
            if (hexes[i].roll == 6) count6++;
            if (hexes[i].roll == 8) count8++;
        }

        assertEq(count6, 2, "Should have exactly two 6s");
        assertEq(count8, 2, "Should have exactly two 8s");
    }

    function testCompleteRollAssignment() public {
        board.generateRolls();

        // Count all numbers
        uint[] memory counts = new uint[](13);
        Board.Hex[] memory allHexes = board.getAllHexes();

        for (uint i = 0; i < allHexes.length; i++) {
            counts[allHexes[i].roll]++;
        }

        // hacked this into place to generate some output to paste into ui to check representation of board
        bool logBoardState = true;
        if (logBoardState) {
            console2.log("=== BOARD STATE ===");
            for (uint i = 0; i < allHexes.length; i++) {
                console2.log("{");
                console2.log(
                    "  resourceType:",
                    uint(allHexes[i].resourceType),
                    ","
                );

                console2.log("  roll:", allHexes[i].roll, ",");
                console2.log("  hasRobber:", allHexes[i].hasRobber);
                console2.log("},");
            }
        }
        // Verify counts
        assertEq(counts[0], 1, "Should have one 0");
        assertEq(counts[1], 0, "Should have no 1s");
        assertEq(counts[2], 1, "Should have one 2");
        assertEq(counts[3], 2, "Should have two 3s");
        assertEq(counts[4], 2, "Should have two 4s");
        assertEq(counts[5], 2, "Should have two 5s");
        assertEq(counts[6], 2, "Should have two 6s");
        assertEq(counts[8], 2, "Should have two 8s");
        assertEq(counts[9], 2, "Should have two 9s");
        assertEq(counts[10], 2, "Should have two 10s");
        assertEq(counts[11], 2, "Should have two 11s");
        assertEq(counts[12], 1, "Should have one 12");
    }

    function testDesertShouldNotHaveNumbers() public view {
        Board.Hex memory desertHex = board.getHex(board.desertHexId());
        assertEq(desertHex.roll, 0, "Desert hex should not have a roll");
    }

    function testUnpackConnections() public view {
        bytes1[] memory connections = board.unpackConnections(0x121314);
        assertEq(connections.length, 3, "Should have three connections");
        assertEq(connections[0], bytes1(0x12), "First byte is incorrect");
        assertEq(connections[1], bytes1(0x13), "Second byte is incorrect");
        assertEq(connections[2], bytes1(0x14), "Third byte is incorrect");
    }

    function testUnpackIncompleteConnections() public view {
        bytes1[] memory connections = board.unpackConnections(0x252eff);
        assertEq(connections.length, 2, "Should have two connections");
        assertEq(connections[0], bytes1(0x25), "First byte is incorrect");
        assertEq(connections[1], bytes1(0x2e), "Second byte is incorrect");
    }

    function testRoadIsValid() public view {
        assertTrue(board.checkRoadIsValid(0x2d29), "Road should be valid");
        assertFalse(board.checkRoadIsValid(0x1830), "Road should not be valid");
    }

    function testRoadUpToSettlement() public {
        address player1 = address(0x1);
        address player2 = address(0x2);

        // Set up a scenario where player1 has a road
        // and player2 has a settlement at the end
        board._testPlaceRoad(0x1218, player1);
        board._testPlaceRoad(0x181e, player1);
        board._testPlaceSettlement(0x24, player2);

        // Try to build up to the settlement
        vm.prank(player1);
        bool allowed = board.checkRoadOriginIsPlayerOwned(0x1e24, player1);
        assertTrue(allowed, "Road should be allowed");
    }

    function testRoadThroughSettlement() public {
        address player1 = address(0x1);
        address player2 = address(0x2);

        // Set up a scenario where player1 has a road
        // and player2 has a settlement at the end
        board._testPlaceRoad(0x1218, player1);
        board._testPlaceRoad(0x181e, player1);
        board._testPlaceSettlement(0x1e, player2);

        // Try to build up to the settlement
        vm.prank(player1);
        bool allowed = board.checkRoadOriginIsPlayerOwned(0x1e24, player1);
        assertFalse(allowed, "Road should not be allowed");
    }

    // this test is not meaningful until the players have roads created
    // function testPlayerHasRoadsAvailable() public view {
    //     assertTrue(
    //         board.checkPlayerHasRoadsAvailable(address(this), player1),
    //         "Player should have roads available"
    //     );
    // }

    // function testPlayerHasSettlementsAvailable() public view {
    //     assertTrue(
    //         board.checkPlayerHasSettlementsAvailable(address(this)),
    //         "Player should have settlements available"
    //     );
    // }

    function testCheckSettlementIsValid() public view {
        assertTrue(
            board.checkSettlementIsValid(0x12),
            "Settlement should be valid"
        );
        assertFalse(
            board.checkSettlementIsValid(0xec),
            "Settlement should not be valid"
        );
    }

    function testCheckSettlementIsAvailable() public {
        address player2 = address(0x2);
        assertTrue(
            board.checkSettlementIsAvailable(0x12),
            "Settlement should be available"
        );
        board._testPlaceSettlement(0x24, player2);

        assertFalse(
            board.checkSettlementIsAvailable(0x24),
            "Settlement should not be available"
        );
    }

    function testCheckSettlementOnRoad() public {
        address player1 = makeAddr("alice");
        address player2 = makeAddr("bob");

        board._testPlaceRoad(0x1218, player1);
        board._testPlaceRoad(0x181e, player1);

        vm.prank(player1);
        assertTrue(
            board.checkSettlementOnRoad(0x1e, player1),
            "Settlement should be on road"
        );
        assertFalse(
            board.checkSettlementOnRoad(0x29, player1),
            "Settlement should not be on road"
        );

        vm.prank(player2);
        assertFalse(
            board.checkSettlementOnRoad(0x1e, player2),
            "Has road, but not correct owner"
        );
    }

    function testCheckSettlementIsNotTooClose() public {
        address player1 = makeAddr("alice");
        board._testPlaceSettlement(0x1a, player1);

        assertTrue(
            board.checkSettlementIsNotTooClose(0x1b),
            "Settlement is not too close"
        );
        assertFalse(
            board.checkSettlementIsNotTooClose(0x14),
            "Settlement should not be too close"
        );
    }

    function testCheckCityIsSettlement() public {
        address player1 = makeAddr("alice");
        board._testPlaceSettlement(0x1a, player1);

        vm.prank(player1);
        assertTrue(
            board.checkCityIsSettlement(0x1a, player1),
            "Node should be a settlement"
        );
        assertFalse(
            board.checkCityIsSettlement(0x1b, player1),
            "Node is not a settlement"
        );
    }

    function testUnpackNodes() public view {
        bytes1[6] memory unpackedNodes = board.unpackHexNodes(0x1217181d1e23);
        assertEq(unpackedNodes.length, 6, "Should have six nodes");
        assertEq(unpackedNodes[0], bytes1(0x12), "First byte is incorrect");
        assertEq(unpackedNodes[1], bytes1(0x17), "Second byte is incorrect");
        assertEq(unpackedNodes[2], bytes1(0x18), "Third byte is incorrect");
        assertEq(unpackedNodes[3], bytes1(0x1d), "Fourth byte is incorrect");
        assertEq(unpackedNodes[4], bytes1(0x1e), "Fifth byte is incorrect");
        assertEq(unpackedNodes[5], bytes1(0x23), "Sixth byte is incorrect");
    }

    function testGetResourcesForEmptyHex() public view {
        (address[] memory playerFound, bytes5[] memory resources) = board
            .getResourcesForHex(0x1217181d1e23);

        assertEq(playerFound.length, 0, "There are no cities or settlements");
        assertEq(resources.length, 0, "There are no cities or settlements");
    }

    function testGetResourcesForHex() public {
        address player1 = makeAddr("alice");
        address player2 = makeAddr("bob");

        board._testPlaceSettlement(0x12, player1);
        board._testPlaceSettlement(0x1e, player2);

        board._testSetHexResource(
            0x1217181d1e23,
            Resources.ResourceTypes.Sheep
        );

        (address[] memory playerFound, bytes5[] memory resources) = board
            .getResourcesForHex(0x1217181d1e23);

        assertEq(
            playerFound.length,
            2,
            "There should be two cities or settlements"
        );
        assertEq(
            resources.length,
            2,
            "There should be two cities or settlements"
        );

        assertEq(playerFound[0], player1, "First player should be player1");
        assertEq(playerFound[1], player2, "Second player should be player2");
        assertEq(resources[0], bytes5(0x0100000000), "First count should be 1");
        assertEq(
            resources[1],
            bytes5(0x0100000000),
            "Second count should be 1"
        );
    }

    function testGetResourcesForHexMultipleSettlementsSamePlayer() public {
        address player1 = makeAddr("alice");

        // Place two settlements for the same player
        board._testPlaceSettlement(0x12, player1);
        board._testPlaceSettlement(0x1e, player1);

        (address[] memory playerFound, bytes5[] memory resources) = board
            .getResourcesForHex(0x1217181d1e23);

        assertEq(playerFound.length, 1, "Should only find one player");
        assertEq(playerFound[0], player1, "Should be player1");

        Resources.ResourceTypes resourceType = board
            .getHex(0x1217181d1e23)
            .resourceType;
        bytes5 expectedResource = board.createResourceBytes5(resourceType, 2); // Should get 2 resources
        assertEq(resources[0], expectedResource, "Should get 2 resources");
    }

    function testGetResourcesForHexWithCity() public {
        address player1 = makeAddr("alice");

        board._testPlaceSettlement(0x12, player1);
        board._testPlaceCity(0x1d, player1);

        board._testSetHexResource(
            0x1217181d1e23,
            Resources.ResourceTypes.Sheep
        );

        (address[] memory playerFound, bytes5[] memory resources) = board
            .getResourcesForHex(0x1217181d1e23);

        // for (uint i = 0; i < playerFound.length; i++) {
        //     console2.log(playerFound[i]);
        //     console2.log("Sheep:", uint8(resources[i][0]));
        //     console2.log("Brick:", uint8(resources[i][1]));
        //     console2.log("Wood:", uint8(resources[i][2]));
        //     console2.log("Wheat:", uint8(resources[i][3]));
        //     console2.log("Stone:", uint8(resources[i][4]));
        // }

        assertEq(
            playerFound.length,
            1,
            "There should be one players - duplicates are not expected"
        );
        assertEq(resources.length, 1, "There should be one entries");
        assertEq(playerFound[0], player1, "Player should be player1");

        assertEq(
            resources[0],
            bytes5(0x0300000000),
            "Count should be 3 - 1 city, 1 settlement"
        );
    }
}
