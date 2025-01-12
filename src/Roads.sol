// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./GamePlay.sol";
import "./GamePlay.sol";

contract Roads {
    Board private _board;
    GamePlay private _gameplay;

    address public longestRoadPlayer = address(0);
    uint8 public longestRoadLength = 0;
    mapping(address => bytes1[][]) public playerPaths;

    mapping(address => uint256) public freeRoads;
    mapping(bytes2 => address) public roads;

    bytes2[] public placedRoads;
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

    function setBoard(address boardContract) external {
        require(address(_board) == address(0), "Board already set");
        _board = Board(boardContract);
    }

    function setGamePlay(address gameplayContract) external {
        require(
            address(_gameplay) == address(0),
            "Gameplay contract already set"
        );
        _gameplay = GamePlay(gameplayContract);
    }

    function placeRoad(bytes2 roadId, address player) external {
        roads[roadId] = player;
        placedRoads.push(roadId);

        updatePaths(roadId, player);
        updateLongestRoad(player);
    }

    // ROAD CHECKS

    function packRoadId(
        bytes1 node1,
        bytes1 node2
    ) public pure returns (bytes2) {
        if (node1 < node2) {
            return bytes2(abi.encodePacked(node1, node2));
        } else {
            return bytes2(abi.encodePacked(node2, node1));
        }
    }

    function getRoad(bytes2 roadId) external view returns (address) {
        return roads[roadId];
    }

    function getFreeRoads(address player) external view returns (uint256) {
        return freeRoads[player];
    }

    function setFreeRoads(address player, uint256 value) external {
        freeRoads[player] = value;
    }

    function updateLongestRoad(address player) public {
        for (uint i = 0; i < playerPaths[player].length; i++) {
            bytes1[] storage path = playerPaths[player][i];
            if (path.length > longestRoadLength) {
                longestRoadLength = uint8(path.length);
                longestRoadPlayer = player;
            }
        }
    }

    function checkIfSettlementBreaksPath(
        bytes1 nodeId,
        address player,
        bytes1[] memory connections
    ) external view returns (bool) {
        // step one - check if the node has two connected roads owned by the same non-me player

        address[] memory roadOwners = new address[](2); // Max 2 other players
        uint8[] memory roadCounts = new uint8[](2);
        uint8 ownerCount = 0;

        for (uint i = 0; i < connections.length; i++) {
            bytes1 connection = connections[i];
            bytes2 roadId = packRoadId(nodeId, connection);

            address roadOwner = roads[roadId];

            if (roadOwner == address(0) || roadOwner == player) {
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

    function breakPathAtNode(bytes1 nodeId, address playerAddress) external {
        address[] memory playerAddresses = _gameplay.getPlayerAddresses();
        for (uint i = 0; i < playerAddresses.length; i++) {
            address player = playerAddresses[i];

            if (player == playerAddress) continue;

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

                        playerPaths[player][j] = path1;
                        playerPaths[player].push(path2);
                        break;
                    }
                }
            }
        }
    }

    function updatePaths(bytes2 newRoad, address player) internal {
        bytes1 node1 = newRoad[0];
        bytes1 node2 = newRoad[1];
        bool roadHandled = false;

        // First pass - look for simple extends and merges
        for (uint i = 0; i < playerPaths[player].length; i++) {
            bytes1[] storage path = playerPaths[player][i];

            // Check for extensions
            if (node1 == path[0]) {
                prependToPath(i, node2, player);
                roadHandled = true;
                break;
            } else if (node2 == path[0]) {
                prependToPath(i, node1, player);
                roadHandled = true;
                break;
            } else if (node1 == path[path.length - 1]) {
                appendToPath(i, node2, player);
                roadHandled = true;
                break;
            } else if (node2 == path[path.length - 1]) {
                appendToPath(i, node1, player);
                roadHandled = true;
                break;
            }

            // Check for merges with other paths
            for (uint j = i + 1; j < playerPaths[player].length; j++) {
                bytes1[] storage path2 = playerPaths[player][j];

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
                    playerPaths[player][i] = newPath;

                    // Remove path2 (swap and pop)
                    playerPaths[player][j] = playerPaths[player][
                        playerPaths[player].length - 1
                    ];
                    playerPaths[player].pop();

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
                        playerPaths[player].push(newPath1);

                        // Create path from branch to end + new node
                        bytes1[] memory newPath2 = new bytes1[](
                            path.length - j + 1
                        );
                        for (uint k = j; k < path.length; k++) {
                            newPath2[k - j] = path[k];
                        }
                        newPath2[path.length - j] = newNode;
                        playerPaths[player].push(newPath2);

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
            playerPaths[player].push(newPath);
        }
    }

    function appendToPath(
        uint256 pathIndex,
        bytes1 newNode,
        address player
    ) internal {
        playerPaths[player][pathIndex].push(newNode);
    }

    function prependToPath(
        uint256 pathIndex,
        bytes1 newNode,
        address player
    ) internal {
        bytes1[] storage path = playerPaths[player][pathIndex];
        bytes1[] memory newPath = new bytes1[](path.length + 1);

        newPath[0] = newNode;
        for (uint i = 0; i < path.length; i++) {
            newPath[i + 1] = path[i];
        }

        playerPaths[player][pathIndex] = newPath;
    }

    modifier onlyGamePlay() {
        require(msg.sender == address(_board), "Only Board can call this");
        _;
    }
}
