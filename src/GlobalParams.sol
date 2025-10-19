// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IGlobalParams} from "./interfaces/IGlobalParams.sol";
import {Counters} from "./utils/Counters.sol";
import {GlobalParamsStorage} from "./storage/GlobalParamsStorage.sol";

/**
 * @title GlobalParams
 * @notice Manages global parameters and platform information.
 * @dev UUPS Upgradeable contract with ERC-7201 namespaced storage
 */
contract GlobalParams is Initializable, IGlobalParams, OwnableUpgradeable, UUPSUpgradeable {
    using Counters for Counters.Counter;

    bytes32 private constant ZERO_BYTES =
        0x0000000000000000000000000000000000000000000000000000000000000000;

    /**
     * @dev Emitted when a platform is enlisted.
     * @param platformHash The identifier of the enlisted platform.
     * @param platformAdminAddress The admin address of the enlisted platform.
     * @param platformFeePercent The fee percentage of the enlisted platform.
     */
    event PlatformEnlisted(
        bytes32 indexed platformHash,
        address indexed platformAdminAddress,
        uint256 platformFeePercent
    );

    /**
     * @dev Emitted when a platform is delisted.
     * @param platformHash The identifier of the delisted platform.
     */
    event PlatformDelisted(bytes32 indexed platformHash);

    /**
     * @dev Emitted when the protocol admin address is updated.
     * @param newAdminAddress The new protocol admin address.
     */
    event ProtocolAdminAddressUpdated(address indexed newAdminAddress);

    /**
     * @dev Emitted when a token is added to a currency.
     * @param currency The currency identifier.
     * @param token The token address added.
     */
    event TokenAddedToCurrency(bytes32 indexed currency, address indexed token);

    /**
     * @dev Emitted when a token is removed from a currency.
     * @param currency The currency identifier.
     * @param token The token address removed.
     */
    event TokenRemovedFromCurrency(bytes32 indexed currency, address indexed token);

    /**
     * @dev Emitted when the protocol fee percent is updated.
     * @param newFeePercent The new protocol fee percentage.
     */
    event ProtocolFeePercentUpdated(uint256 newFeePercent);

    /**
     * @dev Emitted when the platform admin address is updated.
     * @param platformHash The identifier of the platform.
     * @param newAdminAddress The new admin address of the platform.
     */
    event PlatformAdminAddressUpdated(
        bytes32 indexed platformHash,
        address indexed newAdminAddress
    );

    /**
     * @dev Emitted when platform data is added.
     * @param platformHash The identifier of the platform.
     * @param platformDataKey The data key added to the platform.
     */
    event PlatformDataAdded(
        bytes32 indexed platformHash,
        bytes32 indexed platformDataKey
    );

    /**
     * @dev Emitted when platform data is removed.
     * @param platformHash The identifier of the platform.
     * @param platformDataKey The data key removed from the platform.
     */
    event PlatformDataRemoved(
        bytes32 indexed platformHash,
        bytes32 platformDataKey
    );

    /** 
     * @dev Emitted when data is added to the registry.
    * @param key The registry key.
    * @param value The registry value.
    */
    event DataAddedToRegistry(bytes32 indexed key, bytes32 value);

    /**
     * @dev Throws when the input address is zero.
     */
    error GlobalParamsInvalidInput();

    /**
     * @dev Throws when the platform is not listed.
     * @param platformHash The identifier of the platform.
     */
    error GlobalParamsPlatformNotListed(bytes32 platformHash);

    /**
     * @dev Throws when the platform is already listed.
     * @param platformHash The identifier of the platform.
     */
    error GlobalParamsPlatformAlreadyListed(bytes32 platformHash);

    /**
     * @dev Throws when the platform admin is not set.
     * @param platformHash The identifier of the platform.
     */
    error GlobalParamsPlatformAdminNotSet(bytes32 platformHash);

    /**
     * @dev Throws when the platform fee percent is zero.
     * @param platformHash The identifier of the platform.
     */
    error GlobalParamsPlatformFeePercentIsZero(bytes32 platformHash);

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
     * @dev Throws when currency and token arrays length mismatch.
     */
    error GlobalParamsCurrencyTokenLengthMismatch();


    /**
     * @dev Throws when a currency has no tokens registered.
     * @param currency The currency identifier.
     */
    error GlobalParamsCurrencyHasNoTokens(bytes32 currency);

    /**
     * @dev Throws when a token is not found in a currency.
     * @param currency The currency identifier.
     * @param token The token address.
     */
    error GlobalParamsTokenNotInCurrency(bytes32 currency, address token);
    
    /**
     * @dev Reverts if the input address is zero.
     */
    modifier notAddressZero(address account) {
        _revertIfAddressZero(account);
        _;
    }

    /**
     * @dev Modifier that restricts function access to platform administrators of a specific platform.
     * Users attempting to execute functions with this modifier must be the platform admin for the given platform.
     * @param platformHash The unique identifier of the platform.
     */
    modifier onlyPlatformAdmin(bytes32 platformHash) {
        _onlyPlatformAdmin(platformHash);
        _;
    }

    modifier platformIsListed(bytes32 platformHash) {
        if (!checkIfPlatformIsListed(platformHash)) {
            revert GlobalParamsPlatformNotListed(platformHash);
        }
        _;
    }

    /**
     * @dev Constructor that disables initializers to prevent implementation contract initialization
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializer function (replaces constructor)
     * @param protocolAdminAddress The address of the protocol admin.
     * @param protocolFeePercent The protocol fee percentage.
     * @param currencies The array of currency identifiers.
     * @param tokensPerCurrency The array of token arrays for each currency.
     */
    function initialize(
        address protocolAdminAddress,
        uint256 protocolFeePercent,
        bytes32[] memory currencies,
        address[][] memory tokensPerCurrency
    ) public initializer {
        __Ownable_init(protocolAdminAddress);
        __UUPSUpgradeable_init();

        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        $.protocolAdminAddress = protocolAdminAddress;
        $.protocolFeePercent = protocolFeePercent;
        
        uint256 currencyLength = currencies.length;

        if(currencyLength != tokensPerCurrency.length) {
            revert GlobalParamsCurrencyTokenLengthMismatch();
        }
        
        for (uint256 i = 0; i < currencyLength; ) {
            for (uint256 j = 0; j < tokensPerCurrency[i].length; ) {
                address token = tokensPerCurrency[i][j];
                if (token == address(0)) {
                    revert GlobalParamsInvalidInput();
                }
                $.currencyToTokens[currencies[i]].push(token);
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Function that authorizes an upgrade to a new implementation
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
    * @notice Adds a key-value pair to the data registry.
    * @param key The registry key.
    * @param value The registry value.
    */
    function addToRegistry(
        bytes32 key,
        bytes32 value
    ) external onlyOwner {
        if (key == ZERO_BYTES) {
            revert GlobalParamsInvalidInput();
        }
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        $.dataRegistry[key] = value;
        emit DataAddedToRegistry(key, value);
    }

    /**
    * @notice Retrieves a value from the data registry.
    * @param key The registry key.
    * @return value The registry value.
    */
    function getFromRegistry(
        bytes32 key
    ) external view returns (bytes32 value) {
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        value = $.dataRegistry[key];
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function getPlatformAdminAddress(
        bytes32 platformHash
    )
        external
        view
        override
        platformIsListed(platformHash)
        returns (address account)
    {
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        account = $.platformAdminAddress[platformHash];
        if (account == address(0)) {
            revert GlobalParamsPlatformAdminNotSet(platformHash);
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
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        return $.numberOfListedPlatforms.current();
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
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        return $.protocolAdminAddress;
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function getProtocolFeePercent() external view override returns (uint256) {
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        return $.protocolFeePercent;
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function getPlatformFeePercent(
        bytes32 platformHash
    )
        external
        view
        override
        platformIsListed(platformHash)
        returns (uint256 platformFeePercent)
    {
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        platformFeePercent = $.platformFeePercent[platformHash];
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function getPlatformDataOwner(
        bytes32 platformDataKey
    ) external view override returns (bytes32 platformHash) {
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        platformHash = $.platformDataOwner[platformDataKey];
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function checkIfPlatformIsListed(
        bytes32 platformHash
    ) public view override returns (bool) {
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        return $.platformIsListed[platformHash];
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function checkIfPlatformDataKeyValid(
        bytes32 platformDataKey
    ) external view override returns (bool isValid) {
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        isValid = $.platformData[platformDataKey];
    }

    /**
     * @notice Enlists a platform with its admin address and fee percentage.
     * @dev The platformFeePercent can be any value including zero.
     * @param platformHash The platform's identifier.
     * @param platformAdminAddress The platform's admin address.
     * @param platformFeePercent The platform's fee percentage.
     */
    function enlistPlatform(
        bytes32 platformHash,
        address platformAdminAddress,
        uint256 platformFeePercent
    ) external onlyOwner notAddressZero(platformAdminAddress) {
        if (platformHash == ZERO_BYTES) {
            revert GlobalParamsInvalidInput();
        }
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        if ($.platformIsListed[platformHash]) {
            revert GlobalParamsPlatformAlreadyListed(platformHash);
        } else {
            $.platformIsListed[platformHash] = true;
            $.platformAdminAddress[platformHash] = platformAdminAddress;
            $.platformFeePercent[platformHash] = platformFeePercent;
            $.numberOfListedPlatforms.increment();
            emit PlatformEnlisted(
                platformHash,
                platformAdminAddress,
                platformFeePercent
            );
        }
    }

    /**
     * @notice Delists a platform.
     * @param platformHash The platform's identifier.
     */
    function delistPlatform(
        bytes32 platformHash
    ) external onlyOwner platformIsListed(platformHash) {
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        $.platformIsListed[platformHash] = false;
        $.platformAdminAddress[platformHash] = address(0);
        $.platformFeePercent[platformHash] = 0;
        $.numberOfListedPlatforms.decrement();
        emit PlatformDelisted(platformHash);
    }

    /**
     * @notice Adds platform-specific data key.
     * @param platformHash The platform's identifier.
     * @param platformDataKey The platform data key.
     */
    function addPlatformData(
        bytes32 platformHash,
        bytes32 platformDataKey
    ) external platformIsListed(platformHash) onlyPlatformAdmin(platformHash) {
        if (platformDataKey == ZERO_BYTES) {
            revert GlobalParamsInvalidInput();
        }
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        if ($.platformData[platformDataKey]) {
            revert GlobalParamsPlatformDataAlreadySet();
        }
        $.platformData[platformDataKey] = true;
        $.platformDataOwner[platformDataKey] = platformHash;
        emit PlatformDataAdded(platformHash, platformDataKey);
    }

    /**
     * @notice Removes platform-specific data key.
     * @param platformHash The platform's identifier.
     * @param platformDataKey The platform data key.
     */
    function removePlatformData(
        bytes32 platformHash,
        bytes32 platformDataKey
    ) external platformIsListed(platformHash) onlyPlatformAdmin(platformHash) {
        if (platformDataKey == ZERO_BYTES) {
            revert GlobalParamsInvalidInput();
        }
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        if (!$.platformData[platformDataKey]) {
            revert GlobalParamsPlatformDataNotSet();
        }
        $.platformData[platformDataKey] = false;
        $.platformDataOwner[platformDataKey] = ZERO_BYTES;
        emit PlatformDataRemoved(platformHash, platformDataKey);
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function updateProtocolAdminAddress(
        address protocolAdminAddress
    ) external override onlyOwner notAddressZero(protocolAdminAddress) {
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        $.protocolAdminAddress = protocolAdminAddress;
        emit ProtocolAdminAddressUpdated(protocolAdminAddress);
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function updateProtocolFeePercent(
        uint256 protocolFeePercent
    ) external override onlyOwner {
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        $.protocolFeePercent = protocolFeePercent;
        emit ProtocolFeePercentUpdated(protocolFeePercent);
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function updatePlatformAdminAddress(
        bytes32 platformHash,
        address platformAdminAddress
    )
        external
        override
        onlyOwner
        platformIsListed(platformHash)
        notAddressZero(platformAdminAddress)
    {
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        $.platformAdminAddress[platformHash] = platformAdminAddress;
        emit PlatformAdminAddressUpdated(platformHash, platformAdminAddress);
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function addTokenToCurrency(
        bytes32 currency,
        address token
    ) external override onlyOwner notAddressZero(token) {
        if (currency == ZERO_BYTES) {
            revert GlobalParamsInvalidInput();
        }
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        $.currencyToTokens[currency].push(token);
        emit TokenAddedToCurrency(currency, token);
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function removeTokenFromCurrency(
        bytes32 currency,
        address token
    ) external override onlyOwner notAddressZero(token) {
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        address[] storage tokens = $.currencyToTokens[currency];
        uint256 length = tokens.length;
        bool found = false;
        
        for (uint256 i = 0; i < length; ) {
            if (tokens[i] == token) {
                tokens[i] = tokens[length - 1];
                tokens.pop();
                found = true;
                break;
            }
            unchecked { ++i; }
        }
        
        if (!found) {
            revert GlobalParamsTokenNotInCurrency(currency, token);
        }
        emit TokenRemovedFromCurrency(currency, token);
    }

    /**
     * @inheritdoc IGlobalParams
     */
    function getTokensForCurrency(
        bytes32 currency
    ) external view override returns (address[] memory) {
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        return $.currencyToTokens[currency];
    }

    /**
     * @dev Reverts if the input address is zero.
     */
    function _revertIfAddressZero(address account) internal pure {
        if (account == address(0)) {
            revert GlobalParamsInvalidInput();
        }
    }

    /**
     * @dev Internal function to check if the sender is the platform administrator for a specific platform.
     * If the sender is not the platform admin, it reverts with AdminAccessCheckerUnauthorized error.
     * @param platformHash The unique identifier of the platform.
     */
    function _onlyPlatformAdmin(bytes32 platformHash) private view {
        GlobalParamsStorage.Storage storage $ = GlobalParamsStorage._getGlobalParamsStorage();
        if (_msgSender() != $.platformAdminAddress[platformHash]) {
            revert GlobalParamsUnauthorized();
        }
    }
}
