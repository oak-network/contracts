import { ethers } from "hardhat";

async function main() {

  const CampaignInfoFactory = await ethers.getContractFactory("CampaignInfoFactory");
  const campaignInfoFactory = await CampaignInfoFactory.deploy();

  await campaignInfoFactory.deployed();

  console.log(`CampaignInfoFactory deployed to ${campaignInfoFactory.address}`);

  const CampaignRegistry = await ethers.getContractFactory("CampaignRegistry");
  const campaignRegistry = await CampaignInfoFactory.deploy();

  await campaignInfoFactory.deployed();

  console.log(`CampaignRegistry deployed to ${campaignRegistry.address}`);


}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
