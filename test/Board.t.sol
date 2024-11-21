// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
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
        assertEq(board.MAX_PLAYERS(), 4);
        assertEq(board.currentThrow(), 0);
        assertEq(board.currentPlayer(), 0);
        assertEq(board.gameReady(), false);
        assertEq(board.gameStarted(), false);
        assertEq(board.currentPlayerTurn(), 0);
        assertEq(board.currentSetupPlayer(), 0);
        assertEq(board.currentThrow(), 0);
    }

    function testBasicPlayerJoin() public {
        bytes32 name = bytes32("Alice");
        board.joinPlayer(name, Board.Colours.Red);

        Board.Player[] memory players = board.getPlayers();
        assertEq(players.length, 1);
        assertEq(players[0].name, name);
        assertEq(players[0].ethAddress, address(this));
        assertEq(uint(players[0].colour), uint(Board.Colours.Red));
        assertEq(players[0].victoryPoints, 0);
        assertEq(players[0].privateVictoryPoints, 0);
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
        assertGt(roll, 0);
        assertLt(roll, 7);
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

        assertNotEq(sum, firstRoll * 6);
    }

    function testRollingTwoDice() public view {
        (uint256 total, uint256 die1, uint256 die2) = board.rollTwoDice();
        assertGt(total, 0);
        assertLt(total, 13);
        assertGt(die1, 0);
        assertLt(die1, 7);
        assertGt(die2, 0);
        assertLt(die2, 7);
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

        assertNotEq(sumTotal, total * 6);
        assertNotEq(sumDie1, die1 * 6);
        assertNotEq(sumDie2, die2 * 6);
    }

    function testChooseStartingPlayer() public {
        board.joinPlayer("Alice", Board.Colours.Red);

        vm.prank(makeAddr("bob"));
        board.joinPlayer("Bob", Board.Colours.Blue);
        uint256 startingPlayer = board.chooseStartingPlayer();
        assertGt(startingPlayer, 0);
        assertLt(startingPlayer, 2);
    }
}
