// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Resources} from "../src/Resources.sol";
import {DevelopmentCards} from "../src/DevelopmentCards.sol";
import {Board} from "../src/Board.sol";
import {GamePlay} from "../src/GamePlay.sol";
import {Roads} from "../src/Roads.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey); // This address will be our bank

        vm.startBroadcast(deployerPrivateKey);

        // Make deployer the bank
        Resources resources = new Resources(deployer); // Deployer is now the bank
        console2.log("Resources deployed to:", address(resources));
        Roads roads = new Roads();
        console2.log("Roads deployed to:", address(roads));
        DevelopmentCards developmentCards = new DevelopmentCards();
        console2.log(
            "DevelopmentCards deployed to:",
            address(developmentCards)
        );
        Board board = new Board(false);
        console2.log("Board deployed to:", address(board));
        GamePlay gameplay = new GamePlay(
            address(board),
            address(resources),
            address(roads),
            address(developmentCards)
        );
        console2.log("GamePlay deployed to:", address(gameplay));

        console2.log("Setting up contract permissions...");
        resources.setApprovalForGamePlay(address(gameplay));
        board.setDependencies(address(roads), address(gameplay));
        roads.setGamePlay(address(gameplay));
        developmentCards.setGamePlay(address(gameplay));
        vm.stopBroadcast();

        console2.log("\nDeployment Summary:");
        console2.log("------------------");
        console2.log("Bank/Deployer:", deployer);
        console2.log("Resources:", address(resources));
        console2.log("Roads:", address(roads));
        console2.log("DevelopmentCards:", address(developmentCards));
        console2.log("Board:", address(board));
        console2.log("GamePlay:", address(gameplay));
    }
}
