// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DirectFundingConsumer.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

contract LotteryVRF is ConfirmedOwner {
    DirectFundingConsumer public vrf;
    // address public owner;

    uint256 public currentLotteryId;
    uint256 public ticketPrice = 0.01 ether; // Precio por ticket

    struct Lottery {
        uint256 id;
        bool finished;
        uint256 winningNumber;
        uint256 vrfRequestId;
        mapping(uint256 => address[]) numberToPlayers; // número => jugadores
        mapping(address => bool) claimed; // si el jugador ha reclamado
    }

    mapping(uint256 => Lottery) public lotteries;

    // modifier onlyOwner() {
    //     require(msg.sender == owner, "Not owner");
    // }

    constructor(address vrfAddress) ConfirmedOwner(msg.sender) {
        vrf = DirectFundingConsumer(payable(vrfAddress));
        // owner = msg.sender;
        currentLotteryId = 1;
    }

    function msgSenderTest() public view returns (address) {
    return msg.sender;
    }

    /// Compra un ticket para la lotería actual
    function buyTicket(uint256 number) external payable {
        require(number <= 9999, "Number must be 0-9999");
        require(msg.value == ticketPrice, "Incorrect price");

        Lottery storage l = lotteries[currentLotteryId];
        l.numberToPlayers[number].push(msg.sender);
    }

    /// Inicia la lotería solicitando un número aleatorio a VRF
    function startLottery() external onlyOwner {
        Lottery storage l = lotteries[currentLotteryId];
        require(!l.finished, "Lottery already finished");
        uint256 requestId = vrf.requestRandomWords(false);
        l.vrfRequestId = requestId;
    }

    /// Finaliza la lotería y obtiene el número ganador
    function finalizeLottery() external onlyOwner {
        Lottery storage l = lotteries[currentLotteryId];
        require(!l.finished, "Lottery already finished");
        require(l.vrfRequestId != 0, "VRF request not sent");

        uint256 number = vrf.getRandomInRange(l.vrfRequestId, 0, 9999);
        l.winningNumber = number;
        l.finished = true;
    }

    /// Reclama el premio si se ha ganado
    function claimPrize(uint256 lotteryId) external {
        Lottery storage l = lotteries[lotteryId];
        require(l.finished, "Lottery not finished");
        require(!l.claimed[msg.sender], "Already claimed");

        uint256 winNum = l.winningNumber;
        address[] memory winners = l.numberToPlayers[winNum];

        bool isWinner = false;
        for (uint256 i = 0; i < winners.length; i++) {
            if (winners[i] == msg.sender) {
                isWinner = true;
                break;
            }
        }

        require(isWinner, "Not a winner");

        l.claimed[msg.sender] = true;

        uint256 prize = address(this).balance / winners.length;
        payable(msg.sender).transfer(prize);
    }

    /// Avanza a la siguiente lotería
    function nextLottery() external onlyOwner {
        Lottery storage l = lotteries[currentLotteryId];
        require(l.finished, "Current lottery not finished");

        currentLotteryId++;
    }

    /// Permite al owner cambiar el precio del ticket
    function setTicketPrice(uint256 newPrice) external onlyOwner {
        ticketPrice = newPrice;
    }

    /// Consulta los jugadores de un número en la lotería actual
    function getPlayers(uint256 lotteryId, uint256 number) external view returns (address[] memory) {
        return lotteries[lotteryId].numberToPlayers[number];
    }

    /// Consulta el número ganador de una lotería
    function getWinningNumber(uint256 lotteryId) external view returns (uint256) {
        require(lotteries[lotteryId].finished, "Lottery not finished");
        return lotteries[lotteryId].winningNumber;
    }
}
