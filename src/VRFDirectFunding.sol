// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract VRFDirectFunding is VRFConsumerBaseV2Plus {
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Sepolia LINK Token
    LinkTokenInterface public immutable LINK_TOKEN =
        LinkTokenInterface(0x779877A7B0D9E8603169DdbD7836e478b4624789);

    // VRF Coordinator (Sepolia)
    address private constant COORDINATOR =
        0x78ea207D5f7dAB6E369C28f715620aa21e9B0A6C;

    // Gas Lane / KeyHash
    bytes32 public constant KEYHASH =
        0x040f2f15bb782baf0b153760205b2eb8e94c646f0d0b3e3fed7b1928b09e7c14;

    // Último número aleatorio generado
    uint256 public randomResult;

    // Último request ID
    uint256 public lastRequestId;
    event RandomRequested(uint256 requestId);
    event Debug(uint256 allowance, string note);
    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() VRFConsumerBaseV2Plus(COORDINATOR) {}

    /*//////////////////////////////////////////////////////////////
                       REQUEST RANDOM WORDS
    //////////////////////////////////////////////////////////////*/

    function requestRandomNumber() external returns (uint256 requestId) {
        VRFV2PlusClient.RandomWordsRequest memory req = VRFV2PlusClient.RandomWordsRequest({
            keyHash: KEYHASH,
            subId: 0,                 // No se usan subscripciones en direct funding
            requestConfirmations: 3,
            callbackGasLimit: 200000,
            numWords: 1,
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false}) // Direct funding usa LINK
            )
        });
        // emit Debug(req, "request sent");
        requestId = s_vrfCoordinator.requestRandomWords(req);
        lastRequestId = requestId;
        // emit RandomRequested(requestId);
        
        return lastRequestId;
    }

    /*//////////////////////////////////////////////////////////////
                           VRF CALLBACK
    //////////////////////////////////////////////////////////////*/

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        randomResult = randomWords[0];
    }

    /*//////////////////////////////////////////////////////////////
                             FUNDING
    //////////////////////////////////////////////////////////////*/

    function fundWithLink(uint256 amount) external {
        require(
            LINK_TOKEN.transferFrom(msg.sender, address(this), amount),
            "LINK transfer failed"
        );
    }

    function approveLink(uint256 amount) external {
    LINK_TOKEN.approve(COORDINATOR, amount);
}

    function linkBalance() external view returns (uint256) {
        return LINK_TOKEN.balanceOf(address(this));
    }
}
