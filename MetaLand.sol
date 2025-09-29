// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MetaLand {
    // Structure to represent a land parcel
    struct LandParcel {
        uint256 id;
        address owner;
        string location;
        uint256 size; // in square meters
        uint256 price; // in wei
        bool isForSale;
    }
    
    // State variables
    mapping(uint256 => LandParcel) public landParcels;
    uint256 public totalParcels;
    address public contractOwner;
    
    // Events
    event LandRegistered(uint256 indexed landId, address indexed owner, string location, uint256 size);
    event LandPurchased(uint256 indexed landId, address indexed previousOwner, address indexed newOwner, uint256 price);
    event LandListedForSale(uint256 indexed landId, uint256 price);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can perform this action");
        _;
    }
    
    modifier onlyLandOwner(uint256 _landId) {
        require(landParcels[_landId].owner == msg.sender, "You are not the owner of this land");
        _;
    }
    
    // Constructor
    constructor() {
        contractOwner = msg.sender;
        totalParcels = 0;
    }
    
    // Core Function 1: Register a new land parcel
    function registerLand(string memory _location, uint256 _size) public returns (uint256) {
        totalParcels++;
        
        landParcels[totalParcels] = LandParcel({
            id: totalParcels,
            owner: msg.sender,
            location: _location,
            size: _size,
            price: 0,
            isForSale: false
        });
        
        emit LandRegistered(totalParcels, msg.sender, _location, _size);
        return totalParcels;
    }
    
    // Core Function 2: List land for sale
    function listLandForSale(uint256 _landId, uint256 _price) public onlyLandOwner(_landId) {
        require(_landId > 0 && _landId <= totalParcels, "Invalid land ID");
        require(_price > 0, "Price must be greater than zero");
        
        landParcels[_landId].price = _price;
        landParcels[_landId].isForSale = true;
        
        emit LandListedForSale(_landId, _price);
    }
    
    // Core Function 3: Purchase land
    function purchaseLand(uint256 _landId) public payable {
        require(_landId > 0 && _landId <= totalParcels, "Invalid land ID");
        require(landParcels[_landId].isForSale, "Land is not for sale");
        require(msg.value >= landParcels[_landId].price, "Insufficient payment");
        require(msg.sender != landParcels[_landId].owner, "You already own this land");
        
        address previousOwner = landParcels[_landId].owner;
        uint256 price = landParcels[_landId].price;
        
        // Transfer ownership
        landParcels[_landId].owner = msg.sender;
        landParcels[_landId].isForSale = false;
        landParcels[_landId].price = 0;
        
        // Transfer payment to previous owner
        payable(previousOwner).transfer(price);
        
        // Refund excess payment
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
        
        emit LandPurchased(_landId, previousOwner, msg.sender, price);
    }
    
    // Helper function: Get land details
    function getLandDetails(uint256 _landId) public view returns (
        uint256 id,
        address owner,
        string memory location,
        uint256 size,
        uint256 price,
        bool isForSale
    ) {
        require(_landId > 0 && _landId <= totalParcels, "Invalid land ID");
        LandParcel memory land = landParcels[_landId];
        return (land.id, land.owner, land.location, land.size, land.price, land.isForSale);
    }
    
    // Helper function: Get user's lands
    function getMyLands() public view returns (uint256[] memory) {
        uint256 count = 0;
        
        // Count user's lands
        for (uint256 i = 1; i <= totalParcels; i++) {
            if (landParcels[i].owner == msg.sender) {
                count++;
            }
        }
        
        // Create array of user's land IDs
        uint256[] memory myLands = new uint256[](count);
        uint256 index = 0;
        
        for (uint256 i = 1; i <= totalParcels; i++) {
            if (landParcels[i].owner == msg.sender) {
                myLands[index] = i;
                index++;
            }
        }
        
        return myLands;
    }
}