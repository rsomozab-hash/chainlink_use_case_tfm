#!/bin/bash
source .env
##THESE ARE THE VARIABLES THAT SHOULD APPEAR IN THE .env file*
# PRIVATE_KEY=<OWNER PRIVATE KEY>
# CLIENT_PRIVATE_KEY=<CONTESTANT IN THE LOTTERY PRIVATE KEY>
# RPC_URL=https://sepolia.infura.io/v3/<ID>
# SEPOLIA_LINK_TOKEN=0x779877A7B0D9E8603169DdbD7836e478b4624789
# DIRECT_FUNDING_CONTRACT
# LOTTERY_CONTRACT
BALANCE=$(cast call $SEPOLIA_LINK_TOKEN \
    "balanceOf(address)(uint256)" $DIRECT_FUNDING_CONTRACT \
    --rpc-url $RPC_URL | awk '{print $1}')

echo "Available LINK in $DIRECT_FUNDING_CONTRACT is $BALANCE"
##We authorize the lottery contract to access the VRF contract
ISAUTHORIZED=$(cast call $DIRECT_FUNDING_CONTRACT "isAuthorized(address)(bool)" $LOTTERY_CONTRACT 
                                                --rpc-url $RPC_URL --private-key $PRIVATE_KEY)
if [ $ISAUTHORIZED != true ]; then 
    echo "Authorizing..."
    cast send $DIRECT_FUNDING_CONTRACT "addAuthorized(address)" $LOTTERY_CONTRACT --rpc-url $RPC_URL --private-key $PRIVATE_KEY
fi
##We check that there is enough link
if [ "$BALANCE" -lt 100000000000000000 ]; then
    cast send $SEPOLIA_LINK_TOKEN \
            "approve(address,uint256)" $DIRECT_FUNDING_CONTRACT 100000000000000000 \
            --rpc-url $RPC_URL --private-key $PRIVATE_KEY

    cast send $DIRECT_FUNDING_CONTRACT\
            "fundWithLink(uint256)" 100000000000000000 \
            --rpc-url $RPC_URL --private-key $PRIVATE_KEY
    echo "Contract is now funded"
fi

##We order a new lottery in case the current one is finished
OUTPUT=$(cast send $LOTTERY_CONTRACT "nextLottery()" --rpc-url $RPC_URL --private-key $PRIVATE_KEY)
# Precio del ticket (0.01 ETH)
cast send $LOTTERY_CONTRACT \
    "buyTicket(uint256)" 1234 \
    --value 10000000000000000 \
    --private-key $CLIENT_PRIVATE_KEY \
    --rpc-url $RPC_URL
echo "Ticket bought, good luck!"

cast send $LOTTERY_CONTRACT \
    "startLottery()" \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL
echo "Lottery Started"
##We call the lottery ID
LOTTERY_ID=$(cast call $LOTTERY_CONTRACT "currentLotteryId()" --rpc-url $RPC_URL | cast to-dec)
##We get the last request so as to check its status
REQUEST_ID=$(cast call $DIRECT_FUNDING_CONTRACT "lastRequestId()" --rpc-url $RPC_URL | cast to-dec)

##We check the status
FULFILLED_DEC=0
while [ $FULFILLED_DEC -ne 1 ]; do
    echo "Waiting for VRF to fulfill request..."
    sleep 10
    STATUS=$(cast call $DIRECT_FUNDING_CONTRACT "getRequestStatus(uint256)" $REQUEST_ID --rpc-url $RPC_URL)
    HEX=$(echo "$STATUS" | sed 's/^0x//')

    # Tomamos los bytes 32..63 (segunda palabra 32 bytes)
    FULFILLED_HEX=${HEX:64:64}  # empieza en offset 64 hex chars (32 bytes), longitud 64

    # Convertimos a decimal
    FULFILLED_DEC=$((16#$FULFILLED_HEX))
done

cast send $LOTTERY_CONTRACT \
    "finalizeLottery()" \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL

WINNER=$(cast call $LOTTERY_CONTRACT "getWinningNumber(uint256)" $LOTTERY_ID --rpc-url $RPC_URL | cast to-dec)

echo "AND THE WINNING NUMBER IS .... $WINNER!"

RESULT=$(cast send $LOTTERY_CONTRACT \
    "claimPrize(uint256)" $LOTTERY_ID \
    --private-key $CLIENT_PRIVATE_KEY \
    --rpc-url $RPC_URL)

if [$(echo "$RESULT" | grep "status" | awk '{print $2}') -eq 1]; then 
    echo "Congratulations: You have won!!!!!"
else
    echo "Sorry, try again"
fi