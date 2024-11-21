// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./Resources.sol";

// import "hardhat/console.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

contract Board {
    Resources private _resources;
    bytes1 private constant MAX_NODE = 0xab;
    uint8 public constant MAX_PLAYERS = 4;
    uint8 private constant VICTORY_POINTS = 10;
    uint8 public currentThrow = 0;
    uint8 public currentPlayer = 0;
    bool public gameReady = false;
    bool public gameStarted = false;

    uint8 public currentPlayerTurn;
    uint8 public currentSetupPlayer;

    enum Colours {
        Red,
        Yellow,
        Blue,
        Green,
        Purple,
        Orange,
        Brown
    }

    enum NodeStatus {
        Empty,
        HasSettlement,
        HasCity
    }

    struct Player {
        bytes32 name;
        address ethAddress;
        Colours colour;
        uint8 victoryPoints;
        uint8 privateVictoryPoints;
    }

    struct Hex {
        Resources.ResourceTypes resourceType;
        bool hasRobber;
        uint8 roll;
    }

    struct Node {
        bytes1 playerId;
        NodeStatus status;
        bytes3 connections;
    }

    Player[] public players;

    mapping(bytes6 => Hex) public hexes;
    mapping(bytes1 => Node) public nodes;
    mapping(bytes2 => bytes1) public roads;

    constructor(address resources) {
        _resources = Resources(resources);
    }

    function joinPlayer(bytes32 name, Colours colour) public {
        require(players.length < MAX_PLAYERS, "Maximum players already");
        require(
            msg.sender != address(_resources._bank()),
            "Bank may not be a player"
        );
        bool colourAvailable = true;
        bool isAvailable = true;
        for (uint256 i = 0; i < players.length; i++) {
            Player memory player = players[i];
            if (player.name == name || player.ethAddress == msg.sender) {
                isAvailable = false;
            }
            if (player.colour == colour) {
                colourAvailable = false;
            }
        }
        require(isAvailable, "Matching player already exists");
        require(colourAvailable, "Colour already chosen");

        players.push(Player(name, msg.sender, colour, 0, 0));
    }

    function getPlayers() public view returns (Player[] memory) {
        return players;
    }

    /*
     * The below code is known to be insecure as prevrandao can be known by miners.
     * The correct code would instead implement randomness from an external VFR
     */
    function rollSingleDice() public view returns (uint256) {
        return (block.prevrandao % 6) + 1;
    }

    function rollTwoDice()
        public
        view
        returns (uint256 total, uint256 die1, uint256 die2)
    {
        die1 =
            (uint256(keccak256(abi.encodePacked(block.prevrandao, "die1"))) %
                6) +
            1;
        die2 =
            (uint256(keccak256(abi.encodePacked(block.prevrandao, "die2"))) %
                6) +
            1;
        total = die1 + die2;
    }

    function chooseStartingPlayer() public view returns (uint256) {
        require(players.length > 0, "Must have players");
        return
            uint256(
                keccak256(abi.encodePacked(block.prevrandao, "startingPlayer"))
            ) % players.length;
    }

    function nonRandomSetup() internal {
        nodes[0x00].connections = 0x0304ff;
        nodes[0x01].connections = 0x0405ff;
        nodes[0x02].connections = 0x0506ff;

        nodes[0x03].connections = 0x0007ff;
        nodes[0x04].connections = 0x000108;
        nodes[0x05].connections = 0x010209;
        nodes[0x06].connections = 0x020aff;

        nodes[0x07].connections = 0x030b0c;
        nodes[0x08].connections = 0x040c0d;
        nodes[0x09].connections = 0x050d0e;
        nodes[0x0a].connections = 0x060e0f;

        nodes[0x0b].connections = 0x0710ff;
        nodes[0x0c].connections = 0x070811;
        nodes[0x0d].connections = 0x080912;
        nodes[0x0e].connections = 0x090a13;
        nodes[0x0f].connections = 0x0a14ff;

        nodes[0x10].connections = 0x0b1516;
        nodes[0x11].connections = 0x0c1617;
        nodes[0x12].connections = 0x0d1718;
        nodes[0x13].connections = 0x0e1819;
        nodes[0x14].connections = 0x0f191a;

        nodes[0x15].connections = 0x101bff;
        nodes[0x16].connections = 0x10111c;
        nodes[0x17].connections = 0x11121d;
        nodes[0x18].connections = 0x12131e;
        nodes[0x19].connections = 0x13141f;
        nodes[0x1a].connections = 0x1420ff;

        nodes[0x1b].connections = 0x1521ff;
        nodes[0x1c].connections = 0x162122;
        nodes[0x1d].connections = 0x172223;
        nodes[0x1e].connections = 0x182324;
        nodes[0x1f].connections = 0x192425;
        nodes[0x20].connections = 0x1a25ff;

        nodes[0x21].connections = 0x1c26ff;
        nodes[0x22].connections = 0x1c1d27;
        nodes[0x23].connections = 0x1d1e28;
        nodes[0x24].connections = 0x1e1f29;
        nodes[0x25].connections = 0x202aff;

        nodes[0x26].connections = 0x212bff;
        nodes[0x27].connections = 0x222b2c;
        nodes[0x28].connections = 0x232c2d;
        nodes[0x29].connections = 0x242d2e;
        nodes[0x2a].connections = 0x252eff;

        nodes[0x2b].connections = 0x26272f;
        nodes[0x2c].connections = 0x272830;
        nodes[0x2d].connections = 0x282931;
        nodes[0x2e].connections = 0x292a32;

        nodes[0x2f].connections = 0x2b33ff;
        nodes[0x30].connections = 0x2c3334;
        nodes[0x31].connections = 0x2d3435;
        nodes[0x32].connections = 0x2e35ff;

        nodes[0x33].connections = 0x2f30ff;
        nodes[0x34].connections = 0x3031ff;
        nodes[0x35].connections = 0x3132ff;
    }
}
