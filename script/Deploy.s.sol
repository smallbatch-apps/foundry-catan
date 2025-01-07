// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Resources} from "../src/Resources.sol";
import {Board} from "../src/Board.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey); // This address will be our bank

        vm.startBroadcast(deployerPrivateKey);

        // Make deployer the bank
        Resources resources = new Resources(deployer); // Deployer is now the bank
        Board board = new Board(address(resources));

        // Since deployer is the bank, this should work
        resources.setApprovalForBoard(address(board));

        vm.stopBroadcast();

        console2.log("Resources deployed to:", address(resources));
        console2.log("Board deployed to:", address(board));
        console2.log("Bank/Deployer address:", deployer);
    }
}
