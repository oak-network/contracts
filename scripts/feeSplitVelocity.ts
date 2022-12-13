import { ethers, artifacts } from "hardhat";
import { CampaignInfoFactory, CampaignInfo, CampaignRegistry, CampaignOracle, CampaignTreasury, TestUSD, FeeSplit } from "../typechain-types";
import { getHexString } from "../lib/utils";
import { library } from "../typechain-types/contracts";

async function main() {
    const [owner] = await ethers.getSigners()

    // Parameters
    const clientWallet1 = "0xA2a6f51aF77c1bF8eB11fBE482D3e0F382105ee2";
    const clientWallet2 = "0x63216f462174d815fc555496dD9dD5FC99395b7f";
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

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
