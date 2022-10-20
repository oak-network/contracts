import { ethers } from "hardhat";

async function main() {

  const CampaignInfoFactory = await ethers.getContractFactory("CampaignInfoFactory");
  const campaignInfoFactory = await CampaignInfoFactory.deploy();

  // Deploy CampaignFactory
  await campaignInfoFactory.deployed();

  console.log(`CampaignInfoFactory deployed to ${campaignInfoFactory.address}`);

  const CampaignRegistry = await ethers.getContractFactory("CampaignRegistry");
  const campaignRegistry = await CampaignInfoFactory.deploy();
  
  // Deploy CampaignRegistry
  await campaignRegistry.deployed();

  console.log(`CampaignRegistry deployed to ${campaignRegistry.address}`);

  const CampaignOracle = await ethers.getContractFactory("CampaignOracle");
  const campaignOracle = await CampaignOracle.deploy();

  // Deploy CampaignOracle
  await campaignOracle.deployed();

  console.log(`CampaignOracle deployed to ${campaignOracle.address}`);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
