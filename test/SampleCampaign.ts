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
        const campaignRegistry = await CampaignInfoFactory.deploy();
        
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

        return { campaignInfoFactory, campaignRegistry, campaignOracle, owner };
    }

    async function deployInfoContractAfterBaseDeployment() {
        const { campaignInfoFactory, owner } = await loadFixture(deployBaseContractFixture);
        
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

        return { campaignInfoAddress, campaignId };
    }

    describe("Deploy a CampaignInfo using CampaignInfoFactory", function(){

    }) 
})
