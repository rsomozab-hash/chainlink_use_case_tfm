// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
// import "../src/VRFDirectFunding.sol";
import "../src/DirectFundingConsumer.sol";

contract Deploy is Script {
    function run() external returns (DirectFundingConsumer vrfDemo) {
        vm.startBroadcast();

        vrfDemo = new DirectFundingConsumer();

        vm.stopBroadcast();
    }
}
