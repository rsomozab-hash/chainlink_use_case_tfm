cast send 0x779877A7B0D9E8603169DdbD7836e478b4624789 \
        "approve(address,uint256)" 0x33d2344Dd244297Bc6b76c467de9f430D1DB0658 200000000000000000\
        --rpc-url $RPC_URL --private-key $PRIVATE_KEY

cast send 0x33d2344Dd244297Bc6b76c467de9f430D1DB0658\
        "fundWithLink(uint256)" 200000000000000000\
        --rpc-url $RPC_URL --private-key $PRIVATE_KEY



cast call 0x779877A7B0D9E8603169DdbD7836e478b4624789 \
    "balanceOf(address)(uint256)" 0x33d2344Dd244297Bc6b76c467de9f430D1DB0658 \
    --rpc-url $RPC_URL

cast send 0x33d2344Dd244297Bc6b76c467de9f430D1DB0658 \
    "approveLink(uint256)" \
    200000000000000000000 \
    --rpc-url $RPC_URL --private-key $PRIVATE_KEY

cast call 0x779877A7B0D9E8603169DdbD7836e478b4624789 \
    "allowance(address,address)" \
    0x33d2344Dd244297Bc6b76c467de9f430D1DB0658 \
    0x78ea207D5f7dAB6E369C28f715620aa21e9B0A6C \
    --rpc-url $RPC_URL

cast send 0x33d2344Dd244297Bc6b76c467de9f430D1DB0658 \
    "requestRandomNumber()(uint256)" \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL --gas-limit 100000

