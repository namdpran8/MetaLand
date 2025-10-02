// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MetaLand {
    // Enums for land attributes
    enum LandCategory { Residential, Commercial, Industrial, Agricultural, Recreational }
    enum RarityLevel { Common, Uncommon, Rare, Epic, Legendary }
    enum TerrainType { Plains, Mountains, Forest, Desert, Coastal, Urban }
    
    // Structure to represent a land parcel
    struct LandParcel {
        uint256 id;
        address owner;
        string location;
        uint256 size; // in square meters
        uint256 price; // in wei
        bool isForSale;
        
        // New attributes
        LandCategory category;
        RarityLevel rarity;
        TerrainType terrain;
        uint256 resourceLevel; // 0-100
        bool hasWater;
        bool hasMinerals;
        bool hasEnergy;
        uint256 developmentStage; // 0-10
        uint256 registrationTime;
        string[] previousOwners; // History of owners
    }
    
    // Structure for land neighborhoods
    struct Neighborhood {
        uint256 id;
        string name;
        uint256[] landIds;
        address creator;
        uint256 totalLands;
        bool isActive;
    }
    
    // State variables
    mapping(uint256 => LandParcel) public landParcels;
    mapping(uint256 => Neighborhood) public neighborhoods;
    mapping(uint256 => uint256) public landToNeighborhood; // landId => neighborhoodId
    mapping(address => uint256[]) public userLands;
    
    uint256 public totalParcels;
    uint256 public totalNeighborhoods;
    address public contractOwner;
    
    // Events
    event LandRegistered(
        uint256 indexed landId, 
        address indexed owner, 
        string location, 
        uint256 size,
        LandCategory category,
        RarityLevel rarity
    );
    event LandPurchased(
        uint256 indexed landId, 
        address indexed previousOwner, 
        address indexed newOwner, 
        uint256 price
    );
    event LandListedForSale(uint256 indexed landId, uint256 price);
    event LandsMerged(uint256 indexed newLandId, uint256[] mergedLandIds, address indexed owner);
    event LandSplit(uint256 indexed originalLandId, uint256[] newLandIds, address indexed owner);
    event LandAttributesUpdated(uint256 indexed landId, uint256 resourceLevel, uint256 developmentStage);
    event NeighborhoodCreated(uint256 indexed neighborhoodId, string name, address indexed creator);
    event LandAddedToNeighborhood(uint256 indexed landId, uint256 indexed neighborhoodId);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can perform this action");
        _;
    }
    
    modifier onlyLandOwner(uint256 _landId) {
        require(landParcels[_landId].owner == msg.sender, "You are not the owner of this land");
        _;
    }
    
    modifier validLandId(uint256 _landId) {
        require(_landId > 0 && _landId <= totalParcels, "Invalid land ID");
        _;
    }
    
    // Constructor
    constructor() {
        contractOwner = msg.sender;
        totalParcels = 0;
        totalNeighborhoods = 0;
    }
    
    // Core Function 1: Register a new land parcel with full attributes
    function registerLand(
        string memory _location,
        uint256 _size,
        LandCategory _category,
        RarityLevel _rarity,
        TerrainType _terrain,
        bool _hasWater,
        bool _hasMinerals,
        bool _hasEnergy
    ) public returns (uint256) {
        totalParcels++;
        
        // Generate initial resource level based on rarity
        uint256 resourceLevel = uint256(_rarity) * 20 + 10; // 10-90 based on rarity
        
        string[] memory ownerHistory = new string[](1);
        ownerHistory[0] = addressToString(msg.sender);
        
        landParcels[totalParcels] = LandParcel({
            id: totalParcels,
            owner: msg.sender,
            location: _location,
            size: _size,
            price: 0,
            isForSale: false,
            category: _category,
            rarity: _rarity,
            terrain: _terrain,
            resourceLevel: resourceLevel,
            hasWater: _hasWater,
            hasMinerals: _hasMinerals,
            hasEnergy: _hasEnergy,
            developmentStage: 0,
            registrationTime: block.timestamp,
            previousOwners: ownerHistory
        });
        
        userLands[msg.sender].push(totalParcels);
        
        emit LandRegistered(totalParcels, msg.sender, _location, _size, _category, _rarity);
        return totalParcels;
    }
    
    // Simplified register function for basic use
    function registerLandBasic(string memory _location, uint256 _size) public returns (uint256) {
        return registerLand(
            _location,
            _size,
            LandCategory.Residential,
            RarityLevel.Common,
            TerrainType.Plains,
            false,
            false,
            false
        );
    }
    
    // Core Function 2: List land for sale
    function listLandForSale(uint256 _landId, uint256 _price) 
        public 
        validLandId(_landId)
        onlyLandOwner(_landId) 
    {
        require(_price > 0, "Price must be greater than zero");
        
        landParcels[_landId].price = _price;
        landParcels[_landId].isForSale = true;
        
        emit LandListedForSale(_landId, _price);
    }
    
    // Core Function 3: Purchase land
    function purchaseLand(uint256 _landId) public payable validLandId(_landId) {
        require(landParcels[_landId].isForSale, "Land is not for sale");
        require(msg.value >= landParcels[_landId].price, "Insufficient payment");
        require(msg.sender != landParcels[_landId].owner, "You already own this land");
        
        address previousOwner = landParcels[_landId].owner;
        uint256 price = landParcels[_landId].price;
        
        // Update ownership
        landParcels[_landId].owner = msg.sender;
        landParcels[_landId].isForSale = false;
        landParcels[_landId].price = 0;
        
        // Update owner history
        landParcels[_landId].previousOwners.push(addressToString(msg.sender));
        
        // Update user lands mapping
        userLands[msg.sender].push(_landId);
        removeFromUserLands(previousOwner, _landId);
        
        // Transfer payment to previous owner
        payable(previousOwner).transfer(price);
        
        // Refund excess payment
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
        
        emit LandPurchased(_landId, previousOwner, msg.sender, price);
    }
    
    // NEW FEATURE: Merge multiple adjacent lands into one
    function mergeLands(uint256[] memory _landIds, string memory _newLocation) 
        public 
        returns (uint256) 
    {
        require(_landIds.length >= 2, "Need at least 2 lands to merge");
        require(_landIds.length <= 10, "Cannot merge more than 10 lands at once");
        
        uint256 totalSize = 0;
        uint256 avgResourceLevel = 0;
        uint256 maxDevelopmentStage = 0;
        bool mergedHasWater = false;
        bool mergedHasMinerals = false;
        bool mergedHasEnergy = false;
        
        // Verify ownership and calculate combined attributes
        for (uint256 i = 0; i < _landIds.length; i++) {
            require(landParcels[_landIds[i]].owner == msg.sender, "You must own all lands to merge");
            require(!landParcels[_landIds[i]].isForSale, "Cannot merge lands that are for sale");
            
            totalSize += landParcels[_landIds[i]].size;
            avgResourceLevel += landParcels[_landIds[i]].resourceLevel;
            
            if (landParcels[_landIds[i]].developmentStage > maxDevelopmentStage) {
                maxDevelopmentStage = landParcels[_landIds[i]].developmentStage;
            }
            
            if (landParcels[_landIds[i]].hasWater) mergedHasWater = true;
            if (landParcels[_landIds[i]].hasMinerals) mergedHasMinerals = true;
            if (landParcels[_landIds[i]].hasEnergy) mergedHasEnergy = true;
        }
        
        avgResourceLevel = avgResourceLevel / _landIds.length;
        
        // Determine rarity based on merged lands
        RarityLevel newRarity = RarityLevel.Uncommon; // Merged lands get boosted rarity
        if (_landIds.length >= 5) {
            newRarity = RarityLevel.Rare;
        }
        if (_landIds.length >= 8) {
            newRarity = RarityLevel.Epic;
        }
        
        // Create new merged land
        totalParcels++;
        string[] memory ownerHistory = new string[](1);
        ownerHistory[0] = addressToString(msg.sender);
        
        landParcels[totalParcels] = LandParcel({
            id: totalParcels,
            owner: msg.sender,
            location: _newLocation,
            size: totalSize,
            price: 0,
            isForSale: false,
            category: landParcels[_landIds[0]].category,
            rarity: newRarity,
            terrain: landParcels[_landIds[0]].terrain,
            resourceLevel: avgResourceLevel,
            hasWater: mergedHasWater,
            hasMinerals: mergedHasMinerals,
            hasEnergy: mergedHasEnergy,
            developmentStage: maxDevelopmentStage,
            registrationTime: block.timestamp,
            previousOwners: ownerHistory
        });
        
        // Remove old lands
        for (uint256 i = 0; i < _landIds.length; i++) {
            delete landParcels[_landIds[i]];
            removeFromUserLands(msg.sender, _landIds[i]);
        }
        
        userLands[msg.sender].push(totalParcels);
        
        emit LandsMerged(totalParcels, _landIds, msg.sender);
        return totalParcels;
    }
    
    // NEW FEATURE: Split land into multiple smaller parcels
    function splitLand(
        uint256 _landId,
        uint256[] memory _sizes,
        string[] memory _locations
    ) public validLandId(_landId) onlyLandOwner(_landId) returns (uint256[] memory) {
        require(_sizes.length >= 2, "Must split into at least 2 parcels");
        require(_sizes.length == _locations.length, "Sizes and locations must match");
        require(_sizes.length <= 10, "Cannot split into more than 10 parcels");
        require(!landParcels[_landId].isForSale, "Cannot split land that is for sale");
        
        uint256 totalSizeCheck = 0;
        for (uint256 i = 0; i < _sizes.length; i++) {
            totalSizeCheck += _sizes[i];
        }
        require(totalSizeCheck == landParcels[_landId].size, "Total sizes must equal original land size");
        
        LandParcel memory originalLand = landParcels[_landId];
        uint256[] memory newLandIds = new uint256[](_sizes.length);
        
        // Create new split parcels
        for (uint256 i = 0; i < _sizes.length; i++) {
            totalParcels++;
            
            string[] memory ownerHistory = new string[](1);
            ownerHistory[0] = addressToString(msg.sender);
            
            // Each split inherits attributes but with reduced resource level
            uint256 splitResourceLevel = originalLand.resourceLevel * 80 / 100; // 20% reduction
            
            landParcels[totalParcels] = LandParcel({
                id: totalParcels,
                owner: msg.sender,
                location: _locations[i],
                size: _sizes[i],
                price: 0,
                isForSale: false,
                category: originalLand.category,
                rarity: RarityLevel.Common, // Split lands are common
                terrain: originalLand.terrain,
                resourceLevel: splitResourceLevel,
                hasWater: originalLand.hasWater,
                hasMinerals: originalLand.hasMinerals,
                hasEnergy: originalLand.hasEnergy,
                developmentStage: 0, // Reset development
                registrationTime: block.timestamp,
                previousOwners: ownerHistory
            });
            
            userLands[msg.sender].push(totalParcels);
            newLandIds[i] = totalParcels;
        }
        
        // Remove original land
        delete landParcels[_landId];
        removeFromUserLands(msg.sender, _landId);
        
        emit LandSplit(_landId, newLandIds, msg.sender);
        return newLandIds;
    }
    
    // NEW FEATURE: Update land attributes (development, resources)
    function developLand(uint256 _landId) 
        public 
        validLandId(_landId)
        onlyLandOwner(_landId) 
    {
        require(landParcels[_landId].developmentStage < 10, "Land is fully developed");
        
        landParcels[_landId].developmentStage++;
        
        // Development increases resource level
        if (landParcels[_landId].resourceLevel < 95) {
            landParcels[_landId].resourceLevel += 5;
        }
        
        emit LandAttributesUpdated(_landId, landParcels[_landId].resourceLevel, landParcels[_landId].developmentStage);
    }
    
    // NEW FEATURE: Create a neighborhood
    function createNeighborhood(string memory _name, uint256[] memory _landIds) 
        public 
        returns (uint256) 
    {
        require(_landIds.length > 0, "Neighborhood must have at least one land");
        
        // Verify ownership of all lands
        for (uint256 i = 0; i < _landIds.length; i++) {
            require(landParcels[_landIds[i]].owner == msg.sender, "Must own all lands in neighborhood");
        }
        
        totalNeighborhoods++;
        
        neighborhoods[totalNeighborhoods] = Neighborhood({
            id: totalNeighborhoods,
            name: _name,
            landIds: _landIds,
            creator: msg.sender,
            totalLands: _landIds.length,
            isActive: true
        });
        
        // Map lands to neighborhood
        for (uint256 i = 0; i < _landIds.length; i++) {
            landToNeighborhood[_landIds[i]] = totalNeighborhoods;
        }
        
        emit NeighborhoodCreated(totalNeighborhoods, _name, msg.sender);
        return totalNeighborhoods;
    }
    
    // NEW FEATURE: Add land to existing neighborhood
    function addLandToNeighborhood(uint256 _landId, uint256 _neighborhoodId) 
        public 
        validLandId(_landId)
        onlyLandOwner(_landId)
    {
        require(_neighborhoodId > 0 && _neighborhoodId <= totalNeighborhoods, "Invalid neighborhood ID");
        require(neighborhoods[_neighborhoodId].isActive, "Neighborhood is not active");
        require(landToNeighborhood[_landId] == 0, "Land already in a neighborhood");
        
        neighborhoods[_neighborhoodId].landIds.push(_landId);
        neighborhoods[_neighborhoodId].totalLands++;
        landToNeighborhood[_landId] = _neighborhoodId;
        
        emit LandAddedToNeighborhood(_landId, _neighborhoodId);
    }
    
    // Helper function: Get land details
    function getLandDetails(uint256 _landId) public view validLandId(_landId) returns (
        uint256 id,
        address owner,
        string memory location,
        uint256 size,
        uint256 price,
        bool isForSale,
        LandCategory category,
        RarityLevel rarity,
        TerrainType terrain,
        uint256 resourceLevel,
        uint256 developmentStage
    ) {
        LandParcel memory land = landParcels[_landId];
        return (
            land.id, 
            land.owner, 
            land.location, 
            land.size, 
            land.price, 
            land.isForSale,
            land.category,
            land.rarity,
            land.terrain,
            land.resourceLevel,
            land.developmentStage
        );
    }
    
    // Helper function: Get land resources
    function getLandResources(uint256 _landId) public view validLandId(_landId) returns (
        bool hasWater,
        bool hasMinerals,
        bool hasEnergy,
        uint256 resourceLevel
    ) {
        LandParcel memory land = landParcels[_landId];
        return (land.hasWater, land.hasMinerals, land.hasEnergy, land.resourceLevel);
    }
    
    // Helper function: Get land history
    function getLandHistory(uint256 _landId) public view validLandId(_landId) returns (
        string[] memory previousOwners,
        uint256 registrationTime
    ) {
        return (landParcels[_landId].previousOwners, landParcels[_landId].registrationTime);
    }
    
    // Helper function: Get neighborhood details
    function getNeighborhoodDetails(uint256 _neighborhoodId) public view returns (
        uint256 id,
        string memory name,
        uint256[] memory landIds,
        address creator,
        uint256 totalLands,
        bool isActive
    ) {
        require(_neighborhoodId > 0 && _neighborhoodId <= totalNeighborhoods, "Invalid neighborhood ID");
        Neighborhood memory hood = neighborhoods[_neighborhoodId];
        return (hood.id, hood.name, hood.landIds, hood.creator, hood.totalLands, hood.isActive);
    }
    
    // Helper function: Get user's lands
    function getMyLands() public view returns (uint256[] memory) {
        return userLands[msg.sender];
    }
    
    // Internal helper: Remove land from user's lands array
    function removeFromUserLands(address _user, uint256 _landId) internal {
        uint256[] storage lands = userLands[_user];
        for (uint256 i = 0; i < lands.length; i++) {
            if (lands[i] == _landId) {
                lands[i] = lands[lands.length - 1];
                lands.pop();
                break;
            }
        }
    }
    
    // Internal helper: Convert address to string
    function addressToString(address _addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        for (uint256 i = 0; i < 20; i++) {
            str[2+i*2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3+i*2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }
}
