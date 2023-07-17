// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICampaignTreasury {
    
    function getplatformId() external view returns (bytes32);

    function getplatformFeePercent() external view returns (uint256);

    function getplatformFee() external view returns (uint256);

    // function getTotalCollectableByCreator() external view returns (uint256);

    function raisedBalance() external view returns (uint256);

    function currentBalance() external view returns (uint256);

    // function getPledgedAmount() external view returns (uint256);

    // function pledgeInFiat(uint256 amount) external;

    // function setplatformFeePercent(uint256 _platformFeePercent) external;

    // function setPledgedAmount(uint256 _pledgedAmount) external;

    // function disburseFeeToPlatform(
    //     address _platform,
    //     address _token,
    //     uint256 _amount
    // ) external;
}
