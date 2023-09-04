// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./MinimumOrder.sol";

contract OutOfStock is MinimumOrder {
    
    error OutOfStockLimitReached();
    
    constructor(
        bytes32 platformBytes,
        address infoAddress
    ) MinimumOrder(platformBytes, infoAddress) {}

    function PreOrderForAReward(
        address backer,
        bytes32 rewardName
    )
        public override
    {
        if (MinimumOrder.getNumberOfOrders() + 1 > SUCCESS_METRIC) {
            revert OutOfStockLimitReached();
        }
        MinimumOrder.PreOrderForAReward(backer, rewardName);
    }

}
