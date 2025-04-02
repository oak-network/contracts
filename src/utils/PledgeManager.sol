pragma solidity ^0.8.9;

abstract contract PledgeManager {
    struct PendingPledge {
        uint256 amount;
        uint256 expiration;
        bool confirmed;
    }

    // Mapping to track pending pledges by backer address
    mapping(address => PendingPledge) private s_pendingPledges;

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
        require(pledgeAmount > 0, "Pledge amount must be greater than zero");
        require(
            s_pendingPledges[backer].amount == 0,
            "Existing pledge pending"
        );

        // Add the pledge to the pending mapping
        s_pendingPledges[backer] = PendingPledge({
            amount: pledgeAmount,
            expiration: expiration,
            confirmed: false
        });

        // Add the backer to the list if it's their first pledge
        backers.push(backer);

        emit PledgeMade(backer, pledgeAmount, expiration);
    }

    /**
     * @notice Confirms a pledge when funds are received.
     * @param backer The address of the backer whose pledge is being confirmed.
     */
    function _confirmPledge(address backer) internal {
        PendingPledge storage pledge = s_pendingPledges[backer];
        require(!pledge.confirmed, "Pledge already confirmed");
        require(block.timestamp <= pledge.expiration, "Pledge has expired");

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
        require(!pledge.confirmed, "Pledge already confirmed");
        require(block.timestamp > pledge.expiration, "Pledge has not expired");

        uint256 amount = pledge.amount;

        // Remove the pledge
        delete s_pendingPledges[backer];

        emit PledgeExpired(backer, amount);
    }

    /**
     * @notice Clears expired pledges for all backers.
     */
    /// @dev It iterates through all backers and checks if their pledge has expired.
    /// @dev This function is intended to be called periodically to clean up expired pledges.
    function clearExpiredPledges() external {
        for (uint256 i = 0; i < backers.length; i++) {
            address backer = backers[i];
            PendingPledge storage pledge = s_pendingPledges[backer];

            // Check if the pledge is expired and not confirmed
            if (!pledge.confirmed && block.timestamp > pledge.expiration) {
                uint256 amount = pledge.amount;

                // Remove the pledge
                delete s_pendingPledges[backer];

                emit PledgeExpired(backer, amount);
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
}
