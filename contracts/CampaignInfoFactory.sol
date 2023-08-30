// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

//import "@openzeppelin/contracts/access/Ownable.sol";
import "./CampaignInfo.sol";
import "./interfaces/ICampaignRegistry.sol";
import "./interfaces/IGlobalParams.sol";
import "./interfaces/ICampaignInfoFactory.sol";

contract CampaignInfoFactory is ICampaignInfoFactory {
    CampaignInfo newCampaignInfo;
    address registry;

    IGlobalParams private immutable GLOBAL_PARAMS;
    ICampaignRegistry private immutable CAMPAIGN_REGISTRY;

    error CampaignInfoFactoryCampaignCreationFailed();

    constructor(address campaignRegistry, address globalParams) {
        CAMPAIGN_REGISTRY = ICampaignRegistry(campaignRegistry);
        GLOBAL_PARAMS = IGlobalParams(globalParams);
    }

    function createCampaign(
        address creator,
        bytes32 identifierHash,
        CampaignData memory campaignData,
        bytes32[] memory selectedPlatformBytes
    ) external override  {
        bytes memory bytecode = type(CampaignInfo).creationCode;
        address treasuryFactory = CAMPAIGN_REGISTRY.getTreasuryFactoryAddress();
        address token = GLOBAL_PARAMS.getTokenAddress();
        uint256 protocolFeePercent = GLOBAL_PARAMS.getProtocolFeePercent();
        bytes memory argsByteCode = abi.encodePacked(
            bytecode,
            abi.encode(
                GLOBAL_PARAMS,
                treasuryFactory,
                token,
                creator,
                protocolFeePercent,
                identifierHash,
                campaignData,
                selectedPlatformBytes
            )
        );
        address info;
        assembly {
            info := create2(
                0,
                add(argsByteCode, 0x20),
                mload(argsByteCode),
                identifierHash
            )
        }
        if (info == address(0)) {
            revert CampaignInfoFactoryCampaignCreationFailed();
        }
        else {
            CAMPAIGN_REGISTRY.setCampaignInfoAddress(identifierHash, info); 
            emit campaignCreation(identifierHash, info);
        }
    }
}
