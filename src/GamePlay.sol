// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./Board.sol";
import "./Roads.sol";
import "./Random.sol";
import "./Resources.sol";
import "./DevelopmentCards.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

contract GamePlay is Ownable {
    Resources private _resources;
    Roads private _roads;
    Board private _board;
    DevelopmentCards private _developmentCards;

    uint8 public lastRoll = 0;
    address public currentPlayer = address(0);
    bool public gameReady = false;
    uint8 public turnCount = 0;

    mapping(address => Player) public players;
    address[] public playerAddresses;

    uint8 public currentPlayerTurn;
    bool public currentPlayerHasRolled = false;
    uint8 public currentSetupPlayer;

    mapping(address => mapping(Board.HarborType => bool)) public hasHarbor;

    bytes1 private constant MAX_NODE = 0xab;
    uint8 public constant MAX_PLAYERS = 4;
    uint8 private constant VICTORY_POINTS = 10;
    uint8 public constant MAX_SETTLEMENTS_PER_PLAYER = 5;
    uint8 public constant MAX_CITIES_PER_PLAYER = 4;
    uint8 public constant MAX_ROADS_PER_PLAYER = 15;

    bytes5 SETTLEMENT_RESOURCES = 0x0101010001;
    bytes5 CITY_RESOURCES = 0x0000000302;
    bytes5 ROAD_RESOURCES = 0x0101000000;
    bytes5 CARD_RESOURCES = 0x0100000101;

    enum Colours {
        Red,
        Yellow,
        Blue,
        White,
        Orange
    }

    struct Player {
        bytes32 name;
        address ethAddress;
        Colours colour;
        uint8 victoryPoints;
        uint8 roadCount;
        uint8 settlementCount;
        uint8 cityCount;
        bool hasApproved;
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

    constructor(
        address board,
        address resources,
        address roads,
        address developmentCards
    ) Ownable(msg.sender) {
        _board = Board(board);
        _resources = Resources(resources);
        _roads = Roads(roads);
        _developmentCards = DevelopmentCards(developmentCards);
    }

    function joinPlayer(bytes32 name, Colours colour) public {
        if (playerAddresses.length >= MAX_PLAYERS) revert MaxPlayersReached();
        if (msg.sender == _resources.bank()) revert BankCannotBePlayer();

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
        if (!isAvailable) revert PlayerAlreadyExists(name, msg.sender);
        if (!colourAvailable) revert ColorAlreadyChosen(colour);

        // set approval for the board to act as an ERC1155 operator
        _resources.setApprovalForAll(address(this), true);

        if (playerAddresses.length == 0) {
            _board.setBoardStatus(Board.BoardStatus.FindingPlayers);
        }

        players[msg.sender] = Player(
            name,
            msg.sender,
            colour,
            0,
            0,
            0,
            0,
            false
        );
        playerAddresses.push(msg.sender);

        emit PlayerJoined();
    }

    function getResourcesAddress() public view returns (address) {
        return address(_resources);
    }

    function getBoardAddress() public view returns (address) {
        return address(_board);
    }

    function getPlayers() public view returns (Player[] memory) {
        Player[] memory result = new Player[](playerAddresses.length);
        for (uint256 i = 0; i < playerAddresses.length; i++) {
            result[i] = players[playerAddresses[i]];
        }
        return result;
    }

    function playerRollsDice()
        public
        onlyCurrentPlayer
        returns (uint8 total, uint8 die1, uint8 die2)
    {
        if (currentPlayerHasRolled) revert InvalidPlayer(msg.sender);
        (total, die1, die2) = Random.rollTwoDice();
        emit DiceRolled(total, die1, die2);
        currentPlayerHasRolled = true;
        lastRoll = ((die1 & 0x07) << 3) | (die2 & 0x07);

        if (total != 7) {
            assignResourcesOnRoll(total);
        } else {
            activateRobber();
        }
    }

    function getRoll()
        public
        view
        returns (uint8 die1, uint8 die2, uint8 total)
    {
        die1 = (lastRoll >> 3) & 0x07;
        die2 = lastRoll & 0x07;
        total = die1 + die2;
    }

    function endTurn() public onlyCurrentPlayer {
        if (
            turnCount >= playerAddresses.length &&
            _board.boardStatus() == Board.BoardStatus.InitialPlacement
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
            _board.finishInitalPlacement();
        }

        emit TurnStarted(currentPlayer);
        turnCount++;
    }

    function getPlayerAddresses() public view returns (address[] memory) {
        return playerAddresses;
    }

    function chooseStartingPlayer() public view returns (uint256) {
        if (playerAddresses.length == 0) {
            revert InvalidGameState(
                _board.boardStatus(),
                Board.BoardStatus.FindingPlayers
            );
        }
        return
            uint256(
                keccak256(abi.encodePacked(block.prevrandao, "startingPlayer"))
            ) % playerAddresses.length;
    }

    function playerApprovesBoard() public {
        if (players[msg.sender].hasApproved) revert InvalidPlayer(msg.sender);
        _resources.setApprovalForAll(address(this), true);
        players[msg.sender].hasApproved = true;
    }

    function startGame() public {
        if (msg.sender != players[playerAddresses[0]].ethAddress) {
            revert InvalidPlayer(msg.sender);
        }
        if (_board.boardStatus() != Board.BoardStatus.FindingPlayers) {
            revert InvalidGameState(
                _board.boardStatus(),
                Board.BoardStatus.FindingPlayers
            );
        }
        _board.setBoardStatus(Board.BoardStatus.InitialPlacement);
    }

    function selectStartingPlayer() public returns (address) {
        if (
            playerAddresses.length < 2 ||
            _board.boardStatus() < Board.BoardStatus.FindingPlayers
        ) {
            revert InvalidGameState(
                _board.boardStatus(),
                Board.BoardStatus.FindingPlayers
            );
        }

        // pick one of the players at random
        currentPlayerTurn = uint8(
            uint256(keccak256(abi.encodePacked(block.prevrandao))) %
                playerAddresses.length
        );
        currentPlayer = playerAddresses[currentPlayerTurn];

        _board.setBoardStatus(Board.BoardStatus.InitialPlacement);

        return currentPlayer;
    }

    function tradeResourcesWithBank(
        address fromPlayer,
        bytes5 resourcesFrom,
        bytes5 resourcesRequired
    ) public {
        // check if player and banker have resources
        // these are checked in the transfer but we want to reject first if EITHER would fail
        if (
            !_resources.checkPlayerHasResourcesForTrade(
                fromPlayer,
                resourcesFrom
            )
        ) {
            revert InsufficientResources(msg.sender, resourcesFrom);
        }

        bool amountsValid = true;

        uint256[] memory resourcesFromSplit = _resources.splitTradeResources(
            resourcesFrom
        );
        uint256[] memory resourcesRequiredSplit = _resources
            .splitTradeResources(resourcesRequired);

        bool hasHarborGeneric = hasHarborForResourceType(
            fromPlayer,
            Board.HarborType.Generic
        );

        for (uint256 i = 0; i < resourcesFromSplit.length; i++) {
            if (i == 0) {
                continue;
            }
            bool hasHarborForResource = hasHarborForResourceType(
                fromPlayer,
                Board.HarborType(i)
            );

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

        if (!amountsValid) revert InvalidTrade();

        _resources.batchResourcesToBank(fromPlayer, resourcesFrom);
        emit ResourcesToBank(fromPlayer, resourcesFrom);
        _resources.batchResourcesFromBank(fromPlayer, resourcesRequired);
        emit ResourcesFromBank(fromPlayer, resourcesRequired);
    }

    function placeSettlement(bytes1 nodeId) public onlyCurrentPlayer {
        // These rules don't apply on starting turns
        if (!_board.checkSettlementLocationValid(nodeId, msg.sender))
            revert InvalidLocation(nodeId);

        if (
            !_resources.checkPlayerHasResourcesForTrade(
                msg.sender,
                SETTLEMENT_RESOURCES
            )
        ) {
            revert InsufficientResources(msg.sender, SETTLEMENT_RESOURCES);
        }

        if (!checkPlayerHasSettlementsAvailable(msg.sender)) {
            revert BuildingLimitReached(msg.sender, "settlement");
        }

        if (_board.boardStatus() == Board.BoardStatus.Active) {
            _resources.buySettlement(msg.sender);
        }

        players[msg.sender].settlementCount++;
        players[msg.sender].victoryPoints++;

        if (players[currentPlayer].settlementCount == 2) {
            // current player gets resources
            bytes6[] memory hexesForNode = _board.getHexesForNode(nodeId);
            for (uint i = 0; i < hexesForNode.length; i++) {
                uint8 roll = _board.getHex(hexesForNode[i]).roll;
                assignResourcesOnRoll(roll);
            }
        }

        Board.HarborType harborType = _board.getNodeHarborType(nodeId);
        if (
            harborType != Board.HarborType.None &&
            !hasHarbor[currentPlayer][harborType]
        ) {
            hasHarbor[currentPlayer][harborType] = true;
        }

        bytes3 connections = _board.getNode(nodeId).connections;

        bytes1[] memory connectionsArray = new bytes1[](3);
        connectionsArray[0] = connections[0];
        connectionsArray[1] = connections[1];
        connectionsArray[2] = connections[2];

        bool breaksPath = _roads.checkIfSettlementBreaksPath(
            nodeId,
            msg.sender,
            connectionsArray
        );

        if (breaksPath) {
            _roads.breakPathAtNode(nodeId, msg.sender);
        }
        _board.placeSettlement(nodeId, msg.sender);
        testWinConditions();
    }

    function assignResourcesOnRoll(uint8 roll) public {
        bytes6[] memory rolledHexes = _board.getHexesForRoll(roll);

        for (uint i = 0; i < rolledHexes.length; i++) {
            (address[] memory playersFound, bytes5[] memory resources) = _board
                .getResourcesForHex(rolledHexes[i]);
            for (uint j = 0; j < playersFound.length; j++) {
                _resources.batchResourcesFromBank(
                    playersFound[j],
                    resources[j]
                );
                emit ResourcesFromBank(playersFound[j], resources[j]);
            }
        }
    }

    function placeCity(bytes1 nodeId) public onlyCurrentPlayer {
        if (!_board.checkCityIsSettlement(nodeId, msg.sender)) {
            revert InvalidLocation(nodeId);
        }

        if (!checkPlayerHasCitiesAvailable(msg.sender)) {
            revert BuildingLimitReached(msg.sender, "city");
        }

        if (
            !_resources.checkPlayerHasResourcesForTrade(
                msg.sender,
                CITY_RESOURCES
            )
        ) {
            revert InsufficientResources(msg.sender, CITY_RESOURCES);
        }

        _resources.buyCity(msg.sender);

        _board.placeCity(nodeId, msg.sender);

        players[msg.sender].cityCount++;
        players[msg.sender].settlementCount--;
        players[msg.sender].victoryPoints++;
        testWinConditions();
    }

    function buyDevelopmentCard() public {
        if (
            !_resources.checkPlayerHasResourcesForTrade(
                msg.sender,
                CARD_RESOURCES
            )
        ) {
            revert InsufficientResources(msg.sender, CARD_RESOURCES);
        }

        _resources.buyDevelopmentCard(msg.sender);

        DevelopmentCards.DevelopmentCardType cardType = _developmentCards
            .drawCard(msg.sender);
        if (cardType == DevelopmentCards.DevelopmentCardType.VictoryPoint) {
            testWinConditions();
        }
    }

    function checkPlayerHasSettlementsAvailable(
        address playerAddress
    ) public view returns (bool) {
        return
            players[playerAddress].settlementCount < MAX_SETTLEMENTS_PER_PLAYER;
    }

    function checkPlayerHasCitiesAvailable(
        address playerAddress
    ) public view returns (bool) {
        return players[playerAddress].cityCount < MAX_CITIES_PER_PLAYER;
    }

    function checkPlayerHasRoadsAvailable(
        address playerAddress
    ) public view returns (bool) {
        return players[playerAddress].roadCount < MAX_ROADS_PER_PLAYER;
    }

    function checkPlayerHasResourcesForCard(
        address player
    ) public view returns (bool) {
        return
            _resources.checkPlayerHasResourcesForTrade(player, CARD_RESOURCES);
    }

    // TRADES
    function requestTrade(
        address[] calldata requestedPlayers,
        bytes5 offers,
        bytes5 requests
    ) public returns (bool) {
        if (!_resources.checkPlayerHasResourcesForTrade(msg.sender, offers)) {
            revert InsufficientResources(msg.sender, offers);
        }

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
        if (trades[tradeId].recipient != msg.sender) {
            revert InvalidPlayer(msg.sender);
        }

        Trade memory trade = trades[tradeId];

        if (
            !_resources.checkPlayerHasResourcesForTrade(
                trade.recipient,
                trade.requests
            )
        ) {
            revert InsufficientResources(trade.recipient, trade.requests);
        }

        _resources.batchResourcesPlayerToPlayer(
            trades[tradeId].proposer,
            trades[tradeId].recipient,
            trade.offers
        );

        trades[tradeId].status = TradeStatus.Accepted;
    }

    function rejectTrade(uint tradeId) public {
        if (trades[tradeId].recipient != msg.sender) {
            revert InvalidPlayer(msg.sender);
        }

        trades[tradeId].status = TradeStatus.Rejected;
        emit TradeRejected(tradeId);
    }

    function isPlayer(address player) public view returns (bool) {
        return players[player].ethAddress != address(0);
    }

    function hasHarborForResourceType(
        address playerAddress,
        Board.HarborType harborType
    ) public view returns (bool) {
        return hasHarbor[playerAddress][harborType];
    }

    function testWinConditions() public {
        uint8 totalVictoryPoints = players[msg.sender].victoryPoints;

        if (_developmentCards.largestArmyPlayer() == msg.sender) {
            totalVictoryPoints += 2;
        }

        if (_roads.longestRoadPlayer() == msg.sender) {
            totalVictoryPoints += 2;
        }

        if (totalVictoryPoints >= 10) {
            _board.setBoardStatus(Board.BoardStatus.GameOver);
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

    Robber robber;

    function discardResources(bytes5 resources) public {
        if (!robber.active) {
            revert RobberError("Robber not active");
        }

        if (robber.discardAmount[msg.sender] == 0) {
            revert RobberError("Player does not need to discard");
        }

        uint256[] memory splitResources = _resources.splitTradeResources(
            resources
        );
        uint256 total = 0;
        for (uint i = 0; i < splitResources.length; i++) {
            total += splitResources[i];
        }

        if (robber.discardAmount[msg.sender] != total) {
            revert InvalidDiscardAmount(
                msg.sender,
                robber.discardAmount[msg.sender],
                total
            );
        }
        _resources.batchResourcesToBank(msg.sender, resources);
        robber.discardAmount[msg.sender] = 0;
    }

    function moveRobber(bytes6 hexId) public {
        (, , uint8 total) = getRoll();

        if (total != 7 || _developmentCards.knightInPlay() != msg.sender) {
            revert RobberError("Invalid Move");
        }

        _board.moveRobber(robber.currentPosition, hexId);

        robber.currentPosition = hexId;
        robber.needsMovement = false;

        emit RobberStealTarget(msg.sender, robber.validTargets);
    }

    function chooseRobberTarget(address target) public {
        if (!robber.active) {
            revert RobberError("Robber is not active");
        }

        if (!robber.needsStealTarget) {
            revert RobberError("Robber has already stolen from a target");
        }

        bool found = false;
        for (uint i = 0; i < robber.validTargets.length; i++) {
            if (robber.validTargets[i] == target) {
                found = true;
                break;
            }
        }

        if (!found) {
            revert RobberError("Target is not a valid robber target");
        }

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

        if (_developmentCards.knightInPlay() == msg.sender) {
            _developmentCards.disableKnightInPlay();
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
            if (robber.discardAmount[playerAddresses[i]] != 0) {
                revert RobberError("Not all players have discarded");
            }
        }

        if (robber.needsMovement || robber.needsStealTarget) {
            revert RobberError("Robber actions are not complete");
        }

        robber.active = false;
        if (_developmentCards.knightInPlay() != address(0)) {
            _developmentCards.disableKnightInPlay();
        }
    }

    event RobberRolled();
    event PlayerMustMoveRobber(address indexed player);
    event RobberMoved(bytes6 hexId);
    event PlayerRobbed(address indexed player, uint256 excessResources);
    event RobberStealTarget(address indexed player, address[] validTargets);

    // ============== DEVELOPMENT CARD HANDLING ==============

    function playKnightCard() public {
        _developmentCards.playKnightCard(msg.sender);
        testWinConditions();
        // activateRobber();
        emit DevelopmentCards.KnightCardPlayed(msg.sender);
    }

    function playMonopolyCard(Resources.ResourceTypes resourceType) public {
        _developmentCards.removeCardFromPlayer(
            DevelopmentCards.DevelopmentCardType.Monopoly,
            msg.sender
        );

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
        emit DevelopmentCards.MonopolyCardPlayed(msg.sender);
    }

    function playYearOfPlentyCard(bytes5 requestedResources) public {
        uint256[] memory resources = _resources.splitTradeResources(
            requestedResources
        );
        uint256 total = 0;
        for (uint i = 0; i < resources.length; i++) {
            total += resources[i];
        }

        if (total != 2)
            revert InvalidAction("Must request exactly 2 resources");

        _developmentCards.removeCardFromPlayer(
            DevelopmentCards.DevelopmentCardType.YearOfPlenty,
            msg.sender
        );

        emit DevelopmentCards.YearOfPlentyCardPlayed(msg.sender);

        _resources.batchResourcesFromBank(msg.sender, requestedResources);
        emit ResourcesFromBank(msg.sender, requestedResources);
    }

    function playRoadBuildingCard() public {
        _developmentCards.removeCardFromPlayer(
            DevelopmentCards.DevelopmentCardType.RoadBuilding,
            msg.sender
        );
        _roads.setFreeRoads(msg.sender, 2);
    }

    modifier onlyCurrentPlayer() {
        bool isCurrentPlayerTurn = msg.sender == currentPlayer &&
            _board.boardStatus() == Board.BoardStatus.Active;
        if (!isCurrentPlayerTurn) revert NotYourTurn(msg.sender);
        _;
    }

    event TurnStarted(address indexed player);
    event PlayerJoined();

    event DiceRolled(uint8 roll, uint8 die1, uint8 die2);

    event ResourcesGranted(
        address player,
        Resources.ResourceTypes resource,
        uint256 amount
    );

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

    event GameWinner(address player);

    // Player Management
    error MaxPlayersReached();
    error BankCannotBePlayer();
    error PlayerAlreadyExists(bytes32 name, address playerAddress);
    error ColorAlreadyChosen(Colours colour);
    error PlayerNotApproved();
    error InvalidPlayer(address player);

    // Game State
    error InvalidGameState(
        Board.BoardStatus current,
        Board.BoardStatus required
    );
    error NotYourTurn(address player);

    // Resources
    error InsufficientResources(address player, bytes5 required);
    error InvalidTrade();

    // Building
    error InvalidLocation(bytes1 nodeId);
    error LocationTaken(bytes1 nodeId);
    error InvalidRoad(bytes2 roadId);
    error BuildingLimitReached(address player, string buildingType);

    // Game Flow
    error InvalidAction(string reason);

    error RobberError(string reason);
    error InvalidDiscardAmount(
        address player,
        uint256 expected,
        uint256 actual
    );
}
