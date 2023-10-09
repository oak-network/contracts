// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

struct Users {
    // Default owner for all contracts.
    address payable contractOwner;
    // Protocol Admin Address.
    address payable protocolAdminAddress;
    // Platform-1 Admin Address.
    address payable platform1AdminAddress;
    // Platform-2 Admin Address.
    address payable platform2AdminAddress;
    // Creator-1 Address.
    address payable creator1Address;
    // Creator-2 Address.
    address payable creator2Address;
    // Backer-1 Address.
    address payable backer1Address;
    // Backer-2 Address.
    address payable backer2Address;
}