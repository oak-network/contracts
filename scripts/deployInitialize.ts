// import { AllOrNothing } from './../typechain-types/src/treasuries/AllOrNothing';
import { ethers, artifacts } from "hardhat";
import {
  CampaignInfoFactory,
  TestUSD,
  ItemRegistry,
  GlobalParams,
  TreasuryFactory,
  AllOrNothing,
} from "../typechain-types";
import { hexString, hashString } from "../lib/utils";
import { getPushLength } from "hardhat/internal/hardhat-network/stack-traces/opcodes";
import { time } from "@nomicfoundation/hardhat-network-helpers";

async function insertBytecodeInChunks(
  contractInstance: any,
  platformBytes: string,
  bytecodeIndex: number,
  bytecode: string,
  chunkSize: number = 20000
) {
  let chunkIndex = 0;

  for (let i = 0; i < bytecode.length; i += chunkSize) {
    const end = Math.min(i + chunkSize, bytecode.length);
    let bytecodeChunk = bytecode.slice(i, end);
    const isLastChunk = i + chunkSize >= bytecode.length; // True if current chunk is the last

    if (i != 0) {
      bytecodeChunk = "0x" + bytecodeChunk;
    }
    const tx = await contractInstance.addBytecodeChunk(
      platformBytes,
      bytecodeIndex,
      chunkIndex,
      isLastChunk,
      bytecodeChunk
    );
    const receipt = await tx.wait();

    console.log(
      `BytecodeIndex ${bytecodeIndex}, Chunk ${chunkIndex} added with transaction hash: ${receipt.transactionHash}`
    );

    chunkIndex++;
  }
}

async function main() {
  const [owner] = await ethers.getSigners();

  console.log("Owner address " + owner.address);

  const goalAmount = Number(500 * 1e18).toString();
  const testPreMint = Number(900 * 1e18).toString();

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

  const treasuryArtifact = await artifacts.readArtifact("AllOrNothing");

  const bytecodeHash = hashString(treasuryArtifact.bytecode);

  console.log("BytecodeHash: " + bytecodeHash);
  const treasuryFactory: TreasuryFactory = await treasuryFactoryFactory.deploy(
    globalParams.address,
    campaignInfoFactory.address,
    bytecodeHash
  );

  await treasuryFactory.deployed();

  console.log(`TreasuryFactory deployed to ${treasuryFactory.address}`);

  const initialize = await campaignInfoFactory._initialize(
    treasuryFactory.address,
    globalParams.address
  );

  await initialize.wait();
  console.log("Initialized");
  const kickstarter = hashString("Kickstarter");
  const weirdstarter = hashString("Weirdstarter");
  const platforms = [kickstarter, weirdstarter];

  interface ICampaignData {
    launchTime: number;
    deadline: number;
    goalAmount: string;
  }

  const campaignData: ICampaignData = {
    launchTime: Date.now(),
    deadline: Date.now() + 1000000,
    goalAmount: Number(500 * 1e18).toString(),
  };

  const emptyBytes32Array: string[] = [];

  const enlistPlatform = await globalParams.enlistPlatform(
    kickstarter,
    owner.address,
    200
  );

  await enlistPlatform.wait();
  console.log("Platform enlisted");

  const AllOrNothingArtifact = await artifacts.readArtifact("AllOrNothing");

  const bytecode = AllOrNothingArtifact.bytecode;

  await insertBytecodeInChunks(treasuryFactory, kickstarter, 0, bytecode);
  console.log("All bytecode chunks added!");

  const enlistBytecode = await treasuryFactory.enlistBytecode(kickstarter, 0);
  await enlistBytecode.wait();
  console.log("Bytecode enlisted");

  const createCampaign = await campaignInfoFactory.createCampaign(
    owner.address,
    "0xcc7b0ace0b803eb8476b3fb1e74a99df7d3209dfcf42790d24b519e108574dad",
    [kickstarter],
    emptyBytes32Array,
    emptyBytes32Array,
    campaignData
  );
  let result = await createCampaign.wait();
  const infoAddress = result.events?.[0].address.toLowerCase() as string;
  console.log(infoAddress);

  // const len = await treasuryFactory.getBytecodeLength(kickstarter, 0);
  // console.log("length " + len);

  const deploy = await treasuryFactory.deploy(kickstarter, 0, infoAddress);
  result = await deploy.wait();
  const treasuryAddress =
    result.events?.[1].args?.treasuryAddress.toLowerCase() as string;
  console.log(`AllOrNothing ${treasuryAddress} created`);

  interface Reward {
    rewardValue: number;
    isRewardTier: boolean;
    itemId: string[];
    itemValue: number[];
    itemQuantity: number[];
  }

  const reward: Reward = {
    rewardValue: 100,
    isRewardTier: true,
    itemId: [hexString("ab"), hexString("cd")],
    itemValue: [1000, 2000],
    itemQuantity: [10, 20],
  };

  // const allOrNothing = await ethers.getContractAt("src/treasuries/AllOrNothing.sol:AllOrNothing", treasuryAddress);

  const allOrNothing = new ethers.Contract(
    treasuryAddress,
    AllOrNothingArtifact.abi,
    owner
  );

  const rewardName = hashString("SampleReward");
  const addReward = await allOrNothing.addReward(rewardName, reward);
  await addReward.wait();
  console.log(`Reward ${rewardName} added`);

  let approveContract = await testUSD.approve(
    allOrNothing.address,
    ethers.constants.MaxUint256
  );
  await approveContract.wait();

  // const pledgeOnPreLaunch = await allOrNothing.pledgeOnPreLaunch(owner.address);
  // await pledgeOnPreLaunch.wait();
  // console.log(`Pledged on prelaunch`);

  await time.increaseTo(Date.now() + 10000);

  const pledgeForAReward = await allOrNothing.pledgeForAReward(owner.address, [
    rewardName,
  ]);
  await pledgeForAReward.wait();
  console.log(`Pledged for reward ${rewardName}`);

  const getRaisedAmount = await allOrNothing.getRaisedAmount();
  console.log(`Raised amount ${getRaisedAmount}`);

  const pledgeWithoutAReward = await allOrNothing.pledgeWithoutAReward(
    owner.address,
    goalAmount
  );
  await pledgeWithoutAReward.wait();
  console.log(`Pledged without reward`);

  await time.increaseTo(Date.now() + 1000000);

  const disburseFees = await allOrNothing.disburseFees();
  await disburseFees.wait();
  console.log(`Fees disbursed`);

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
