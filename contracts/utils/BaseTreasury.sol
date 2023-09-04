// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ICampaignInfo.sol";
import "../interfaces/ICampaignTreasury.sol";
import "../utils/CampaignAccessChecker.sol";

abstract contract BaseTreasury is ICampaignTreasury, CampaignAccessChecker {
    bytes32 internal constant ZERO_BYTES =
        0x0000000000000000000000000000000000000000000000000000000000000000;
    uint256 internal constant PERCENT_DIVIDER = 10000;

    bytes32 internal immutable PLATFORM_BYTES;
    uint256 internal immutable PLATFORM_FEE_PERCENT;
    IERC20 internal immutable TOKEN;
    ICampaignInfo internal immutable CAMPAIGN_INFO;

    uint256 internal s_pledgedAmountInCrypto;
    bool internal s_cryptoFeeDisbursed;

    // Event emitted when fees are successfully disbursed
    event FeesDisbursed(uint256 protocolShare, uint256 platformShare);

    // Event emitted when a withdrawal is successful
    event WithdrawalSuccessful(address to, uint256 amount);

    // Event emitted when the success condition is not fulfilled during fee disbursement
    event SuccessConditionNotFulfilled();

    error TreasuryTransferFailed();
    error TreasurySuccessConditionNotFulfilled();
    error TreasuryFeeNotDisbursed();

    constructor(
        bytes32 platformBytes,
        address infoAddress
    ) CampaignAccessChecker(infoAddress) {
        PLATFORM_BYTES = platformBytes;
        CAMPAIGN_INFO = ICampaignInfo(infoAddress);
        TOKEN = IERC20(INFO.getTokenAddress());
        PLATFORM_FEE_PERCENT = INFO.getPlatformFeePercent(platformBytes);
    }

    function disburseFees() public virtual override {
        if (!_checkSuccessCondition()) {
            revert TreasurySuccessConditionNotFulfilled();
        }
        uint256 balance = s_pledgedAmountInCrypto;
        uint256 protocolShare = (balance * INFO.getProtocolFeePercent()) /
            PERCENT_DIVIDER;
        uint256 platformShare = (balance *
            INFO.getPlatformFeePercent(PLATFORM_BYTES)) / PERCENT_DIVIDER;
        bool success = TOKEN.transfer(
            INFO.getProtocolAdminAddress(),
            protocolShare
        );
        if (!success) {
            revert TreasuryTransferFailed();
        }
        success = TOKEN.transfer(
            INFO.getPlatformAdminAddress(PLATFORM_BYTES),
            platformShare
        );
        if (!success) {
            revert TreasuryTransferFailed();
        }
        s_cryptoFeeDisbursed = true;
        emit FeesDisbursed(protocolShare, platformShare);
    }

    function withdraw() public virtual override {
        if (!s_cryptoFeeDisbursed) {
            revert TreasuryFeeNotDisbursed();
        }
        uint256 balance = TOKEN.balanceOf(address(this));
        address recipient = INFO.owner();
        bool success = TOKEN.transfer(recipient, balance);
        if (!success) {
            revert TreasuryTransferFailed();
        }
        emit WithdrawalSuccessful(recipient, balance);
    }

    function getplatformBytes() external view override returns (bytes32) {
        return PLATFORM_BYTES;
    }

    function getplatformFeePercent() external view override returns (uint256) {
        return PLATFORM_FEE_PERCENT;
    }

    function _checkSuccessCondition() internal view virtual returns (bool);
}
