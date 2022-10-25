import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Deploy a Sample Campaign and multilist across different clients", function() {
    async function deployBaseContractFixture() {
        const [owner] = await ethers.getSigners()

        const CampaignInfoFactory = await ethers.getContractFactory("CampaignInfoFactory");
        const campaignInfoFactory = await CampaignInfoFactory.deploy();
      
        // Deploy CampaignFactory
        await campaignInfoFactory.deployed();
      
        console.log(`CampaignInfoFactory deployed to ${campaignInfoFactory.address}`);
      
        const CampaignRegistry = await ethers.getContractFactory("CampaignRegistry");
        const campaignRegistry = await CampaignRegistry.deploy();
        
        // Deploy CampaignRegistry
        await campaignRegistry.deployed();
      
        console.log(`CampaignRegistry deployed to ${campaignRegistry.address}`);
      
        const CampaignOracle = await ethers.getContractFactory("CampaignOracle");
        const campaignOracle = await CampaignOracle.deploy();
      
        // Deploy CampaignOracle
        await campaignOracle.deployed();
      
        console.log(`CampaignOracle deployed to ${campaignOracle.address}`);

        await campaignOracle.initialize(campaignRegistry.address);
        await campaignInfoFactory.setRegistry(campaignRegistry.address);
        await campaignRegistry.initialize(campaignInfoFactory.address, campaignOracle.address);

        return { campaignInfoFactory, campaignRegistry, campaignOracle, owner };
    }

    async function deployInfoTreasuryOriginAfterBase() {
        const { campaignInfoFactory, campaignRegistry, owner } = await loadFixture(deployBaseContractFixture);
        
        const identifier = ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.utils.toUtf8Bytes("/sampleproject/jsdkfjs")), 8);
        const originPlatform = ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.utils.toUtf8Bytes("Kickstarter")), 8)
        const goalAmount = 10000;
        const startsAt = 1669273128;
        const deadline = 1674543528;
        const creatorUrl = ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.utils.toUtf8Bytes("/samplecreatorurl/jsdkfjs")), 8);
        const reachPlatforms = [
            ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.utils.toUtf8Bytes("Kickstarter")), 8),
            ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.utils.toUtf8Bytes("Weirdstarter")), 8)
        ];
        
        const { campaignInfoAddress, campaignId } = await campaignInfoFactory.createCampaign(identifier, originPlatform, goalAmount, startsAt, deadline, creatorUrl, reachPlatforms);

        console.log(`CampaignInfo having Id ${campaignId} created at ${campaignInfoAddress} using CampaignInfoFactory`);
        
        const CampaignTreasury = await ethers.getContractFactory("CampaignTreasury");
        const campaignTreasury = await CampaignTreasury.deploy(
            campaignRegistry.address, 
            campaignInfoAddress,
            ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.utils.toUtf8Bytes("Kickstarter")), 8) 
            );

        console.log(`Deploying the Treasury for Origin platform...`);
        await campaignTreasury.deployed();

        console.log(`CampaignTreasury deployed to ${campaignTreasury.address}`);

        const campaignInfo = await ethers.getContractAt("contracts/CampaignInfo.sol:CampaignInfo", campaignInfoAddress);
        
        await campaignInfo.setTreasuryAddress(
            ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.utils.toUtf8Bytes("Kickstarter")), 8),
            campaignTreasury.address
        );

        console.log(`Treasury address set for Origin platform in CampaignInfo...`);

        return { campaignInfo, CampaignTreasury, campaignRegistry };
    }
    
    async function deployReachTreasuryAndSetAddressAtInfo () {
        const { campaignInfo, CampaignTreasury } = await loadFixture(deployInfoTreasuryOriginAfterBase);

        const campaignTreasury = await CampaignTreasury.deploy(
            campaignRegistry.address, 
            campaignInfoAddress,
            ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.utils.toUtf8Bytes("Weirdstarter")), 8) 
            );

        console.log(`Deploying the Treasury for Reach platform...`);
        await campaignTreasury.deployed();

        console.log(`CampaignTreasury deployed to ${campaignTreasury.address}`);
        
        await campaignInfo.setTreasuryAddress(
            ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.utils.toUtf8Bytes("Weirdstarter")), 8),
            campaignTreasury.address
        );

        console.log(`Treasury address set for reach platform in CampaignInfo...`);

        return { campaignTreasury };
    }

    describe("Deploy a CampaignInfo using CampaignInfoFactory", function(){
    }) 
})
