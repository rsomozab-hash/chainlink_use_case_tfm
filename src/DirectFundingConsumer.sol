// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {VRFV2PlusWrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @notice Direct funding consumer example for Chainlink VRF v2.5 (Wrapper).
 * @dev Based on Chainlink docs: Get a Random Number (Direct Funding).
 *      Adaptado para Foundry + Sepolia.
 */
contract DirectFundingConsumer is VRFV2PlusWrapperConsumerBase, ConfirmedOwner {
    using VRFV2PlusClient for VRFV2PlusClient.RandomWordsRequest;

    event RequestSent(uint256 indexed requestId, uint32 numWords, bool paidInNative,address by);
    event RequestFulfilled(uint256 indexed requestId, uint256[] randomWords, uint256 payment);
    event LinkWithdrawn(address to, uint256 amount);
    event NativeWithdrawn(address to, uint256 amount);

    struct RequestStatus {
        uint256 paid; // amount paid in LINK (in LINK's smallest unit) or wei if paid in native (wrapper indicates)
        bool fulfilled;
        uint256[] randomWords;
    }

    mapping(uint256 => RequestStatus) public s_requests;
    uint256[] public requestIds;
    uint256 public lastRequestId;
    mapping(address => bool) private _authorized;

    // Modificador que permite al owner o a un trusted caller
    modifier onlyOwnerOrAuthorized() {
        require(msg.sender == owner() || _authorized[msg.sender], "Not allowed");
        _;
    }

    // Funciones de administración de trusted callers
    function addAuthorized(address _addr) external onlyOwner {
        _authorized[_addr] = true;
    }

    function removeAuthorized(address _addr) external onlyOwner {
        _authorized[_addr] = false;
    }

    function isAuthorized(address _addr) external view returns (bool) {
        return _authorized[_addr];
    }

    // === Configurable parameters (defaults for Sepolia from docs) ===
    uint32 public callbackGasLimit = 100_000;    // ajusta según tu callback
    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;

    // Sepolia addresses (ejemplos oficiales / docs)
    address public immutable linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address public immutable wrapperAddress = 0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1;

    LinkTokenInterface private immutable LINK;

    constructor() ConfirmedOwner(msg.sender) VRFV2PlusWrapperConsumerBase(wrapperAddress) {
        LINK = LinkTokenInterface(linkAddress);
    }

    /**
     * @notice Request randomness, paying with LINK or native ETH depending on flag.
     * @param enableNativePayment If true, the wrapper will be paid in native token (ETH); otherwise pays in LINK.
     * @return requestId the request identifier
     */
    function requestRandomWords(bool enableNativePayment) external onlyOwnerOrAuthorized returns (uint256 requestId) {
        emit RequestSent(requestId, numWords, enableNativePayment, address(msg.sender));
        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(
            VRFV2PlusClient.ExtraArgsV1({ nativePayment: enableNativePayment })
        );

        uint256 reqPrice;
        if (enableNativePayment) {
            // When paying in native token, the wrapper expects msg.value to cover the cost.
            // The helper returns (requestId, priceInNativeWei)
            (requestId, reqPrice) = requestRandomnessPayInNative(callbackGasLimit, requestConfirmations, numWords, extraArgs);
            // Note: caller must send msg.value equal/greater than reqPrice when calling this function.
        } else {
            // Paying in LINK: wrapper will pull LINK from this contract (so contract must have LINK and allowance)
            (requestId, reqPrice) = requestRandomness(callbackGasLimit, requestConfirmations, numWords, extraArgs);
        }

        // Store request info correctly (fixed struct initialization)
        s_requests[requestId] = RequestStatus({
            paid: reqPrice,
            fulfilled: false,
            randomWords: new uint256[](0)
        });


        requestIds.push(requestId);
        lastRequestId = requestId;

        
        return requestId;
    }

    /**
     * @notice VRF callback. Do NOT make external calls here that can fail.
     */
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(s_requests[_requestId].paid > 0, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;

        emit RequestFulfilled(_requestId, _randomWords, s_requests[_requestId].paid);
    }
    function getRandomInRange(uint256 requestId, uint256 min, uint256 max) public view returns (uint256) {
    require(max > min, "Invalid range");

    // Recuperamos la request
    RequestStatus memory request = s_requests[requestId];
    // require(request.exists, "Request does not exist");
    require(request.fulfilled, "Request not fulfilled yet");
    require(request.randomWords.length > 0, "No random words stored");

    // Rango total
    uint256 range = max - min + 1;

    // Convertir randomWords[0] al rango deseado
    return (request.randomWords[0] % range) + min;
}


    // === Helpers / admin ===

    /// @notice Return the request status (paid, fulfilled, randomWords)
    function getRequestStatus(uint256 _requestId) external view returns (uint256 paid, bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].paid > 0, "request not found");
        RequestStatus memory rs = s_requests[_requestId];
        return (rs.paid, rs.fulfilled, rs.randomWords);
    }

    /// @notice Fund this contract with LINK via transferFrom (user must approve this contract first)
    function fundWithLink(uint256 amount) external {
        bool ok = LINK.transferFrom(msg.sender, address(this), amount);
        require(ok, "LINK transfer failed");
    }

    /// @notice Approve wrapper/coordinator to pull LINK from this contract (optional helper)
    function approveWrapper(uint256 amount) external onlyOwner {
        LINK.approve(wrapperAddress, amount);
    }

    /// @notice Withdraw all LINK to owner
    function withdrawLink() external onlyOwner {
        uint256 bal = LINK.balanceOf(address(this));
        require(LINK.transfer(owner(), bal), "withdraw LINK failed");
        emit LinkWithdrawn(owner(), bal);
    }

    /// @notice Withdraw native ETH to owner
    function withdrawNative(uint256 amount) external onlyOwner {
        (bool success, ) = payable(owner()).call{ value: amount }("");
        require(success, "withdraw native failed");
        emit NativeWithdrawn(owner(), amount);
    }

    receive() external payable {}
}
