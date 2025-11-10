// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import {Users} from "./utils/Types.sol";
import {Defaults} from "./utils/Defaults.sol";
import {TestToken} from "../mocks/TestToken.sol";
import {GlobalParams} from "src/GlobalParams.sol";
import {CampaignInfoFactory} from "src/CampaignInfoFactory.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {TreasuryFactory} from "src/TreasuryFactory.sol";
import {AllOrNothing} from "src/treasuries/AllOrNothing.sol";
import {KeepWhatsRaised} from "src/treasuries/KeepWhatsRaised.sol";
import {IGlobalParams} from "src/interfaces/IGlobalParams.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DataRegistryKeys} from "src/constants/DataRegistryKeys.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Test is Test, Defaults {
    //Variables
    Users internal users;

    //Test Contracts - Multiple tokens for multi-token testing
    TestToken internal usdtToken;  // 6 decimals - Tether
    TestToken internal usdcToken;  // 6 decimals - USD Coin
    TestToken internal cUSDToken;  // 18 decimals - Celo Dollar
    
    // Legacy support - points to cUSDToken for backward compatibility
    TestToken internal testToken;
    
    GlobalParams internal globalParams;
    CampaignInfoFactory internal campaignInfoFactory;
    TreasuryFactory internal treasuryFactory;
    AllOrNothing internal allOrNothingImplementation;
    KeepWhatsRaised internal keepWhatsRaisedImplementation;
    CampaignInfo internal campaignInfo;

    function setUp() public virtual {
        // Create users for testing.
        users = Users({
            contractOwner: createUser("ContractOwner"),
            protocolAdminAddress: createUser("ProtocolAdminAddress"),
            platform1AdminAddress: createUser("Platform1AdminAddress"),
            platform2AdminAddress: createUser("Platform2AdminAddress"),
            creator1Address: createUser("Creator1Address"),
            creator2Address: createUser("Creator2Address"),
            backer1Address: createUser("Backer1Address"),
            backer2Address: createUser("Backer2Address")
        });

        vm.startPrank(users.contractOwner);

        // Deploy multiple test tokens with different decimals
        usdtToken = new TestToken("Tether USD", "USDT", 6);
        usdcToken = new TestToken("USD Coin", "USDC", 6);
        cUSDToken = new TestToken("Celo Dollar", "cUSD", 18);
        
        // Backward compatibility
        testToken = cUSDToken;
        
        // Setup currencies and tokens for multi-token support
        bytes32[] memory currencies = new bytes32[](1);
        currencies[0] = bytes32("USD");
        
        address[][] memory tokensPerCurrency = new address[][](1);
        tokensPerCurrency[0] = new address[](3);
        tokensPerCurrency[0][0] = address(usdtToken);
        tokensPerCurrency[0][1] = address(usdcToken);
        tokensPerCurrency[0][2] = address(cUSDToken);
        
        // Deploy GlobalParams with UUPS proxy
        GlobalParams globalParamsImpl = new GlobalParams();
        bytes memory globalParamsInitData = abi.encodeWithSelector(
            GlobalParams.initialize.selector,
            users.protocolAdminAddress,
            PROTOCOL_FEE_PERCENT,
            currencies,
            tokensPerCurrency
        );
        ERC1967Proxy globalParamsProxy = new ERC1967Proxy(
            address(globalParamsImpl),
            globalParamsInitData
        );
        globalParams = GlobalParams(address(globalParamsProxy));

        // Deploy CampaignInfo implementation
        campaignInfo = new CampaignInfo();
        console.log("CampaignInfo address: ", address(campaignInfo));

        // Deploy TreasuryFactory with UUPS proxy
        TreasuryFactory treasuryFactoryImpl = new TreasuryFactory();
        bytes memory treasuryFactoryInitData = abi.encodeWithSelector(
            TreasuryFactory.initialize.selector,
            IGlobalParams(address(globalParams))
        );
        ERC1967Proxy treasuryFactoryProxy = new ERC1967Proxy(
            address(treasuryFactoryImpl),
            treasuryFactoryInitData
        );
        treasuryFactory = TreasuryFactory(address(treasuryFactoryProxy));

        // Deploy CampaignInfoFactory with UUPS proxy
        CampaignInfoFactory campaignFactoryImpl = new CampaignInfoFactory();
        bytes memory campaignFactoryInitData = abi.encodeWithSelector(
            CampaignInfoFactory.initialize.selector,
            users.contractOwner,
            IGlobalParams(address(globalParams)),
            address(campaignInfo),
            address(treasuryFactory)
        );
        ERC1967Proxy campaignFactoryProxy = new ERC1967Proxy(
            address(campaignFactoryImpl),
            campaignFactoryInitData
        );
        campaignInfoFactory = CampaignInfoFactory(address(campaignFactoryProxy));

        allOrNothingImplementation = new AllOrNothing();
        keepWhatsRaisedImplementation = new KeepWhatsRaised();
        
        vm.stopPrank();
        
        // Set time constraints in dataRegistry (requires protocol admin)
        vm.startPrank(users.protocolAdminAddress);
        globalParams.addToRegistry(
            DataRegistryKeys.CAMPAIGN_LAUNCH_BUFFER,
            bytes32(uint256(0)) // No buffer for most tests
        );
        globalParams.addToRegistry(
            DataRegistryKeys.MINIMUM_CAMPAIGN_DURATION,
            bytes32(uint256(0)) // No minimum duration for most tests
        );
        vm.stopPrank();
        
        vm.startPrank(users.contractOwner);
        //Mint tokens to backers - all three token types
        usdtToken.mint(users.backer1Address, TOKEN_MINT_AMOUNT / 1e12); // Adjust for 6 decimals
        usdtToken.mint(users.backer2Address, TOKEN_MINT_AMOUNT / 1e12);
        
        usdcToken.mint(users.backer1Address, TOKEN_MINT_AMOUNT / 1e12);
        usdcToken.mint(users.backer2Address, TOKEN_MINT_AMOUNT / 1e12);
        
        cUSDToken.mint(users.backer1Address, TOKEN_MINT_AMOUNT);
        cUSDToken.mint(users.backer2Address, TOKEN_MINT_AMOUNT);
        
        // Also mint to platform admins for setFeeAndPledge tests
        usdtToken.mint(users.platform1AdminAddress, TOKEN_MINT_AMOUNT / 1e12);
        usdcToken.mint(users.platform1AdminAddress, TOKEN_MINT_AMOUNT / 1e12);
        cUSDToken.mint(users.platform1AdminAddress, TOKEN_MINT_AMOUNT);
        
        usdtToken.mint(users.platform2AdminAddress, TOKEN_MINT_AMOUNT / 1e12);
        usdcToken.mint(users.platform2AdminAddress, TOKEN_MINT_AMOUNT / 1e12);
        cUSDToken.mint(users.platform2AdminAddress, TOKEN_MINT_AMOUNT);

        vm.stopPrank();

        // Label the base test contracts.
        vm.label({account: address(usdtToken), newLabel: "USDT"});
        vm.label({account: address(usdcToken), newLabel: "USDC"});
        vm.label({account: address(cUSDToken), newLabel: "cUSD"});
        vm.label({account: address(testToken), newLabel: "TestToken(cUSD)"});
        vm.label({
            account: address(globalParams),
            newLabel: "Global Parameter"
        });
        vm.label({
            account: address(campaignInfoFactory),
            newLabel: "Campaign Info Factory"
        });
        vm.label({
            account: address(treasuryFactory),
            newLabel: "Treasury Factory"
        });

        // Warp to October 1, 2023 at 00:00 GMT to provide a more realistic testing environment.
        vm.warp(OCTOBER_1_2023);
    }

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({account: user, newBalance: 100 ether});
        return user;
    }
    
    /// @dev Helper to get token amount adjusted for decimals
    function getTokenAmount(address token, uint256 baseAmount) internal view returns (uint256) {
        if (token == address(usdtToken) || token == address(usdcToken)) {
            return baseAmount / 1e12; // Convert 18 decimal amount to 6 decimal
        }
        return baseAmount; // 18 decimals (cUSD)
    }
}