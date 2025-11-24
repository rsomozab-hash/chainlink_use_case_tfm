#!/bin/bash
source .env
##.env must include the following variables.
# PRIVATE_KEY=<WALLET ADDRESS> The owner address private key
# RPC_URL=https://sepolia.infura.io/v3/b4ac5baaeb9a46f38d69c96513e521a9
# SEPOLIA_LINK_TOKEN=0x779877A7B0D9E8603169DdbD7836e478b4624789
# DIRECT_FUNDING_CONTRACT=<CONTRACT ADDRESS> deployed Direct Funding Consumer.sol contract
# First we fund our contract from our Sepolia Account with LINKs should it be underfunded

BALANCE=$(cast call $SEPOLIA_LINK_TOKEN \
    "balanceOf(address)(uint256)" $DIRECT_FUNDING_CONTRACT \
    --rpc-url $RPC_URL | awk '{print $1}')
##We check that there is enough link
if [ "$BALANCE" -lt 100000000000000000 ]; then
    cast send $SEPOLIA_LINK_TOKEN \
            "approve(address,uint256)" $DIRECT_FUNDING_CONTRACT 200000000000000000 \
            --rpc-url $RPC_URL --private-key $PRIVATE_KEY

    cast send $DIRECT_FUNDING_CONTRACT\
            "fundWithLink(uint256)" 200000000000000000 \
            --rpc-url $RPC_URL --private-key $PRIVATE_KEY
fi


##We Request the Random Number
cast send $DIRECT_FUNDING_CONTRACT \
    "requestRandomWords(bool)" false \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL 

REQUEST_ID=$(cast call $DIRECT_FUNDING_CONTRACT "lastRequestId()" --rpc-url $RPC_URL)

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

echo "Request Fulfilled"

RESULT=$(cast call $DIRECT_FUNDING_CONTRACT "getRandomInRange(uint256, uint256, uint256)" $REQUEST_ID 0 100 \
                        --rpc-url $RPC_URL | cast to-dec)

echo "The resulting Random Number is $RESULT"
