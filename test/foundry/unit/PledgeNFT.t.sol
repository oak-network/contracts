// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "../Base.t.sol";

contract PledgeNFT_Test is Base_Test {
    CampaignInfo public campaign;
    KeepWhatsRaised public treasury;

    bytes32 public constant PLATFORM_HASH = keccak256("PLATFORM_1");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    function setUp() public override {
        super.setUp();

        // Enlist platform
        vm.prank(users.protocolAdminAddress);
        globalParams.enlistPlatform(PLATFORM_HASH, users.platform1AdminAddress, PLATFORM_FEE_PERCENT, address(0));

        // Register treasury implementation
        vm.startPrank(users.platform1AdminAddress);
        treasuryFactory.registerTreasuryImplementation(PLATFORM_HASH, 1, address(keepWhatsRaisedImplementation));
        vm.stopPrank();

        vm.prank(users.protocolAdminAddress);
        treasuryFactory.approveTreasuryImplementation(PLATFORM_HASH, 1);

        // Create a campaign
        bytes32 identifierHash = keccak256("TEST_CAMPAIGN");
        bytes32[] memory selectedPlatforms = new bytes32[](1);
        selectedPlatforms[0] = PLATFORM_HASH;
        bytes32[] memory keys = new bytes32[](0);
        bytes32[] memory values = new bytes32[](0);

        vm.prank(users.creator1Address);
        campaignInfoFactory.createCampaign(
            users.creator1Address,
            identifierHash,
            selectedPlatforms,
            keys,
            values,
            CAMPAIGN_DATA,
            "Test Campaign NFT",
            "TCNFT",
            "ipfs://QmTestImage",
            "ipfs://QmTestContract"
        );

        address campaignAddress = campaignInfoFactory.identifierToCampaignInfo(identifierHash);
        campaign = CampaignInfo(campaignAddress);

        // Deploy treasury
        vm.prank(users.platform1AdminAddress);
        address treasuryAddress = treasuryFactory.deploy(PLATFORM_HASH, campaignAddress, 1);
        treasury = KeepWhatsRaised(treasuryAddress);
    }

    function test_OnlyTreasuryCanMintNFT() public {
        // Try to mint without TREASURY_ROLE - should revert
        vm.expectRevert();
        vm.prank(users.backer1Address);
        campaign.mintNFTForPledge(users.backer1Address, bytes32(0), address(testToken), 100e18, 0, 0);
    }

    function test_TreasuryCanMintNFT() public {
        // Treasury has TREASURY_ROLE, should be able to mint
        vm.prank(address(treasury));
        uint256 tokenId = campaign.mintNFTForPledge(users.backer1Address, bytes32(0), address(testToken), 100e18, 0, 0);

        // Verify NFT was minted
        assertEq(tokenId, 1, "First token ID should be 1");
        assertEq(campaign.balanceOf(users.backer1Address), 1, "Backer should have 1 NFT");
        assertEq(campaign.ownerOf(tokenId), users.backer1Address, "Backer should own the NFT");
    }

    function test_TokenIdIncrementsAndNeverReuses() public {
        // Mint first NFT
        vm.prank(address(treasury));
        uint256 tokenId1 = campaign.mintNFTForPledge(users.backer1Address, bytes32(0), address(testToken), 100e18, 0, 0);
        assertEq(tokenId1, 1, "First token ID should be 1");

        // Mint second NFT
        vm.prank(address(treasury));
        uint256 tokenId2 = campaign.mintNFTForPledge(users.backer1Address, bytes32(0), address(testToken), 100e18, 0, 0);
        assertEq(tokenId2, 2, "Second token ID should be 2");

        // Burn first NFT
        vm.prank(users.backer1Address);
        campaign.burn(tokenId1);

        // Mint third NFT - should be 3, NOT reusing 1
        vm.prank(address(treasury));
        uint256 tokenId3 = campaign.mintNFTForPledge(users.backer1Address, bytes32(0), address(testToken), 100e18, 0, 0);
        assertEq(tokenId3, 3, "Third token ID should be 3, not reusing burned ID 1");

        // Verify balances
        assertEq(campaign.balanceOf(users.backer1Address), 2, "Backer should have 2 NFTs after burn");
    }

    function test_BurnRemovesNFT() public {
        // Mint NFT
        vm.prank(address(treasury));
        uint256 tokenId = campaign.mintNFTForPledge(users.backer1Address, bytes32(0), address(testToken), 100e18, 0, 0);

        assertEq(campaign.balanceOf(users.backer1Address), 1, "Backer should have 1 NFT");

        // Burn NFT
        vm.prank(users.backer1Address);
        campaign.burn(tokenId);

        // Verify NFT was burned
        assertEq(campaign.balanceOf(users.backer1Address), 0, "Backer should have 0 NFTs after burn");

        // Trying to query owner of burned token should revert
        vm.expectRevert();
        campaign.ownerOf(tokenId);
    }
}
