// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./Resources.sol";
import "./Roads.sol";
import "./GameData.sol";
import "./GamePlay.sol";
import "./DevelopmentCards.sol";
import "./Random.sol";

import {console2} from "forge-std/console2.sol";

contract Board {
    using Random for uint8[];
    using Random for HarborType[9];
    using Random for Resources.ResourceTypes[];
    using Random for bytes6[];

    Roads private _roads;
    GamePlay private _gameplay;

    BoardStatus public boardStatus = BoardStatus.New;
    bytes6 public desertHexId;
    bool public testMode;

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

    struct HexDevelopment {
        address player;
        uint8 level; // 1 for settlement, 2 for city
    }

    struct Hex {
        Resources.ResourceTypes resourceType;
        bool hasRobber;
        HexDevelopment[] developments;
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

    bytes6[19] public hexIds;

    bytes2[] public harborEdges;

    enum HarborType {
        None,
        Sheep,
        Brick,
        Wood,
        Stone,
        Wheat,
        Generic
    }

    mapping(bytes6 => Hex) public hexes;
    mapping(bytes1 => Node) public nodes;
    mapping(uint8 => bytes6[]) public rollToHexes;
    mapping(bytes1 => HarborType) public nodeHarborType;

    constructor(bool _testMode) {
        testMode = _testMode;
        nonRandomSetup();
        assignResources();
        generateRolls();
        generateHarbors();
    }

    function setDependencies(
        address roadsContract,
        address gameplayContract
    ) external {
        _roads = Roads(roadsContract);
        _gameplay = GamePlay(gameplayContract);
    }

    function finishInitalPlacement() public {
        if (boardStatus != BoardStatus.InitialPlacement) {
            revert GamePlay.InvalidGameState(
                boardStatus,
                BoardStatus.InitialPlacement
            );
        }
        boardStatus = BoardStatus.Active;

        boardStatus = BoardStatus.Active;
        emit GameStatusChanged(BoardStatus.Active);
    }

    function setBoardStatus(BoardStatus newStatus) external {
        boardStatus = newStatus;
        emit GameStatusChanged(newStatus);
    }

    function nonRandomSetup() internal {
        hexIds = GameData.getHexIds();
        harborEdges = GameData.getHarborEdges();

        GameData.NodeConnections[53] memory nodeConnections = GameData
            .getNodeConnections();

        for (uint i = 0; i < nodeConnections.length; i++) {
            nodes[nodeConnections[i].nodeId].connections = nodeConnections[i]
                .connections;
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

    function getNode(bytes1 nodeId) public view returns (Node memory) {
        return nodes[nodeId];
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
        Resources.ResourceTypes[] memory terrains = GameData.getTerrainTypes();
        terrains.shuffle();

        return terrains;
    }

    function generateHarbors() public {
        HarborType[9] memory harborTypes = GameData.getHarborTypes();

        harborTypes.shuffle();

        for (uint i = 0; i < harborEdges.length; i++) {
            nodeHarborType[harborEdges[i][0]] = harborTypes[i];
            nodeHarborType[harborEdges[i][1]] = harborTypes[i];
        }
    }

    function getNodeHarborType(bytes1 nodeId) public view returns (HarborType) {
        return nodeHarborType[nodeId];
    }

    function assignResources() public {
        if (
            boardStatus != BoardStatus.New &&
            boardStatus != BoardStatus.HasResources
        ) {
            revert GamePlay.InvalidGameState(
                boardStatus,
                BoardStatus.HasResources
            );
        }

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

    function getResourcesForHex(
        bytes6 hexId
    )
        public
        view
        returns (address[] memory playerFound, bytes5[] memory resources)
    {
        Hex memory hexTile = hexes[hexId];
        if (hexTile.hasRobber) {
            return (new address[](0), new bytes5[](0));
        }

        // Temporary arrays to track unique players
        address[] memory tempPlayers = new address[](
            hexTile.developments.length
        );
        bytes5[] memory tempResources = new bytes5[](
            hexTile.developments.length
        );
        uint numUnique = 0;

        console2.log("Number of developments:", hexTile.developments.length);

        // Combine resources for same player
        for (uint i = 0; i < hexTile.developments.length; i++) {
            address player = hexTile.developments[i].player;
            uint8 level = hexTile.developments[i].level;
            bytes5 newResource = createResourceBytes5(
                hexTile.resourceType,
                hexTile.developments[i].level
            );

            console2.log("Development", i, "Player:", uint160(player));
            console2.log("Level:", level);
            console2.log("New resource:", uint40(newResource));

            // Check if we've seen this player
            bool found = false;
            for (uint j = 0; j < numUnique; j++) {
                if (tempPlayers[j] == player) {
                    console2.log("Found existing player at index", j);
                    console2.log(
                        "Previous resources:",
                        uint40(tempResources[j])
                    );

                    tempResources[j] |= newResource;
                    console2.log(
                        "Combined resources:",
                        uint40(tempResources[j])
                    );
                    found = true;
                    break;
                }
            }

            // New player
            if (!found) {
                console2.log("New player at index", numUnique);
                tempPlayers[numUnique] = player;
                tempResources[numUnique] = newResource;
                numUnique++;
            }
        }

        // Create final arrays of correct size
        playerFound = new address[](numUnique);
        resources = new bytes5[](numUnique);
        for (uint i = 0; i < numUnique; i++) {
            playerFound[i] = tempPlayers[i];
            resources[i] = tempResources[i];
            console2.log("Final player", i, ":", uint160(playerFound[i]));
            console2.log("Final resources:", uint40(resources[i]));
        }
    }

    function combineResources(
        bytes5 a,
        bytes5 b
    ) internal pure returns (bytes5) {
        bytes5 result;
        for (uint8 i = 0; i < 5; i++) {
            uint8 aAmount = uint8(uint40(a) >> (i * 8));
            uint8 bAmount = uint8(uint40(b) >> (i * 8));
            result |= bytes5(uint40(aAmount + bAmount) << (i * 8));
        }
        return result;
    }

    function createResourceBytes5(
        Resources.ResourceTypes resourceType,
        uint8 amount
    ) public pure returns (bytes5) {
        if (resourceType == Resources.ResourceTypes.Sheep)
            return bytes5(bytes5(uint40(amount)) << 32);
        if (resourceType == Resources.ResourceTypes.Brick)
            return bytes5(bytes5(uint40(amount)) << 24);
        if (resourceType == Resources.ResourceTypes.Wood)
            return bytes5(bytes5(uint40(amount)) << 16);
        if (resourceType == Resources.ResourceTypes.Stone)
            return bytes5(bytes5(uint40(amount)) << 8);
        if (resourceType == Resources.ResourceTypes.Wheat)
            return bytes5(bytes5(uint40(amount)));
        return bytes5(0);
    }

    function setNodePlayerAddress(
        bytes1 nodeId,
        address playerAddress
    ) external {
        nodes[nodeId].playerAddress = playerAddress;
    }

    function setNodeStatus(bytes1 nodeId, NodeStatus status) external {
        nodes[nodeId].status = status;
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
            shuffledHexIds.shuffle();
            // Attempt to place all critical numbers
            bool placementValid = true;
            for (uint i = 0; i < criticalNumbers.length; i++) {
                bool numberPlaced = false;
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

        for (uint i = 0; i < 6; i++) {
            for (uint j = 0; j < 6; j++) {
                if (nodes1[i] == nodes2[j]) return true;
            }
        }

        return false;
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

    function getHexesForRoll(
        uint8 roll
    ) external view returns (bytes6[] memory) {
        return rollToHexes[roll];
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

    function byteToUint(bytes1 b) internal pure returns (uint8) {
        return uint8(bytes1(b));
    }

    function checkSettlementLocationValid(
        bytes1 nodeId,
        address playerAddress
    ) public view returns (bool) {
        if (
            boardStatus == BoardStatus.Active &&
            !checkSettlementOnRoad(nodeId, playerAddress)
        ) {
            return false;
        }

        if (
            !checkSettlementIsValid(nodeId) ||
            !checkSettlementIsAvailable(nodeId)
        ) {
            return false;
        }

        if (!checkSettlementIsNotTooClose(nodeId)) {
            return false;
        }

        return true;
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

    function checkSettlementOnRoad(
        bytes1 nodeId,
        address playerAddress
    ) public view returns (bool) {
        bytes1[] memory connections = unpackConnections(
            nodes[nodeId].connections
        );

        // loop over roads from this node and check if they are owned by the player
        for (uint i = 0; i < connections.length; i++) {
            bytes2 testRoadId = _roads.packRoadId(nodeId, connections[i]);
            if (_roads.getRoad(testRoadId) == playerAddress) {
                return true;
            }
        }

        // none are owned by the player
        return false;
    }

    function checkCityIsSettlement(
        bytes1 nodeId,
        address playerAddress
    ) public view returns (bool) {
        return
            nodes[nodeId].status == NodeStatus.HasSettlement &&
            nodes[nodeId].playerAddress == playerAddress;
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
        bytes2 roadId,
        address playerAddress
    ) public view returns (bool) {
        bytes1 node1 = roadId[0];
        bytes1 node2 = roadId[1];

        // if the player has a settlement or city on either node, then the road is valid
        if (nodes[node1].playerAddress == playerAddress) return true;
        if (nodes[node2].playerAddress == playerAddress) return true;

        bytes1[] memory connections1 = unpackConnections(
            nodes[node1].connections
        );

        for (uint i = 0; i < connections1.length; i++) {
            bytes2 existingRoadId = _roads.packRoadId(node1, connections1[i]);
            if (
                _roads.getRoad(existingRoadId) == playerAddress &&
                nodes[node1].playerAddress == address(0)
            ) {
                return true;
            }
        }

        bytes1[] memory connections2 = unpackConnections(
            nodes[node2].connections
        );

        for (uint i = 0; i < connections2.length; i++) {
            bytes2 existingRoadId = _roads.packRoadId(node2, connections2[i]);
            if (
                _roads.getRoad(existingRoadId) == playerAddress &&
                nodes[node2].playerAddress == address(0)
            ) {
                return true;
            }
        }

        return false;
    }

    function checkRoadIsAvailable(bytes2 roadId) public view returns (bool) {
        return _roads.getRoad(roadId) == address(0);
    }

    function placeRoadFinal(bytes2 roadId, address playerAddress) internal {
        _roads.placeRoad(roadId, playerAddress);
    }

    function placeRoad(bytes2 roadId, address playerAddress) external {
        placeRoadFinal(roadId, playerAddress);
        emit RoadPlaced(roadId, playerAddress);
    }

    function placeSettlementFinal(
        bytes1 nodeId,
        address playerAddress
    ) internal {
        nodes[nodeId].playerAddress = playerAddress;
        nodes[nodeId].status = NodeStatus.HasSettlement;

        bytes6[] memory touchingHexes = getHexesForNode(nodeId);

        // Add development to each hex
        for (uint i = 0; i < touchingHexes.length; i++) {
            if (touchingHexes[i] == desertHexId) continue;
            if (touchingHexes[i] != 0) {
                // Skip empty slots
                hexes[touchingHexes[i]].developments.push(
                    HexDevelopment(playerAddress, 1)
                );
            }
        }
    }

    function placeSettlement(bytes1 nodeId, address playerAddress) external {
        placeSettlementFinal(nodeId, playerAddress);
        emit SettlementPlaced(nodeId, playerAddress);
    }

    function placeCityFinal(bytes1 nodeId, address playerAddress) internal {
        nodes[nodeId].status = NodeStatus.HasCity;

        bytes6[] memory touchingHexes = getHexesForNode(nodeId);

        // Upgrade development on each hex
        for (uint i = 0; i < touchingHexes.length; i++) {
            if (touchingHexes[i] == desertHexId) continue;
            if (touchingHexes[i] != 0) {
                // Skip empty slots
                HexDevelopment[] storage developments = hexes[touchingHexes[i]]
                    .developments;
                for (uint j = 0; j < developments.length; j++) {
                    if (
                        developments[j].player == playerAddress &&
                        developments[j].level == 1
                    ) {
                        developments[j].level = 2;
                        break; // Found and upgraded the settlement, move to next hex
                    }
                }
            }
        }
    }

    function placeCity(bytes1 nodeId, address playerAddress) external {
        placeCityFinal(nodeId, playerAddress);
        emit CityPlaced(nodeId, playerAddress);
    }

    function moveRobber(bytes6 fromHexId, bytes6 toHexId) external {
        hexes[fromHexId].hasRobber = false;
        hexes[toHexId].hasRobber = true;
        emit RobberMoved(toHexId);
    }

    // TEST HELPER FUNCTIONS

    function _testPlaceRoad(bytes2 roadId, address player) public {
        if (testMode) {
            _roads.placeRoad(roadId, player);
        }
    }

    function _testSetHexRoll(bytes6 hexId, uint8 roll) public {
        if (testMode) {
            hexes[hexId].roll = roll;
        }
    }

    function _testSetHexResource(
        bytes6 hexId,
        Resources.ResourceTypes resourceType
    ) public {
        if (testMode) {
            hexes[hexId].resourceType = resourceType;
        }
    }

    function _testPlaceSettlement(bytes1 nodeId, address player) public {
        if (testMode) placeSettlementFinal(nodeId, player);
    }

    function _testPlaceCity(bytes1 nodeId, address player) public {
        if (testMode) {
            nodes[nodeId].status = NodeStatus.HasCity;

            bytes6[] memory touchingHexes = getHexesForNode(nodeId);
            for (uint i = 0; i < touchingHexes.length; i++) {
                hexes[touchingHexes[i]].developments.push(
                    HexDevelopment(player, 2)
                );
            }

            // Upgrade development on each hex
            // for (uint i = 0; i < touchingHexes.length; i++) {
            //     if (touchingHexes[i] == desertHexId) continue;
            //     if (touchingHexes[i] != 0) {

            // Skip empty slots
            // HexDevelopment[] storage developments = hexes[
            //     touchingHexes[i]
            // ].developments;
            // for (uint j = 0; j < developments.length; j++) {
            //     if (
            //         developments[j].player == player &&
            //         developments[j].level == 1
            //     ) {
            //         developments[j].level = 2;
            //         break; // Found and upgraded the settlement, move to next hex
            //     }
            // }
            // }
            // }
        }
    }

    event SettlementPlaced(bytes1 nodeId, address player);
    event CityPlaced(bytes1 nodeId, address player);
    event RoadPlaced(bytes2 roadId, address player);
    event GameStatusChanged(BoardStatus newStatus);
    event RobberMoved(bytes6 hexId);
}
