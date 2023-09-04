// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./CampaignInfo.sol";
import "./interfaces/IGlobalParams.sol";
import "./interfaces/ICampaignInfo.sol";
import "./utils/AddressCalculator.sol";

contract TreasuryFactory {
    mapping(bytes32 => mapping(uint256 => bytes)) private s_platformByteCode;
    mapping(bytes => bool) private s_approvedByteCode;

    IGlobalParams private immutable GLOBAL_PARAMS;
    address private immutable CAMPAIGN_INFO_FACTORY;
    bytes32 private immutable CAMPAIGNINFO_BYTECODEHASH;

    error TreasuryFactoryUnauthorized();
    error TreasuryFactoryInvalidKey();
    error TreasuryFactoryByteCodeAlreadyApproved();
    error TreasuryFactoryByteCodeNotApproved();
    error TreasuryFactoryTreasuryCreationFailed();
    error TreasuryFactoryInvalidAddress();

    constructor(
        address globalParams,
        address infoFactory,
        bytes32 bytecodeHash
    ) {
        GLOBAL_PARAMS = IGlobalParams(globalParams);
        CAMPAIGN_INFO_FACTORY = infoFactory;
        CAMPAIGNINFO_BYTECODEHASH = bytecodeHash;
    }

    modifier onlyPlatformAdmin(bytes32 platformBytes) {
        _checkIfPlatformAdmin(platformBytes);
        _;
    }

    modifier onlyProtocolAdmin() {
        _checkIfProtocolAdmin();
        _;
    }

    function computeTreasuryAddress(
        bytes32 identifierHash,
        bytes32 platformBytes,
        uint256 bytecodeIndex
    ) external view returns (address treasuryAddress, bool isDeployed) {
        (treasuryAddress, isDeployed) = AddressCalculator.computeAddress(
            keccak256(abi.encodePacked(identifierHash, platformBytes)),
            keccak256(s_platformByteCode[platformBytes][bytecodeIndex]),
            address(this)
        );
    }

    function addByteCode(
        bytes32 platformBytes,
        uint256 bytecodeIndex,
        bytes calldata bytecode
    ) external onlyPlatformAdmin(platformBytes) {
        s_platformByteCode[platformBytes][bytecodeIndex] = bytecode;
    }

    function enlistByteCode(
        bytes32 platformBytes,
        uint256 bytecodeIndex
    ) external onlyProtocolAdmin {
        bytes memory bytecode = s_platformByteCode[platformBytes][
            bytecodeIndex
        ];
        if (bytecode.length == 0) {
            revert TreasuryFactoryInvalidKey();
        }
        if (s_approvedByteCode[bytecode]) {
            revert TreasuryFactoryByteCodeAlreadyApproved();
        }
        s_approvedByteCode[bytecode] = true;
    }

    function delistByteCode(
        bytes32 platformBytes,
        uint256 bytecodeIndex
    ) external onlyProtocolAdmin {
        bytes storage bytecode = s_platformByteCode[platformBytes][
            bytecodeIndex
        ];
        if (bytecode.length == 0) {
            revert TreasuryFactoryInvalidKey();
        }
        s_approvedByteCode[bytecode] = false;
        delete s_platformByteCode[platformBytes][bytecodeIndex];
    }

    function deploy(
        bytes32 platformBytes,
        uint256 bytecodeIndex,
        bytes32 identifierHash
    ) external {
        bytes memory bytecode = s_platformByteCode[platformBytes][
            bytecodeIndex
        ];
        if (!s_approvedByteCode[bytecode]) {
            revert TreasuryFactoryByteCodeNotApproved();
        }
        (address infoAddress, bool isValid) = AddressCalculator.computeAddress(
            identifierHash,
            CAMPAIGNINFO_BYTECODEHASH,
            CAMPAIGN_INFO_FACTORY
        );
        if (!isValid && infoAddress == address(0)) {
            revert TreasuryFactoryInvalidAddress();
        }
        bytes memory argsByteCode = abi.encodePacked(
            bytecode,
            abi.encode(platformBytes, infoAddress)
        );
        bytes32 salt = keccak256(
            abi.encodePacked(identifierHash, platformBytes)
        );
        address treasury;
        assembly {
            treasury := create2(
                0,
                add(argsByteCode, 0x20),
                mload(argsByteCode),
                salt
            )
        }
        if (treasury == address(0)) {
            revert TreasuryFactoryTreasuryCreationFailed();
        } else {
            CampaignInfo(infoAddress).setPlatformInfo(platformBytes, treasury);
        }
    }

    function _checkIfPlatformAdmin(bytes32 platformBytes) private view {
        if (
            GLOBAL_PARAMS.getPlatformAdminAddress(platformBytes) != msg.sender
        ) {
            revert TreasuryFactoryUnauthorized();
        }
    }

    function _checkIfProtocolAdmin() private view {
        if (GLOBAL_PARAMS.getProtocolAdminAddress() != msg.sender) {
            revert TreasuryFactoryUnauthorized();
        }
    }
}
