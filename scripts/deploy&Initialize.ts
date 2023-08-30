import { ethers, artifacts } from "hardhat";
import {
  CampaignInfoFactory,
  CampaignRegistry,
  TestUSD,
  ModelFactory
} from "../typechain-types";
import { getHexString } from "../lib/utils";
import { getPushLength } from "hardhat/internal/hardhat-network/stack-traces/opcodes";

async function main() {
  const [owner] = await ethers.getSigners();

  console.log("Owner address " + owner.address);

  const goalAmount = Number(500 * 1e18).toString();
  const testPreMint = Number(500 * 1e18).toString();

  const modelFactoryFactory = await ethers.getContractFactory(
    "ModelFactory"
  );
  const modelFactory: ModelFactory =
    await modelFactoryFactory.deploy();

  await modelFactory.deployed();
  
  const campaignRegistryFactory = await ethers.getContractFactory(
    "CampaignRegistry"
  );
  const campaignRegistry: CampaignRegistry =
    await campaignRegistryFactory.deploy();

  await campaignRegistry.deployed();

  console.log(`CampaignRegistry deployed to ${campaignRegistry.address}`);

  const campaignInfoFactoryFactory = await ethers.getContractFactory(
    "CampaignInfoFactory"
  );
  const campaignInfoFactory: CampaignInfoFactory =
    await campaignInfoFactoryFactory.deploy(campaignRegistry.address);

  await campaignInfoFactory.deployed();

  console.log(`CampaignInfoFactory deployed to ${campaignInfoFactory.address}`);

  const testUSDFactory = await ethers.getContractFactory("TestUSD");
  const testUSD: TestUSD = await testUSDFactory.deploy();

  await testUSD.deployed();

  console.log(`TestUSD deployed to ${testUSD.address}`);

  const mint = await testUSD.mint(owner.address, testPreMint);
  console.log(`${testPreMint} minted to user`);

  await mint.wait();

  const initialize = await campaignRegistry.initialize(
    campaignInfoFactory.address
  );
  await initialize.wait();

  const identifier = "sampleCampaign";
  const kickstarter = getHexString("Kickstarter");
  const weirdstarter = getHexString("Weirdstarter");
  const launchTime = 1686867453;
  const deadline = 1694816253;
  const platforms = [kickstarter, weirdstarter];

  const tx = await campaignInfoFactory.createCampaign(
    owner.address,
    testUSD.address,
    launchTime,
    deadline,
    goalAmount,
    identifier,
    platforms
  );

  let result = await tx.wait();
  console.log(result.events);

  console.log(
    "NEXT_PUBLIC_CAMPAIGN_REGISTRY=" +
      campaignRegistry.address +
      "\nNEXT_PUBLIC_CAMPAIGN_INFO_FACTORY=" +
      campaignInfoFactory.address +
      "\nNEXT_PUBLIC_TEST_USD=" +
      testUSD.address,
      "\nNEXT_PUBLIC_MODEL_FACTORY=" +
      modelFactory.address
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
