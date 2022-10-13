import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("CampaignInfoFactory", function () {

  async function deployCampaignInfoFactory() {

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const CampaignInfoFactory = await ethers.getContractFactory("CampaignInfoFactory");
    const campaignInfoFactory = await CampaignInfoFactory.deploy();

    return { campaignInfoFactory };
  }

  describe("Deployment", function () {

    it("Should set the right owner", async function () {
      const { campaignInfoFactory } = await loadFixture(deployCampaignInfoFactory);

      expect(await campaignInfoFactory.owner()).to.equal(owner.address);
    });

});
