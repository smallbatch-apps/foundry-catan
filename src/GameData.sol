// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./Resources.sol";
import "./Board.sol";

library GameData {
    struct NodeConnections {
        bytes1 nodeId;
        bytes3 connections;
    }

    function getHexIds() external pure returns (bytes6[19] memory) {
        bytes6[19] memory hexIds = [
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
        return hexIds;
    }

    function getHarborEdges() external pure returns (bytes2[9] memory) {
        bytes2[9] memory harborEdges = [
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

        return harborEdges;
    }

    function getNodeConnections()
        external
        pure
        returns (NodeConnections[53] memory)
    {
        // Initial rnodes[0x00].connections = 0x0304ff;
        NodeConnections[53] memory nodeConnections = [
            NodeConnections(bytes1(0x01), bytes3(0x0405ff)),
            NodeConnections(bytes1(0x02), bytes3(0x0506ff)),
            NodeConnections(bytes1(0x03), bytes3(0x0007ff)),
            NodeConnections(bytes1(0x04), bytes3(0x000108)),
            NodeConnections(bytes1(0x05), bytes3(0x010209)),
            NodeConnections(bytes1(0x06), bytes3(0x020aff)),
            NodeConnections(bytes1(0x07), bytes3(0x030b0c)),
            NodeConnections(bytes1(0x08), bytes3(0x040c0d)),
            NodeConnections(bytes1(0x09), bytes3(0x050d0e)),
            NodeConnections(bytes1(0x0a), bytes3(0x060e0f)),
            NodeConnections(bytes1(0x0b), bytes3(0x0710ff)),
            NodeConnections(bytes1(0x0c), bytes3(0x070811)),
            NodeConnections(bytes1(0x0d), bytes3(0x080912)),
            NodeConnections(bytes1(0x0e), bytes3(0x090a13)),
            NodeConnections(bytes1(0x0f), bytes3(0x0a14ff)),
            NodeConnections(bytes1(0x10), bytes3(0x0b1516)),
            NodeConnections(bytes1(0x11), bytes3(0x0c1617)),
            NodeConnections(bytes1(0x12), bytes3(0x0d1718)),
            NodeConnections(bytes1(0x13), bytes3(0x0e1819)),
            NodeConnections(bytes1(0x14), bytes3(0x0f191a)),
            NodeConnections(bytes1(0x15), bytes3(0x101bff)),
            NodeConnections(bytes1(0x16), bytes3(0x10111c)),
            NodeConnections(bytes1(0x17), bytes3(0x11121d)),
            NodeConnections(bytes1(0x18), bytes3(0x12131e)),
            NodeConnections(bytes1(0x19), bytes3(0x13141f)),
            NodeConnections(bytes1(0x1a), bytes3(0x1420ff)),
            NodeConnections(bytes1(0x1b), bytes3(0x1521ff)),
            NodeConnections(bytes1(0x1c), bytes3(0x162122)),
            NodeConnections(bytes1(0x1d), bytes3(0x172223)),
            NodeConnections(bytes1(0x1e), bytes3(0x182324)),
            NodeConnections(bytes1(0x1f), bytes3(0x192425)),
            NodeConnections(bytes1(0x20), bytes3(0x1a25ff)),
            NodeConnections(bytes1(0x21), bytes3(0x1c26ff)),
            NodeConnections(bytes1(0x22), bytes3(0x1c1d27)),
            NodeConnections(bytes1(0x23), bytes3(0x1d1e28)),
            NodeConnections(bytes1(0x24), bytes3(0x1e1f29)),
            NodeConnections(bytes1(0x25), bytes3(0x202aff)),
            NodeConnections(bytes1(0x26), bytes3(0x212bff)),
            NodeConnections(bytes1(0x27), bytes3(0x222b2c)),
            NodeConnections(bytes1(0x28), bytes3(0x232c2d)),
            NodeConnections(bytes1(0x29), bytes3(0x242d2e)),
            NodeConnections(bytes1(0x2a), bytes3(0x252eff)),
            NodeConnections(bytes1(0x2b), bytes3(0x26272f)),
            NodeConnections(bytes1(0x2c), bytes3(0x272830)),
            NodeConnections(bytes1(0x2d), bytes3(0x282931)),
            NodeConnections(bytes1(0x2e), bytes3(0x292a32)),
            NodeConnections(bytes1(0x2f), bytes3(0x2b33ff)),
            NodeConnections(bytes1(0x30), bytes3(0x2c3334)),
            NodeConnections(bytes1(0x31), bytes3(0x2d3435)),
            NodeConnections(bytes1(0x32), bytes3(0x2e35ff)),
            NodeConnections(bytes1(0x33), bytes3(0x2f30ff)),
            NodeConnections(bytes1(0x34), bytes3(0x3031ff)),
            NodeConnections(bytes1(0x35), bytes3(0x3132ff))
        ];

        return nodeConnections;
    }

    function getTerrainTypes()
        external
        pure
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
        return terrains;
    }

    function getHarborTypes()
        external
        pure
        returns (Board.HarborType[9] memory)
    {
        // Board.HarborType[] memory harborTypes = new Board.HarborType[](9);
        Board.HarborType[9] memory harborTypes = [
            Board.HarborType.Generic,
            Board.HarborType.Generic,
            Board.HarborType.Generic,
            Board.HarborType.Generic,
            Board.HarborType.Wood,
            Board.HarborType.Brick,
            Board.HarborType.Wheat,
            Board.HarborType.Stone,
            Board.HarborType.Sheep
        ];

        return harborTypes;
    }

    // Any other large data arrays you need
}
