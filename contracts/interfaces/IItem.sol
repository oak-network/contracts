// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IItem {

    struct Item {
        uint256 actualWeight;
        uint256 height;
        uint256 width;
        uint256 length;
        bytes32 category;
        bytes32 declaredCurrency;
    }
}