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
        0xaadc36B74638f144Ef5b7F30d1D9420d0aB81cbA;

    // Gas Lane / KeyHash
    bytes32 public constant KEYHASH =
        0x1153181c3f1cf7f2298b1ba58836df7f8d6009de0fe46156f0bb141c924c6de0;

    // Último número aleatorio generado
    uint256 public randomResult;

    // Último request ID
    uint256 public lastRequestId;

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

        requestId = s_vrfCoordinator.requestRandomWords(req);
        lastRequestId = requestId;
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

    function linkBalance() external view returns (uint256) {
        return LINK_TOKEN.balanceOf(address(this));
    }
}
