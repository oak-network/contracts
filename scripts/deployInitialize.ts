import { ethers, artifacts } from "hardhat";
import {
  CampaignInfoFactory,
  TestUSD,
  ItemRegistry,
  GlobalParams,
  TreasuryFactory,
} from "../typechain-types";
import { getHexString } from "../lib/utils";
import { getPushLength } from "hardhat/internal/hardhat-network/stack-traces/opcodes";

async function main() {
  const [owner] = await ethers.getSigners();

  console.log("Owner address " + owner.address);

  const goalAmount = Number(500 * 1e18).toString();
  const testPreMint = Number(500 * 1e18).toString();

  const testUSDFactory = await ethers.getContractFactory("TestUSD");
  const testUSD: TestUSD = await testUSDFactory.deploy();

  await testUSD.deployed();

  console.log(`TestUSD deployed to ${testUSD.address}`);

  const mint = await testUSD.mint(owner.address, testPreMint);
  console.log(`${testPreMint} minted to user`);

  await mint.wait();

  const globalParamsFactory = await ethers.getContractFactory("GlobalParams");
  const globalParams: GlobalParams = await globalParamsFactory.deploy(
    owner.address,
    testUSD.address,
    200
  );

  await globalParams.deployed();

  console.log(`GlobalParams deployed to ${globalParams.address}`);

  const itemRegistryFactory = await ethers.getContractFactory("ItemRegistry");
  const itemRegistry: ItemRegistry = await itemRegistryFactory.deploy();

  await itemRegistry.deployed();

  console.log(`ItemRegistry deployed to ${itemRegistry.address}`);

  const campaignInfoFactoryFactory = await ethers.getContractFactory(
    "CampaignInfoFactory"
  );
  const campaignInfoFactory: CampaignInfoFactory =
    await campaignInfoFactoryFactory.deploy(globalParams.address);

  await campaignInfoFactory.deployed();

  console.log(`CampaignInfoFactory deployed to ${campaignInfoFactory.address}`);

  const treasuryFactoryFactory = await ethers.getContractFactory(
    "TreasuryFactory"
  );
  const treasuryFactory: TreasuryFactory = await treasuryFactoryFactory.deploy(
    globalParams.address,
    campaignInfoFactory.address,
    "0xcab5945253cc855eaf3d70b80fd57d6d03bf6ce326ab3763380f9b96b7384a2e"
  );

  await treasuryFactory.deployed();

  const initialize = await campaignInfoFactory._initialize(
    treasuryFactory.address,
    globalParams.address
  );

  await initialize.wait();
  const kickstarter = getHexString("Kickstarter");
  const weirdstarter = getHexString("Weirdstarter");
  const platforms = [kickstarter, weirdstarter];

  interface ICampaignData {
    launchTime: number;
    deadline: number;
    goalAmount: string;
  }

  const campaignData: ICampaignData = {
    launchTime: 1686867453,
    deadline: 1694816253,
    goalAmount: Number(500 * 1e18).toString(),
  };

  const emptyBytes32Array: string[] = [];

  const createCampaign = await campaignInfoFactory.createCampaign(
    owner.address,
    "0xcc7b0ace0b803eb8476b3fb1e74a99df7d3209dfcf42790d24b519e108574dad",
    platforms,
    emptyBytes32Array,
    emptyBytes32Array,
    campaignData
  );

  console.log(
    "NEXT_PUBLIC_GLOBAL_PARAMS=" +
      globalParams.address +
      "\nNEXT_PUBLIC_CAMPAIGN_INFO_FACTORY=" +
      campaignInfoFactory.address +
      "\nNEXT_PUBLIC_TREASURY_FACTORY=" +
      treasuryFactory.address,
    "\nNEXT_PUBLIC_TEST_USD=" + testUSD.address,
    "\nNEXT_PUBLIC_ITEM_REGISTRY=" + itemRegistry.address
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
