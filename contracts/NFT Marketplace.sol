// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title NFTMarketplace
 * @dev A simple NFT marketplace where users can mint, list, and buy NFTs
 */
contract NFTMarketplace is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    // Marketplace fee percentage (2%)
    uint256 public marketplaceFee = 200; // 200 = 2% (basis points)
    uint256 public constant MAX_FEE = 10000; // 100%
    
    // Structure for NFT market item
    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        uint256 price;
        bool isListed;
    }
    
    // Mapping from token ID to market item details
    mapping(uint256 => MarketItem) private marketItems;
    
    // Events
    event NFTMinted(uint256 tokenId, address creator, string tokenURI);
    event NFTListed(uint256 tokenId, address seller, uint256 price);
    event NFTPurchased(uint256 tokenId, address seller, address buyer, uint256 price);
    
    constructor() ERC721("NFT Marketplace", "NFTM") Ownable(msg.sender) {}
    
    /**
     * @dev Creates a new NFT token
     * @param tokenURI The URI containing the metadata for the NFT
     * @return The newly created token ID
     */
    function createNFT(string memory tokenURI) public returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        
        emit NFTMinted(newTokenId, msg.sender, tokenURI);
        
        return newTokenId;
    }
    
    /**
     * @dev Lists an NFT for sale in the marketplace
     * @param tokenId ID of the NFT to list
     * @param price Price of the NFT in wei
     */
    function listNFT(uint256 tokenId, uint256 price) public {
        require(ownerOf(tokenId) == msg.sender, "Only the owner can list this NFT");
        require(price > 0, "Price must be greater than 0");
        
        // Transfer ownership to the contract
        approve(address(this), tokenId);
        
        marketItems[tokenId] = MarketItem({
            tokenId: tokenId,
            seller: payable(msg.sender),
            price: price,
            isListed: true
        });
        
        emit NFTListed(tokenId, msg.sender, price);
    }
    
    /**
     * @dev Allows a user to purchase a listed NFT
     * @param tokenId ID of the NFT to purchase
     */
    function buyNFT(uint256 tokenId) public payable {
        MarketItem storage item = marketItems[tokenId];
        require(item.isListed, "NFT is not listed for sale");
        require(msg.value >= item.price, "Insufficient funds sent");
        
        address seller = item.seller;
        uint256 price = item.price;
        
        // Calculate marketplace fee
        uint256 fee = (price * marketplaceFee) / MAX_FEE;
        uint256 sellerAmount = price - fee;
        
        // Transfer NFT to buyer
        _transfer(address(this), msg.sender, tokenId);
        
        // Transfer funds to seller
        (bool success, ) = payable(seller).call{value: sellerAmount}("");
        require(success, "Transfer to seller failed");
        
        // Mark as no longer listed
        item.isListed = false;
        delete marketItems[tokenId];
        
        emit NFTPurchased(tokenId, seller, msg.sender, price);
    }
    
    /**
     * @dev Allows owner to update the marketplace fee
     * @param newFee New fee in basis points (e.g., 250 = 2.5%)
     */
    function updateMarketplaceFee(uint256 newFee) public onlyOwner {
        require(newFee <= 1000, "Fee cannot exceed 10%");
        marketplaceFee = newFee;
    }
}
