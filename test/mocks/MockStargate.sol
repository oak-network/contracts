// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStargate, StargateType, Ticket} from "@stargate-v2/interfaces/IStargate.sol";
import {
    IOFT,
    SendParam,
    MessagingFee,
    MessagingReceipt,
    OFTReceipt,
    OFTLimit,
    OFTFeeDetail
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";

contract MockStargate is IStargate {
    using SafeERC20 for IERC20;

    IERC20 private immutable i_token;
    ILayerZeroEndpointV2 private immutable i_endpoint;
    uint32 private immutable i_srcEid;

    uint256 public nativeFee;
    uint256 public amountReceivedOverride;
    uint64 public nonce;

    constructor(IERC20 token_, ILayerZeroEndpointV2 endpoint_, uint32 srcEid_) {
        i_token = token_;
        i_endpoint = endpoint_;
        i_srcEid = srcEid_;
    }

    function setNativeFee(uint256 fee) external {
        nativeFee = fee;
    }

    function setAmountReceivedOverride(uint256 amount) external {
        amountReceivedOverride = amount;
    }

    function oftVersion() external pure override returns (bytes4 interfaceId, uint64 version) {
        return (type(IOFT).interfaceId, 1);
    }

    function token() external view override returns (address) {
        return address(i_token);
    }

    function approvalRequired() external pure override returns (bool) {
        return true;
    }

    function sharedDecimals() external view override returns (uint8) {
        return IERC20Metadata(address(i_token)).decimals();
    }

    function quoteOFT(
        SendParam calldata sendParam
    ) external view override returns (OFTLimit memory limit, OFTFeeDetail[] memory feeDetails, OFTReceipt memory receipt)
    {
        limit = OFTLimit({minAmountLD: 0, maxAmountLD: type(uint256).max});
        feeDetails = new OFTFeeDetail[](0);

        uint256 received = amountReceivedOverride == 0 ? sendParam.amountLD : amountReceivedOverride;
        receipt = OFTReceipt({amountSentLD: sendParam.amountLD, amountReceivedLD: received});
    }

    function quoteSend(SendParam calldata, bool) external view override returns (MessagingFee memory fee) {
        fee = MessagingFee({nativeFee: nativeFee, lzTokenFee: 0});
    }

    function send(
        SendParam calldata sendParam,
        MessagingFee calldata fee,
        address
    ) external payable override returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) {
        return _send(sendParam, fee);
    }

    function sendToken(
        SendParam calldata sendParam,
        MessagingFee calldata fee,
        address
    )
        external
        payable
        override
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt, Ticket memory ticket)
    {
        (msgReceipt, oftReceipt) = _send(sendParam, fee);
        ticket = Ticket({ticketId: 0, passengerBytes: ""});
    }

    function stargateType() external pure override returns (StargateType) {
        return StargateType.OFT;
    }

    function _send(
        SendParam calldata sendParam,
        MessagingFee calldata fee
    ) internal returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) {
        if (msg.value < fee.nativeFee) {
            revert("MockStargate: insufficient fee");
        }

        address receiver = address(uint160(uint256(sendParam.to)));
        uint256 received = amountReceivedOverride == 0 ? sendParam.amountLD : amountReceivedOverride;

        uint64 currentNonce = nonce;
        nonce = currentNonce + 1;

        i_token.safeTransferFrom(msg.sender, address(this), sendParam.amountLD);

        if (sendParam.composeMsg.length > 0) {
            i_token.safeTransfer(receiver, received);

            bytes memory composeMsg =
                abi.encodePacked(bytes32(uint256(uint160(msg.sender))), sendParam.composeMsg);
            bytes memory fullMsg = OFTComposeMsgCodec.encode(currentNonce, i_srcEid, received, composeMsg);
            bytes32 guid =
                keccak256(abi.encodePacked(currentNonce, i_srcEid, msg.sender, sendParam.dstEid, receiver, fullMsg));

            i_endpoint.sendCompose(receiver, guid, 0, fullMsg);
            i_endpoint.lzCompose(address(this), receiver, guid, 0, fullMsg, bytes(""));

            msgReceipt = MessagingReceipt({guid: guid, nonce: currentNonce, fee: fee});
        } else {
            i_token.safeTransfer(receiver, received);
            bytes32 guid = keccak256(
                abi.encodePacked(currentNonce, i_srcEid, msg.sender, sendParam.dstEid, receiver, received)
            );
            msgReceipt = MessagingReceipt({guid: guid, nonce: currentNonce, fee: fee});
        }

        oftReceipt = OFTReceipt({amountSentLD: sendParam.amountLD, amountReceivedLD: received});
    }
}
