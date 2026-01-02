// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {console2} from "forge-std/console2.sol";
import {TestToken} from "../test/mocks/TestToken.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {CampaignInfoFactory} from "src/CampaignInfoFactory.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {TreasuryFactory} from "src/TreasuryFactory.sol";
import {KeepWhatsRaised} from "src/treasuries/KeepWhatsRaised.sol";
import {IGlobalParams} from "src/interfaces/IGlobalParams.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DataRegistryKeys} from "src/constants/DataRegistryKeys.sol";
import {DeployBase} from "./lib/DeployBase.s.sol";

/**
 * @notice Script to deploy and setup all needed contracts for the keepWhatsRaised
 * @dev Updated for the new KeepWhatsRaised contract that stores fees locally
 */
contract DeployAllAndSetupKeepWhatsRaised is DeployBase {
    // Customizable values (set through environment variables)
    bytes32 platformHash;
    uint256 protocolFeePercent;
    uint256 platformFeePercent;
    uint256 tokenMintAmount;
    bool simulate;
    uint256 bufferTime;
    uint256 campaignLaunchBuffer;
    uint256 minimumCampaignDuration;

    // Contract addresses
    address testToken;
    address globalParams;
    address globalParamsImplementation;
    address campaignInfo;
    address treasuryFactory;
    address treasuryFactoryImplementation;
    address campaignInfoFactory;
    address campaignInfoFactoryImplementation;
    address keepWhatsRaisedImplementation;

    // User addresses
    address deployerAddress;
    address finalProtocolAdmin;
    address finalPlatformAdmin;
    address platformAdapter;
    address backer1;
    address backer2;

    // Flags to track what was completed
    bool platformEnlisted = false;
    bool implementationRegistered = false;
    bool implementationApproved = false;
    bool adminRightsTransferred = false;

    // Flags for contract deployment or reuse
    bool testTokenDeployed = false;
    bool globalParamsDeployed = false;
    bool treasuryFactoryDeployed = false;
    bool campaignInfoFactoryDeployed = false;
    bool keepWhatsRaisedDeployed = false;

    // Configure parameters based on environment variables
    function setupParams() internal {
        // Get customizable values
        string memory platformName = vm.envOr("PLATFORM_NAME", string("VAKI"));
        platformHash = keccak256(abi.encodePacked(platformName));
        protocolFeePercent = vm.envOr("PROTOCOL_FEE_PERCENT", uint256(100)); // Default 1%
        platformFeePercent = vm.envOr("PLATFORM_FEE_PERCENT", uint256(600)); // Default 6%
        tokenMintAmount = vm.envOr("TOKEN_MINT_AMOUNT", uint256(10000000e18));
        simulate = vm.envOr("SIMULATE", false);
        bufferTime = vm.envOr("BUFFER_TIME", uint256(0));
        campaignLaunchBuffer = vm.envOr("CAMPAIGN_LAUNCH_BUFFER", uint256(0));
        minimumCampaignDuration = vm.envOr("MINIMUM_CAMPAIGN_DURATION", uint256(0));

        // Get user addresses
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        deployerAddress = vm.addr(deployerKey);

        // These are the final admin addresses that will receive control
        finalProtocolAdmin = vm.envOr("PROTOCOL_ADMIN_ADDRESS", deployerAddress);
        finalPlatformAdmin = vm.envOr("PLATFORM_ADMIN_ADDRESS", deployerAddress);
        platformAdapter = vm.envOr("PLATFORM_ADAPTER_ADDRESS", address(0));
        backer1 = vm.envOr("BACKER1_ADDRESS", address(0));
        backer2 = vm.envOr("BACKER2_ADDRESS", address(0));

        // Check for existing contract addresses
        testToken = vm.envOr("TOKEN_ADDRESS", address(0));
        globalParams = vm.envOr("GLOBAL_PARAMS_ADDRESS", address(0));
        treasuryFactory = vm.envOr("TREASURY_FACTORY_ADDRESS", address(0));
        campaignInfoFactory = vm.envOr("CAMPAIGN_INFO_FACTORY_ADDRESS", address(0));
        keepWhatsRaisedImplementation = vm.envOr("KEEP_WHATS_RAISED_IMPLEMENTATION_ADDRESS", address(0));

        console2.log("Using platform hash for:", platformName);
        console2.log("Protocol fee percent:", protocolFeePercent);
        console2.log("Platform fee percent:", platformFeePercent);
        console2.log("Simulation mode:", simulate);
        console2.log("Deployer address:", deployerAddress);
        console2.log("Final protocol admin:", finalProtocolAdmin);
        console2.log("Final platform admin:", finalPlatformAdmin);
        console2.log("Platform adapter (trusted forwarder):", platformAdapter);
        console2.log("Buffer time (seconds):", bufferTime);
        console2.log("Campaign launch buffer (seconds):", campaignLaunchBuffer);
        console2.log("Minimum campaign duration (seconds):", minimumCampaignDuration);
    }

    function setRegistryValues() internal {
        if (!globalParamsDeployed) {
            console2.log("Skipping setRegistryValues - using existing GlobalParams");
            return;
        }

        console2.log("Setting registry values on GlobalParams");
        // Only use startPrank in simulation mode
        if (simulate) {
            vm.startPrank(deployerAddress);
        }

        GlobalParams(globalParams).addToRegistry(DataRegistryKeys.BUFFER_TIME, bytes32(bufferTime));
        GlobalParams(globalParams).addToRegistry(DataRegistryKeys.CAMPAIGN_LAUNCH_BUFFER, bytes32(campaignLaunchBuffer));
        GlobalParams(globalParams).addToRegistry(
            DataRegistryKeys.MINIMUM_CAMPAIGN_DURATION, bytes32(minimumCampaignDuration)
        );

        if (simulate) {
            vm.stopPrank();
        }
    }

    // Deploy or reuse contracts
    function deployContracts() internal {
        console2.log("Setting up contracts...");

        // Deploy or reuse TestToken
        // Only deploy TestToken if CURRENCIES is not provided (backward compatibility)
        string memory tokenName = vm.envOr("TOKEN_NAME", string("TestToken"));
        string memory tokenSymbol = vm.envOr("TOKEN_SYMBOL", string("TST"));

        if (testToken == address(0) && shouldDeployTestToken()) {
            uint8 decimals = uint8(vm.envOr("TOKEN_DECIMALS", uint256(18)));
            testToken = address(new TestToken(tokenName, tokenSymbol, decimals));
            testTokenDeployed = true;
            console2.log("TestToken deployed at:", testToken);
        } else if (testToken != address(0)) {
            console2.log("Reusing TestToken at:", testToken);
        } else {
            console2.log("Skipping TestToken deployment - using custom tokens for currencies");
        }

        // Deploy or reuse GlobalParams
        if (globalParams == address(0)) {
            (bytes32[] memory currencies, address[][] memory tokensPerCurrency) = loadCurrenciesAndTokens(testToken);

            // Deploy GlobalParams with UUPS proxy
            GlobalParams globalParamsImpl = new GlobalParams();
            globalParamsImplementation = address(globalParamsImpl);
            bytes memory globalParamsInitData = abi.encodeWithSelector(
                GlobalParams.initialize.selector, deployerAddress, protocolFeePercent, currencies, tokensPerCurrency
            );
            ERC1967Proxy globalParamsProxy = new ERC1967Proxy(address(globalParamsImpl), globalParamsInitData);
            globalParams = address(globalParamsProxy);
            globalParamsDeployed = true;
            console2.log("GlobalParams proxy deployed at:", globalParams);
            console2.log("  Implementation:", globalParamsImplementation);
        } else {
            console2.log("Reusing GlobalParams at:", globalParams);
        }

        // GlobalParams is required to continue
        require(globalParams != address(0), "GlobalParams address is required");

        // Deploy CampaignInfo implementation if needed for new deployments
        if (campaignInfoFactory == address(0)) {
            campaignInfo = address(new CampaignInfo());
            console2.log("CampaignInfo deployed at:", campaignInfo);
        }

        // Deploy or reuse TreasuryFactory
        if (treasuryFactory == address(0)) {
            // Deploy TreasuryFactory with UUPS proxy
            TreasuryFactory treasuryFactoryImpl = new TreasuryFactory();
            treasuryFactoryImplementation = address(treasuryFactoryImpl);
            bytes memory treasuryFactoryInitData =
                abi.encodeWithSelector(TreasuryFactory.initialize.selector, IGlobalParams(globalParams));
            ERC1967Proxy treasuryFactoryProxy = new ERC1967Proxy(address(treasuryFactoryImpl), treasuryFactoryInitData);
            treasuryFactory = address(treasuryFactoryProxy);
            treasuryFactoryDeployed = true;
            console2.log("TreasuryFactory proxy deployed at:", treasuryFactory);
            console2.log("  Implementation:", treasuryFactoryImplementation);
        } else {
            console2.log("Reusing TreasuryFactory at:", treasuryFactory);
        }

        // Deploy or reuse CampaignInfoFactory
        if (campaignInfoFactory == address(0)) {
            // Deploy CampaignInfoFactory with UUPS proxy
            CampaignInfoFactory campaignFactoryImpl = new CampaignInfoFactory();
            campaignInfoFactoryImplementation = address(campaignFactoryImpl);
            bytes memory campaignFactoryInitData = abi.encodeWithSelector(
                CampaignInfoFactory.initialize.selector,
                deployerAddress,
                IGlobalParams(globalParams),
                campaignInfo,
                treasuryFactory
            );
            ERC1967Proxy campaignFactoryProxy = new ERC1967Proxy(address(campaignFactoryImpl), campaignFactoryInitData);
            campaignInfoFactory = address(campaignFactoryProxy);
            campaignInfoFactoryDeployed = true;
            console2.log("CampaignInfoFactory proxy deployed at:", campaignInfoFactory);
            console2.log("  Implementation:", campaignInfoFactoryImplementation);
        } else {
            console2.log("Reusing CampaignInfoFactory at:", campaignInfoFactory);
        }

        // Deploy or reuse KeepWhatsRaised implementation
        if (keepWhatsRaisedImplementation == address(0)) {
            keepWhatsRaisedImplementation = address(new KeepWhatsRaised());
            keepWhatsRaisedDeployed = true;
            console2.log("KeepWhatsRaised implementation deployed at:", keepWhatsRaisedImplementation);
        } else {
            console2.log("Reusing KeepWhatsRaised implementation at:", keepWhatsRaisedImplementation);
        }
    }

    // Setup steps when deployer has all roles
    function enlistPlatform() internal {
        // Skip if we didn't deploy GlobalParams (assuming it's already set up)
        if (!globalParamsDeployed) {
            console2.log("Skipping enlistPlatform - using existing GlobalParams");
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
            platformFeePercent,
            platformAdapter // Platform adapter (trusted forwarder) - can be set later with setPlatformAdapter
        );

        if (simulate) {
            vm.stopPrank();
        }
        platformEnlisted = true;
        console2.log("Platform enlisted successfully");
    }

    function registerTreasuryImplementation() internal {
        // Skip only if both TreasuryFactory and implementation are reused (assuming already set up)
        if (!treasuryFactoryDeployed && !keepWhatsRaisedDeployed) {
            console2.log("Skipping registerTreasuryImplementation - using existing contracts");
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
            keepWhatsRaisedImplementation
        );

        if (simulate) {
            vm.stopPrank();
        }
        implementationRegistered = true;
        console2.log("Treasury implementation registered successfully");
    }

    function approveTreasuryImplementation() internal {
        // Skip only if both TreasuryFactory and implementation are reused (assuming already set up)
        if (!treasuryFactoryDeployed && !keepWhatsRaisedDeployed) {
            console2.log("Skipping approveTreasuryImplementation - using existing contracts");
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
        // Only mint tokens if we deployed TestToken
        if (!testTokenDeployed) {
            console2.log("Skipping mintTokens - using existing TestToken");
            return;
        }

        if (backer1 != address(0) && backer2 != address(0)) {
            console2.log("Minting tokens to test backers");
            TestToken(testToken).mint(backer1, tokenMintAmount);
            if (backer1 != backer2) {
                TestToken(testToken).mint(backer2, tokenMintAmount);
            }
            console2.log("Tokens minted successfully");
        }
    }

    // Transfer admin rights to final addresses
    function transferAdminRights() internal {
        // Skip if we didn't deploy GlobalParams (assuming it's already set up)
        if (!globalParamsDeployed) {
            console2.log("Skipping transferAdminRights - using existing GlobalParams");
            adminRightsTransferred = true;
            return;
        }

        console2.log("Transferring admin rights to final addresses...");
        // Only use startPrank in simulation mode
        if (simulate) {
            vm.startPrank(deployerAddress);
        }

        // Only transfer if the final addresses are different from deployer
        if (finalPlatformAdmin != deployerAddress) {
            console2.log("Updating platform admin address for platform hash:", vm.toString(platformHash));
            GlobalParams(globalParams).updatePlatformAdminAddress(platformHash, finalPlatformAdmin);
        }

        if (finalProtocolAdmin != deployerAddress) {
            console2.log("Transferring protocol admin rights to:", finalProtocolAdmin);
            GlobalParams(globalParams).updateProtocolAdminAddress(finalProtocolAdmin);

            //Transfer admin rights to the final protocol admin
            GlobalParams(globalParams).transferOwnership(finalProtocolAdmin);
            console2.log("GlobalParams transferred to:", finalProtocolAdmin);
            if (campaignInfoFactoryDeployed) {
                CampaignInfoFactory(campaignInfoFactory).transferOwnership(finalProtocolAdmin);
                console2.log("CampaignInfoFactory transferred to:", finalProtocolAdmin);
            }
        }

        if (simulate) {
            vm.stopPrank();
        }

        adminRightsTransferred = true;
        console2.log("Admin rights transferred successfully");
    }

    function run() external {
        // Load configuration
        setupParams();

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        // Start broadcast with deployer key (skip in simulation mode)
        if (!simulate) {
            vm.startBroadcast(deployerKey);
        }

        // Deploy or reuse contracts
        deployContracts();
        setRegistryValues();

        // Setup the protocol with individual transactions in the correct order
        // Since deployer is both protocol and platform admin initially, we can do all steps
        enlistPlatform();
        registerTreasuryImplementation();
        approveTreasuryImplementation();

        // Mint tokens if needed
        mintTokens();

        // Finally, transfer admin rights to the final addresses
        transferAdminRights();

        // Stop broadcast (skip in simulation mode)
        if (!simulate) {
            vm.stopBroadcast();
        }

        // Output summary
        console2.log("\n===========================================");
        console2.log("    Deployment & Setup Summary");
        console2.log("===========================================");
        console2.log("\n--- Core Protocol Contracts (UUPS Proxies) ---");
        console2.log("GLOBAL_PARAMS_PROXY:", globalParams);
        if (globalParamsImplementation != address(0)) {
            console2.log("  Implementation:", globalParamsImplementation);
        }
        console2.log("TREASURY_FACTORY_PROXY:", treasuryFactory);
        if (treasuryFactoryImplementation != address(0)) {
            console2.log("  Implementation:", treasuryFactoryImplementation);
        }
        console2.log("CAMPAIGN_INFO_FACTORY_PROXY:", campaignInfoFactory);
        if (campaignInfoFactoryImplementation != address(0)) {
            console2.log("  Implementation:", campaignInfoFactoryImplementation);
        }

        console2.log("\n--- Treasury Implementation Contracts ---");
        if (campaignInfo != address(0)) {
            console2.log("CAMPAIGN_INFO_IMPLEMENTATION:", campaignInfo);
        }
        console2.log("KEEP_WHATS_RAISED_IMPLEMENTATION:", keepWhatsRaisedImplementation);

        console2.log("\n--- Platform Configuration ---");
        console2.log("Platform Name Hash:", vm.toString(platformHash));
        console2.log("Protocol Admin:", finalProtocolAdmin);
        console2.log("Platform Admin:", finalPlatformAdmin);
        console2.log("Platform Adapter (Trusted Forwarder):", platformAdapter);
        console2.log("GlobalParams owner:", GlobalParams(globalParams).owner());
        console2.log("CampaignInfoFactory owner:", CampaignInfoFactory(campaignInfoFactory).owner());

        console2.log("\n--- Supported Currencies & Tokens ---");
        string memory currenciesConfig = vm.envOr("CURRENCIES", string(""));
        if (bytes(currenciesConfig).length > 0) {
            string[] memory currencyStrings = _split(currenciesConfig, ",");
            string memory tokensConfig = vm.envOr("TOKENS_PER_CURRENCY", string(""));
            string[] memory perCurrencyConfigs = _split(tokensConfig, ";");

            for (uint256 i = 0; i < currencyStrings.length; i++) {
                string memory currency = _trimWhitespace(currencyStrings[i]);
                console2.log(string(abi.encodePacked("Currency: ", currency)));

                string[] memory tokenStrings = _split(perCurrencyConfigs[i], ",");
                for (uint256 j = 0; j < tokenStrings.length; j++) {
                    console2.log("  Token:", _trimWhitespace(tokenStrings[j]));
                }
            }
        } else {
            console2.log("Currency: USD (default)");
            console2.log("  Token:", testToken);
            if (testTokenDeployed) {
                console2.log("  (TestToken deployed for testing)");
            }
        }

        if (backer1 != address(0)) {
            console2.log("\n--- Test Backers (Tokens Minted) ---");
            console2.log("Backer1:", backer1);
            if (backer2 != address(0) && backer1 != backer2) {
                console2.log("Backer2:", backer2);
            }
        }

        console2.log("\n--- Setup Steps ---");
        console2.log("Platform enlisted:", platformEnlisted);
        console2.log("Treasury implementation registered:", implementationRegistered);
        console2.log("Treasury implementation approved:", implementationApproved);
        console2.log("Admin rights transferred:", adminRightsTransferred);

        console2.log("\n===========================================");
        console2.log("Deployment and setup completed successfully!");
        console2.log("===========================================");
    }
}
