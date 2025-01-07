// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./Resources.sol";

// import "hardhat/console.sol";
import {console2} from "forge-std/console2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Board is Ownable {
    Resources private _resources;

    uint8 public lastRoll = 0;
    address public currentPlayer = address(0);
    bool public gameReady = false;
    BoardStatus public boardStatus = BoardStatus.New;
    bytes6 public desertHexId;
    uint8 public turnCount = 0;

    uint8 public currentPlayerTurn;
    bool public currentPlayerHasRolled = false;
    uint8 public currentSetupPlayer;

    bytes1 private constant MAX_NODE = 0xab;
    uint8 public constant MAX_PLAYERS = 4;
    uint8 private constant VICTORY_POINTS = 10;
    uint8 public constant MAX_SETTLEMENTS_PER_PLAYER = 5;
    uint8 public constant MAX_CITIES_PER_PLAYER = 4;
    uint8 public constant MAX_ROADS_PER_PLAYER = 15;

    address public longestRoadPlayer = address(0);
    uint8 public longestRoadLength = 0;

    mapping(address => uint256) public freeRoads;

    bytes5 SETTLEMENT_RESOURCES = 0x0101010001;
    bytes5 CITY_RESOURCES = 0x0000000302;
    bytes5 ROAD_RESOURCES = 0x0101000000;
    bytes5 CARD_RESOURCES = 0x0100000101;

    enum Colours {
        Red,
        Yellow,
        Blue,
        White,
        Orange // used solely for testing
    }

    enum NodeStatus {
        Empty,
        HasSettlement,
        HasCity
    }

    enum BoardStatus {
        NoBoard,
        New,
        HasResources,
        HasRolls,
        FindingPlayers,
        InitialPlacement,
        Active,
        GameOver
    }

    struct Player {
        bytes32 name;
        address ethAddress;
        Colours colour;
        uint8 victoryPoints;
        uint8 roadCount;
        uint8 settlementCount;
        uint8 cityCount;
    }

    struct Hex {
        Resources.ResourceTypes resourceType;
        bool hasRobber;
        uint8 roll;
    }

    struct Node {
        address playerAddress;
        NodeStatus status;
        bytes3 connections;
    }

    struct Harbor {
        bytes2 roadId;
        HarborType harborType;
    }

    enum TradeStatus {
        Pending,
        Accepted,
        Rejected
    }

    struct Trade {
        address proposer;
        address recipient;
        bytes5 offers;
        bytes5 requests;
        TradeStatus status;
    }
    Trade[] public trades;

    mapping(address => Player) public players;
    address[] public playerAddresses;

    bytes6[19] public hexIds = [
        bytes6(0x00030407080c),
        bytes6(0x01040508090d),
        bytes6(0x020506090a0e),
        bytes6(0x070b0c101116),
        bytes6(0x080c0d111217),
        bytes6(0x090d0e121318),
        bytes6(0x0a0e0f131419),
        bytes6(0x1015161b1c21),
        bytes6(0x1116171c1d22),
        bytes6(0x1217181d1e23),
        bytes6(0x1318191e1f24),
        bytes6(0x14191a1f2025),
        bytes6(0x1c212226272b),
        bytes6(0x1d222327282c),
        bytes6(0x1e232428292d),
        bytes6(0x1f2425292a2e),
        bytes6(0x272b2c2f3033),
        bytes6(0x282c2d303134),
        bytes6(0x292d2e313235)
    ];

    bytes2[] public placedRoads;

    bytes2[] public harborEdges = [
        bytes2(0x0003),
        bytes2(0x0105),
        bytes2(0x0a0f),
        bytes2(0x0b10),
        bytes2(0x1a20),
        bytes2(0x2126),
        bytes2(0x2a2e),
        bytes2(0x2f33),
        bytes2(0x3134)
    ];

    enum HarborType {
        None,
        Sheep,
        Brick,
        Wood,
        Stone,
        Wheat,
        Generic
    }

    enum DevelopmentCardType {
        Knight,
        Monopoly,
        VictoryPoint,
        RoadBuilding,
        YearOfPlenty
    }

    mapping(bytes6 => Hex) public hexes;
    mapping(bytes1 => Node) public nodes;
    mapping(bytes2 => address) public roads;
    mapping(uint8 => bytes6[]) public rollToHexes;

    mapping(bytes1 => HarborType) public nodeHarborType;

    mapping(address => mapping(HarborType => bool)) public hasHarbor;

    mapping(address => DevelopmentCardType[]) public developmentCards;

    constructor(address resources) Ownable(msg.sender) {
        _resources = Resources(resources);
        nonRandomSetup();
        assignResources();
        generateRolls();
        generateHarbors();
    }

    function joinPlayer(bytes32 name, Colours colour) public {
        require(
            playerAddresses.length < MAX_PLAYERS,
            "Maximum players already"
        );
        require(msg.sender != _resources.bank(), "Bank may not be a player");
        bool colourAvailable = true;
        bool isAvailable = true;
        for (uint256 i = 0; i < playerAddresses.length; i++) {
            Player memory player = players[playerAddresses[i]];
            if (player.name == name || player.ethAddress == msg.sender) {
                isAvailable = false;
            }
            if (player.colour == colour) {
                colourAvailable = false;
            }
        }
        require(isAvailable, "Matching player already exists");
        require(colourAvailable, "Colour already chosen");

        // set approval for the board to act as an ERC1155 operator
        _resources.setApprovalForAll(address(this), true);

        players[msg.sender] = Player(name, msg.sender, colour, 0, 0, 0, 0);
        playerAddresses.push(msg.sender);

        emit PlayerJoined();
    }

    function getPlayers() public view returns (Player[] memory) {
        Player[] memory result = new Player[](playerAddresses.length);
        for (uint256 i = 0; i < playerAddresses.length; i++) {
            result[i] = players[playerAddresses[i]];
        }
        return result;
    }

    /*
     * The below code is known to be insecure as prevrandao can be known by miners.
     * The correct code would instead implement randomness from an external VFR
     */
    function rollSingleDice() public view returns (uint8) {
        return uint8(uint256(block.prevrandao) % 6) + 1;
    }

    function rollTwoDice()
        public
        view
        returns (uint8 total, uint8 die1, uint8 die2)
    {
        die1 = uint8(
            (uint256(keccak256(abi.encodePacked(block.prevrandao, "die1"))) %
                6) + 1
        );
        die2 = uint8(
            (uint256(keccak256(abi.encodePacked(block.prevrandao, "die2"))) %
                6) + 1
        );
        total = die1 + die2;
    }

    function playerRollsDice()
        public
        onlyCurrentPlayer
        returns (uint8 total, uint8 die1, uint8 die2)
    {
        require(!currentPlayerHasRolled, "Player has already rolled");
        (total, die1, die2) = rollTwoDice();
        emit DiceRolled(total, die1, die2);
        currentPlayerHasRolled = true;
        setRoll(die1, die2);

        if (total != 7) {
            assignResourcesOnRoll(total);
        } else {
            activateRobber();
        }
    }

    function setRoll(uint8 d1, uint8 d2) internal {
        // Pack into bottom 6 bits (3 bits each)
        lastRoll = ((d1 & 0x07) << 3) | (d2 & 0x07);
    }

    function getRoll()
        public
        view
        returns (uint8 die1, uint8 die2, uint8 total)
    {
        die1 = (lastRoll >> 3) & 0x07; // Extract bits 3-5
        die2 = lastRoll & 0x07; // Extract bits 0-2
        total = die1 + die2;
    }

    function finishInitalPlacement() public {
        require(
            boardStatus == BoardStatus.InitialPlacement,
            "Game not in initial placement"
        );
        boardStatus = BoardStatus.Active;
        emit GameStatusChanged(BoardStatus.Active);
    }

    function endTurn() public onlyCurrentPlayer {
        if (
            turnCount >= playerAddresses.length &&
            boardStatus == BoardStatus.InitialPlacement
        ) {
            currentPlayerTurn = currentPlayerTurn == 0
                ? uint8(playerAddresses.length - 1)
                : uint8(currentPlayerTurn - 1);
        } else {
            currentPlayerTurn = uint8(
                (currentPlayerTurn + 1) % playerAddresses.length
            );
        }
        currentPlayer = playerAddresses[currentPlayerTurn];
        currentPlayerHasRolled = false;

        if (turnCount == (playerAddresses.length - 1) * 2) {
            finishInitalPlacement();
        }

        emit TurnStarted(currentPlayer);
        turnCount++;
    }

    function chooseStartingPlayer() public view returns (uint256) {
        require(playerAddresses.length > 0, "Must have players");
        return
            uint256(
                keccak256(abi.encodePacked(block.prevrandao, "startingPlayer"))
            ) % playerAddresses.length;
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

        for (uint i = 0; i < 14; i++) {
            developmentCards[address(0)].push(DevelopmentCardType.Knight);
        }

        for (uint i = 0; i < 5; i++) {
            developmentCards[address(0)].push(DevelopmentCardType.VictoryPoint);
        }

        for (uint256 i = 0; i < 2; i++) {
            developmentCards[address(0)].push(DevelopmentCardType.RoadBuilding);
            developmentCards[address(0)].push(DevelopmentCardType.Monopoly);
            developmentCards[address(0)].push(DevelopmentCardType.YearOfPlenty);
        }

        // shuffle the development cards
        for (uint256 i = developmentCards[address(0)].length; i > 1; i--) {
            uint256 j = uint256(
                keccak256(
                    abi.encodePacked(block.prevrandao, block.timestamp, i)
                )
            ) % i;
            (
                developmentCards[address(0)][i - 1],
                developmentCards[address(0)][j]
            ) = (
                developmentCards[address(0)][j],
                developmentCards[address(0)][i - 1]
            );
        }
    }

    function getHex(bytes6 hexId) public view returns (Hex memory) {
        return hexes[hexId];
    }

    function getAllHexes() public view returns (Hex[] memory) {
        Hex[] memory result = new Hex[](19);
        for (uint i = 0; i < 19; i++) {
            result[i] = hexes[hexIds[i]];
        }
        return result;
    }

    function getAllNodes() public view returns (Node[] memory) {
        Node[] memory result = new Node[](54);
        for (uint8 i = 0; i <= 0x35; i++) {
            result[i] = nodes[bytes1(i)];
        }
        return result;
    }

    struct Road {
        bytes2 id;
        address owner;
    }

    function getAllRoads() public view returns (Road[] memory) {
        Road[] memory allRoads = new Road[](placedRoads.length);
        for (uint i = 0; i < placedRoads.length; i++) {
            allRoads[i] = Road(placedRoads[i], roads[placedRoads[i]]);
        }
        return allRoads;
    }

    function getAllHarbors() public view returns (Harbor[] memory) {
        Harbor[] memory allHarbors = new Harbor[](harborEdges.length);
        for (uint i = 0; i < harborEdges.length; i++) {
            allHarbors[i] = Harbor(
                harborEdges[i],
                nodeHarborType[harborEdges[i][1]]
            );
        }
        return allHarbors;
    }

    function generateRolls() public {
        // assign random rolls to hexes
        assignCriticalRolls();
        assignNonCriticalRolls();
    }

    function generateTerrainDistribution()
        public
        view
        returns (Resources.ResourceTypes[] memory)
    {
        Resources.ResourceTypes[]
            memory terrains = new Resources.ResourceTypes[](19);

        uint8 index = 0;

        for (uint8 i = 0; i < 4; i++) {
            terrains[index++] = Resources.ResourceTypes.Wood;
            terrains[index++] = Resources.ResourceTypes.Sheep;
            terrains[index++] = Resources.ResourceTypes.Wheat;
        }

        for (uint8 i = 0; i < 3; i++) {
            terrains[index++] = Resources.ResourceTypes.Brick;
            terrains[index++] = Resources.ResourceTypes.Stone;
        }

        terrains[index] = Resources.ResourceTypes.Desert;
        bytes32 seed = bytes32(block.prevrandao);
        for (uint8 i = 0; i < terrains.length; i++) {
            seed = keccak256(abi.encodePacked(seed, i));
            uint256 j = uint256(seed) % terrains.length;
            Resources.ResourceTypes temp = terrains[i];
            terrains[i] = terrains[j];
            terrains[j] = temp;
        }

        return terrains;
    }

    function generateHarbors() public {
        HarborType[9] memory harborTypes = [
            HarborType.Generic,
            HarborType.Generic,
            HarborType.Generic,
            HarborType.Generic,
            HarborType.Wood,
            HarborType.Brick,
            HarborType.Wheat,
            HarborType.Stone,
            HarborType.Sheep
        ];

        for (uint i = 0; i < harborTypes.length; i++) {
            uint j = uint(keccak256(abi.encodePacked(block.prevrandao, i))) %
                harborTypes.length;
            HarborType temp = harborTypes[i];
            harborTypes[i] = harborTypes[j];
            harborTypes[j] = temp;
        }

        for (uint i = 0; i < harborEdges.length; i++) {
            nodeHarborType[harborEdges[i][0]] = harborTypes[i];
            nodeHarborType[harborEdges[i][1]] = harborTypes[i];
        }
    }

    function assignResources() public {
        require(
            boardStatus == BoardStatus.New ||
                boardStatus == BoardStatus.HasResources,
            "Board already has rolls generated"
        );
        Resources.ResourceTypes[]
            memory terrains = generateTerrainDistribution();

        for (uint i = 0; i < hexIds.length; i++) {
            hexes[hexIds[i]].resourceType = terrains[i];
            if (terrains[i] == Resources.ResourceTypes.Desert) {
                desertHexId = hexIds[i];
            }
        }
        boardStatus = BoardStatus.HasResources;
    }

    function startGame() public {
        require(
            msg.sender == players[currentPlayer].ethAddress,
            "Only first player can start the game"
        );
        require(
            boardStatus == BoardStatus.FindingPlayers,
            "Game not ready to start"
        );
        boardStatus = BoardStatus.InitialPlacement;
        emit GameStatusChanged(BoardStatus.InitialPlacement);
    }

    function selectStartingPlayer() public returns (address) {
        require(playerAddresses.length >= 2, "Need at least 2 players");
        require(boardStatus >= BoardStatus.HasRolls, "Game already started");

        // pick one of the players at random
        currentPlayerTurn = uint8(
            uint256(keccak256(abi.encodePacked(block.prevrandao))) %
                playerAddresses.length
        );
        currentPlayer = playerAddresses[currentPlayerTurn];
        boardStatus = BoardStatus.InitialPlacement;

        return currentPlayer;
    }

    function tradeResourcesWithBank(
        address fromPlayer,
        bytes5 resourcesFrom,
        bytes5 resourcesRequired
    ) public {
        // check if player and banker have resources
        // these are checked in the transfer but we want to reject first if EITHER would fail
        require(
            _resources.checkPlayerHasResourcesForTrade(
                fromPlayer,
                resourcesFrom
            ),
            "Player does not have resources for trade"
        );
        require(
            _resources.checkPlayerHasResourcesForTrade(
                _resources.bankAddress(),
                resourcesRequired
            ),
            "Player does not have resources for trade"
        );

        bool amountsValid = true;

        uint256[] memory resourcesFromSplit = _resources.splitTradeResources(
            resourcesFrom
        );
        uint256[] memory resourcesRequiredSplit = _resources
            .splitTradeResources(resourcesRequired);

        bool hasHarborGeneric = hasHarbor[fromPlayer][HarborType.Generic];

        for (uint256 i = 0; i < resourcesFromSplit.length; i++) {
            if (i == 0) {
                continue;
            }
            bool hasHarborForResource = hasHarbor[fromPlayer][HarborType(i)];

            if (hasHarborForResource) {
                if ((resourcesFromSplit[i] * 2) != resourcesRequiredSplit[i]) {
                    amountsValid = false;
                    break;
                }
            }

            if (hasHarborGeneric) {
                if ((resourcesFromSplit[i] * 3) != resourcesRequiredSplit[i]) {
                    amountsValid = false;
                    break;
                }
            }

            if ((resourcesFromSplit[i] * 4) != resourcesRequiredSplit[i]) {
                amountsValid = false;
                break;
            }
        }

        require(amountsValid, "Invalid trade");

        _resources.batchResourcesToBank(fromPlayer, resourcesFrom);
        emit ResourcesToBank(fromPlayer, resourcesFrom);
        _resources.batchResourcesFromBank(fromPlayer, resourcesRequired);
        emit ResourcesFromBank(fromPlayer, resourcesRequired);
    }

    function unpackHexNodes(
        bytes6 hexId
    ) public pure returns (bytes1[6] memory) {
        bytes1[6] memory surroundingNodes;

        surroundingNodes[0] = bytes1(hexId[0]);
        surroundingNodes[1] = bytes1(hexId[1]);
        surroundingNodes[2] = bytes1(hexId[2]);
        surroundingNodes[3] = bytes1(hexId[3]);
        surroundingNodes[4] = bytes1(hexId[4]);
        surroundingNodes[5] = bytes1(hexId[5]);

        return surroundingNodes;
    }

    function assignResourcesOnRoll(uint8 roll) public {
        bytes6[] memory rolledHexes = rollToHexes[roll];

        // uint8
        for (uint i = 0; i < rolledHexes.length; i++) {
            (
                address[] memory playersFound,
                uint8[] memory counts
            ) = getResourcesForHex(rolledHexes[i]);

            for (uint j = 0; j < playersFound.length; j++) {
                _resources.resourceFromBank(
                    playersFound[j],
                    hexes[rolledHexes[i]].resourceType,
                    counts[j]
                );
                emit ResourcesGranted(
                    playersFound[j],
                    hexes[rolledHexes[i]].resourceType,
                    counts[j]
                );
            }
        }
    }

    function getResourcesForHex(
        bytes6 hexId
    )
        public
        view
        returns (address[] memory playerFound, uint8[] memory counts)
    {
        bytes1[6] memory surroundingNodes = unpackHexNodes(hexId);
        uint8 numFound = 0;
        for (uint i = 0; i < surroundingNodes.length; i++) {
            if (nodes[surroundingNodes[i]].playerAddress != address(0)) {
                numFound++;
            }
        }

        // the max number of players that can be around a hex is 3
        playerFound = new address[](numFound);
        counts = new uint8[](numFound);

        uint8 index = 0;

        for (uint i = 0; i < surroundingNodes.length; i++) {
            Node memory node = nodes[surroundingNodes[i]];
            if (node.playerAddress != address(0)) {
                playerFound[index] = node.playerAddress;
                counts[index] = node.status == NodeStatus.HasSettlement ? 1 : 2;
                index++;
            }
        }
    }

    function assignCriticalRolls() public {
        uint8[] memory criticalNumbers = new uint8[](4);
        criticalNumbers[0] = 6;
        criticalNumbers[1] = 6;
        criticalNumbers[2] = 8;
        criticalNumbers[3] = 8;

        bytes6[] memory assignedHexes = new bytes6[](4);

        bool boardComplete = false;
        uint attempts = 0;
        // moderately inefficient, but it will continually try to make a valid board
        // in terms of the critical numbers not being adjacent to each other. It should
        while (!boardComplete && attempts < 10) {
            attempts++;
            for (uint i = 0; i < assignedHexes.length; i++) {}
            delete rollToHexes[6]; // Clear the arrays for 6s
            delete rollToHexes[8]; // Clear the arrays for 8s

            bool[] memory usedHexes = new bool[](19); // All false by default
            // Create shuffled copy of hexIds for this attempt
            bytes6[] memory shuffledHexIds = new bytes6[](hexIds.length);
            for (uint i = 0; i < hexIds.length; i++) {
                shuffledHexIds[i] = hexIds[i];
            }
            for (uint i = 0; i < shuffledHexIds.length; i++) {
                uint j = uint(
                    keccak256(abi.encodePacked(block.prevrandao, i))
                ) % shuffledHexIds.length;
                bytes6 temp = shuffledHexIds[i];
                shuffledHexIds[i] = shuffledHexIds[j];
                shuffledHexIds[j] = temp;
            }
            // Attempt to place all critical numbers
            bool placementValid = true;
            for (uint i = 0; i < criticalNumbers.length; i++) {
                bool numberPlaced = false;
                // console2.log("Trying to place:", criticalNumbers[i]);
                for (uint j = 0; j < shuffledHexIds.length; j++) {
                    if (shuffledHexIds[j] == desertHexId || usedHexes[j]) {
                        continue;
                    }

                    if (!hasAdjacentCriticalNumbers(shuffledHexIds[j])) {
                        hexes[shuffledHexIds[j]].roll = criticalNumbers[i];
                        usedHexes[j] = true;
                        numberPlaced = true;
                        rollToHexes[criticalNumbers[i]].push(shuffledHexIds[j]);
                        assignedHexes[i] = shuffledHexIds[j];
                        break;
                    }
                }

                if (!numberPlaced) {
                    placementValid = false;
                    break;
                }
            }

            boardComplete = placementValid;
        }
    }

    function hasAdjacentCriticalNumbers(
        bytes6 hexId
    ) internal view returns (bool) {
        for (uint i = 0; i < hexIds.length; i++) {
            bytes6 otherHexId = hexIds[i];
            if (otherHexId == hexId) continue;

            // Check if this current hex has a 6 or 8 and is adjacent to the other hex
            if (
                (hexes[otherHexId].roll == 6 || hexes[otherHexId].roll == 8) &&
                checkAdjacency(hexId, otherHexId)
            ) {
                return true;
            }
        }
        return false;
    }

    // Checks if two hexes are adjacent by checking if the sum of the absolute
    // differences in their coordinates is 2 - this is a key feature of cube co-ordinates
    function checkAdjacency(
        bytes6 hexId1,
        bytes6 hexId2
    ) public pure returns (bool) {
        bytes1[6] memory nodes1 = unpackHexNodes(hexId1);
        bytes1[6] memory nodes2 = unpackHexNodes(hexId2);

        uint8 sharedNodes = 0;
        for (uint i = 0; i < 6; i++) {
            for (uint j = 0; j < 6; j++) {
                if (nodes1[i] == nodes2[j]) {
                    sharedNodes++;
                }
            }
        }

        return sharedNodes == 2;
    }

    function abs(int8 x) internal pure returns (int8) {
        return x >= 0 ? x : -int8(x);
    }

    function assignNonCriticalRolls() public {
        uint8[] memory numbers = new uint8[](14);
        numbers[0] = 2;
        numbers[1] = 3;
        numbers[2] = 3;
        numbers[3] = 4;
        numbers[4] = 4;
        numbers[5] = 5;
        numbers[6] = 5;
        numbers[7] = 9;
        numbers[8] = 9;
        numbers[9] = 10;
        numbers[10] = 10;
        numbers[11] = 11;
        numbers[12] = 11;
        numbers[13] = 12;

        // randomise the numbers
        for (uint i = 0; i < numbers.length; i++) {
            uint j = uint(keccak256(abi.encodePacked(block.prevrandao, i))) %
                numbers.length;
            uint8 temp = numbers[i];
            numbers[i] = numbers[j];
            numbers[j] = temp;
        }

        uint8 currentNumberIndex = 0;

        // loop over the hexes and assign the numbers
        for (uint i = 0; i < hexIds.length; i++) {
            if (hexes[hexIds[i]].roll != 0) continue;
            if (hexes[hexIds[i]].resourceType == Resources.ResourceTypes.Desert)
                continue;

            hexes[hexIds[i]].roll = numbers[currentNumberIndex];
            rollToHexes[numbers[currentNumberIndex]].push(hexIds[i]);
            currentNumberIndex++;
        }
    }

    function getHexesForNode(
        bytes1 nodeId
    ) public view returns (bytes6[] memory) {
        // Max 3 hexes can touch a node
        bytes6[] memory foundHexes = new bytes6[](3);
        uint8 count = 0;

        // Check each hex
        for (uint i = 0; i < hexIds.length; i++) {
            bytes6 hexId = hexIds[i];
            bytes1[6] memory nodesForHex = unpackHexNodes(hexId);

            for (uint j = 0; j < nodesForHex.length; j++) {
                if (nodesForHex[j] == nodeId) {
                    foundHexes[count] = hexId;
                    count++;
                    break;
                }
            }
        }

        return foundHexes;
    }

    function unpackConnections(
        bytes3 packed
    ) public pure returns (bytes1[] memory) {
        bool isIncomplete = packed[2] == 0xFF;
        bytes1[] memory result = new bytes1[](isIncomplete ? 2 : 3);
        result[0] = packed[0];
        result[1] = packed[1];
        if (!isIncomplete) {
            result[2] = packed[2];
        }
        return result;
    }

    function placeRoad(bytes2 roadId) public onlyCurrentPlayer {
        require(checkRoadIsValid(roadId), "Invalid road");
        require(checkRoadIsAvailable(roadId), "Road already placed");
        require(
            checkRoadOriginIsPlayerOwned(roadId),
            "Road origin is not player owned"
        );
        require(
            checkPlayerHasRoadsAvailable(msg.sender),
            "Player has run out of roads"
        );

        if (boardStatus == BoardStatus.Active && freeRoads[msg.sender] == 0) {
            require(
                checkPlayerHasResourcesForRoad(msg.sender),
                "Player does not have resources for road"
            );

            _resources.buyRoad();
        }

        roads[roadId] = msg.sender;
        players[msg.sender].roadCount++;
        placedRoads.push(roadId);

        updatePaths(roadId);
        updateLongestRoad();

        testWinConditions();

        emit RoadPlaced(roadId, msg.sender);
    }

    function placeSettlement(bytes1 nodeId) public onlyCurrentPlayer {
        // These rules don't apply on starting turns
        if (boardStatus == BoardStatus.Active) {
            require(checkSettlementOnRoad(nodeId), "Settlement not on road");
            require(
                checkPlayerHasResourcesForSettlement(msg.sender),
                "Player does not have resources for settlement"
            );
        }

        require(checkSettlementIsValid(nodeId), "Invalid settlement");
        require(
            checkSettlementIsAvailable(nodeId),
            "Settlement already placed"
        );
        require(
            checkPlayerHasSettlementsAvailable(msg.sender),
            "Player has run out of settlements"
        );
        require(
            checkSettlementIsNotTooClose(nodeId),
            "Settlement is too close to another settlement"
        );

        if (boardStatus == BoardStatus.Active) {
            _resources.buySettlement();
        }

        nodes[nodeId].playerAddress = msg.sender;
        nodes[nodeId].status = NodeStatus.HasSettlement;

        players[msg.sender].settlementCount++;
        players[msg.sender].victoryPoints++;

        if (players[currentPlayer].settlementCount == 2) {
            // current player gets resources
            bytes6[] memory hexesForNode = getHexesForNode(nodeId);
            for (uint i = 0; i < hexesForNode.length; i++) {
                assignResourcesOnRoll(hexes[hexesForNode[i]].roll);
            }
        }

        HarborType harborType = nodeHarborType[nodeId];
        if (
            harborType != HarborType.None &&
            !hasHarbor[currentPlayer][harborType]
        ) {
            hasHarbor[currentPlayer][harborType] = true;
        }
        bool breaksPath = checkIfSettlementBreaksPath(nodeId);

        if (breaksPath) {
            breakPathAtNode(nodeId); // TODO: Implement breaking path
        }

        emit SettlementPlaced(nodeId, msg.sender);
        testWinConditions();
    }

    function placeCity(bytes1 nodeId) public onlyCurrentPlayer {
        require(checkCityIsSettlement(nodeId), "Node is not a settlement");
        require(
            checkPlayerHasCitiesAvailable(msg.sender),
            "Player has run out of cities"
        );
        require(
            checkPlayerHasResourcesForCity(msg.sender),
            "Player does not have resources for city"
        );

        _resources.buyCity();

        nodes[nodeId].status = NodeStatus.HasCity;
        players[msg.sender].cityCount++;
        players[msg.sender].settlementCount--;
        players[msg.sender].victoryPoints++;
        emit CityPlaced(nodeId, msg.sender);
        testWinConditions();
    }

    // ROAD CHECKS

    function checkRoadIsValid(bytes2 roadId) public view returns (bool) {
        // a road value of 0 is invalid
        if (roadId == 0x0000) return false;
        // the largest road id is 0x3535
        if (roadId > 0x3535) return false;

        bytes1 node = roadId[0];

        bytes1[] memory connections = unpackConnections(
            nodes[node].connections
        );

        for (uint i = 0; i < connections.length; i++) {
            if (connections[i] == roadId[1]) {
                return true;
            }
        }

        return false;
    }

    function checkRoadOriginIsPlayerOwned(
        bytes2 roadId
    ) public view returns (bool) {
        bytes1 node1 = roadId[0];
        bytes1 node2 = roadId[1];

        // if the player has a settlement or city on either node, then the road is valid
        if (nodes[node1].playerAddress == msg.sender) return true;
        if (nodes[node2].playerAddress == msg.sender) return true;

        bytes1[] memory connections1 = unpackConnections(
            nodes[node1].connections
        );

        for (uint i = 0; i < connections1.length; i++) {
            bytes2 existingRoadId = packRoadId(node1, connections1[i]);
            if (
                roads[existingRoadId] == msg.sender &&
                nodes[node1].playerAddress == address(0)
            ) {
                return true;
            }
        }

        bytes1[] memory connections2 = unpackConnections(
            nodes[node2].connections
        );

        for (uint i = 0; i < connections2.length; i++) {
            bytes2 existingRoadId = packRoadId(node2, connections2[i]);
            if (
                roads[existingRoadId] == msg.sender &&
                nodes[node2].playerAddress == address(0)
            ) {
                return true;
            }
        }

        return false;
    }

    // TRADES
    function requestTrade(
        address[] calldata requestedPlayers,
        bytes5 offers,
        bytes5 requests
    ) public returns (bool) {
        require(
            _resources.checkPlayerHasResourcesForTrade(msg.sender, offers),
            "Player does not have resources for trade"
        );

        bool playersReceived = false;

        for (uint i = 0; i < requestedPlayers.length; i++) {
            if (playerAddresses[i] == msg.sender) {
                continue;
            }
            if (
                !_resources.checkPlayerHasResourcesForTrade(
                    playerAddresses[i],
                    requests
                )
            ) {
                continue;
            }

            trades.push(
                Trade({
                    proposer: msg.sender,
                    recipient: playerAddresses[i],
                    offers: offers,
                    requests: requests,
                    status: TradeStatus.Pending
                })
            );
            playersReceived = true;
            emit TradeRequested(playerAddresses[i], offers, requests);
        }

        return playersReceived;
    }

    function acceptTrade(uint tradeId) public {
        require(
            trades[tradeId].recipient == msg.sender,
            "Not the recipient of this trade"
        );
        Trade memory trade = trades[tradeId];
        require(
            _resources.checkPlayerHasResourcesForTrade(
                trade.recipient,
                trade.requests
            ),
            "Player does not have resources for trade"
        );
        _resources.batchResourcesPlayerToPlayer(
            trades[tradeId].proposer,
            trades[tradeId].recipient,
            trade.offers
        );

        trades[tradeId].status = TradeStatus.Accepted;
    }

    function rejectTrade(uint tradeId) public {
        require(
            trades[tradeId].recipient == msg.sender,
            "Not the recipient of this trade"
        );
        trades[tradeId].status = TradeStatus.Rejected;
        emit TradeRejected(tradeId);
    }

    function packRoadId(
        bytes1 node1,
        bytes1 node2
    ) internal pure returns (bytes2) {
        if (node1 < node2) {
            return bytes2(abi.encodePacked(node1, node2));
        } else {
            return bytes2(abi.encodePacked(node2, node1));
        }
    }

    function checkRoadIsAvailable(bytes2 roadId) public view returns (bool) {
        return roads[roadId] == address(0);
    }

    function checkPlayerHasRoadsAvailable(
        address playerAddress
    ) public view returns (bool) {
        return players[playerAddress].roadCount < MAX_ROADS_PER_PLAYER;
    }

    function checkPlayerHasSettlementsAvailable(
        address playerAddress
    ) public view returns (bool) {
        return
            players[playerAddress].settlementCount < MAX_SETTLEMENTS_PER_PLAYER;
    }

    function isCurrentPlayerTurn(address player) public view returns (bool) {
        return player == currentPlayer && boardStatus == BoardStatus.Active;
    }

    function checkPlayerHasResourcesForCard(
        address player
    ) public view returns (bool) {
        return
            _resources.checkPlayerHasResourcesForTrade(player, CARD_RESOURCES);
    }

    function checkPlayerHasResourcesForCity(
        address player
    ) public view returns (bool) {
        return
            _resources.checkPlayerHasResourcesForTrade(player, CITY_RESOURCES);
    }

    function checkPlayerHasResourcesForSettlement(
        address player
    ) public view returns (bool) {
        return
            _resources.checkPlayerHasResourcesForTrade(
                player,
                SETTLEMENT_RESOURCES
            );
    }

    function checkPlayerHasResourcesForRoad(
        address player
    ) public view returns (bool) {
        return
            _resources.checkPlayerHasResourcesForTrade(player, ROAD_RESOURCES);
    }

    function byteToUint(bytes1 b) internal pure returns (uint8) {
        return uint8(bytes1(b));
    }

    function checkSettlementIsValid(bytes1 nodeId) public pure returns (bool) {
        return nodeId <= 0x35;
    }

    function checkSettlementIsAvailable(
        bytes1 nodeId
    ) public view returns (bool) {
        return nodes[nodeId].playerAddress == address(0);
    }

    function checkSettlementIsNotTooClose(
        bytes1 nodeId
    ) public view returns (bool) {
        bytes1[] memory connections = unpackConnections(
            nodes[nodeId].connections
        );

        for (uint i = 0; i < connections.length; i++) {
            if (nodes[connections[i]].playerAddress != address(0)) {
                return false;
            }
        }
        return true;
    }

    function checkSettlementOnRoad(bytes1 nodeId) public view returns (bool) {
        bytes1[] memory connections = unpackConnections(
            nodes[nodeId].connections
        );

        // loop over roads from this node and check if they are owned by the player
        for (uint i = 0; i < connections.length; i++) {
            bytes2 testRoadId = packRoadId(nodeId, connections[i]);
            if (roads[testRoadId] == msg.sender) {
                return true;
            }
        }

        // none are owned by the player
        return false;
    }

    function checkPlayerHasCitiesAvailable(
        address playerAddress
    ) public view returns (bool) {
        return players[playerAddress].cityCount < MAX_CITIES_PER_PLAYER;
    }

    function checkCityIsSettlement(bytes1 nodeId) public view returns (bool) {
        return
            nodes[nodeId].status == NodeStatus.HasSettlement &&
            nodes[nodeId].playerAddress == msg.sender;
    }

    function isPlayer(address player) public view returns (bool) {
        return players[player].ethAddress != address(0);
    }

    function testWinConditions() public {
        uint8 totalVictoryPoints = players[msg.sender].victoryPoints;

        for (uint i = 0; developmentCards[msg.sender].length > 0; i++) {
            if (
                developmentCards[msg.sender][i] ==
                DevelopmentCardType.VictoryPoint
            ) {
                totalVictoryPoints++;
            }
        }

        if (largestArmyPlayer == msg.sender) {
            totalVictoryPoints += 2;
        }

        if (longestRoadPlayer == msg.sender) {
            totalVictoryPoints += 2;
        }

        if (totalVictoryPoints >= 10) {
            boardStatus = BoardStatus.GameOver;
            emit GameWinner(msg.sender);
        }
    }

    // ============== ROBBER HANDLING ==============

    struct Robber {
        bool active;
        uint256 turnInitiated;
        mapping(address => uint256) discardAmount;
        bool needsMovement;
        bool needsStealTarget;
        address[] validTargets;
        bytes6 currentPosition;
    }

    Robber public robber;

    mapping(bytes1 => bool) public nodeHasRobber;

    function discardResources(bytes5 resources) public {
        uint256[] memory splitResources = _resources.splitTradeResources(
            resources
        );
        uint256 total = 0;
        for (uint i = 0; i < splitResources.length; i++) {
            total += splitResources[i];
        }

        require(
            robber.discardAmount[msg.sender] == total,
            "Player must discard the correct amount of resources"
        );

        _resources.batchResourcesToBank(msg.sender, resources);
        robber.discardAmount[msg.sender] = 0;
        emit ResourcesToBank(msg.sender, resources);
    }

    function moveRobber(bytes6 hexId) public onlyCurrentPlayer {
        (, , uint8 total) = getRoll();
        require(
            total == 7 || knightInPlay == msg.sender,
            "Player cannot move robber"
        );

        bytes1[6] memory previousNodes = unpackHexNodes(robber.currentPosition);

        for (uint i = 0; i < previousNodes.length; i++) {
            if (nodeHasRobber[previousNodes[i]]) {
                nodeHasRobber[previousNodes[i]] = false;
            }
        }

        hexes[robber.currentPosition].hasRobber = false;

        bytes1[6] memory surroundingNodes = unpackHexNodes(hexId);

        for (uint i = 0; i < surroundingNodes.length; i++) {
            if (
                nodes[surroundingNodes[i]].playerAddress != address(0) &&
                nodes[surroundingNodes[i]].playerAddress != msg.sender
            ) {
                nodeHasRobber[surroundingNodes[i]] = true;
                robber.validTargets.push(
                    nodes[surroundingNodes[i]].playerAddress
                );
            }
        }

        robber.currentPosition = hexId;
        hexes[hexId].hasRobber = true;

        robber.needsMovement = false;
        emit RobberMoved(hexId);
        emit RobberStealTarget(msg.sender, robber.validTargets);
    }

    function chooseRobberTarget(address target) public {
        require(robber.active, "Robber is not active");
        require(
            robber.needsStealTarget,
            "Robber has already stolen from a target"
        );
        bool found = false;
        for (uint i = 0; i < robber.validTargets.length; i++) {
            if (robber.validTargets[i] == target) {
                found = true;
                break;
            }
        }
        require(found, "Target is not a valid robber target");

        Resources.ResourceTypes stolenResource = pickRandomResource(target);

        if (stolenResource != Resources.ResourceTypes.Unknown) {
            bytes5 stolenBytes = _resources.createResourceBytes5(
                stolenResource,
                1
            );

            _resources.resourcePlayerToPlayer(
                msg.sender,
                target,
                stolenResource,
                1
            );
            emit ResourcesPlayerToPlayer(msg.sender, target, stolenBytes);
        }

        delete robber.validTargets;
        robber.needsStealTarget = false;

        if (knightInPlay == msg.sender) {
            knightInPlay = address(0);
        }
    }

    function checkForRobbedPlayers() public {
        address[] memory robbedPlayers = new address[](3);
        uint256 robbedCount = 0;

        for (uint i = 0; i < playerAddresses.length; i++) {
            bytes5 playerResources = _resources.getPlayerResourcesAsBytes5(
                playerAddresses[i]
            );

            uint256[] memory resources = _resources.splitTradeResources(
                playerResources
            );

            uint256 total = 0;
            for (uint j = 1; i < resources.length; j++) {
                total += resources[j];
            }
            if (total <= 7) {
                continue;
            }

            uint256 excess = total / 2;
            robbedPlayers[robbedCount] = playerAddresses[i];
            robber.discardAmount[playerAddresses[i]] = excess;
            robbedCount++;

            emit PlayerRobbed(playerAddresses[i], excess);
        }

        address[] memory finalRobbedPlayers = new address[](robbedCount);
        for (uint i = 0; i < robbedCount; i++) {
            finalRobbedPlayers[i] = robbedPlayers[i];
        }

        robber.validTargets = finalRobbedPlayers;
    }

    function pickRandomResource(
        address player
    ) public view returns (Resources.ResourceTypes) {
        bytes5 playerResources = _resources.getPlayerResourcesAsBytes5(player);
        uint256[] memory resources = _resources.splitTradeResources(
            playerResources
        );

        uint256 total = 0;
        for (uint i = 1; i < resources.length; i++) {
            total += resources[i];
        }

        if (total == 0) return Resources.ResourceTypes.Unknown;

        uint256 random = (uint256(
            keccak256(abi.encodePacked(block.prevrandao, player))
        ) % total) + 1;

        uint256 count = 0;
        for (uint i = 1; i < resources.length; i++) {
            count += resources[i];
            if (count >= random) {
                return Resources.ResourceTypes(i);
            }
        }

        return Resources.ResourceTypes.Unknown;
    }

    function activateRobber() public {
        robber.active = true;
        robber.turnInitiated = turnCount;
        robber.needsMovement = true;
        robber.needsStealTarget = true;
        emit RobberRolled();
        emit PlayerMustMoveRobber(msg.sender);
    }

    function resetRobber() public {
        for (uint i = 0; i < playerAddresses.length; i++) {
            require(
                robber.discardAmount[playerAddresses[i]] == 0,
                "Not all players have discarded"
            );
        }

        require(
            robber.needsMovement && robber.needsStealTarget,
            "Robber actions are not complete"
        );

        robber.active = false;
        if (knightInPlay != address(0)) {
            knightInPlay = address(0);
        }
    }

    event RobberRolled();
    event PlayerMustMoveRobber(address indexed player);
    event RobberMoved(bytes6 hexId);
    event PlayerRobbed(address indexed player, uint256 excessResources);
    event RobberStealTarget(address indexed player, address[] validTargets);

    // ============== DEVELOPMENT CARD HANDLING ==============

    address knightInPlay = address(0);

    address public largestArmyPlayer = address(0);
    uint8 public largestArmySize = 0;

    mapping(address => uint8) public armySize;

    function drawCard() external {
        require(
            developmentCards[address(0)].length > 0,
            "No cards left in the deck"
        );

        // Pop the last card from the deck
        DevelopmentCardType drawnCard = developmentCards[address(0)][
            developmentCards[address(0)].length - 1
        ];
        developmentCards[address(0)].pop();

        developmentCards[msg.sender].push(drawnCard);

        if (drawnCard == DevelopmentCardType.VictoryPoint) {
            testWinConditions();
        }
    }

    function removeCardFromPlayer(DevelopmentCardType cardType) public {
        bool found = false;
        for (uint i = 0; i < developmentCards[msg.sender].length; i++) {
            if (developmentCards[msg.sender][i] == cardType) {
                developmentCards[msg.sender][i] = developmentCards[msg.sender][
                    developmentCards[msg.sender].length - 1
                ];
                developmentCards[msg.sender].pop();
                found = true;
                break;
            }
        }
        require(found, "Player does not have this development card");
    }

    function playKnightCard() public {
        removeCardFromPlayer(DevelopmentCardType.Knight);

        armySize[msg.sender]++;

        if (largestArmySize < armySize[msg.sender]) {
            largestArmySize = armySize[msg.sender];
            largestArmyPlayer = msg.sender;
        }
        testWinConditions();
        knightInPlay = msg.sender;
        activateRobber();
    }

    function playMonopolyCard(Resources.ResourceTypes resourceType) public {
        removeCardFromPlayer(DevelopmentCardType.Monopoly);

        emit MonopolyCardPlayed(msg.sender);

        for (uint i = 0; i < playerAddresses.length; i++) {
            address player = playerAddresses[i];
            if (player == msg.sender) continue;

            uint256 amount = _resources.balanceOf(
                player,
                uint256(resourceType)
            );
            if (amount > 0) {
                _resources.safeTransferFrom(
                    player,
                    msg.sender,
                    uint256(resourceType),
                    amount,
                    ""
                );
                emit ResourcesPlayerToPlayer(
                    player,
                    msg.sender,
                    _resources.createResourceBytes5(resourceType, uint8(amount))
                );
            }
        }
    }

    function playYearOfPlentyCard(bytes5 requestedResources) public {
        uint256[] memory resources = _resources.splitTradeResources(
            requestedResources
        );
        uint256 total = 0;
        for (uint i = 0; i < resources.length; i++) {
            total += resources[i];
        }
        require(total == 2, "Year of Plenty must request exactly 2 resources");

        removeCardFromPlayer(DevelopmentCardType.YearOfPlenty);

        emit YearOfPlentyCardPlayed(msg.sender);

        _resources.batchResourcesFromBank(msg.sender, requestedResources);
        emit ResourcesFromBank(msg.sender, requestedResources);
    }

    function playRoadBuildingCard() public {
        removeCardFromPlayer(DevelopmentCardType.RoadBuilding);
        freeRoads[msg.sender] = 2;
    }

    // ============== ROAD AND PATH HANDLING ==============

    mapping(address => bytes1[][]) public playerPaths;

    function appendToPath(uint256 pathIndex, bytes1 newNode) internal {
        playerPaths[msg.sender][pathIndex].push(newNode);
    }

    function prependToPath(uint256 pathIndex, bytes1 newNode) internal {
        bytes1[] storage path = playerPaths[msg.sender][pathIndex];
        bytes1[] memory newPath = new bytes1[](path.length + 1);

        newPath[0] = newNode;
        for (uint i = 0; i < path.length; i++) {
            newPath[i + 1] = path[i];
        }

        playerPaths[msg.sender][pathIndex] = newPath;
    }

    function updateLongestRoad() public {
        for (uint i = 0; i < playerPaths[msg.sender].length; i++) {
            bytes1[] storage path = playerPaths[msg.sender][i];
            if (path.length > longestRoadLength) {
                longestRoadLength = uint8(path.length);
                longestRoadPlayer = msg.sender;
            }
        }
    }

    function checkIfSettlementBreaksPath(
        bytes1 nodeId
    ) internal view returns (bool) {
        // step one - check if the node has two connected roads owned by the same non-me player

        address[] memory roadOwners = new address[](2); // Max 2 other players
        uint8[] memory roadCounts = new uint8[](2);
        uint8 ownerCount = 0;

        for (uint i = 0; i < nodes[nodeId].connections.length; i++) {
            bytes1 connection = nodes[nodeId].connections[i];
            bytes2 roadId = packRoadId(nodeId, connection);

            address roadOwner = roads[roadId];

            if (roadOwner == address(0) || roadOwner == msg.sender) {
                continue;
            }

            bool found = false;
            for (uint j = 0; j < ownerCount; j++) {
                if (roadOwners[j] == roadOwner) {
                    roadCounts[j]++;
                    if (roadCounts[j] == 2) {
                        return true; // Found a broken road
                    }
                    found = true;
                    break;
                }
            }

            if (!found) {
                roadOwners[ownerCount] = roadOwner;
                roadCounts[ownerCount] = 1;
                ownerCount++;
            }
        }
        return false;
    }

    function breakPathAtNode(bytes1 nodeId) internal {
        for (uint i = 0; i < playerAddresses.length; i++) {
            address player = playerAddresses[i];

            if (player == msg.sender) continue;

            for (uint j = 0; j < playerPaths[player].length; j++) {
                bytes1[] storage path = playerPaths[player][j];

                for (uint k = 0; k < path.length; k++) {
                    if (path[k] == nodeId) {
                        // TODO: Implement breaking path
                        bytes1[] memory path1 = new bytes1[](k);
                        for (uint m = 0; m < k; m++) {
                            path1[m] = path[m];
                        }

                        // Create second half (k+1 to end)
                        bytes1[] memory path2 = new bytes1[](
                            path.length - (k + 1)
                        );
                        for (uint m = k + 1; m < path.length; m++) {
                            path2[m - (k + 1)] = path[m];
                        }

                        playerPaths[player][j] = path1; // Replace original
                        playerPaths[player].push(path2); // Add second half
                        break;
                    }
                }
            }
        }
    }

    function updatePaths(bytes2 newRoad) internal {
        bytes1 node1 = newRoad[0];
        bytes1 node2 = newRoad[1];
        bool roadHandled = false;

        // First pass - look for simple extends and merges
        for (uint i = 0; i < playerPaths[msg.sender].length; i++) {
            bytes1[] storage path = playerPaths[msg.sender][i];

            // Check for extensions
            if (node1 == path[0]) {
                prependToPath(i, node2);
                roadHandled = true;
                break;
            } else if (node2 == path[0]) {
                prependToPath(i, node1);
                roadHandled = true;
                break;
            } else if (node1 == path[path.length - 1]) {
                appendToPath(i, node2);
                roadHandled = true;
                break;
            } else if (node2 == path[path.length - 1]) {
                appendToPath(i, node1);
                roadHandled = true;
                break;
            }

            // Check for merges with other paths
            for (uint j = i + 1; j < playerPaths[msg.sender].length; j++) {
                bytes1[] storage path2 = playerPaths[msg.sender][j];

                if (
                    (node1 == path[path.length - 1] && node2 == path2[0]) ||
                    (node2 == path[path.length - 1] && node1 == path2[0])
                ) {
                    // Merge paths
                    bytes1[] memory newPath = new bytes1[](
                        path.length + path2.length
                    );

                    // Copy path1
                    for (uint k = 0; k < path.length; k++) {
                        newPath[k] = path[k];
                    }

                    // Copy path2
                    for (uint k = 0; k < path2.length; k++) {
                        newPath[path.length + k] = path2[k];
                    }

                    // Update path1 to be combined path
                    playerPaths[msg.sender][i] = newPath;

                    // Remove path2 (swap and pop)
                    playerPaths[msg.sender][j] = playerPaths[msg.sender][
                        playerPaths[msg.sender].length - 1
                    ];
                    playerPaths[msg.sender].pop();

                    roadHandled = true;
                    break;
                }
            }
            if (roadHandled) break;

            // Check for branches (if not already handled)
            if (!roadHandled) {
                for (uint j = 1; j < path.length - 1; j++) {
                    if (path[j] == node1 || path[j] == node2) {
                        // Found a branch point!
                        bytes1 branchNode = path[j];
                        bytes1 newNode = (branchNode == node1) ? node2 : node1;

                        // Create path from start to branch + new node
                        bytes1[] memory newPath1 = new bytes1[](j + 2);
                        for (uint k = 0; k <= j; k++) {
                            newPath1[k] = path[k];
                        }
                        newPath1[j + 1] = newNode;
                        playerPaths[msg.sender].push(newPath1);

                        // Create path from branch to end + new node
                        bytes1[] memory newPath2 = new bytes1[](
                            path.length - j + 1
                        );
                        for (uint k = j; k < path.length; k++) {
                            newPath2[k - j] = path[k];
                        }
                        newPath2[path.length - j] = newNode;
                        playerPaths[msg.sender].push(newPath2);

                        roadHandled = true;
                        break;
                    }
                }
            }
            if (roadHandled) break;
        }

        // If road wasn't handled, create new standalone path
        if (!roadHandled) {
            bytes1[] memory newPath = new bytes1[](2);
            newPath[0] = node1;
            newPath[1] = node2;
            playerPaths[msg.sender].push(newPath);
        }
    }

    // TEST HELPER FUNCTIONS
    function _testPlaceRoad(bytes2 roadId, address player) public onlyOwner {
        roads[roadId] = player;
    }

    function _testPlaceSettlement(
        bytes1 nodeId,
        address player
    ) public onlyOwner {
        nodes[nodeId].playerAddress = player;
        nodes[nodeId].status = NodeStatus.HasSettlement;
    }

    function _testPlaceCity(bytes1 nodeId, address player) public onlyOwner {
        nodes[nodeId].playerAddress = player;
        nodes[nodeId].status = NodeStatus.HasCity;
    }

    modifier onlyCurrentPlayer() {
        require(isCurrentPlayerTurn(msg.sender), "Not your turn");
        _;
    }

    event RoadPlaced(bytes2 roadId, address player);
    event SettlementPlaced(bytes1 nodeId, address player);
    event CityPlaced(bytes1 nodeId, address player);

    event TurnStarted(address indexed player);
    event PlayerJoined();

    event DiceRolled(uint8 roll, uint8 die1, uint8 die2);

    event ResourcesGranted(
        address player,
        Resources.ResourceTypes resource,
        uint256 amount
    );

    event GameStatusChanged(BoardStatus newStatus);

    event TradeRequested(
        address indexed player,
        bytes5 offers,
        bytes5 requests
    );

    event ResourcesToBank(address player, bytes5 resources);

    event ResourcesFromBank(address player, bytes5 resources);

    event ResourcesPlayerToPlayer(
        address playerFrom,
        address playerTo,
        bytes5 resources
    );

    event TradeAccepted(
        address fromPlayer,
        address toPlayer,
        bytes5 offers,
        bytes5 requests
    );
    event TradeRejected(uint tradeId);

    event MonopolyCardPlayed(address player);
    event YearOfPlentyCardPlayed(address player);
    event GameWinner(address player);
}
