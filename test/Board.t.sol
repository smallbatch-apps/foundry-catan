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
    }

    function testInitialState() public view {
        assertEq(board.MAX_PLAYERS(), 4, "Incorrect max players");
        assertEq(board.currentThrow(), 0, "Current throw is not 0");
        assertEq(board.currentPlayer(), 0, "Current player is not 0");
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
}
