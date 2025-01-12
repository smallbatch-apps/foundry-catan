// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./Board.sol";
import "./Resources.sol";

library Random {
    function getRandomSeed(uint256 nonce) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.prevrandao, nonce)));
    }

    function shuffle(uint8[] memory array) internal view {
        for (uint i = 0; i < array.length; i++) {
            uint j = getRandomSeed(i) % array.length;
            (array[i], array[j]) = (array[j], array[i]);
        }
    }

    function shuffle(Board.HarborType[9] memory array) internal view {
        for (uint i = 0; i < 9; i++) {
            uint j = getRandomSeed(i) % 9;
            (array[i], array[j]) = (array[j], array[i]);
        }
    }

    function rollDie() internal view returns (uint8) {
        return uint8(getRandomSeed(0) % 6) + 1;
    }

    function rollTwoDice()
        internal
        view
        returns (uint8 total, uint8 die1, uint8 die2)
    {
        die1 = uint8(getRandomSeed(1) % 6) + 1;
        die2 = uint8(getRandomSeed(2) % 6) + 1;
        total = die1 + die2;
    }

    function shuffle(Resources.ResourceTypes[] memory array) internal view {
        for (uint i = 0; i < array.length; i++) {
            uint j = getRandomSeed(i) % array.length;
            (array[i], array[j]) = (array[j], array[i]);
        }
    }

    function shuffle(bytes6[] memory array) internal view {
        for (uint i = 0; i < array.length; i++) {
            uint j = getRandomSeed(i) % array.length;
            (array[i], array[j]) = (array[j], array[i]);
        }
    }
}
