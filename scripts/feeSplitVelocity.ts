import { ethers, artifacts } from "hardhat";
import { CampaignInfoFactory, CampaignInfo, CampaignRegistry, CampaignOracle, CampaignTreasury, TestUSD, FeeSplit } from "../typechain-types";
import { getHexString } from "../lib/utils";
import { library } from "../typechain-types/contracts";

async function main() {
    const [owner] = await ethers.getSigners()

    // Parameters
    const platformWallet1 = "0xA2a6f51aF77c1bF8eB11fBE482D3e0F382105ee2";
    const platformWallet2 = "0x63216f462174d815fc555496dD9dD5FC99395b7f";
    const pledge1 = Number(50 * 1e18).toString()
    const pledge2 = Number(70 * 1e18).toString()
    const goalAmount = Number(500 * 1e18).toString()
    const testPreMint = Number(500 * 1e18).toString()

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

    const mint = await testUSD.mint(owner.address, testPreMint);
    console.log(`${testPreMint} minted to user`);

    await mint.wait();

    const setRegistry = await campaignInfoFactory.setRegistry(campaignRegistry.address);
    await setRegistry.wait();
    const initialize = await campaignRegistry.initialize(campaignInfoFactory.address, campaignOracle.address);
    await initialize.wait();

    const identifier = "/sampleproject";
    const originPlatform = getHexString("Kickstarter");
    const launchTime = 1666753961;
    const deadline = 1672002761;
    const creatorUrl = "/samplecreatorurl/jsdkfjs";
    const reachPlatforms = [
        getHexString("Weirdstarter")
    ];

    console.log(originPlatform);
    console.log(reachPlatforms[0]);

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
    
    const campaignInfoArtifact = await artifacts.readArtifact("CampaignInfo");
    const campaignInfo = new ethers.Contract(newCampaignInfoAddress, campaignInfoArtifact.abi, owner);

    let setplatformInfo = await campaignInfo.setplatformInfo(
        originPlatform,
        platformWallet1,
        campaignTreasury.address,
        testUSD.address
    );
    await setplatformInfo.wait();
    console.log(`Treasury address set for Origin platform in CampaignInfo...`);

    console.log(`Deploying the Treasury for Reach platform...`);
    const campaignTreasury2: CampaignTreasury = await campaignTreasuryFactory.deploy(
        campaignRegistry.address,
        newCampaignInfoAddress,
        reachPlatforms[0]
    );

    await campaignTreasury2.deployed();

    console.log(`CampaignTreasury deployed to ${campaignTreasury2.address}`);

    setplatformInfo = await campaignInfo.setplatformInfo(
        reachPlatforms[0],
        platformWallet2,
        campaignTreasury2.address,
        testUSD.address
    );
    await setplatformInfo.wait();
    console.log(`Treasury address set for reach platform in CampaignInfo`);

    const increaseAllowance = await testUSD.increaseAllowance(campaignInfo.address, goalAmount);
    await increaseAllowance.wait();
        
    let pledgeThroughplatform = await campaignInfo.pledgeThroughplatform(reachPlatforms[0], pledge1);
    await pledgeThroughplatform.wait();
    console.log(`Pledged ${pledge1} to reachPlatform`);
    pledgeThroughplatform = await campaignInfo.pledgeThroughplatform(originPlatform, pledge2);
    await pledgeThroughplatform.wait();
    console.log(`Pledged ${pledge2} to originPlatform`);
    
    const treasury1Balance = campaignInfo.getPledgedAmountForplatformCrypto(originPlatform);
    console.log(`Treasury1 ${treasury1Balance}`);
    const treasury2Balance = campaignInfo.getPledgedAmountForplatformCrypto(reachPlatforms[0]);
    console.log(`Treasury2 ${treasury2Balance}`);

    // Proportional fee split with the velocity of fundraising
    
    const splitFeeWithVelocityOfFundraising = await campaignInfo.splitFeeWithVelocityOfFundraising();
    await splitFeeWithVelocityOfFundraising.wait();
    console.log(`Fee splits disbursed to platform wallets!`);

    const platformWallet1Balance = await testUSD.balanceOf(platformWallet1);
    const platformWallet2Balance = await testUSD.balanceOf(platformWallet2);
    console.log(`tUSD balance of platform1 ${platformWallet1} ${platformWallet1Balance}`);
    console.log(`tUSD balance of platform2 ${platformWallet2} ${platformWallet2Balance}`);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
