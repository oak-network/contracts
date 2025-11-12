// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Counters} from "./Counters.sol";

/**
 * @title PledgeNFT
 * @notice Abstract contract for NFTs representing pledges with on-chain metadata
 * @dev Contains counter logic and NFT metadata storage
 */
abstract contract PledgeNFT is ERC721Burnable, AccessControl {
    using Strings for uint256;
    using Strings for address;
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;

    /**
     * @dev Struct to store pledge data for each token
     */
    struct PledgeData {
        address backer;
        bytes32 reward;
        address treasury;
        address tokenAddress;
        uint256 amount;
        uint256 shippingFee;
        uint256 tipAmount;
    }

    // NFT metadata storage
    string internal s_nftName;
    string internal s_nftSymbol;
    string internal s_imageURI;
    string internal s_contractURI;
    
    // Token ID counter (also serves as pledge ID counter)
    Counters.Counter internal s_tokenIdCounter;

    // Mapping from token ID to pledge data
    mapping(uint256 => PledgeData) internal s_pledgeData;

    /**
     * @dev Emitted when the image URI is updated
     * @param newImageURI The new image URI
     */
    event ImageURIUpdated(string newImageURI);

    /**
     * @dev Emitted when the contract URI is updated
     * @param newContractURI The new contract URI
     */
    event ContractURIUpdated(string newContractURI);

    /**
     * @dev Emitted when a pledge NFT is minted
     * @param tokenId The token ID
     * @param backer The backer address
     * @param treasury The treasury address
     * @param reward The reward identifier
     */
    event PledgeNFTMinted(
        uint256 indexed tokenId,
        address indexed backer,
        address indexed treasury,
        bytes32 reward
    );

    /**
     * @dev Emitted when unauthorized access is attempted
     */
    error PledgeNFTUnAuthorized();

    /**
     * @notice Initialize NFT metadata
     * @dev Called by CampaignInfo during initialization
     * @param _nftName NFT collection name
     * @param _nftSymbol NFT collection symbol
     * @param _imageURI NFT image URI for individual tokens
     * @param _contractURI IPFS URI for contract-level metadata
     */
    function _initializeNFT(
        string calldata _nftName,
        string calldata _nftSymbol,
        string calldata _imageURI,
        string calldata _contractURI
    ) internal {
        s_nftName = _nftName;
        s_nftSymbol = _nftSymbol;
        s_imageURI = _imageURI;
        s_contractURI = _contractURI;
    }

    /**
     * @notice Mints a pledge NFT (auto-increments counter)
     * @dev Called by treasuries - returns the new token ID to use as pledge ID
     * @param backer The backer address
     * @param reward The reward identifier
     * @param tokenAddress The address of the token used for the pledge
     * @param amount The pledge amount
     * @param shippingFee The shipping fee
     * @param tipAmount The tip amount
     * @return tokenId The minted token ID (to be used as pledge ID in treasury)
     */
    function mintNFTForPledge(
        address backer,
        bytes32 reward,
        address tokenAddress,
        uint256 amount,
        uint256 shippingFee,
        uint256 tipAmount
    ) public virtual onlyRole(MINTER_ROLE) returns (uint256 tokenId) {
        // Increment counter and get new token ID
        s_tokenIdCounter.increment();
        tokenId = s_tokenIdCounter.current();
        
        // Set pledge data
        s_pledgeData[tokenId] = PledgeData({
            backer: backer,
            reward: reward,
            treasury: _msgSender(),
            tokenAddress: tokenAddress,
            amount: amount,
            shippingFee: shippingFee,
            tipAmount: tipAmount
        });
        
        // Mint NFT
        _safeMint(backer, tokenId);
        
        emit PledgeNFTMinted(tokenId, backer, msg.sender, reward);
        
        return tokenId;
    }

    /**
     * @notice Burns a pledge NFT
     * @param tokenId The token ID to burn
     */
    function burn(uint256 tokenId) public virtual override {
        delete s_pledgeData[tokenId];
        super.burn(tokenId);
    }

    /**
     * @notice Override name to return initialized name
     * @return The NFT collection name
     */
    function name() public view virtual override returns (string memory) {
        return s_nftName;
    }

    /**
     * @notice Override symbol to return initialized symbol
     * @return The NFT collection symbol
     */
    function symbol() public view virtual override returns (string memory) {
        return s_nftSymbol;
    }

    /**
     * @notice Sets the image URI for all NFTs
     * @dev Must be overridden by inheriting contracts to implement access control
     * @param newImageURI The new image URI
     */
    function setImageURI(string calldata newImageURI) external virtual;

    /**
     * @notice Returns contract-level metadata URI
     * @return The contract URI
     */
    function contractURI() external view virtual returns (string memory) {
        return s_contractURI;
    }

    /**
     * @notice Update contract-level metadata URI
     * @dev Must be overridden by inheriting contracts to implement access control
     * @param newContractURI The new contract URI
     */
    function updateContractURI(string calldata newContractURI) external virtual;

    /**
     * @notice Gets current total number of pledges
     * @return The current pledge count
     */
    function getPledgeCount() external view virtual returns (uint256) {
        return s_tokenIdCounter.current();
    }

    /**
     * @notice Returns the token URI with on-chain metadata
     * @param tokenId The token ID
     * @return The base64 encoded JSON metadata
     */
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        _requireOwned(tokenId);

        PledgeData memory data = s_pledgeData[tokenId];
        
        string memory json = string(
            abi.encodePacked(
                '{"name":"', name(), " #", tokenId.toString(),
                '","image":"', s_imageURI,
                '","attributes":[',
                '{"trait_type":"Backer","value":"', Strings.toHexString(uint160(data.backer), 20), '"},',
                '{"trait_type":"Reward","value":"', Strings.toHexString(uint256(data.reward), 32), '"},',
                '{"trait_type":"Treasury","value":"', Strings.toHexString(uint160(data.treasury), 20), '"},',
                '{"trait_type":"Campaign","value":"', Strings.toHexString(uint160(address(this)), 20), '"},',
                '{"trait_type":"PledgeToken","value":"', Strings.toHexString(uint160(data.tokenAddress), 20), '"},',
                '{"trait_type":"PledgeAmount","value":"', data.amount.toString(), '"},',
                '{"trait_type":"ShippingFee","value":"', data.shippingFee.toString(), '"},',
                '{"trait_type":"TipAmount","value":"', data.tipAmount.toString(), '"}',
                "]}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /**
     * @notice Gets the image URI
     * @return The current image URI
     */
    function getImageURI() external view returns (string memory) {
        return s_imageURI;
    }

    /**
     * @notice Gets the pledge data for a token
     * @param tokenId The token ID
     * @return The pledge data
     */
    function getPledgeData(uint256 tokenId) external view returns (PledgeData memory) {
        return s_pledgeData[tokenId];
    }

    /**
     * @dev Internal function to set pledge data for a token
     * @param tokenId The token ID
     * @param backer The backer address
     * @param reward The reward identifier
     * @param tokenAddress The address of the token used for the pledge
     * @param amount The pledge amount
     * @param shippingFee The shipping fee
     * @param tipAmount The tip amount
     */

    /**
     * @notice Override supportsInterface for multiple inheritance
     * @param interfaceId The interface ID
     * @return True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

