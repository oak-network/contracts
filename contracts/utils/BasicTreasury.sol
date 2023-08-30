// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ICampaignInfo.sol";
import "../interfaces/ICampaignTreasury.sol";

abstract contract BasicTreasury is ICampaignTreasury {
    bytes32 internal constant ZERO_BYTES =
        0x0000000000000000000000000000000000000000000000000000000000000000;
    uint256 internal constant PERCENT_DIVIDER = 10000;

    bytes32 internal immutable PLATFORM_BYTES;
    uint256 internal immutable PLATFORM_FEE_PERCENT;
    ICampaignInfo internal immutable INFO;
    IERC20 internal immutable TOKEN;

    uint256 internal s_pledgedAmountInCrypto;
    bool internal s_cryptoFeeDisbursed;

    error TreasuryTransferFailed();
    error TreasurySuccessConditionNotFulfilled();
    error TreasuryFeeNotDisbursed();

    constructor(
        bytes32 platformBytes,
        uint256 platformFeePercent,
        address infoAddress,
        address tokenAddress
    ) {
        PLATFORM_BYTES = platformBytes;
        PLATFORM_FEE_PERCENT = platformFeePercent;
        INFO = ICampaignInfo(infoAddress);
        TOKEN = IERC20(tokenAddress);
    }

    function disburseFees() public virtual override {
        uint256 balance = s_pledgedAmountInCrypto;
        if (_checkSuccessCondition()) {
            uint256 protocolShare = (balance * INFO.getProtocolFeePercent()) /
                PERCENT_DIVIDER;
            uint256 platformShare = (balance * INFO.getPlatformFeePercent(PLATFORM_BYTES)) /
                PERCENT_DIVIDER;
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
        } else {
            revert TreasurySuccessConditionNotFulfilled();
        }
    }

    function withdraw() public virtual override {
        if (s_cryptoFeeDisbursed) {
            uint256 balance = TOKEN.balanceOf(address(this));
            bool success = TOKEN.transfer(INFO.owner(), balance);
            if (!success) revert TreasuryTransferFailed();
        } else {
            revert TreasuryFeeNotDisbursed();
        }
    }

    function getplatformBytes() external view override returns (bytes32) {
        return PLATFORM_BYTES;
    }

    function getplatformFeePercent() external view override returns (uint256) {
        return PLATFORM_FEE_PERCENT;
    }

    function _checkSuccessCondition() internal view virtual returns (bool);
}
