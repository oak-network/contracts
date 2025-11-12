// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title ICampaignInfo
 * @notice An interface for managing campaign information in a crowdfunding system.
 * @dev Inherits from IERC721 as CampaignInfo is an ERC721 NFT collection
 */
interface ICampaignInfo is IERC721 {
    /**
     * @notice Returns the owner of the contract.
     * @return The address of the contract owner.
     */
    function owner() external view returns (address);

    /**
     * @notice Checks if a platform has been selected for the campaign.
     * @param platformHash The bytes32 identifier of the platform to check.
     * @return True if the platform is selected, false otherwise.
     */
    function checkIfPlatformSelected(
        bytes32 platformHash
    ) external view returns (bool);

    /**
     * @notice Retrieves the total amount raised across non-cancelled treasuries.
     * @dev This excludes cancelled treasuries and is affected by refunds.
     * @return The total amount raised in the campaign.
     */
    function getTotalRaisedAmount() external view returns (uint256);

    /**
     * @notice Retrieves the total lifetime raised amount across all treasuries.
     * @dev This amount never decreases even when refunds are processed.
     *      It represents the sum of all pledges/payments ever made to the campaign,
     *      regardless of cancellations or refunds.
     * @return The total lifetime raised amount as a uint256 value.
     */
    function getTotalLifetimeRaisedAmount() external view returns (uint256);

    /**
     * @notice Retrieves the total refunded amount across all treasuries.
     * @dev This is calculated as the difference between lifetime raised amount
     *      and current raised amount. It represents the sum of all refunds
     *      that have been processed across all treasuries.
     * @return The total refunded amount as a uint256 value.
     */
    function getTotalRefundedAmount() external view returns (uint256);

    /**
     * @notice Retrieves the total available raised amount across all treasuries.
     * @dev This includes funds from both active and cancelled treasuries,
     *      and is affected by refunds. It represents the actual current
     *      balance of funds across all treasuries.
     * @return The total available raised amount as a uint256 value.
     */
    function getTotalAvailableRaisedAmount() external view returns (uint256);

    /**
     * @notice Retrieves the total raised amount from cancelled treasuries only.
     * @dev This is the opposite of getTotalRaisedAmount(), which only includes
     *      non-cancelled treasuries. This function only sums up raised amounts
     *      from treasuries that have been cancelled.
     * @return The total raised amount from cancelled treasuries as a uint256 value.
     */
    function getTotalCancelledAmount() external view returns (uint256);

    /**
     * @notice Retrieves the total expected (pending) amount across payment treasuries.
     * @dev This only applies to payment treasuries and represents payments that
     *      have been created but not yet confirmed. Regular treasuries are skipped.
     * @return The total expected amount as a uint256 value.
     */
    function getTotalExpectedAmount() external view returns (uint256);

    /**
     * @notice Retrieves the address of the protocol administrator.
     * @return The address of the protocol administrator.
     */
    function getProtocolAdminAddress() external view returns (address);

    /**
     * @notice Retrieves the address of the platform administrator for a specific platform.
     * @param platformHash The bytes32 identifier of the platform.
     * @return The address of the platform administrator.
     */
    function getPlatformAdminAddress(
        bytes32 platformHash
    ) external view returns (address);

    /**
     * @notice Retrieves the campaign's launch time.
     * @return The timestamp when the campaign was launched.
     */
    function getLaunchTime() external view returns (uint256);

    /**
     * @notice Retrieves the campaign's deadline.
     * @return The timestamp when the campaign ends.
     */
    function getDeadline() external view returns (uint256);

    /**
     * @notice Retrieves the campaign's funding goal amount.
     * @return The funding goal amount of the campaign.
     */
    function getGoalAmount() external view returns (uint256);

    /**
     * @notice Retrieves the protocol fee percentage for the campaign.
     * @return The protocol fee percentage applied to the campaign.
     */
    function getProtocolFeePercent() external view returns (uint256);

    /**
     * @notice Retrieves the campaign's currency identifier.
     * @return The bytes32 currency identifier for the campaign.
     */
    function getCampaignCurrency() external view returns (bytes32);

    /**
     * @notice Retrieves the cached accepted tokens for the campaign.
     * @return An array of token addresses accepted for the campaign.
     */
    function getAcceptedTokens() external view returns (address[] memory);

    /**
     * @notice Checks if a token is accepted for the campaign.
     * @param token The token address to check.
     * @return True if the token is accepted; otherwise, false.
     */
    function isTokenAccepted(address token) external view returns (bool);

    /**
     * @notice Retrieves the platform fee percentage for a specific platform.
     * @param platformHash The bytes32 identifier of the platform.
     * @return The platform fee percentage applied to the campaign on the platform.
     */
    function getPlatformFeePercent(
        bytes32 platformHash
    ) external view returns (uint256);

    /**
     * @notice Retrieves the claim delay (in seconds) configured for the given platform.
     * @param platformHash The identifier of the platform.
     * @return The claim delay in seconds.
     */
    function getPlatformClaimDelay(
        bytes32 platformHash
    ) external view returns (uint256);

    /**
     * @notice Retrieves platform-specific data for the campaign.
     * @param platformDataKey The bytes32 identifier of the platform-specific data.
     * @return The platform-specific data associated with the given key.
     */
    function getPlatformData(
        bytes32 platformDataKey
    ) external view returns (bytes32);

    /**
     * @notice Retrieves the unique identifier hash of the campaign.
     * @return The bytes32 hash that uniquely identifies the campaign.
     */
    function getIdentifierHash() external view returns (bytes32);

    /**
     * @notice Transfers ownership of the contract to a new owner.
     * @param newOwner The address of the new contract owner.
     */
    function transferOwnership(address newOwner) external;

    /**
     * @notice Updates the campaign's launch time.
     * @param launchTime The new launch timestamp.
     */
    function updateLaunchTime(uint256 launchTime) external;

    /**
     * @notice Updates the campaign's deadline.
     * @param deadline The new deadline timestamp.
     */
    function updateDeadline(uint256 deadline) external;

    /**
     * @notice Updates the campaign's funding goal amount.
     * @param goalAmount The new funding goal amount.
     */
    function updateGoalAmount(uint256 goalAmount) external;

    /**
     * @notice Updates the selection status of a platform for the campaign.
     * @dev It can only be called for a platform if its not approved i.e. the platform treasury is not deployed
     * @param platformHash The bytes32 identifier of the platform.
     * @param selection The new selection status (true or false).
     * @param platformDataKey An array of platform-specific data keys.
     * @param platformDataValue An array of platform-specific data values.
     */
    function updateSelectedPlatform(
        bytes32 platformHash,
        bool selection,
        bytes32[] calldata platformDataKey,
        bytes32[] calldata platformDataValue
    ) external;

    /**
     * @dev Returns true if the campaign is paused, and false otherwise.
     */
    function paused() external view returns (bool);

    /**
     * @dev Returns true if the campaign is cancelled, and false otherwise.
     */
    function cancelled() external view returns (bool);

    /**
     * @notice Retrieves a value from the GlobalParams data registry.
     * @param key The registry key.
     * @return value The registry value.
     */
    function getDataFromRegistry(bytes32 key) external view returns (bytes32 value);

    /**
     * @notice Retrieves the buffer time from the GlobalParams data registry.
     * @return bufferTime The buffer time value.
     */
    function getBufferTime() external view returns (uint256 bufferTime);

    /**
     * @notice Retrieves a platform-specific line item type configuration from GlobalParams.
     * @param platformHash The identifier of the platform.
     * @param typeId The identifier of the line item type.
     * @return exists Whether this line item type exists and is active.
     * @return label The label identifier for the line item type.
     * @return countsTowardGoal Whether this line item counts toward the campaign goal.
     * @return applyProtocolFee Whether this line item is included in protocol fee calculation.
     * @return canRefund Whether this line item can be refunded.
     * @return instantTransfer Whether this line item amount can be instantly transferred.
     */
    function getLineItemType(
        bytes32 platformHash,
        bytes32 typeId
    )
        external
        view
        returns (
            bool exists,
            string memory label,
            bool countsTowardGoal,
            bool applyProtocolFee,
            bool canRefund,
            bool instantTransfer
        );

    /**
     * @notice Mints a pledge NFT for a backer
     * @dev Can only be called by treasuries with MINTER_ROLE
     * @param backer The backer address
     * @param reward The reward identifier
     * @param tokenAddress The address of the token used for the pledge
     * @param amount The pledge amount
     * @param shippingFee The shipping fee
     * @param tipAmount The tip amount
     * @return tokenId The minted token ID (pledge ID)
     */
    function mintNFTForPledge(
        address backer,
        bytes32 reward,
        address tokenAddress,
        uint256 amount,
        uint256 shippingFee,
        uint256 tipAmount
    ) external returns (uint256 tokenId);

    /**
     * @notice Sets the image URI for NFT metadata
     * @param newImageURI The new image URI
     */
    function setImageURI(string calldata newImageURI) external;

    /**
     * @notice Updates the contract-level metadata URI
     * @param newContractURI The new contract URI
     */
    function updateContractURI(string calldata newContractURI) external;

    /**
     * @notice Burns a pledge NFT
     * @param tokenId The token ID to burn
     */
    function burn(uint256 tokenId) external;

    /**
     * @dev Returns true if the campaign is locked (after treasury deployment), and false otherwise.
     */
    function isLocked() external view returns (bool);
}
