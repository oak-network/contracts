// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Base_Test} from "../../Base.t.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import {PaymentTreasury} from "src/treasuries/PaymentTreasury.sol";
import {CampaignInfo} from "src/CampaignInfo.sol";
import {ICampaignPaymentTreasury} from "src/interfaces/ICampaignPaymentTreasury.sol";
import {LogDecoder} from "../../utils/LogDecoder.sol";

/// @notice Common testing logic needed by all PaymentTreasury integration tests.
abstract contract PaymentTreasury_Integration_Shared_Test is LogDecoder, Base_Test {
    address campaignAddress;
    address treasuryAddress;
    PaymentTreasury internal paymentTreasury;

    // Payment test data
    bytes32 internal constant PAYMENT_ID_1 = keccak256("payment1");
    bytes32 internal constant PAYMENT_ID_2 = keccak256("payment2");
    bytes32 internal constant PAYMENT_ID_3 = keccak256("payment3");
    bytes32 internal constant ITEM_ID_1 = keccak256("item1");
    bytes32 internal constant ITEM_ID_2 = keccak256("item2");
    uint256 internal constant PAYMENT_AMOUNT_1 = 1000e18;
    uint256 internal constant PAYMENT_AMOUNT_2 = 2000e18;
    uint256 internal constant PAYMENT_EXPIRATION = 7 days;
    bytes32 internal constant BUYER_ID_1 = keccak256("buyer1");
    bytes32 internal constant BUYER_ID_2 = keccak256("buyer2");
    bytes32 internal constant BUYER_ID_3 = keccak256("buyer3");

    /// @dev Initial dependent functions setup included for PaymentTreasury Integration Tests.
    function setUp() public virtual override {
        super.setUp();
        console.log("setUp: enlistPlatform");

        // Enlist Platform
        enlistPlatform(PLATFORM_1_HASH);
        console.log("enlisted platform");

        registerTreasuryImplementation(PLATFORM_1_HASH);
        console.log("registered treasury");

        approveTreasuryImplementation(PLATFORM_1_HASH);
        console.log("approved treasury");

        // Create Campaign
        createCampaign(PLATFORM_1_HASH);
        console.log("created campaign");

        // Deploy Treasury Contract
        deploy(PLATFORM_1_HASH);
        console.log("deployed treasury");
    }

    /**
     * @notice Implements enlistPlatform helper function.
     * @param platformHash The platform bytes.
     */
    function enlistPlatform(bytes32 platformHash) internal {
        vm.startPrank(users.protocolAdminAddress);
        globalParams.enlistPlatform(platformHash, users.platform1AdminAddress, PLATFORM_FEE_PERCENT);
        vm.stopPrank();
    }

    function registerTreasuryImplementation(bytes32 platformHash) internal {
        PaymentTreasury implementation = new PaymentTreasury();
        vm.startPrank(users.platform1AdminAddress);
        treasuryFactory.registerTreasuryImplementation(platformHash, 2, address(implementation));
        vm.stopPrank();
    }

    function approveTreasuryImplementation(bytes32 platformHash) internal {
        vm.startPrank(users.protocolAdminAddress);
        treasuryFactory.approveTreasuryImplementation(platformHash, 2);
        vm.stopPrank();
    }

    /**
     * @notice Implements createCampaign helper function. It creates new campaign info contract
     * @param platformHash The platform bytes.
     */
    function createCampaign(bytes32 platformHash) internal {
        bytes32 identifierHash = keccak256(abi.encodePacked(platformHash));
        bytes32[] memory selectedPlatformHash = new bytes32[](1);
        selectedPlatformHash[0] = platformHash;

        bytes32[] memory platformDataKey = new bytes32[](0);
        bytes32[] memory platformDataValue = new bytes32[](0);

        vm.startPrank(users.creator1Address);
        vm.recordLogs();

        campaignInfoFactory.createCampaign(
            users.creator1Address,
            identifierHash,
            selectedPlatformHash,
            platformDataKey,
            platformDataValue,
            CAMPAIGN_DATA
        );

        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        (bytes32[] memory topics,) = decodeTopicsAndData(
            entries, "CampaignInfoFactoryCampaignCreated(bytes32,address)", address(campaignInfoFactory)
        );

        require(topics.length == 3, "Unexpected topic length for event");

        campaignAddress = address(uint160(uint256(topics[2])));
    }

    /**
     * @notice Implements deploy helper function. It deploys treasury contract.
     */
    function deploy(bytes32 platformHash) internal {
        vm.startPrank(users.platform1AdminAddress);
        vm.recordLogs();

        // Deploy the treasury contract with implementation ID 2 for PaymentTreasury
        treasuryFactory.deploy(platformHash, campaignAddress, 2, NAME, SYMBOL);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        (bytes32[] memory topics, bytes memory data) = decodeTopicsAndData(
            entries, "TreasuryFactoryTreasuryDeployed(bytes32,uint256,address,address)", address(treasuryFactory)
        );

        require(topics.length >= 3, "Expected indexed params missing");

        treasuryAddress = abi.decode(data, (address));
        paymentTreasury = PaymentTreasury(treasuryAddress);
    }

    /**
     * @notice Creates a payment
     */
    function createPayment(
        address caller,
        bytes32 paymentId,
        bytes32 buyerId,
        bytes32 itemId,
        uint256 amount,
        uint256 expiration
    ) internal {
        vm.prank(caller);
        paymentTreasury.createPayment(paymentId, buyerId, itemId, amount, expiration);
    }

    /**
     * @notice Cancels a payment
     */
    function cancelPayment(address caller, bytes32 paymentId) internal {
        vm.prank(caller);
        paymentTreasury.cancelPayment(paymentId);
    }

    /**
     * @notice Confirms a payment
     */
    function confirmPayment(address caller, bytes32 paymentId) internal {
        vm.prank(caller);
        paymentTreasury.confirmPayment(paymentId);
    }

    /**
     * @notice Confirms multiple payments in batch
     */
    function confirmPaymentBatch(address caller, bytes32[] memory paymentIds) internal {
        vm.prank(caller);
        paymentTreasury.confirmPaymentBatch(paymentIds);
    }

    /**
     * @notice Claims a refund
     */
    function claimRefund(address caller, bytes32 paymentId, address refundAddress) 
        internal 
        returns (uint256 refundAmount) 
    {
        vm.startPrank(caller);
        vm.recordLogs();
        
        paymentTreasury.claimRefund(paymentId, refundAddress);
        
        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        (bytes32[] memory topics, bytes memory data) = decodeTopicsAndData(
            logs, "RefundClaimed(bytes32,uint256,address)", treasuryAddress
        );
        
        refundAmount = abi.decode(data, (uint256));
        
        vm.stopPrank();
    }

    /**
     * @notice Disburses fees
     */
    function disburseFees(address treasury)
        internal
        returns (uint256 protocolShare, uint256 platformShare)
    {
        vm.recordLogs();

        PaymentTreasury(treasury).disburseFees();

        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes memory data = decodeEventFromLogs(logs, "FeesDisbursed(uint256,uint256)", treasury);

        (protocolShare, platformShare) = abi.decode(data, (uint256, uint256));
    }

    /**
     * @notice Withdraws funds
     */
    function withdraw(address treasury)
        internal
        returns (address to, uint256 amount)
    {
        vm.recordLogs();

        PaymentTreasury(treasury).withdraw();

        Vm.Log[] memory logs = vm.getRecordedLogs();

        (bytes32[] memory topics, bytes memory data) =
            decodeTopicsAndData(logs, "WithdrawalSuccessful(address,uint256)", treasury);

        to = address(uint160(uint256(topics[1])));
        amount = abi.decode(data, (uint256));
    }

    /**
     * @notice Pauses the treasury
     */
    function pauseTreasury(address caller, address treasury, bytes32 message) internal {
        vm.prank(caller);
        PaymentTreasury(treasury).pauseTreasury(message);
    }

    /**
     * @notice Unpauses the treasury
     */
    function unpauseTreasury(address caller, address treasury, bytes32 message) internal {
        vm.prank(caller);
        PaymentTreasury(treasury).unpauseTreasury(message);
    }

    /**
     * @notice Cancels the treasury
     */
    function cancelTreasury(address caller, address treasury, bytes32 message) internal {
        vm.prank(caller);
        PaymentTreasury(treasury).cancelTreasury(message);
    }

    /**
     * @notice Helper to create and fund a payment from buyer
     */
    function _createAndFundPayment(
        bytes32 paymentId,
        bytes32 buyerId,
        bytes32 itemId,
        uint256 amount,
        address buyerAddress
    ) internal {
        // Fund buyer
        deal(address(testToken), buyerAddress, amount);
        
        // Buyer approves treasury
        vm.prank(buyerAddress);
        testToken.approve(treasuryAddress, amount);
        
        // Create payment
        uint256 expiration = block.timestamp + PAYMENT_EXPIRATION;
        createPayment(users.platform1AdminAddress, paymentId, buyerId, itemId, amount, expiration);
        
        // Transfer tokens from buyer to treasury
        vm.prank(buyerAddress);
        testToken.transfer(treasuryAddress, amount);
    }

    /**
     * @notice Helper to create multiple test payments
     */
    function _createTestPayments() internal {
        _createAndFundPayment(PAYMENT_ID_1, BUYER_ID_1, ITEM_ID_1, PAYMENT_AMOUNT_1, users.backer1Address);
        _createAndFundPayment(PAYMENT_ID_2, BUYER_ID_2, ITEM_ID_2, PAYMENT_AMOUNT_2, users.backer2Address);
    }
}