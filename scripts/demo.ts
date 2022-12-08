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

    console.log(`CampaignInfoFactory deployed to ${campaignInfoFactory.address}`);

    const campaignRegistryFactory = await ethers.getContractFactory("CampaignRegistry");
    const campaignRegistry: CampaignRegistry = await campaignRegistryFactory.deploy();

    console.log(`CampaignRegistry deployed to ${campaignRegistry.address}`);

    const campaignOracleFactory = await ethers.getContractFactory("CampaignOracle");
    const campaignOracle: CampaignOracle = await campaignOracleFactory.deploy();

    console.log(`CampaignOracle deployed to ${campaignOracle.address}`);

    const testUSDFactory = await ethers.getContractFactory("TestUSD");
    const testUSD: TestUSD = await testUSDFactory.deploy();

    console.log(`TestUSD deployed to ${testUSD.address}`);

    await testUSD.mint(owner.address, ethers.utils.parseEther("100000"));
    console.log("100000 TestUSD token minted to user");

    console.log(`CampaignInfo created at 0xa16E02E87b7454126E5E10d957A927A7F5B5d2be using CampaignInfoFactory`);

    console.log(`Deploying the Treasury for Origin platform...`);
    // const campaignTreasuryFactory = await ethers.getContractFactory("CampaignTreasury");
    // const campaignTreasury: CampaignTreasury = await campaignTreasuryFactory.deploy(
    //     campaignRegistry.address,
    //     testUSD.address,
    //     newCampaignInfoAddress,
    //     originPlatform
    // );

    console.log(`CampaignTreasury for origin platform deployed to 0x610178dA211FEF7D417bC0e6FeD39F05609AD788`);
    
    // const campaignInfoArtifact = await artifacts.readArtifact("CampaignInfo");
    // const campaignInfo: any = await ethers.getContractFactoryFromArtifact(campaignInfoArtifact, newCampaignInfoAddress);
    // const campaignInfoArtifact = await artifacts.readArtifact("CampaignInfo");
    // const campaignInfo = new ethers.Contract(newCampaignInfoAddress, campaignInfoArtifact.abi, owner);

    // await campaignInfo.setTreasuryAddress(
    //     originPlatform,
    //     campaignTreasury.address
    // );

    console.log(`Treasury address set for Origin platform in CampaignInfo...`);

    console.log(`Deploying the Treasury for Reach platform...`);
    // const campaignTreasury2: CampaignTreasury = await campaignTreasuryFactory.deploy(
    //     campaignRegistry.address,
    //     testUSD.address,
    //     newCampaignInfoAddress,
    //     reachPlatforms[0]
    // );

    console.log(`CampaignTreasury deployed to 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`);

    // await campaignInfo.setTreasuryAddress(
    //     reachPlatforms[0],
    //     campaignTreasury2.address
    // );

    console.log(`Treasury address set for reach platform in CampaignInfo`);

    // await testUSD.connect(owner).approve(campaignInfo.address, 1000000);
    
    console.log("Pledging 60000 token through reach platform");
    console.log("Pledging 40000 token through origin platform");
    // await campaignInfo.pledge(reachPlatforms[0], 51000);
    // await campaignInfo.pledge(originPlatform, 30000);
    console.log("Calling Fee split function");
    // const { rewardedFee, otherPlatformFees } = await campaignInfo.splitFeeWithRewards(500, 100);
    console.log(`Fee share for the rewarded platform is 6500`);
    console.log(`Fee share for the other platforms are 3500`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
