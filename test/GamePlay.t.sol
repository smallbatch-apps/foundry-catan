// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Board} from "../src/Board.sol";
import {GamePlay} from "../src/GamePlay.sol";
import {Resources} from "../src/Resources.sol";
import {DevelopmentCards} from "../src/DevelopmentCards.sol";
import {Roads} from "../src/Roads.sol";

contract GamePlayTest is Test {
    Board board;
    GamePlay gameplay;
    Resources resources;
    DevelopmentCards developmentCards;
    Roads roads;
    address bank;
    uint256 public seed;

    function setUp() public {
        string[] memory cmds = new string[](1);
        cmds[0] = "./generate_seed.sh";
        bytes memory result = vm.ffi(cmds);

        vm.prevrandao(bytes32(result));

        bank = makeAddr("bank");
        resources = new Resources(bank);
        roads = new Roads();
        developmentCards = new DevelopmentCards();
        board = new Board(true);
        gameplay = new GamePlay(
            address(board),
            address(resources),
            address(roads),
            address(developmentCards)
        );
        gameplay.enableTestMode();
        roads.setGamePlay(address(gameplay));
        developmentCards.setGamePlay(address(gameplay));
        vm.prank(bank);
        resources.setApprovalForGamePlay(address(gameplay));
    }

    function testInitialState() public view {
        assertEq(gameplay.MAX_PLAYERS(), 4, "Incorrect max players");
        assertEq(gameplay.lastRoll(), 0, "Current throw is not 0");
        assertEq(
            gameplay.currentPlayer(),
            address(0),
            "Current player is not 0"
        );
        assertEq(gameplay.gameReady(), false, "Game is not ready");

        assertEq(
            gameplay.currentPlayerTurn(),
            0,
            "Current player turn is not 0"
        );
        assertEq(
            gameplay.currentSetupPlayer(),
            0,
            "Current setup player is not 0"
        );
    }

    function testBasicPlayerJoin() public {
        bytes32 name = bytes32("Alice");
        gameplay.joinPlayer(name, GamePlay.Colours.Red);

        GamePlay.Player[] memory players = gameplay.getPlayers();
        assertEq(players.length, 1, "Incorrect number of players");
        assertEq(players[0].name, name, "Incorrect player name");
        assertEq(
            players[0].ethAddress,
            address(this),
            "Incorrect player address"
        );
        assertEq(
            uint(players[0].colour),
            uint(GamePlay.Colours.Red),
            "Incorrect player colour"
        );
        assertEq(
            players[0].victoryPoints,
            0,
            "Incorrect player victory points"
        );
    }

    function testCannotReuseSameColor() public {
        gameplay.joinPlayer("Alice", GamePlay.Colours.Red);
        vm.startPrank(makeAddr("bob"));
        vm.expectRevert(
            abi.encodeWithSelector(
                GamePlay.ColorAlreadyChosen.selector,
                GamePlay.Colours.Red
            )
        );
        gameplay.joinPlayer("Bob", GamePlay.Colours.Red);
        vm.stopPrank();
    }

    function testMaxPlayers() public {
        gameplay.joinPlayer("Alice", GamePlay.Colours.Red);

        vm.prank(makeAddr("bob"));
        gameplay.joinPlayer("Bob", GamePlay.Colours.Blue);

        vm.prank(makeAddr("charlie"));
        gameplay.joinPlayer("Charlie", GamePlay.Colours.White);

        vm.prank(makeAddr("dave"));
        gameplay.joinPlayer("Dave", GamePlay.Colours.Yellow);

        vm.prank(makeAddr("eve"));
        vm.expectRevert(GamePlay.MaxPlayersReached.selector);
        gameplay.joinPlayer("Eve", GamePlay.Colours.Orange);
    }

    function testCannotJoinTwice() public {
        gameplay.joinPlayer("Alice", GamePlay.Colours.Red);

        vm.expectRevert(
            abi.encodeWithSelector(
                GamePlay.PlayerAlreadyExists.selector,
                bytes32("Alice"),
                address(this)
            )
        );
        gameplay.joinPlayer("Alice", GamePlay.Colours.Red);
    }

    function testRequestTrade() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        address charlie = makeAddr("charlie");

        vm.prank(alice);
        gameplay.joinPlayer("Alice", GamePlay.Colours.Red);
        vm.prank(bob);
        gameplay.joinPlayer("Bob", GamePlay.Colours.Blue);
        vm.prank(charlie);
        gameplay.joinPlayer("Charlie", GamePlay.Colours.White);

        // Give Alice her resources (sheep and wheat)
        vm.prank(bank);
        resources.safeTransferFrom(
            bank,
            alice,
            uint256(Resources.ResourceTypes.Sheep),
            1,
            ""
        );
        vm.prank(bank);
        resources.safeTransferFrom(
            bank,
            alice,
            uint256(Resources.ResourceTypes.Wheat),
            1,
            ""
        );

        // Give Bob a brick
        vm.prank(bank);
        resources.safeTransferFrom(
            bank,
            bob,
            uint256(Resources.ResourceTypes.Brick),
            1,
            ""
        );

        // Create array of players to offer trade to
        address[] memory tradePlayers = new address[](2);
        tradePlayers[0] = bob;
        tradePlayers[1] = charlie;

        // Create trade offer: 1 sheep + 1 wheat for 1 brick
        bytes5 offers = bytes5(0x0100000001); // [0,0,1,1,0] - sheep and wheat
        bytes5 requests = bytes5(0x0001000000); // [1,0,0,0,0] - brick
        vm.prank(alice);
        emit GamePlay.TradeRequested(bob, offers, requests);
        bool success = gameplay.requestTrade(tradePlayers, offers, requests);
        assertTrue(success, "Trade request should succeed");
    }
}
