import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Deploy base contracts", function() {
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
    }
})
