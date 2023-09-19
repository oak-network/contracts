import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from 'hardhat';
import { ContractTransaction, ContractReceipt, utils } from 'ethers';
import { CampaignInfo, CampaignInfoFactory, CampaignInfoFactory__factory, CampaignInfo__factory, GlobalParams, GlobalParams__factory, TestUSD, TestUSD__factory, TreasuryFactory, TreasuryFactory__factory } from "../typechain-types";
import { convertBytesToString, convertStringToBytes } from '../utils/helpers'

describe("Treasury `AllOrNothing` All Functionality", function () {

    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deployOnceFixture() {
        let contractOwner: SignerWithAddress, protocolAdminAddr: SignerWithAddress, platform1AdminAddr: SignerWithAddress, creator1Addr: SignerWithAddress, otherAccounts: SignerWithAddress[];
        let testUsd: TestUSD, globalParams: GlobalParams, campaignInfoFactory: CampaignInfoFactory, treasuryFactory: TreasuryFactory, campaignInfo: CampaignInfo;


        [contractOwner, protocolAdminAddr, platform1AdminAddr, creator1Addr, ...otherAccounts] = await ethers.getSigners();
        // Get contracts
        const TESTUSD = (await ethers.getContractFactory("TestUSD", contractOwner)) as TestUSD__factory;
        const GLOBALPARAMS = (await ethers.getContractFactory("GlobalParams", contractOwner)) as GlobalParams__factory;
        const CAMPAIGNINFOFACTORY = (await ethers.getContractFactory("CampaignInfoFactory", contractOwner)) as CampaignInfoFactory__factory;
        const TREASURYFACTORY = (await ethers.getContractFactory("TreasuryFactory", contractOwner)) as TreasuryFactory__factory;
        const CAMPAIGNINFO = (await ethers.getContractFactory("CampaignInfo", contractOwner)) as CampaignInfo__factory;

        // Deploy contracts
        testUsd = await TESTUSD.deploy();
        await testUsd.deployed();

        globalParams = await GLOBALPARAMS.deploy(protocolAdminAddr.address, testUsd.address, 200);
        await globalParams.deployed();

        campaignInfoFactory = await CAMPAIGNINFOFACTORY.deploy(globalParams.address);
        await campaignInfoFactory.deployed();

        const bytecodeHash = utils.keccak256(CAMPAIGNINFO.bytecode);
        treasuryFactory = await TREASURYFACTORY.deploy(globalParams.address, campaignInfoFactory.address, bytecodeHash);
        await treasuryFactory.deployed();

        return { contractOwner, protocolAdminAddr, platform1AdminAddr, creator1Addr, testUsd, globalParams, campaignInfoFactory, treasuryFactory, CAMPAIGNINFO }
    }

    const enlistPlatform = async () => {

        const fixture = await loadFixture(deployOnceFixture);

        const platformBytes = convertStringToBytes("KickStarter");
        const platformFeePercent = 100;

        const enlistPlatformTransaction: ContractTransaction = await fixture.globalParams.connect(fixture.contractOwner).enlistPlatform(platformBytes, fixture.platform1AdminAddr.address, platformFeePercent);

        const enlistPlatformReceipt: ContractReceipt = await enlistPlatformTransaction.wait();

        return { fixture, enlistPlatformTransaction, enlistPlatformReceipt }
    }

    const addBytecode = async () => {

        const { fixture } = await loadFixture(enlistPlatform);

        const platformBytes = convertStringToBytes("KickStarter");
        const platformByteCodeIndex = 0;
        const platformByteCode = fixture.CAMPAIGNINFO.bytecode;

        const addBytecodeTransaction: ContractTransaction = await fixture.treasuryFactory.connect(fixture.platform1AdminAddr).addBytecode(platformBytes, platformByteCodeIndex, platformByteCode);

        const addBytecodeReceipt: ContractReceipt = await addBytecodeTransaction.wait();

        return { fixture, addBytecodeTransaction, addBytecodeReceipt }
    }

    const enlistBytecode = async () => {

        const { fixture } = await loadFixture(addBytecode);

        const platformBytes = convertStringToBytes("KickStarter");
        const platformByteCodeIndex = 0;

        const enlistBytecodeTransaction: ContractTransaction = await fixture.treasuryFactory.connect(fixture.protocolAdminAddr).enlistBytecode(platformBytes, platformByteCodeIndex);

        const enlistBytecodeReceipt: ContractReceipt = await enlistBytecodeTransaction.wait();

        return { fixture, enlistBytecodeTransaction, enlistBytecodeReceipt }
    }

    it("Enlisting Platform in Global Params Contract", async () => {
        const { fixture, enlistPlatformTransaction, enlistPlatformReceipt } = await loadFixture(enlistPlatform);

        const platformBytes = convertStringToBytes("KickStarter");
        const s_platformIsListed = await fixture.globalParams.checkIfplatformIsListed(platformBytes);
        expect(s_platformIsListed).to.equal(true);

    });

    it("Adding Bytecode in Treasury Factory Contract", async () => {
        const { fixture, addBytecodeTransaction, addBytecodeReceipt } = await loadFixture(addBytecode);

        const event = addBytecodeReceipt.events?.find(event => event.event === 'TreasuryFactoryBytecodeAdded');
        const platformBytes = convertStringToBytes("KickStarter");
        const platformByteCodeIndex = 0;
        const platformByteCode = fixture.CAMPAIGNINFO.bytecode;

        expect(event?.args!.platformBytes).to.equal(platformBytes);
        expect(event?.args!.bytecodeIndex).to.equal(platformByteCodeIndex);
        expect(event?.args!.bytecode).to.equal(platformByteCode);

    });

    it("Enlisting Bytecode in Treasury Factory Contract", async () => {
        const { fixture, enlistBytecodeTransaction, enlistBytecodeReceipt } = await loadFixture(enlistBytecode);

        const event = enlistBytecodeReceipt.events?.find(event => event.event === 'TreasuryFactoryBytecodeEnlisted');
        const platformBytes = convertStringToBytes("KickStarter");
        const platformByteCodeIndex = 0;

        expect(event?.args!.platformBytes).to.equal(platformBytes);
        expect(event?.args!.bytecodeIndex).to.equal(platformByteCodeIndex);

    });


});