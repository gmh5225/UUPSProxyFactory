// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/UUPSProxyFactory.sol";

contract DeployScript is Script {
    bytes32 constant SALT = bytes32(uint256(0x0000000000000000000000000000000000000000d3bf2663da51c10215000003));

    function run() external {
        // TODO: encrypt your private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // start broadcast
        vm.startBroadcast(deployerPrivateKey);

        // deploy
        UUPSProxyFactory factory = new UUPSProxyFactory{ salt: SALT }();
        // deployed at: 0x6CeF682028A46015462b176c6F36d2BCb19515EE
        console2.log("UUPSProxyFactory deployed at:", address(factory));

        // stop broadcast
        vm.stopBroadcast();

        // print deployment info
        console2.log("Deployment completed!");
    }
}
