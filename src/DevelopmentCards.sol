// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./Board.sol";
import "./Resources.sol";
import "./GamePlay.sol";

contract DevelopmentCards {
    GamePlay private _gameplay;

    constructor() {
        setupDevelopmentCards();
    }

    enum DevelopmentCardType {
        Knight,
        Monopoly,
        VictoryPoint,
        RoadBuilding,
        YearOfPlenty
    }

    address public knightInPlay = address(0);

    address public largestArmyPlayer = address(0);
    uint8 public largestArmySize = 0;

    mapping(address => uint8) public armySize;

    mapping(address => DevelopmentCardType[]) public developmentCards;

    function setGamePlay(address gameplayContract) external {
        require(address(_gameplay) == address(0), "GamePlay already set");
        _gameplay = GamePlay(gameplayContract);
    }

    function setupDevelopmentCards() internal {
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

    function disableKnightInPlay() external onlyGamePlay {
        knightInPlay = address(0);
    }

    function drawCard(address player) external returns (DevelopmentCardType) {
        require(
            developmentCards[address(0)].length > 0,
            "No cards left in the deck"
        );

        // Pop the last card from the deck
        DevelopmentCardType drawnCard = developmentCards[address(0)][
            developmentCards[address(0)].length - 1
        ];
        developmentCards[address(0)].pop();

        developmentCards[player].push(drawnCard);

        return drawnCard;
    }

    function removeCardFromPlayer(
        DevelopmentCardType cardType,
        address player
    ) public {
        bool found = false;
        for (uint i = 0; i < developmentCards[player].length; i++) {
            if (developmentCards[player][i] == cardType) {
                developmentCards[player][i] = developmentCards[player][
                    developmentCards[player].length - 1
                ];
                developmentCards[player].pop();
                found = true;
                break;
            }
        }
        require(found, "Player does not have this development card");
    }

    function playKnightCard(address player) public {
        removeCardFromPlayer(DevelopmentCardType.Knight, player);

        armySize[player]++;

        if (largestArmySize < armySize[player]) {
            largestArmySize = armySize[player];
            largestArmyPlayer = player;
        }
        knightInPlay = player;
    }

    function countVictoryPointCards(
        address player
    ) public view onlyGamePlay returns (uint8) {
        uint8 count = 0;
        for (uint i = 0; developmentCards[player].length > 0; i++) {
            if (
                developmentCards[player][i] == DevelopmentCardType.VictoryPoint
            ) {
                count++;
            }
        }
        return count;
    }

    modifier onlyGamePlay() {
        require(
            msg.sender == address(_gameplay),
            "Only GamePlay contract can call this"
        );
        _;
    }

    event KnightCardPlayed(address player);
    event MonopolyCardPlayed(address player);
    event YearOfPlentyCardPlayed(address player);
}
