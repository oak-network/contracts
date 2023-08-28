// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

abstract contract TimestampChecker {

    error CurrentTimeIsGreater(uint256 inputTime, uint256 currentTime);
    error CurrentTimeIsLess(uint256 inputTime, uint256 currentTime);

    modifier currentTimeIsGreater(uint256 inputTime) {
        _checkIfCurrentTimeIsGreater(inputTime);
        _;
    }

    modifier currentTimeIsLess(uint256 inputTime) {
        _checkIfCurrentTimeIsLess(inputTime);
        _;
    }

    function _checkIfCurrentTimeIsGreater(uint256 inputTime) internal view virtual {
        uint256 currentTime = block.timestamp;
        if (currentTime > inputTime) {
            revert CurrentTimeIsGreater(inputTime, currentTime);
        }
    }

    function _checkIfCurrentTimeIsLess(uint256 inputTime) internal view virtual {
        uint256 currentTime = block.timestamp;
        if (currentTime < inputTime) {
            revert CurrentTimeIsLess(inputTime, currentTime);
        }
    }
}
    