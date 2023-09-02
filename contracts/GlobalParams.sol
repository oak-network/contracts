// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./interfaces/IGlobalParams.sol";

contract GlobalParams is IGlobalParams, Ownable, Pausable {
    using Counters for Counters.Counter;

    bytes32 private constant ZERO_BYTES =
        0x0000000000000000000000000000000000000000000000000000000000000000;
    address private s_protocolAdminAddress;
    address private s_tokenAddress;
    uint256 private s_protocolFeePercent;
    mapping(bytes32 => bool) private s_platformIsListed;
    mapping(bytes32 => address) private s_platformAdminAddress;
    mapping(bytes32 => uint256) private s_platformFeePercent;
    mapping(bytes32 => bytes32) private s_platformData;
    mapping(bytes32 => bytes32) private s_platformDataOwner;

    Counters.Counter private s_numberOfListedPlatforms;

    // Event emitted when a platform is enlisted
    event PlatformEnlisted(
        bytes32 indexed platformBytes,
        address indexed platformAdminAddress,
        uint256 platformFeePercent
    );

    // Event emitted when a platform is delisted
    event PlatformDelisted(bytes32 indexed platformBytes);

    // Event emitted when the protocol admin address is updated
    event ProtocolAdminAddressUpdated(address indexed newAdminAddress);

    // Event emitted when the token address is updated
    event TokenAddressUpdated(address indexed newTokenAddress);

    // Event emitted when the protocol fee percent is updated
    event ProtocolFeePercentUpdated(uint256 newFeePercent);

    // Event emitted when the platform admin address is updated
    event PlatformAdminAddressUpdated(
        bytes32 indexed platformBytes,
        address indexed newAdminAddress
    );
    event PlatformDataAdded(
        bytes32 indexed platformBytes,
        bytes32 indexed platformDataKey,
        bytes32 platformDataValue
    );
    event PlatformDataRemoved(
        bytes32 indexed platformBytes,
        bytes32 platformDataKey,
        bytes32 platformDataValue
    );

    error GlobalParamsInvalidInput();
    error GlobalParamsPlatformNotListed(
        bytes32 platformBytes,
        address platformAdminAddress
    );
    error GlobalParamsPlatformAlreadyListed(bytes32 platformBytes);
    error GlobalParamsPlatformAdminNotSet(bytes32 platformBytes);
    error GlobalParamesFeePercentIsZero(bytes32 platformBytes);
    error GlabalParamsPlatformDataAlreadySet();
    error GlabalParamsPlatformDataNotSet();

    constructor(
        address protocolAdminAddress,
        address tokenAddress,
        uint256 protocolFeePercent
    ) {
        s_protocolAdminAddress = protocolAdminAddress;
        s_tokenAddress = tokenAddress;
        s_protocolFeePercent = protocolFeePercent;
    }

    modifier notAddressZero(address account) {
        _checkIfAddressZero(account);
        _;
    }

    function checkIfplatformIsListed(
        bytes32 platformBytes
    ) external view override returns (bool) {
        if (s_platformIsListed[platformBytes]) {
            return true;
        } else return false;
    }

    function getPlatformAdminAddress(
        bytes32 platformBytes
    ) external view override returns (address account) {
        account = s_platformAdminAddress[platformBytes];
        if (account == address(0)) {
            revert GlobalParamsPlatformAdminNotSet(platformBytes);
        }
    }

    function getNumberOfListedPlatforms()
        external
        view
        override
        returns (uint256)
    {
        return s_numberOfListedPlatforms.current();
    }

    function getProtocolAdminAddress()
        external
        view
        override
        returns (address)
    {
        return s_protocolAdminAddress;
    }

    function getTokenAddress() external view override returns (address) {
        return s_tokenAddress;
    }

    function getProtocolFeePercent() external view override returns (uint256) {
        return s_protocolFeePercent;
    }

    function getPlatformFeePercent(
        bytes32 platformBytes
    ) external view override returns (uint256 platformFeePercent) {
        platformFeePercent = s_platformFeePercent[platformBytes];
        if (platformFeePercent == 0) {
            revert GlobalParamesFeePercentIsZero(platformBytes);
        }
    }

    function getPlatformData(
        bytes32 platformDataKey
    ) external view override returns (bytes32 platformDataValue) {
        platformDataValue = s_platformData[platformDataKey];
        if (platformDataValue == ZERO_BYTES) {
            revert GlobalParamsInvalidInput();
        }
    }

    function getPlatformDataOwner(
        bytes32 platformDataKey
    ) external view override returns (bytes32 platformBytes) {
        platformBytes = s_platformDataOwner[platformDataKey];
        if (platformBytes == ZERO_BYTES) {
            revert GlobalParamsInvalidInput();
        }
    }

    function _checkIfAddressZero(address account) internal pure {
        if (account == address(0)) {
            revert GlobalParamsInvalidInput();
        }
    }

    function enlistPlatform(
        bytes32 platformBytes,
        address platformAdminAddress,
        uint256 platformFeePercent
    ) external onlyOwner {
        if (s_platformIsListed[platformBytes]) {
            revert GlobalParamsPlatformAlreadyListed(platformBytes);
        } else {
            s_platformIsListed[platformBytes] = true;
            s_platformAdminAddress[platformBytes] = platformAdminAddress;
            s_platformFeePercent[platformBytes] = platformFeePercent;
            s_numberOfListedPlatforms.increment();
            emit PlatformEnlisted(
                platformBytes,
                platformAdminAddress,
                platformFeePercent
            );
        }
    }

    function delistPlatform(bytes32 platformBytes) external onlyOwner {
        if (s_platformIsListed[platformBytes]) {
            s_platformIsListed[platformBytes] = false;
            s_platformAdminAddress[platformBytes] = address(0);
            s_platformFeePercent[platformBytes] = 0;
            s_numberOfListedPlatforms.decrement();
            emit PlatformDelisted(platformBytes);
        } else {
            revert GlobalParamsPlatformNotListed(platformBytes, address(0));
        }
    }

    function addPlatformData(
        bytes32 platformBytes,
        bytes32 platformDataKey,
        bytes32 platformDataValue
    ) external {
        if (platformDataKey == ZERO_BYTES || platformDataValue == ZERO_BYTES) {
            revert GlobalParamsInvalidInput();
        }
        if (s_platformData[platformDataKey] != ZERO_BYTES) {
            revert GlabalParamsPlatformDataAlreadySet();
        }
        s_platformData[platformDataKey] = platformDataValue;
        s_platformDataOwner[platformDataKey] = platformBytes;
        emit PlatformDataAdded(
            platformBytes,
            platformDataKey,
            platformDataValue
        );
    }

    function removePlatformData(
        bytes32 platformBytes,
        bytes32 platformDataKey
    ) external {
        if (platformDataKey == ZERO_BYTES) {
            revert GlobalParamsInvalidInput();
        }
        if (s_platformData[platformDataKey] == ZERO_BYTES) {
            revert GlabalParamsPlatformDataNotSet();
        }
        s_platformData[platformDataKey] = ZERO_BYTES;
        s_platformDataOwner[platformDataKey] = ZERO_BYTES;
        emit PlatformDataRemoved(
            platformBytes,
            platformDataKey,
            s_platformData[platformDataKey]
        );
    }

    function updateProtocolAdminAddress(
        address protocolAdminAddress
    ) external override onlyOwner notAddressZero(protocolAdminAddress) {
        s_protocolAdminAddress = protocolAdminAddress;
        emit ProtocolAdminAddressUpdated(protocolAdminAddress);
    }

    function updateTokenAddress(
        address tokenAddress
    ) external override onlyOwner notAddressZero(tokenAddress) {
        s_tokenAddress = tokenAddress;
        emit TokenAddressUpdated(tokenAddress);
    }

    function updateProtocolFeePercent(
        uint256 protocolFeePercent
    ) external override onlyOwner {
        s_protocolFeePercent = protocolFeePercent;
        emit ProtocolFeePercentUpdated(protocolFeePercent);
    }

    function updatePlatformAdminAddress(
        bytes32 platformBytes,
        address platformAdminAddress
    ) external override onlyOwner notAddressZero(platformAdminAddress) {
        if (s_platformIsListed[platformBytes]) {
            s_platformAdminAddress[platformBytes] = platformAdminAddress;
            emit PlatformAdminAddressUpdated(
                platformBytes,
                platformAdminAddress
            );
        } else {
            revert GlobalParamsPlatformNotListed(
                platformBytes,
                platformAdminAddress
            );
        }
    }
}
