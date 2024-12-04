// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Board} from "../src/Board.sol";
import {Resources} from "../src/Resources.sol";

contract BoardTest is Test {
    Board board;
    Resources resources;
    address bank;

    function setUp() public {
        bank = makeAddr("bank");
        resources = new Resources(bank);
        board = new Board(address(resources)); // This deploys a fresh contract for each test

        vm.prank(bank);
        resources.setApprovalForBoard(address(board));
    }

    function testInitialState() public view {
        assertEq(board.MAX_PLAYERS(), 4, "Incorrect max players");
        assertEq(board.currentThrow(), 0, "Current throw is not 0");
        assertEq(board.currentPlayer(), address(0), "Current player is not 0");
        assertEq(board.gameReady(), false, "Game is not ready");
        assertEq(board.gameStarted(), false, "Game is not started");
        assertEq(board.currentPlayerTurn(), 0, "Current player turn is not 0");
        assertEq(
            board.currentSetupPlayer(),
            0,
            "Current setup player is not 0"
        );
        assertEq(board.currentThrow(), 0);
    }

    function testBasicPlayerJoin() public {
        bytes32 name = bytes32("Alice");
        board.joinPlayer(name, Board.Colours.Red);

        Board.Player[] memory players = board.getPlayers();
        assertEq(players.length, 1, "Incorrect number of players");
        assertEq(players[0].name, name, "Incorrect player name");
        assertEq(
            players[0].ethAddress,
            address(this),
            "Incorrect player address"
        );
        assertEq(
            uint(players[0].colour),
            uint(Board.Colours.Red),
            "Incorrect player colour"
        );
        assertEq(
            players[0].victoryPoints,
            0,
            "Incorrect player victory points"
        );
        assertEq(
            players[0].privateVictoryPoints,
            0,
            "Incorrect player private victory points"
        );
    }

    function testBankCannotJoin() public {
        vm.prank(bank);
        vm.expectRevert("Bank may not be a player");
        board.joinPlayer("Bank", Board.Colours.Red);
    }

    function testCannotReuseSameColor() public {
        board.joinPlayer("Alice", Board.Colours.Red);
        vm.startPrank(makeAddr("bob"));
        vm.expectRevert("Colour already chosen");
        board.joinPlayer("Bob", Board.Colours.Red);
        vm.stopPrank();
    }

    function testMaxPlayers() public {
        board.joinPlayer("Alice", Board.Colours.Red);

        vm.prank(makeAddr("bob"));
        board.joinPlayer("Bob", Board.Colours.Blue);

        vm.prank(makeAddr("charlie"));
        board.joinPlayer("Charlie", Board.Colours.Green);

        vm.prank(makeAddr("dave"));
        board.joinPlayer("Dave", Board.Colours.Yellow);

        vm.prank(makeAddr("eve"));
        vm.expectRevert("Maximum players already");
        board.joinPlayer("Eve", Board.Colours.Orange);
    }

    function testCannotJoinTwice() public {
        board.joinPlayer("Alice", Board.Colours.Red);
        vm.expectRevert("Matching player already exists");
        board.joinPlayer("Alice", Board.Colours.Red);
    }

    function testRollSingleDice() public view {
        uint256 roll = board.rollSingleDice();
        assertGt(roll, 0, "Invalid dice roll - 0 or lower");
        assertLt(roll, 7, "Invalid dice roll - 7 or higher");
    }

    /*
     * This test has a known false failure rate of 1/7776
     * It is theoretically possible to roll the same dice 6 times in a row.
     */
    function testSingleDiceRandomness() public {
        uint256 firstRoll = board.rollSingleDice();
        uint256 sum = firstRoll;

        for (uint i = 0; i < 5; i++) {
            vm.roll(block.number + i + 1);
            vm.prevrandao(bytes32(uint256(i + 100)));
            sum += board.rollSingleDice();
        }

        assertNotEq(sum, firstRoll * 6, "Duplicate dice");
    }

    function testRollingTwoDice() public view {
        (uint256 total, uint256 die1, uint256 die2) = board.rollTwoDice();
        assertGt(total, 1, "Invalid roll for two dice");
        assertLt(total, 13, "Invalid roll for two dice");
        assertGt(die1, 0, "Invalid dice roll");
        assertLt(die1, 7, "Invalid dice roll");
        assertGt(die2, 0, "Invalid dice roll");
        assertLt(die2, 7, "Invalid dice roll");
    }

    function testTwoDiceRandomness() public {
        (uint256 total, uint256 die1, uint256 die2) = board.rollTwoDice();
        uint256 sumTotal = total;
        uint256 sumDie1 = die1;
        uint256 sumDie2 = die2;

        for (uint i = 0; i < 5; i++) {
            vm.roll(block.number + i + 1);
            vm.prevrandao(bytes32(uint256(i + 100)));
            (
                uint256 totalReroll,
                uint256 die1Reroll,
                uint256 die2Reroll
            ) = board.rollTwoDice();
            sumTotal += totalReroll;
            sumDie1 += die1Reroll;
            sumDie2 += die2Reroll;
        }

        assertNotEq(
            sumTotal,
            total * 6,
            "Total appears to be caused by duplicate dice"
        );
        assertNotEq(
            sumDie1,
            die1 * 6,
            "Die 1 appears to be caused by duplicate dice"
        );
        assertNotEq(
            sumDie2,
            die2 * 6,
            "Die 2 appears to be caused by duplicate dice"
        );
    }

    function testChooseStartingPlayer() public {
        board.joinPlayer("Alice", Board.Colours.Red);

        vm.prank(makeAddr("bob"));
        board.joinPlayer("Bob", Board.Colours.Blue);
        uint256 startingPlayer = board.chooseStartingPlayer();
        assertGt(startingPlayer, 0, "Starting player is not greater than 0");
        assertLt(startingPlayer, 2, "Starting player is not less than 2");
    }

    function testGenerateTerrainDistribution() public view {
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

    function testCriticalNumberPlacement() public view {
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

    function testCompleteRollAssignment() public view {
        // Count all numbers
        uint[] memory counts = new uint[](13);

        Board.Hex[] memory allHexes = board.getAllHexes();

        for (uint i = 0; i < allHexes.length; i++) {
            console.log("Hex", i);
            console.log("Resource Type", uint(allHexes[i].resourceType));
            console.log("Has Robber", allHexes[i].hasRobber);
            console.log("Roll", allHexes[i].roll);
            console.log("");
        }

        for (uint i = 0; i < allHexes.length; i++) {
            counts[allHexes[i].roll]++;
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
        bool allowed = board.checkRoadOriginIsPlayerOwned(0x1e24);
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
        bool allowed = board.checkRoadOriginIsPlayerOwned(0x1e24);
        assertFalse(allowed, "Road should not be allowed");
    }

    // this test is not meaningful until the players have roads created
    function testPlayerHasRoadsAvailable() public view {
        assertTrue(
            board.checkPlayerHasRoadsAvailable(address(this)),
            "Player should have roads available"
        );
    }

    function testPlayerHasSettlementsAvailable() public view {
        assertTrue(
            board.checkPlayerHasSettlementsAvailable(address(this)),
            "Player should have settlements available"
        );
    }

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
            board.checkSettlementOnRoad(0x1e),
            "Settlement should be on road"
        );
        assertFalse(
            board.checkSettlementOnRoad(0x29),
            "Settlement should not be on road"
        );

        vm.prank(player2);
        assertFalse(
            board.checkSettlementOnRoad(0x1e),
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
            board.checkCityIsSettlement(0x1a),
            "Node should be a settlement"
        );
        assertFalse(
            board.checkCityIsSettlement(0x1b),
            "Node is not a settlement"
        );
    }
}
