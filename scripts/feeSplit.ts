import { ethers } from "hardhat";
import { CampaignInfoFactory, CampaignInfo, CampaignRegistry, CampaignOracle, CampaignTreasury, TestUSD } from "../typechain-types";
import { getHexString } from "../lib/utils";

async function main() {
    const [owner] = await ethers.getSigners()

    const campaignInfoFactoryFactory = await ethers.getContractFactory("CampaignInfoFactory");
    const campaignInfoFactory: CampaignInfoFactory = await campaignInfoFactoryFactory.deploy();

    console.log(`CampaignInfoFactory deployed to ${campaignInfoFactory.address}`);

    const campaignRegistryFactory = await ethers.getContractFactory("CampaignRegistry");
    const campaignRegistry: CampaignRegistry = await campaignRegistryFactory.deploy();

    console.log(`CampaignRegistry deployed to ${campaignRegistry.address}`);

    const campaignOracleFactory = await ethers.getContractFactory("CampaignOracle");
    const campaignOracle: CampaignOracle = await campaignOracleFactory.deploy();

    console.log(`CampaignOracle deployed to ${campaignOracle.address}`);

    const testUSDFactory = await ethers.getContractFactory("TestUSD");
    const testUSD: CampaignOracle = await testUSDFactory.deploy();

    console.log(`TestUSD deployed to ${testUSD.address}`);

    await testUSD.mint()

    await campaignInfoFactory.setRegistry(campaignRegistry.address);
    await campaignRegistry.initialize(campaignInfoFactory.address, campaignOracle.address);

    const identifier = "/sampleproject";
    const originPlatform = getHexString("Kickstarter");
    const goalAmount = 1000000;
    const launchTime = 1666753961;
    const deadline = 1672002761;
    const creatorUrl = "/samplecreatorurl/jsdkfjs";
    const reachPlatforms = [
        getHexString("Weirdstarter")
    ];

    const tx = await campaignInfoFactory.createCampaign(identifier, originPlatform, goalAmount, launchTime, deadline, creatorUrl, reachPlatforms);

    const result = await tx.wait()
    const newCampaignInfoAddress = result.events?.[1].args?.campaignInfoAddress;

    console.log(`CampaignInfo created at ${newCampaignInfoAddress} using CampaignInfoFactory`);

    console.log(`Deploying the Treasury for Origin platform...`);
    const campaignTreasuryFactory = await ethers.getContractFactory("CampaignTreasury");
    const campaignTreasury: CampaignTreasury = await campaignTreasuryFactory.deploy(
        campaignRegistry.address,
        testUSD.address,
        newCampaignInfoAddress,
        originPlatform
    );

    console.log(`CampaignTreasury deployed to ${campaignTreasury.address}`);

    const campaignInfo: CampaignInfo = await ethers.getContractAt("contracts/CampaignInfo.sol:CampaignInfo", newCampaignInfoAddress);

    console.log("The CampaignInfo: " + campaignInfo);

    await campaignInfo.setTreasuryAddress(
        originPlatform,
        campaignTreasury.address
    );

    console.log(`Treasury address set for Origin platform in CampaignInfo...`);

    console.log(`Deploying the Treasury for Reach platform...`);
    const campaignTreasury2: CampaignTreasury = await campaignTreasuryFactory.deploy(
        campaignRegistry.address,
        testUSD.address,
        newCampaignInfoAddress,
        reachPlatforms[0]
    );

    console.log(`CampaignTreasury deployed to ${campaignTreasury2.address}`);

    await campaignInfo.setTreasuryAddress(
        reachPlatforms[0],
        campaignTreasury2.address
    );

    console.log(`Treasury address set for reach platform in CampaignInfo`);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
