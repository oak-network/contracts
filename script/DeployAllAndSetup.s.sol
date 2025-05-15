// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {TestUSD} from "src/TestUSD.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {CampaignInfoFactory} from "src/CampaignInfoFactory.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {TreasuryFactory} from "src/TreasuryFactory.sol";
import {AllOrNothing} from "src/treasuries/AllOrNothing.sol";

/**
 * @notice Script to deploy and setup all needed contracts for the protocol
 */
contract DeployAllAndSetup is Script {
    // Customizable values (set through environment variables)
    bytes32 platformHash;
    uint256 protocolFeePercent;
    uint256 platformFeePercent;
    uint256 tokenMintAmount;
    bool simulate;

    // Contract addresses
    address testUSD;
    address globalParams;
    address campaignInfo;
    address treasuryFactory;
    address campaignInfoFactory;
    address allOrNothingImplementation;

    // User addresses
    address deployerAddress;
    address finalProtocolAdmin;
    address finalPlatformAdmin;
    address backer1;
    address backer2;

    // Flags to track what was completed
    bool platformEnlisted = false;
    bool implementationRegistered = false;
    bool implementationApproved = false;
    bool adminRightsTransferred = false;

    // Flags for contract deployment or reuse
    bool testUsdDeployed = false;
    bool globalParamsDeployed = false;
    bool treasuryFactoryDeployed = false;
    bool campaignInfoFactoryDeployed = false;
    bool allOrNothingDeployed = false;

    // Configure parameters based on environment variables
    function setupParams() internal {
        // Get customizable values
        string memory platformName = vm.envOr(
            "PLATFORM_NAME",
            string("MiniFunder")
        );
        platformHash = keccak256(abi.encodePacked(platformName));
        protocolFeePercent = vm.envOr("PROTOCOL_FEE_PERCENT", uint256(100)); // Default 1%
        platformFeePercent = vm.envOr("PLATFORM_FEE_PERCENT", uint256(400)); // Default 4%
        tokenMintAmount = vm.envOr("TOKEN_MINT_AMOUNT", uint256(10000000e18));
        simulate = vm.envOr("SIMULATE", false);

        // Get user addresses
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        deployerAddress = vm.addr(deployerKey);

        // These are the final admin addresses that will receive control
        finalProtocolAdmin = vm.envOr(
            "PROTOCOL_ADMIN_ADDRESS",
            deployerAddress
        );
        finalPlatformAdmin = vm.envOr(
            "PLATFORM_ADMIN_ADDRESS",
            deployerAddress
        );
        backer1 = vm.envOr("BACKER1_ADDRESS", address(0));
        backer2 = vm.envOr("BACKER2_ADDRESS", address(0));

        // Check for existing contract addresses
        testUSD = vm.envOr("TEST_USD_ADDRESS", address(0));
        globalParams = vm.envOr("GLOBAL_PARAMS_ADDRESS", address(0));
        treasuryFactory = vm.envOr("TREASURY_FACTORY_ADDRESS", address(0));
        campaignInfoFactory = vm.envOr(
            "CAMPAIGN_INFO_FACTORY_ADDRESS",
            address(0)
        );
        allOrNothingImplementation = vm.envOr(
            "ALL_OR_NOTHING_IMPLEMENTATION_ADDRESS",
            address(0)
        );

        console2.log("Using platform hash for:", platformName);
        console2.log("Protocol fee percent:", protocolFeePercent);
        console2.log("Platform fee percent:", platformFeePercent);
        console2.log("Simulation mode:", simulate);
        console2.log("Deployer address:", deployerAddress);
        console2.log("Final protocol admin:", finalProtocolAdmin);
        console2.log("Final platform admin:", finalPlatformAdmin);
    }

    // Deploy or reuse contracts
    function deployContracts() internal {
        console2.log("Setting up contracts...");

        // Deploy or reuse TestUSD
        if (testUSD == address(0)) {
            testUSD = address(new TestUSD());
            testUsdDeployed = true;
            console2.log("TestUSD deployed at:", testUSD);
        } else {
            console2.log("Reusing TestUSD at:", testUSD);
        }

        // Deploy or reuse GlobalParams
        if (globalParams == address(0)) {
            globalParams = address(
                new GlobalParams(
                    deployerAddress, // Initially deployer is protocol admin
                    testUSD,
                    protocolFeePercent
                )
            );
            globalParamsDeployed = true;
            console2.log("GlobalParams deployed at:", globalParams);
        } else {
            console2.log("Reusing GlobalParams at:", globalParams);
        }

        // We need at least TestUSD and GlobalParams to continue
        require(testUSD != address(0), "TestUSD address is required");
        require(globalParams != address(0), "GlobalParams address is required");

        // Deploy CampaignInfo implementation if needed for new deployments
        if (campaignInfoFactory == address(0)) {
            campaignInfo = address(new CampaignInfo(address(this)));
            console2.log("CampaignInfo deployed at:", campaignInfo);
        }

        // Deploy or reuse TreasuryFactory
        if (treasuryFactory == address(0)) {
            treasuryFactory = address(
                new TreasuryFactory(GlobalParams(globalParams))
            );
            treasuryFactoryDeployed = true;
            console2.log("TreasuryFactory deployed at:", treasuryFactory);
        } else {
            console2.log("Reusing TreasuryFactory at:", treasuryFactory);
        }

        // Deploy or reuse CampaignInfoFactory
        if (campaignInfoFactory == address(0)) {
            campaignInfoFactory = address(
                new CampaignInfoFactory(
                    GlobalParams(globalParams),
                    campaignInfo
                )
            );
            CampaignInfoFactory(campaignInfoFactory)._initialize(
                treasuryFactory,
                globalParams
            );
            campaignInfoFactoryDeployed = true;
            console2.log(
                "CampaignInfoFactory deployed and initialized at:",
                campaignInfoFactory
            );
        } else {
            console2.log(
                "Reusing CampaignInfoFactory at:",
                campaignInfoFactory
            );
        }

        // Deploy or reuse AllOrNothing implementation
        if (allOrNothingImplementation == address(0)) {
            allOrNothingImplementation = address(new AllOrNothing());
            allOrNothingDeployed = true;
            console2.log(
                "AllOrNothing implementation deployed at:",
                allOrNothingImplementation
            );
        } else {
            console2.log(
                "Reusing AllOrNothing implementation at:",
                allOrNothingImplementation
            );
        }
    }

    // Setup steps when deployer has all roles
    function enlistPlatform() internal {
        // Skip if we didn't deploy GlobalParams (assuming it's already set up)
        if (!globalParamsDeployed) {
            console2.log(
                "Skipping enlistPlatform - using existing GlobalParams"
            );
            platformEnlisted = true;
            return;
        }

        console2.log("Setting up: enlistPlatform");
        // Only use startPrank in simulation mode
        if (simulate) {
            vm.startPrank(deployerAddress);
        }

        GlobalParams(globalParams).enlistPlatform(
            platformHash,
            deployerAddress, // Initially deployer is platform admin
            platformFeePercent
        );

        if (simulate) {
            vm.stopPrank();
        }
        platformEnlisted = true;
        console2.log("Platform enlisted successfully");
    }

    function registerTreasuryImplementation() internal {
        // Skip if we didn't deploy TreasuryFactory (assuming it's already set up)
        if (!treasuryFactoryDeployed || !allOrNothingDeployed) {
            console2.log(
                "Skipping registerTreasuryImplementation - using existing contracts"
            );
            implementationRegistered = true;
            return;
        }

        console2.log("Setting up: registerTreasuryImplementation");
        // Only use startPrank in simulation mode
        if (simulate) {
            vm.startPrank(deployerAddress);
        }

        TreasuryFactory(treasuryFactory).registerTreasuryImplementation(
            platformHash,
            0, // Implementation ID
            allOrNothingImplementation
        );

        if (simulate) {
            vm.stopPrank();
        }
        implementationRegistered = true;
        console2.log("Treasury implementation registered successfully");
    }

    function approveTreasuryImplementation() internal {
        // Skip if we didn't deploy TreasuryFactory (assuming it's already set up)
        if (!treasuryFactoryDeployed || !allOrNothingDeployed) {
            console2.log(
                "Skipping approveTreasuryImplementation - using existing contracts"
            );
            implementationApproved = true;
            return;
        }

        console2.log("Setting up: approveTreasuryImplementation");
        // Only use startPrank in simulation mode
        if (simulate) {
            vm.startPrank(deployerAddress);
        }

        TreasuryFactory(treasuryFactory).approveTreasuryImplementation(
            platformHash,
            0 // Implementation ID
        );

        if (simulate) {
            vm.stopPrank();
        }
        implementationApproved = true;
        console2.log("Treasury implementation approved successfully");
    }

    function mintTokens() internal {
        // Only mint tokens if we deployed TestUSD
        if (!testUsdDeployed) {
            console2.log("Skipping mintTokens - using existing TestUSD");
            return;
        }

        if (backer1 != address(0) && backer2 != address(0)) {
            console2.log("Minting tokens to test backers");
            TestUSD(testUSD).mint(backer1, tokenMintAmount);
            if (backer1 != backer2) {
                TestUSD(testUSD).mint(backer2, tokenMintAmount);
            }
            console2.log("Tokens minted successfully");
        }
    }

    // Transfer admin rights to final addresses
    function transferAdminRights() internal {
        // Skip if we didn't deploy GlobalParams (assuming it's already set up)
        if (!globalParamsDeployed) {
            console2.log(
                "Skipping transferAdminRights - using existing GlobalParams"
            );
            adminRightsTransferred = true;
            return;
        }

        console2.log("Transferring admin rights to final addresses...");

        // Only transfer if the final addresses are different from deployer
        if (finalProtocolAdmin != deployerAddress) {
            console2.log(
                "Transferring protocol admin rights to:",
                finalProtocolAdmin
            );
            GlobalParams(globalParams).updateProtocolAdminAddress(
                finalProtocolAdmin
            );
        }

        if (finalPlatformAdmin != deployerAddress) {
            console2.log(
                "Updating platform admin address for platform hash:",
                vm.toString(platformHash)
            );
            GlobalParams(globalParams).updatePlatformAdminAddress(
                platformHash,
                finalPlatformAdmin
            );
        }

        adminRightsTransferred = true;
        console2.log("Admin rights transferred successfully");
    }

    function run() external {
        // Load configuration
        setupParams();

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        // Start broadcast with deployer key
        vm.startBroadcast(deployerKey);

        // Deploy or reuse contracts
        deployContracts();

        // Setup the protocol with individual transactions in the correct order
        // Since deployer is both protocol and platform admin initially, we can do all steps
        enlistPlatform();
        registerTreasuryImplementation();
        approveTreasuryImplementation();

        // Mint tokens if needed
        mintTokens();

        // Finally, transfer admin rights to the final addresses
        transferAdminRights();

        // Stop broadcast
        vm.stopBroadcast();

        // Output summary
        console2.log("\n--- Deployment & Setup Summary ---");
        console2.log("Platform Name Hash:", vm.toString(platformHash));
        console2.log("TEST_USD_ADDRESS:", testUSD);
        console2.log("GLOBAL_PARAMS_ADDRESS:", globalParams);
        if (campaignInfo != address(0)) {
            console2.log("CAMPAIGN_INFO_ADDRESS:", campaignInfo);
        }
        console2.log("TREASURY_FACTORY_ADDRESS:", treasuryFactory);
        console2.log("CAMPAIGN_INFO_FACTORY_ADDRESS:", campaignInfoFactory);
        console2.log(
            "ALL_OR_NOTHING_IMPLEMENTATION_ADDRESS:",
            allOrNothingImplementation
        );
        console2.log("Protocol Admin:", finalProtocolAdmin);
        console2.log("Platform Admin:", finalPlatformAdmin);

        if (backer1 != address(0)) {
            console2.log("Backer1 (tokens minted):", backer1);
        }
        if (backer2 != address(0) && backer1 != backer2) {
            console2.log("Backer2 (tokens minted):", backer2);
        }

        console2.log("\nDeployment status:");
        console2.log(
            "- TestUSD:",
            testUsdDeployed ? "Newly deployed" : "Reused existing"
        );
        console2.log(
            "- GlobalParams:",
            globalParamsDeployed ? "Newly deployed" : "Reused existing"
        );
        console2.log(
            "- TreasuryFactory:",
            treasuryFactoryDeployed ? "Newly deployed" : "Reused existing"
        );
        console2.log(
            "- CampaignInfoFactory:",
            campaignInfoFactoryDeployed ? "Newly deployed" : "Reused existing"
        );
        console2.log(
            "- AllOrNothing Implementation:",
            allOrNothingDeployed ? "Newly deployed" : "Reused existing"
        );

        console2.log("\nSetup steps:");
        console2.log("1. Platform enlisted:", platformEnlisted);
        console2.log(
            "2. Treasury implementation registered:",
            implementationRegistered
        );
        console2.log(
            "3. Treasury implementation approved:",
            implementationApproved
        );
        console2.log("4. Admin rights transferred:", adminRightsTransferred);

        console2.log("\nDeployment and setup completed successfully!");
    }
}
