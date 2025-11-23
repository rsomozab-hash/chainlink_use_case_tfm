// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/DirectFundingConsumer.sol";
import "../src/Lottery.sol";

contract Deploy is Script {
    function run() external returns (DirectFundingConsumer vrfDemo) {
        bytes32 pkBytes = vm.envBytes32("PRIVATE_KEY");
        uint256 deployerPrivateKey = uint256(pkBytes);
        string memory rpcUrl = vm.envString("RPC_URL");

        vm.startBroadcast(deployerPrivateKey);

        // 1️) Desplegar DirectFundingConsumer si aún no lo tienes
        DirectFundingConsumer vrf = new DirectFundingConsumer();

        // 2️) Desplegar la lotería pasando la dirección del VRF
        LotteryVRF lottery = new LotteryVRF(address(vrf));

        // 3️) Opcional: cambiar precio del ticket
        lottery.setTicketPrice(0.01 ether);

        vm.stopBroadcast();

        console.log("VRF deployed at:", address(vrf));
        console.log("Lottery deployed at:", address(lottery));
    }
}
