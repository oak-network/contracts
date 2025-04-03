// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract PledgeManager is Ownable {
    struct PendingPledge {
        uint256 amount;
        uint256 expiration;
        bool confirmed;
    }

    // Mapping to track pending pledges by backer address
    mapping(address => PendingPledge) private s_pendingPledges;

    // Mapping to track backers and their index in the backers array
    mapping(address => uint256) private s_backerIndex;

    // Total pledged amount
    uint256 public totalPledged;

    // Array to track backers
    address[] private backers;

    // Event emitted when a pledge is made
    event PledgeMade(
        address indexed backer,
        uint256 amount,
        uint256 expiration
    );

    // Event emitted when a pledge expires
    event PledgeExpired(address indexed backer, uint256 amount);

    // Event emitted when a pledge is confirmed
    event PledgeConfirmed(address indexed backer, uint256 amount);

    /**
     * @dev Throws an error indicating a zero pledge amount.
     */
    error ZeroPledge();

    /**
     * @dev Throws an error indicating the pledge expiration is in the past.
     */
    error ExpirationInPast();

    /**
     * @dev Throws an error indicating an existing pending pledge.
     */
    error ExistingPledgePending();

    /**
     * @dev Throws an error indicating the pledge is already confirmed.
     */
    error PledgeAlreadyConfirmed();

    /**
     * @dev Throws an error indicating the pledge has already expired.
     */
    error PledgeAlreadyExpired();

    /**
     * @dev Throws an error indicating the pledge is not expired.
     */
    error PledgeNotExpired();

    /**
     * @notice Allows a backer to make a pledge.
     * @param backer The address of the backer making the pledge.
     * @param pledgeAmount The amount of the pledge.
     * @param expiration The expiration timestamp for the pledge.
     */
    function _makePledge(
        address backer,
        uint256 pledgeAmount,
        uint256 expiration
    ) internal {
        if (pledgeAmount == 0) revert ZeroPledge();
        if (expiration <= block.timestamp) revert ExpirationInPast();
        if (s_pendingPledges[backer].amount != 0)
            revert ExistingPledgePending();
        if (s_pendingPledges[backer].confirmed) revert PledgeAlreadyConfirmed();

        // Add the pledge to the pending mapping
        s_pendingPledges[backer] = PendingPledge({
            amount: pledgeAmount,
            expiration: expiration,
            confirmed: false
        });

        // Add the backer to the list if it's their first pledge
        s_backerIndex[backer] = backers.length;
        backers.push(backer);

        emit PledgeMade(backer, pledgeAmount, expiration);
    }

    /**
     * @notice Confirms a pledge when funds are received.
     * @param backer The address of the backer whose pledge is being confirmed.
     */
    function _confirmPledge(address backer) internal {
        PendingPledge storage pledge = s_pendingPledges[backer];
        if (pledge.amount == 0) revert ZeroPledge();
        if (pledge.confirmed) revert PledgeAlreadyConfirmed();
        if (block.timestamp > pledge.expiration) revert PledgeAlreadyExpired();

        // Mark the pledge as confirmed
        pledge.confirmed = true;
        totalPledged += pledge.amount;

        emit PledgeConfirmed(backer, pledge.amount);
    }

    /**
     * @notice Invalidates expired pledges.
     * @param backer The address of the backer whose pledge is being invalidated.
     */
    function _invalidateExpiredPledge(address backer) internal {
        PendingPledge storage pledge = s_pendingPledges[backer];
        if (pledge.amount == 0) revert ZeroPledge();
        if (pledge.confirmed) revert PledgeAlreadyConfirmed();
        if (block.timestamp <= pledge.expiration) revert PledgeNotExpired();

        uint256 amount = pledge.amount;

        // Remove the pledge
        delete s_pendingPledges[backer];

        emit PledgeExpired(backer, amount);
    }

    /**
     * @notice Clears expired pledges for all backers.
     * @dev Restricted to the contract owner or admin to prevent misuse.
     */
    function clearExpiredPledges() public onlyOwner {
        for (uint256 i = 0; i < backers.length; ) {
            address backer = backers[i];
            PendingPledge storage pledge = s_pendingPledges[backer];

            // Check if the pledge is expired and not confirmed
            if (!pledge.confirmed && block.timestamp > pledge.expiration) {
                uint256 amount = pledge.amount;

                // Remove the pledge
                delete s_pendingPledges[backer];

                // Remove the backer from the list
                backers[i] = backers[backers.length - 1];
                backers.pop();

                emit PledgeExpired(backer, amount);
            } else {
                unchecked {
                    i++;
                }
            }
        }
    }

    /**
     * @notice Retrieves the pledged amount for a backer.
     * @param backer The address of the backer.
     * @return The pledged amount.
     */
    function _getPledgedAmount(address backer) internal view returns (uint256) {
        return s_pendingPledges[backer].amount;
    }

    /**
     * @notice Retrieves the pending pledge for a given backer.
     * @param backer The address of the backer.
     * @return The pending pledge.
     */
    function _getPendingPledge(
        address backer
    ) internal view returns (PendingPledge memory) {
        return s_pendingPledges[backer];
    }

    /**
     * @notice Retrieves the list of backers.
     * @return The array of backer addresses.
     */
    function _getBackers() internal view returns (address[] memory) {
        return backers;
    }
}
