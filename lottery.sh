#!/bin/bash
source .env

BALANCE=$(cast call $SEPOLIA_LINK_TOKEN \
    "balanceOf(address)(uint256)" $DIRECT_FUNDING_CONTRACT \
    --rpc-url $RPC_URL | awk '{print $1}')
##We authorize the lottery contract to access the 
cast send $DIRECT_FUNDING_CONTRACT "addAuthorized(address)" $LOTTERY_CONTRACT --rpc-url $RPC_URL --private-key $PRIVATE_KEY

##We check that there is enough link
if [ "$BALANCE" -lt 100000000000000000 ]; then
    cast send $SEPOLIA_LINK_TOKEN \
            "approve(address,uint256)" $DIRECT_FUNDING_CONTRACT 200000000000000000 \
            --rpc-url $RPC_URL --private-key $PRIVATE_KEY

    cast send $DIRECT_FUNDING_CONTRACT\
            "fundWithLink(uint256)" 200000000000000000 \
            --rpc-url $RPC_URL --private-key $PRIVATE_KEY
fi
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
    sleep 5
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

echo "AND THE WINNER NUMBER IS .... $WINNER!"

cast send $LOTTERY_CONTRACT \
    "claimPrize(uint256)" $LOTTERY_ID \
    --private-key $CLIENT_PRIVATE_KEY \
    --rpc-url $RPC_URL