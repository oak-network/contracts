// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./interfaces/IGlobalParams.sol";

/**
 * @title GlobalParams
 * @notice Manages global parameters and platform information.
 */
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
    mapping(bytes32 => bytes32) private s_platformDataOwner;
    mapping(bytes32 => bool) private s_platformData;

    Counters.Counter private s_numberOfListedPlatforms;

    /**
     * @dev Emitted when a platform is enlisted.
     * @param platformBytes The identifier of the enlisted platform.
     * @param platformAdminAddress The admin address of the enlisted platform.
     * @param platformFeePercent The fee percentage of the enlisted platform.
     */
    event PlatformEnlisted(
        bytes32 indexed platformBytes,
        address indexed platformAdminAddress,
        uint256 platformFeePercent
    );

    /**
     * @dev Emitted when a platform is delisted.
     * @param platformBytes The identifier of the delisted platform.
     */
    event PlatformDelisted(bytes32 indexed platformBytes);

    /**
     * @dev Emitted when the protocol admin address is updated.
     * @param newAdminAddress The new protocol admin address.
     */
    event ProtocolAdminAddressUpdated(address indexed newAdminAddress);

    /**
     * @dev Emitted when the token address is updated.
     * @param newTokenAddress The new token address.
     */
    event TokenAddressUpdated(address indexed newTokenAddress);

    /**
     * @dev Emitted when the protocol fee percent is updated.
     * @param newFeePercent The new protocol fee percentage.
     */
    event ProtocolFeePercentUpdated(uint256 newFeePercent);

    /**
     * @dev Emitted when the platform admin address is updated.
     * @param platformBytes The identifier of the platform.
     * @param newAdminAddress The new admin address of the platform.
     */
    event PlatformAdminAddressUpdated(
        bytes32 indexed platformBytes,
        address indexed newAdminAddress
    );

    /**
     * @dev Emitted when platform data is added.
     * @param platformBytes The identifier of the platform.
     * @param platformDataKey The data key added to the platform.
     */
    event PlatformDataAdded(
        bytes32 indexed platformBytes,
        bytes32 indexed platformDataKey
    );

    /**
     * @dev Emitted when platform data is removed.
     * @param platformBytes The identifier of the platform.
     * @param platformDataKey The data key removed from the platform.
     */
    event PlatformDataRemoved(
        bytes32 indexed platformBytes,
        bytes32 platformDataKey
    );

    /**
     * @dev Throws when the input address is zero.
     */
    error GlobalParamsInvalidInput();

    /**
     * @dev Throws when the platform is not listed.
     * @param platformBytes The identifier of the platform.
     * @param platformAdminAddress The admin address of the platform.
     */
    error GlobalParamsPlatformNotListed(
        bytes32 platformBytes,
        address platformAdminAddress
    );

    /**
     * @dev Throws when the platform is already listed.
     * @param platformBytes The identifier of the platform.
     */
    error GlobalParamsPlatformAlreadyListed(bytes32 platformBytes);

    /**
     * @dev Throws when the platform admin is not set.
     * @param platformBytes The identifier of the platform.
     */
    error GlobalParamsPlatformAdminNotSet(bytes32 platformBytes);

    /**
     * @dev Throws when the platform fee percent is zero.
     * @param platformBytes The identifier of the platform.
     */
    error GlobalParamsPlatformFeePercentIsZero(bytes32 platformBytes);

    /**
     * @dev Throws when the platform data is already set.
     */
    error GlobalParamsPlatformDataAlreadySet();

    /**
     * @dev Throws when the platform data is not set.
     */
    error GlobalParamsPlatformDataNotSet();

    /**
     * @dev Throws when the platform data slot is already taken.
     */
    error GlobalParamsPlatformDataSlotTaken();

    /**
     * @dev Throws when the caller is not authorized.
     */
    error GlobalParamsUnauthorized();

    /**
     * @dev Reverts if the input address is zero.
     */
    modifier notAddressZero(address account) {
        _checkIfAddressZero(account);
        _;
    }

    /**
     * @dev Modifier that restricts function access to platform administrators of a specific platform.
     * Users attempting to execute functions with this modifier must be the platform admin for the given platform.
     * @param platformBytes The unique identifier of the platform.
     */
    modifier onlyPlatformAdmin(bytes32 platformBytes) {
        _checkIfPlatformAdmin(platformBytes);
        _;
    }

    /**
     * @param protocolAdminAddress The address of the protocol admin.
     * @param tokenAddress The address of the token contract.
     * @param protocolFeePercent The protocol fee percentage.
     */
    constructor(
        address protocolAdminAddress,
        address tokenAddress,
        uint256 protocolFeePercent
    ) {
        s_protocolAdminAddress = protocolAdminAddress;
        s_tokenAddress = tokenAddress;
        s_protocolFeePercent = protocolFeePercent;
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function checkIfplatformIsListed(
        bytes32 platformBytes
    ) external view override returns (bool) {
        return s_platformIsListed[platformBytes];
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function getPlatformAdminAddress(
        bytes32 platformBytes
    ) external view override returns (address account) {
        account = s_platformAdminAddress[platformBytes];
        if (account == address(0)) {
            revert GlobalParamsPlatformAdminNotSet(platformBytes);
        }
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function getNumberOfListedPlatforms()
        external
        view
        override
        returns (uint256)
    {
        return s_numberOfListedPlatforms.current();
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function getProtocolAdminAddress()
        external
        view
        override
        returns (address)
    {
        return s_protocolAdminAddress;
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function getTokenAddress() external view override returns (address) {
        return s_tokenAddress;
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function getProtocolFeePercent() external view override returns (uint256) {
        return s_protocolFeePercent;
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function getPlatformFeePercent(
        bytes32 platformBytes
    ) external view override returns (uint256 platformFeePercent) {
        platformFeePercent = s_platformFeePercent[platformBytes];
        if (platformFeePercent == 0) {
            revert GlobalParamsPlatformFeePercentIsZero(platformBytes);
        }
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function getPlatformDataOwner(
        bytes32 platformDataKey
    ) external view override returns (bytes32 platformBytes) {
        platformBytes = s_platformDataOwner[platformDataKey];
        if (platformBytes == ZERO_BYTES) {
            revert GlobalParamsInvalidInput();
        }
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function checkIfPlatformDataKeyValid(
        bytes32 platformDataKey
    ) external view override returns (bool isValid) {
        isValid = s_platformData[platformDataKey];
    }

    /**
     * @notice Enlists a platform with its admin address and fee percentage.
     * @param platformBytes The platform's identifier.
     * @param platformAdminAddress The platform's admin address.
     * @param platformFeePercent The platform's fee percentage.
     */
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

    /**
     * @notice Delists a platform.
     * @param platformBytes The platform's identifier.
     */
    function delistPlatform(bytes32 platformBytes) external onlyOwner {
        if (!s_platformIsListed[platformBytes]) {
            revert GlobalParamsPlatformNotListed(platformBytes, address(0));
        }
        s_platformIsListed[platformBytes] = false;
        s_platformAdminAddress[platformBytes] = address(0);
        s_platformFeePercent[platformBytes] = 0;
        s_numberOfListedPlatforms.decrement();
        emit PlatformDelisted(platformBytes);
    }

    /**
     * @notice Adds platform-specific data key.
     * @param platformBytes The platform's identifier.
     * @param platformDataKey The platform data key.
     */
    function addPlatformData(
        bytes32 platformBytes,
        bytes32 platformDataKey
    ) external onlyPlatformAdmin(platformBytes) {
        if (platformDataKey == ZERO_BYTES) {
            revert GlobalParamsInvalidInput();
        }
        if (s_platformData[platformDataKey] != false) {
            revert GlobalParamsPlatformDataAlreadySet();
        }
        if (s_platformDataOwner[platformDataKey] == platformBytes) {
            revert GlobalParamsPlatformDataSlotTaken();
        }
        s_platformData[platformDataKey] = true;
        s_platformDataOwner[platformDataKey] = platformBytes;
        emit PlatformDataAdded(platformBytes, platformDataKey);
    }

    /**
     * @notice Removes platform-specific data key.
     * @param platformBytes The platform's identifier.
     * @param platformDataKey The platform data key.
     */
    function removePlatformData(
        bytes32 platformBytes,
        bytes32 platformDataKey
    ) external onlyPlatformAdmin(platformBytes) {
        if (platformDataKey == ZERO_BYTES) {
            revert GlobalParamsInvalidInput();
        }
        if (s_platformData[platformDataKey] == false) {
            revert GlobalParamsPlatformDataNotSet();
        }
        s_platformData[platformDataKey] = false;
        s_platformDataOwner[platformDataKey] = ZERO_BYTES;
        emit PlatformDataRemoved(platformBytes, platformDataKey);
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function updateProtocolAdminAddress(
        address protocolAdminAddress
    ) external override onlyOwner notAddressZero(protocolAdminAddress) {
        s_protocolAdminAddress = protocolAdminAddress;
        emit ProtocolAdminAddressUpdated(protocolAdminAddress);
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function updateTokenAddress(
        address tokenAddress
    ) external override onlyOwner notAddressZero(tokenAddress) {
        s_tokenAddress = tokenAddress;
        emit TokenAddressUpdated(tokenAddress);
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function updateProtocolFeePercent(
        uint256 protocolFeePercent
    ) external override onlyOwner {
        s_protocolFeePercent = protocolFeePercent;
        emit ProtocolFeePercentUpdated(protocolFeePercent);
    }

    /**
     * @inheritdoc IGlobalParams
     */
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

    /**
     * @dev Reverts if the input address is zero.
     */
    function _checkIfAddressZero(address account) internal pure {
        if (account == address(0)) {
            revert GlobalParamsInvalidInput();
        }
    }

    /**
     * @dev Internal function to check if the sender is the platform administrator for a specific platform.
     * If the sender is not the platform admin, it reverts with AdminAccessCheckerUnauthorized error.
     * @param platformBytes The unique identifier of the platform.
     */
    function _checkIfPlatformAdmin(bytes32 platformBytes) private view {
        if (msg.sender != s_platformAdminAddress[platformBytes]) {
            revert GlobalParamsUnauthorized();
        }
    }
}
