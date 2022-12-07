import { ethers, artifacts } from "hardhat";
import { CampaignInfoFactory, CampaignInfo, CampaignRegistry, CampaignOracle, CampaignTreasury, TestUSD, FeeSplit } from "../typechain-types";
import { getHexString } from "../lib/utils";
import { library } from "../typechain-types/contracts";

async function main() {
    const [owner] = await ethers.getSigners()

    // const feeSplitLibraryFactory = await ethers.getContractFactory("FeeSplit");
    // const feeSplitLibrary: FeeSplit = await feeSplitLibraryFactory.deploy();

    const campaignInfoFactoryFactory = await ethers.getContractFactory("CampaignInfoFactory");
    const campaignInfoFactory: CampaignInfoFactory = await campaignInfoFactoryFactory.deploy();

    await campaignInfoFactory.deployed();

    console.log(`CampaignInfoFactory deployed to ${campaignInfoFactory.address}`);

    const campaignRegistryFactory = await ethers.getContractFactory("CampaignRegistry");
    const campaignRegistry: CampaignRegistry = await campaignRegistryFactory.deploy();

    await campaignRegistry.deployed();

    console.log(`CampaignRegistry deployed to ${campaignRegistry.address}`);

    const campaignOracleFactory = await ethers.getContractFactory("CampaignOracle");
    const campaignOracle: CampaignOracle = await campaignOracleFactory.deploy();

    await campaignOracle.deployed();

    console.log(`CampaignOracle deployed to ${campaignOracle.address}`);

    const testUSDFactory = await ethers.getContractFactory("TestUSD");
    const testUSD: TestUSD = await testUSDFactory.deploy();

    await testUSD.deployed();

    console.log(`TestUSD deployed to ${testUSD.address}`);

    const mint = await testUSD.mint(owner.address, ethers.utils.parseEther("100000"));
    console.log("100000 TestUSD token minted to user");

    await mint.wait();

    const setRegistry = await campaignInfoFactory.setRegistry(campaignRegistry.address);
    await setRegistry.wait();
    const initialize = await campaignRegistry.initialize(campaignInfoFactory.address, campaignOracle.address);
    await initialize.wait();

    const identifier = "/sampleproject";
    const originPlatform = getHexString("Kickstarter");
    const goalAmount = 100000;
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
        newCampaignInfoAddress,
        originPlatform
    );

    await campaignTreasury.deployed();


    console.log(`CampaignTreasury deployed to ${campaignTreasury.address}`);
    
    // const campaignInfoArtifact = await artifacts.readArtifact("CampaignInfo");
    // const campaignInfo: any = await ethers.getContractFactoryFromArtifact(campaignInfoArtifact, newCampaignInfoAddress);
    const campaignInfoArtifact = await artifacts.readArtifact("CampaignInfo");
    const campaignInfo = new ethers.Contract(newCampaignInfoAddress, campaignInfoArtifact.abi, owner);

    console.log("The CampaignInfo: " + campaignInfo);

    let setTreasuryAndToken = await campaignInfo.setTreasuryAndToken(
        originPlatform,
        campaignTreasury.address,
        testUSD.address
    );
    await setTreasuryAndToken.wait();
    console.log(`Treasury address set for Origin platform in CampaignInfo...`);

    console.log(`Deploying the Treasury for Reach platform...`);
    const campaignTreasury2: CampaignTreasury = await campaignTreasuryFactory.deploy(
        campaignRegistry.address,
        newCampaignInfoAddress,
        reachPlatforms[0]
    );

    await campaignTreasury2.deployed();

    console.log(`CampaignTreasury deployed to ${campaignTreasury2.address}`);

    setTreasuryAndToken = await campaignInfo.setTreasuryAndToken(
        reachPlatforms[0],
        campaignTreasury2.address,
        testUSD.address
    );
    await setTreasuryAndToken.wait();
    console.log(`Treasury address set for reach platform in CampaignInfo`);

    const increaseAllowance = await testUSD.increaseAllowance(campaignInfo.address, 1000000);
    await increaseAllowance.wait();
    let pledge = await campaignInfo.pledge(reachPlatforms[0], 51000);
    await pledge.wait();
    pledge = await campaignInfo.pledge(originPlatform, 30000);
    await pledge.wait();
    const { rewardedFee, otherPlatformFees } = await campaignInfo.splitFeeWithRewards(500, 100);
    console.log(`Fee share for the rewarded platform is ${rewardedFee}`);
    console.log(`Fee share for the other platforms are ${otherPlatformFees}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
