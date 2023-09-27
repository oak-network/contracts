import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from 'hardhat';
import { ContractTransaction, ContractReceipt, utils } from 'ethers';
import { AllOrNothing, AllOrNothing__factory, CampaignInfo, CampaignInfoFactory, CampaignInfoFactory__factory, CampaignInfo__factory, GlobalParams, GlobalParams__factory, TestUSD, TestUSD__factory, TreasuryFactory, TreasuryFactory__factory } from "../../typechain-types";
import { convertBigNumber, convertBytesToString, convertStringToBytes, splitByteCodeIntoChunks } from '../../utils/helpers'

describe("Treasury `AllOrNothing` All Functionality", function () {

    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deployOnceFixture() {
        let contractOwner: SignerWithAddress, protocolAdminAddr: SignerWithAddress, platform1AdminAddr: SignerWithAddress, creator1Addr: SignerWithAddress, backer1Addr: SignerWithAddress, otherAccounts: SignerWithAddress[];
        let testUsd: TestUSD, globalParams: GlobalParams, campaignInfoFactory: CampaignInfoFactory, treasuryFactory: TreasuryFactory, campaignInfo: CampaignInfo, allOrNothing: AllOrNothing;


        [contractOwner, protocolAdminAddr, platform1AdminAddr, creator1Addr, backer1Addr, ...otherAccounts] = await ethers.getSigners();
        // Get contracts
        const TESTUSD = (await ethers.getContractFactory("TestUSD", contractOwner)) as TestUSD__factory;
        const GLOBALPARAMS = (await ethers.getContractFactory("GlobalParams", contractOwner)) as GlobalParams__factory;
        const CAMPAIGNINFOFACTORY = (await ethers.getContractFactory("CampaignInfoFactory", contractOwner)) as CampaignInfoFactory__factory;
        const TREASURYFACTORY = (await ethers.getContractFactory("TreasuryFactory", contractOwner)) as TreasuryFactory__factory;
        const CAMPAIGNINFO = (await ethers.getContractFactory("CampaignInfo", contractOwner)) as CampaignInfo__factory;
        const ALLORNOTHING = (await ethers.getContractFactory("AllOrNothing", contractOwner)) as AllOrNothing__factory;

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

        //Initialize campaignInfoFactory
        const initialize = await campaignInfoFactory._initialize(treasuryFactory.address, globalParams.address);
        await initialize.wait();

        //Mint token to the backer
        const mint = await testUsd.mint(backer1Addr.address, convertBigNumber(1000000, 18));
        await mint.wait();

        return { contractOwner, protocolAdminAddr, platform1AdminAddr, creator1Addr, testUsd, globalParams, campaignInfoFactory, treasuryFactory, CAMPAIGNINFO, ALLORNOTHING, backer1Addr }
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
        const platformByteCode = fixture.ALLORNOTHING.bytecode;
        
        const platformByteCodeChunks = splitByteCodeIntoChunks(platformByteCode, 2);

        const addBytecodeChunk1Transaction: ContractTransaction = await fixture.treasuryFactory.connect(fixture.platform1AdminAddr).addBytecodeChunk(platformBytes, platformByteCodeIndex, 0, false, platformByteCodeChunks[0]);
        const addBytecodeChunk1Receipt: ContractReceipt = await addBytecodeChunk1Transaction.wait();

        const addBytecodeChunk2Transaction: ContractTransaction = await fixture.treasuryFactory.connect(fixture.platform1AdminAddr).addBytecodeChunk(platformBytes, platformByteCodeIndex, 1, true, platformByteCodeChunks[1]);
        const addBytecodeChunk2Receipt: ContractReceipt = await addBytecodeChunk2Transaction.wait();

        return { fixture, addBytecodeChunk1Transaction, addBytecodeChunk1Receipt, addBytecodeChunk2Transaction, addBytecodeChunk2Receipt }
    }

    const enlistBytecode = async () => {

        const { fixture } = await loadFixture(addBytecode);

        const platformBytes = convertStringToBytes("KickStarter");
        const platformByteCodeIndex = 0;

        const enlistBytecodeTransaction: ContractTransaction = await fixture.treasuryFactory.connect(fixture.protocolAdminAddr).enlistBytecode(platformBytes, platformByteCodeIndex);

        const enlistBytecodeReceipt: ContractReceipt = await enlistBytecodeTransaction.wait();

        return { fixture, enlistBytecodeTransaction, enlistBytecodeReceipt }
    }

    const createCampaign = async () => {

        const { fixture } = await loadFixture(enlistBytecode);

        const platformBytes = convertStringToBytes("KickStarter");
        const selectedPlatformBytes = [platformBytes];
        const identifierHash = utils.keccak256(platformBytes);
        const blockTimestamp = (await ethers.provider.getBlock('latest')).timestamp;
        const launchTime = blockTimestamp + 300;
        const campaignData = {
            launchTime,
            deadline: launchTime + 300,
            goalAmount: 100
        }

        const createCampaignTransaction: ContractTransaction = await fixture.campaignInfoFactory.connect(fixture.creator1Addr).createCampaign(fixture.creator1Addr.address, identifierHash, selectedPlatformBytes, [], [], campaignData);
        const createCampaignReceipt: ContractReceipt = await createCampaignTransaction.wait();        

        return { fixture, createCampaignTransaction, createCampaignReceipt }
    }

    const deploy = async () => {
        const { fixture, createCampaignReceipt } = await loadFixture(createCampaign);

        const event = createCampaignReceipt.events?.find(event => event.event === 'CampaignInfoFactoryCampaignCreated');
        const infoAddress = event?.args!.campaignInfoAddress;
        const platformBytes = convertStringToBytes("KickStarter");
        const platformByteCodeIndex = 0;

        const deployTransaction: ContractTransaction = await fixture.treasuryFactory.connect(fixture.platform1AdminAddr).deploy(platformBytes, platformByteCodeIndex, infoAddress);
        const deployReceipt: ContractReceipt = await deployTransaction.wait();

        return { fixture, deployTransaction, deployReceipt, infoAddress }
    }

    const addReward = async () => {
        const { fixture, deployReceipt } = await loadFixture(deploy);
        const event = deployReceipt.events?.find(event => event.event === 'TreasuryFactoryTreasuryDeployed');
        const treasuryAddress = event?.args!.treasuryAddress;
        const allOrNothing: AllOrNothing = await ethers.getContractAt("AllOrNothing", treasuryAddress);

        const rewardName = convertStringToBytes("sampleReward");
        const reward = {
            rewardValue: ethers.BigNumber.from(1000),
            isRewardTier: true,
            itemId: [convertStringToBytes("sampleItem")],
            itemValue: [ethers.BigNumber.from(1000)],
            itemQuantity: [ethers.BigNumber.from(10)]
        }

        const addRewardTransaction: ContractTransaction = await allOrNothing.connect(fixture.creator1Addr).addReward(rewardName, reward);
        const addRewardReceipt: ContractReceipt = await addRewardTransaction.wait();

        return {fixture, addRewardTransaction, addRewardReceipt, reward, allOrNothing}

    }

    const pledgeOnPreLaunch = async () => {
        const { fixture, allOrNothing } = await loadFixture(addReward);

        //Increase Allowance to the AllOrNothing Contract
        const increaseAllowanceTransaction = await fixture.testUsd.connect(fixture.backer1Addr).increaseAllowance(allOrNothing.address, convertBigNumber(1, 18));
        await increaseAllowanceTransaction.wait();

        const pledgeOnPreLaunchTransaction: ContractTransaction = await allOrNothing.connect(fixture.backer1Addr).pledgeOnPreLaunch(fixture.backer1Addr.address);
        const pledgeOnPreLaunchReceipt: ContractReceipt = await pledgeOnPreLaunchTransaction.wait();

        return {fixture, pledgeOnPreLaunchTransaction, pledgeOnPreLaunchReceipt}
    }

    it("Enlisting Platform in Global Params Contract", async () => {
        const { fixture, enlistPlatformTransaction, enlistPlatformReceipt } = await loadFixture(enlistPlatform);

        const platformBytes = convertStringToBytes("KickStarter");
        const s_platformIsListed = await fixture.globalParams.checkIfplatformIsListed(platformBytes);
        expect(s_platformIsListed).to.equal(true);

        const platformAdminAddress = await fixture.globalParams.getPlatformAdminAddress(platformBytes);
        expect(platformAdminAddress).to.equal(fixture.platform1AdminAddr.address);

    });

    it("Adding Bytecode in Treasury Factory Contract", async () => {
        const { fixture, addBytecodeChunk1Transaction, addBytecodeChunk1Receipt, addBytecodeChunk2Transaction, addBytecodeChunk2Receipt } = await loadFixture(addBytecode);

        const event1 = addBytecodeChunk1Receipt.events?.find(event => event.event === 'TreasuryFactoryBytecodeChunkAdded');
        const platformBytes = convertStringToBytes("KickStarter");
        const platformByteCodeIndex = 0;
        const platformByteCode = fixture.ALLORNOTHING.bytecode;
        const platformByteCodeChunks = splitByteCodeIntoChunks(platformByteCode, 2);
        
        expect(event1?.args!.platformBytes).to.equal(platformBytes);
        expect(event1?.args!.bytecodeIndex).to.equal(platformByteCodeIndex);
        expect(event1?.args!.bytecodeChunk).to.equal(0);
        expect(event1?.args!.bytecode).to.equal(platformByteCodeChunks[0]);

        const event2 = addBytecodeChunk2Receipt.events?.find(event => event.event === 'TreasuryFactoryBytecodeChunkAdded');
        expect(event2?.args!.platformBytes).to.equal(platformBytes);
        expect(event2?.args!.bytecodeIndex).to.equal(platformByteCodeIndex);
        expect(event2?.args!.bytecodeChunk).to.equal(1);
        expect(event2?.args!.bytecode).to.equal(platformByteCodeChunks[1]);

    });

    it("Enlisting Bytecode in Treasury Factory Contract", async () => {
        const { fixture, enlistBytecodeTransaction, enlistBytecodeReceipt } = await loadFixture(enlistBytecode);

        const event = enlistBytecodeReceipt.events?.find(event => event.event === 'TreasuryFactoryBytecodeEnlisted');
        const platformBytes = convertStringToBytes("KickStarter");
        const platformByteCodeIndex = 0;

        expect(event?.args!.platformBytes).to.equal(platformBytes);
        expect(event?.args!.bytecodeIndex).to.equal(platformByteCodeIndex);

    });

    it("Creating Campaign in Campaign Info Factory Contract", async () => {
        const { fixture, createCampaignTransaction, createCampaignReceipt } = await loadFixture(createCampaign);

        const event = createCampaignReceipt.events?.find(event => event.event === 'CampaignInfoFactoryCampaignCreated');

        const platformBytes = convertStringToBytes("KickStarter");
        const identifierHash = utils.keccak256(platformBytes);

        expect(event?.args!.identifierHash).to.equal(identifierHash);
        console.log("Campaign Info Address: ", event?.args!.campaignInfoAddress)
    });

    it("Deploy Treasury in Treasury Factory Contract", async () => {
        const {fixture, deployTransaction, deployReceipt, infoAddress} = await loadFixture(deploy);

        const event = deployReceipt.events?.find(event => event.event === 'TreasuryFactoryTreasuryDeployed');

        const platformBytes = convertStringToBytes("KickStarter");
        const platformByteCodeIndex = 0;

        expect(event?.args!.platformBytes).to.equal(platformBytes);
        expect(event?.args!.bytecodeIndex).to.equal(platformByteCodeIndex);
        expect(event?.args!.infoAddress).to.equal(infoAddress);

        console.log("Treasury Address: ", event?.args!.treasuryAddress);
    });

    it("Add Reward in AllOrNothing Contract", async () => {
        const {fixture, addRewardTransaction, addRewardReceipt, reward} = await loadFixture(addReward);

        const event = addRewardReceipt.events?.find(event => event.event === 'RewardAdded');

        const rewardName = convertStringToBytes("sampleReward");

        expect(event?.args!.rewardName).to.equal(rewardName);
        const rewardEvent = event?.args!.reward;
        expect(rewardEvent.isRewardTier).to.equal(reward.isRewardTier);
        expect(rewardEvent.itemId).to.eql(reward.itemId);
        expect(rewardEvent.rewardValue).to.equal(reward.rewardValue);
        expect(rewardEvent.itemValue).to.eql(reward.itemValue);
        expect(rewardEvent.itemQuantity).to.eql(reward.itemQuantity);
    });

    it('Pre Launch Pledge in AllOrNothing Contract', async () => {
        const {fixture, pledgeOnPreLaunchTransaction, pledgeOnPreLaunchReceipt} = await loadFixture(pledgeOnPreLaunch);

        const event = pledgeOnPreLaunchReceipt.events?.find(event => event.event === 'Receipt');

        expect(event?.args!.backer).to.equal(fixture.backer1Addr.address);
        expect(event?.args!.pledgeAmount).to.equal(convertBigNumber(1, 18));

    })


});