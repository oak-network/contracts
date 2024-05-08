// import { AllOrNothing } from './../typechain-types/src/treasuries/AllOrNothing';
import { ethers, artifacts } from 'hardhat';
import {
  CampaignInfoFactory,
  TestUSD,
  ItemRegistry,
  GlobalParams,
  TreasuryFactory,
  AllOrNothing,
} from '../typechain-types';
import { hexString, hashString } from '../lib/utils';
import { getPushLength } from 'hardhat/internal/hardhat-network/stack-traces/opcodes';
import { time } from '@nomicfoundation/hardhat-network-helpers';

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
      bytecodeChunk = '0x' + bytecodeChunk;
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

//   console.log('Owner address ' + owner.address);

  const goalAmount = Number(5 * 1e18).toString();
  const testPreMint = Number(900 * 1e18).toString();

  const campaignInfoFactoryAddress =
    '0x439a1E55881C0f825c4246FA1fa2546C26D6e17c';
  const globalParamsAddress = '0x76Fb7e0Df8d4Ed66c851F3E99940f64b6EB7B1f9';
  const itemRegistryAddress = '0x5c1135415E4fD97DDD188624B4a1f3c8cAF5b549';
  const treasuryFactoryAddress = '0x3a9dE40993cc7275918C98d07628B06840fFAa8A';
  const testUSDAddress = '0xC97e2f349744655c403eE6DEEe782ED2cD1E63fe';

  const globalParams = await ethers.getContractAt(
    'src/GlobalParams.sol:GlobalParams',
    globalParamsAddress
  );

  const campaignInfoFactory = await ethers.getContractAt(
    'src/CampaignInfoFactory.sol:CampaignInfoFactory',
    campaignInfoFactoryAddress
  );

  const treasuryFactory = await ethers.getContractAt(
    'src/TreasuryFactory.sol:TreasuryFactory',
    treasuryFactoryAddress
  );

  const testUSD = await ethers.getContractAt(
    'src/TestUSD.sol:TestUSD',
    testUSDAddress
  );

  const itemRegistry = await ethers.getContractAt(
    'src/utils/ItemRegistry.sol:ItemRegistry',
    itemRegistryAddress
  );

  const mint = await testUSD.mint(owner.address, testPreMint);
//   console.log(`${testPreMint} minted to user`);

  await mint.wait();

  const kickstarter = hashString('Kickstarter');
  const weirdstarter = hashString('Weirdstarter');
  const platforms = [kickstarter, weirdstarter];

  interface ICampaignData {
    launchTime: number;
    deadline: number;
    goalAmount: string;
  }

  const campaignData: ICampaignData = {
    launchTime: Date.now() + 100,
    deadline: 1711658160000,
    goalAmount: Number(500 * 1e18).toString(),
  };

  const emptyBytes32Array: string[] = [];

  const AllOrNothingArtifact = await artifacts.readArtifact('AllOrNothing');

  const createCampaign = await campaignInfoFactory.createCampaign(
    owner.address,
    '0xa8da229518e493b9e43b9cb5e3cb79a5360d2ffe1012cfac01a6e86d8b8ae5cc',
    [kickstarter],
    emptyBytes32Array,
    emptyBytes32Array,
    campaignData
  );
  let result = await createCampaign.wait();
  const infoAddress = result.events?.[0].address.toLowerCase() as string;
  console.log('Campaign ', infoAddress);

  // ------------

//   const platformsBE = ['kickstarter'];

//   const createCampaignParams = [
//     owner.address,
//     ethers.utils.keccak256(ethers.utils.toUtf8Bytes(kickstarter)),
//     [kickstarter],
//     [],
//     [],
//     campaignData,
//   ];
//   const provider = new ethers.providers.JsonRpcProvider(
//     process.env.ALFAJORES_RPC_URL
//   );

  // Calculate EIP-1559 parameters
//   const feeData = await provider.getFeeData();
//   const maxFeePerGas = feeData.maxFeePerGas;
//   const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas;

//   let tx = await campaignInfoFactory.createCampaign(...createCampaignParams, {
//     maxFeePerGas, // EIP-1559 parameter
//     maxPriorityFeePerGas, // EIP-1559 parameter
//   });

//   console.log('Transaction hash Backend Campaign: ' + tx.hash);

  const deploy = await treasuryFactory.deploy(kickstarter, 0, infoAddress);
  result = await deploy.wait();
  const treasuryAddress =
    result.events?.[1].args?.treasuryAddress.toLowerCase() as string;
  console.log(`AllOrNothing ${treasuryAddress}`);

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
    itemId: [hexString('ab'), hexString('cd')],
    itemValue: [1000, 2000],
    itemQuantity: [10, 20],
  };

  const allOrNothing = new ethers.Contract(
    treasuryAddress,
    AllOrNothingArtifact.abi,
    owner
  );

//   console.log(
//     'NEXT_PUBLIC_GLOBAL_PARAMS=' +
//       globalParams.address +
//       '\nNEXT_PUBLIC_CAMPAIGN_INFO_FACTORY=' +
//       campaignInfoFactory.address +
//       '\nNEXT_PUBLIC_TREASURY_FACTORY=' +
//       treasuryFactory.address,
//     '\nNEXT_PUBLIC_TEST_USD=' + testUSD.address,
//     '\nNEXT_PUBLIC_ITEM_REGISTRY=' + itemRegistry.address
//   );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
