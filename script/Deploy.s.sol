// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Resources} from "../src/Resources.sol";
import {Board} from "../src/Board.sol";

contract Deploy is Script {
    function run() external {
        // Retrieve private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        address bank = makeAddr("bank"); // For local testing
        // For production, you might want to use a specific address
        // address bank = 0x...;

        // Deploy Resources first
        Resources resources = new Resources(bank);

        // Deploy Board with Resources address
        Board board = new Board(address(resources));

        // Set up initial approvals
        vm.prank(bank);
        resources.setApprovalForBoard(address(board));

        vm.stopBroadcast();

        // Log the deployed addresses
        console2.log("Resources deployed to:", address(resources));
        console2.log("Board deployed to:", address(board));
        console2.log("Bank address:", bank);
    }
}
