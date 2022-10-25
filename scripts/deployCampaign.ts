import { ethers } from "hardhat";
import { CampaignInfoFactory, CampaignInfo, CampaignRegistry, CampaignOracle, CampaignTreasury } from "../typechain-types";

async function main() {

    //const [owner, otherAccount] = await ethers.getSigners()

    const campaignInfoFactoryFactory = await ethers.getContractFactory("CampaignInfoFactory");
    const campaignInfoFactory: CampaignInfoFactory = await campaignInfoFactoryFactory.deploy();
    
    // Deploy CampaignFactory
    // await campaignInfoFactory.deployed();
    
    console.log(`CampaignInfoFactory deployed to ${campaignInfoFactory.address}`);
    
    const campaignRegistryFactory = await ethers.getContractFactory("CampaignRegistry");
    const campaignRegistry: CampaignRegistry = await campaignRegistryFactory.deploy();
    
    // Deploy CampaignRegistry
    //await campaignRegistry.deployed();
    
    console.log(`CampaignRegistry deployed to ${campaignRegistry.address}`);
    
    const campaignOracleFactory = await ethers.getContractFactory("CampaignOracle");
    const campaignOracle: CampaignOracle = await campaignOracleFactory.deploy();
    
    // Deploy CampaignOracle
    //await campaignOracle.deployed();
    
    console.log(`CampaignOracle deployed to ${campaignOracle.address}`);

    await campaignInfoFactory.setRegistry(campaignRegistry.address);
    await campaignRegistry.initialize(campaignInfoFactory.address, campaignOracle.address);
    
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
    
    console.log(`Deploying the Treasury for Origin platform...`);
    const campaignTreasuryFactory = await ethers.getContractFactory("CampaignTreasury");
    const campaignTreasury: CampaignTreasury = await campaignTreasuryFactory.deploy(
        campaignRegistry.address, 
        campaignInfoAddress,
        ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.utils.toUtf8Bytes("Kickstarter")), 8) 
        );

    //await campaignTreasury.deployed();

    console.log(`CampaignTreasury deployed to ${campaignTreasury.address}`);

    const campaignInfo: CampaignInfo = await ethers.getContractAt("contracts/CampaignInfo.sol:CampaignInfo", campaignInfoAddress);
    
    await campaignInfo.setTreasuryAddress(
        ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.utils.toUtf8Bytes("Kickstarter")), 8),
        campaignTreasury.address
    );

    console.log(`Treasury address set for Origin platform in CampaignInfo...`);
    
    console.log(`Deploying the Treasury for Reach platform...`);
    const campaignTreasury2: CampaignTreasury = await CampaignTreasury.deploy(
        campaignRegistry.address, 
        campaignInfoAddress,
        ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.utils.toUtf8Bytes("Weirdstarter")), 8) 
        );

    //await campaignTreasury2.deployed();

    console.log(`CampaignTreasury deployed to ${campaignTreasury2.address}`);
    
    await campaignInfo.setTreasuryAddress(
        ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.utils.toUtf8Bytes("Weirdstarter")), 8),
        campaignTreasury2.address
    );

    console.log(`Treasury address set for reach platform in CampaignInfo`);

    console.log(`Setting pledge data for reach platform in Oracle contract`);
    await campaignOracle.setPledgeAmountForClient(
        ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.utils.toUtf8Bytes("Weirdstarter")), 8),
        campaignInfo.address,
        "100000"
    );

    console.log(`Reading pledge data from Oracle contract for reach platform...`);
    const pledgeAmountForReach = await campaignOracle.getPledgeAmountForClient(
        ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.utils.toUtf8Bytes("Weirdstarter")), 8),
        campaignInfo.address
    );
    console.log(`Current pledge amount for reach platform ${pledgeAmountForReach}`);

    console.log(`Setting pledge data for origin platform in Oracle contract`);    
    await campaignOracle.setPledgeAmountForClient(
        ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.utils.toUtf8Bytes("Kickstarter")), 8),
        campaignInfo.address,
        "100000"
    );    

    console.log(`Reading pledge data from Oracle contract for reach platform...`);
    const pledgeAmountForOrigin = await campaignOracle.getPledgeAmountForClient(
        ethers.utils.hexZeroPad(ethers.utils.hexlify(ethers.utils.toUtf8Bytes("Weirdstarter")), 8),
        campaignInfo.address
    );  
    console.log(`Current pledge amount for origin platform ${pledgeAmountForOrigin}`);
  
    console.log(`Reading total pledge amount from CampaignInfo...`);
    const totalPledge = await campaignInfo.getTotalPledgeAmount();
    console.log(`Total pledge amount for origin & reach platform ${totalPledge}`);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
