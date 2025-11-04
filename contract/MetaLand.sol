// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MetaLand {
    // Enums for land attributes
    enum LandCategory { Residential, Commercial, Industrial, Agricultural, Recreational }
    enum RarityLevel { Common, Uncommon, Rare, Epic, Legendary }
    enum TerrainType { Plains, Mountains, Forest, Desert, Coastal, Urban }
    enum AuctionStatus { Active, Ended, Cancelled }
    
    // Structure to represent a land parcel
    struct LandParcel {
        uint256 id;
        address owner;
        string location;
        uint256 size;
        uint256 price;
        bool isForSale;
        
        // Attributes
        LandCategory category;
        RarityLevel rarity;
        TerrainType terrain;
        uint256 resourceLevel;
        bool hasWater;
        bool hasMinerals;
        bool hasEnergy;
        uint256 developmentStage;
        uint256 registrationTime;
        string[] previousOwners;
        
        // NEW: Rental info
        bool isForRent;
        uint256 rentPrice;
        address tenant;
        uint256 rentStartTime;
        uint256 rentEndTime;
        
        // NEW: Access control
        bool isPrivateSale;
        mapping(address => bool) whitelist;
        
        // NEW: Tax info
        uint256 lastTaxPayment;
        uint256 taxBalance;
    }
    
    // NEW: Bid structure
    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
        bool active;
    }
    
    // NEW: Auction structure
    struct Auction {
        uint256 landId;
        address seller;
        uint256 startPrice;
        uint256 currentBid;
        address highestBidder;
        uint256 startTime;
        uint256 endTime;
        AuctionStatus status;
        bool ended;
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
    mapping(uint256 => uint256) public landToNeighborhood;
    mapping(address => uint256[]) public userLands;
    
    // NEW: Bidding mappings
    mapping(uint256 => Bid[]) public landBids;
    mapping(uint256 => mapping(address => uint256)) public bidderIndex;
    
    // NEW: Auction mappings
    mapping(uint256 => Auction) public auctions;
    uint256 public totalAuctions;
    
    // NEW: Platform settings
    uint256 public platformFeePercent = 2; // 2% platform fee
    uint256 public taxRatePerYear = 1; // 1% annual tax
    address public platformWallet;
    uint256 public constant TAX_PERIOD = 365 days;
    
    uint256 public totalParcels;
    uint256 public totalNeighborhoods;
    address public contractOwner;
    
    // Events
    event LandRegistered(uint256 indexed landId, address indexed owner, string location, uint256 size, LandCategory category, RarityLevel rarity);
    event LandPurchased(uint256 indexed landId, address indexed previousOwner, address indexed newOwner, uint256 price);
    event LandListedForSale(uint256 indexed landId, uint256 price);
    event LandsMerged(uint256 indexed newLandId, uint256[] mergedLandIds, address indexed owner);
    event LandSplit(uint256 indexed originalLandId, uint256[] newLandIds, address indexed owner);
    event LandAttributesUpdated(uint256 indexed landId, uint256 resourceLevel, uint256 developmentStage);
    event NeighborhoodCreated(uint256 indexed neighborhoodId, string name, address indexed creator);
    event LandAddedToNeighborhood(uint256 indexed landId, uint256 indexed neighborhoodId);
    
    // NEW: Additional events
    event BidPlaced(uint256 indexed landId, address indexed bidder, uint256 amount);
    event BidAccepted(uint256 indexed landId, address indexed seller, address indexed buyer, uint256 amount);
    event BidCancelled(uint256 indexed landId, address indexed bidder);
    event AuctionCreated(uint256 indexed auctionId, uint256 indexed landId, uint256 startPrice, uint256 endTime);
    event AuctionBidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 amount);
    event LandRented(uint256 indexed landId, address indexed tenant, uint256 rentPrice, uint256 duration);
    event RentEnded(uint256 indexed landId, address indexed tenant);
    event TaxPaid(uint256 indexed landId, uint256 amount);
    event WhitelistUpdated(uint256 indexed landId, address indexed user, bool status);
    
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
    
    modifier notRented(uint256 _landId) {
        require(!landParcels[_landId].isForRent || landParcels[_landId].tenant == address(0), "Land is currently rented");
        _;
    }
    
    // Constructor
    constructor() {
        contractOwner = msg.sender;
        platformWallet = msg.sender;
        totalParcels = 0;
        totalNeighborhoods = 0;
        totalAuctions = 0;
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
        
        uint256 resourceLevel = uint256(_rarity) * 20 + 10;
        
        string[] memory ownerHistory = new string[](1);
        ownerHistory[0] = addressToString(msg.sender);
        
        LandParcel storage newLand = landParcels[totalParcels];
        newLand.id = totalParcels;
        newLand.owner = msg.sender;
        newLand.location = _location;
        newLand.size = _size;
        newLand.price = 0;
        newLand.isForSale = false;
        newLand.category = _category;
        newLand.rarity = _rarity;
        newLand.terrain = _terrain;
        newLand.resourceLevel = resourceLevel;
        newLand.hasWater = _hasWater;
        newLand.hasMinerals = _hasMinerals;
        newLand.hasEnergy = _hasEnergy;
        newLand.developmentStage = 0;
        newLand.registrationTime = block.timestamp;
        newLand.previousOwners = ownerHistory;
        newLand.isForRent = false;
        newLand.rentPrice = 0;
        newLand.tenant = address(0);
        newLand.lastTaxPayment = block.timestamp;
        newLand.taxBalance = 0;
        newLand.isPrivateSale = false;
        
        userLands[msg.sender].push(totalParcels);
        
        emit LandRegistered(totalParcels, msg.sender, _location, _size, _category, _rarity);
        return totalParcels;
    }
    
    // Simplified register function
    function registerLandBasic(string memory _location, uint256 _size) public returns (uint256) {
        return registerLand(_location, _size, LandCategory.Residential, RarityLevel.Common, TerrainType.Plains, false, false, false);
    }
    
    // Core Function 2: List land for sale
    function listLandForSale(uint256 _landId, uint256 _price) public validLandId(_landId) onlyLandOwner(_landId) notRented(_landId) {
        require(_price > 0, "Price must be greater than zero");
        
        landParcels[_landId].price = _price;
        landParcels[_landId].isForSale = true;
        
        emit LandListedForSale(_landId, _price);
    }
    
    // Core Function 3: Purchase land
    function purchaseLand(uint256 _landId) public payable validLandId(_landId) {
        LandParcel storage land = landParcels[_landId];
        require(land.isForSale, "Land is not for sale");
        require(msg.value >= land.price, "Insufficient payment");
        require(msg.sender != land.owner, "You already own this land");
        
        // Check whitelist for private sales
        if (land.isPrivateSale) {
            require(land.whitelist[msg.sender], "You are not whitelisted for this land");
        }
        
        address previousOwner = land.owner;
        uint256 price = land.price;
        
        // Calculate platform fee
        uint256 platformFee = (price * platformFeePercent) / 100;
        uint256 sellerAmount = price - platformFee;
        
        // Update ownership
        land.owner = msg.sender;
        land.isForSale = false;
        land.price = 0;
        land.previousOwners.push(addressToString(msg.sender));
        land.isPrivateSale = false;
        
        // Update user lands mapping
        userLands[msg.sender].push(_landId);
        removeFromUserLands(previousOwner, _landId);
        
        // Transfer payments
        payable(previousOwner).transfer(sellerAmount);
        payable(platformWallet).transfer(platformFee);
        
        // Refund excess
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
        
        emit LandPurchased(_landId, previousOwner, msg.sender, price);
    }
    
    // NEW FEATURE: Place a bid on land
    function placeBid(uint256 _landId) public payable validLandId(_landId) {
        require(msg.value > 0, "Bid must be greater than zero");
        require(landParcels[_landId].owner != msg.sender, "Cannot bid on own land");
        
        // Check if bidder already has an active bid
        uint256 existingIndex = bidderIndex[_landId][msg.sender];
        if (existingIndex > 0 && landBids[_landId][existingIndex - 1].active) {
            // Return previous bid
            uint256 previousBid = landBids[_landId][existingIndex - 1].amount;
            landBids[_landId][existingIndex - 1].active = false;
            payable(msg.sender).transfer(previousBid);
        }
        
        // Add new bid
        landBids[_landId].push(Bid({
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp,
            active: true
        }));
        
        bidderIndex[_landId][msg.sender] = landBids[_landId].length;
        
        emit BidPlaced(_landId, msg.sender, msg.value);
    }
    
    // NEW FEATURE: Accept a bid
    function acceptBid(uint256 _landId, address _bidder) public validLandId(_landId) onlyLandOwner(_landId) notRented(_landId) {
        uint256 index = bidderIndex[_landId][_bidder];
        require(index > 0, "No bid from this address");
        
        Bid storage bid = landBids[_landId][index - 1];
        require(bid.active, "Bid is not active");
        
        uint256 amount = bid.amount;
        bid.active = false;
        
        // Calculate platform fee
        uint256 platformFee = (amount * platformFeePercent) / 100;
        uint256 sellerAmount = amount - platformFee;
        
        address previousOwner = landParcels[_landId].owner;
        
        // Transfer ownership
        landParcels[_landId].owner = _bidder;
        landParcels[_landId].isForSale = false;
        landParcels[_landId].price = 0;
        landParcels[_landId].previousOwners.push(addressToString(_bidder));
        
        userLands[_bidder].push(_landId);
        removeFromUserLands(previousOwner, _landId);
        
        // Transfer payments
        payable(previousOwner).transfer(sellerAmount);
        payable(platformWallet).transfer(platformFee);
        
        // Refund other active bidders
        for (uint256 i = 0; i < landBids[_landId].length; i++) {
            if (landBids[_landId][i].active && landBids[_landId][i].bidder != _bidder) {
                landBids[_landId][i].active = false;
                payable(landBids[_landId][i].bidder).transfer(landBids[_landId][i].amount);
            }
        }
        
        emit BidAccepted(_landId, previousOwner, _bidder, amount);
    }
    
    // NEW FEATURE: Cancel your bid
    function cancelBid(uint256 _landId) public validLandId(_landId) {
        uint256 index = bidderIndex[_landId][msg.sender];
        require(index > 0, "No bid from your address");
        
        Bid storage bid = landBids[_landId][index - 1];
        require(bid.active, "Bid is not active");
        
        uint256 amount = bid.amount;
        bid.active = false;
        
        payable(msg.sender).transfer(amount);
        
        emit BidCancelled(_landId, msg.sender);
    }
    
    // NEW FEATURE: Create auction
    function createAuction(uint256 _landId, uint256 _startPrice, uint256 _duration) 
        public 
        validLandId(_landId) 
        onlyLandOwner(_landId) 
        notRented(_landId) 
        returns (uint256) 
    {
        require(_startPrice > 0, "Start price must be greater than zero");
        require(_duration >= 1 hours && _duration <= 30 days, "Invalid duration");
        require(!landParcels[_landId].isForSale, "Land is already for sale");
        
        totalAuctions++;
        
        auctions[totalAuctions] = Auction({
            landId: _landId,
            seller: msg.sender,
            startPrice: _startPrice,
            currentBid: 0,
            highestBidder: address(0),
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            status: AuctionStatus.Active,
            ended: false
        });
        
        landParcels[_landId].isForSale = true;
        landParcels[_landId].price = _startPrice;
        
        emit AuctionCreated(totalAuctions, _landId, _startPrice, block.timestamp + _duration);
        return totalAuctions;
    }
    
    // NEW FEATURE: Bid on auction
    function bidOnAuction(uint256 _auctionId) public payable {
        require(_auctionId > 0 && _auctionId <= totalAuctions, "Invalid auction ID");
        Auction storage auction = auctions[_auctionId];
        
        require(auction.status == AuctionStatus.Active, "Auction is not active");
        require(block.timestamp < auction.endTime, "Auction has ended");
        require(msg.value >= auction.startPrice, "Bid below start price");
        require(msg.value > auction.currentBid, "Bid not high enough");
        require(msg.sender != auction.seller, "Cannot bid on own auction");
        
        // Refund previous highest bidder
        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.currentBid);
        }
        
        auction.currentBid = msg.value;
        auction.highestBidder = msg.sender;
        
        emit AuctionBidPlaced(_auctionId, msg.sender, msg.value);
    }
    
    // NEW FEATURE: End auction
    function endAuction(uint256 _auctionId) public {
        require(_auctionId > 0 && _auctionId <= totalAuctions, "Invalid auction ID");
        Auction storage auction = auctions[_auctionId];
        
        require(auction.status == AuctionStatus.Active, "Auction is not active");
        require(block.timestamp >= auction.endTime, "Auction not yet ended");
        require(!auction.ended, "Auction already finalized");
        
        auction.ended = true;
        auction.status = AuctionStatus.Ended;
        
        uint256 landId = auction.landId;
        landParcels[landId].isForSale = false;
        
        if (auction.highestBidder != address(0)) {
            // Calculate fees
            uint256 platformFee = (auction.currentBid * platformFeePercent) / 100;
            uint256 sellerAmount = auction.currentBid - platformFee;
            
            // Transfer ownership
            address previousOwner = landParcels[landId].owner;
            landParcels[landId].owner = auction.highestBidder;
            landParcels[landId].previousOwners.push(addressToString(auction.highestBidder));
            
            userLands[auction.highestBidder].push(landId);
            removeFromUserLands(previousOwner, landId);
            
            // Transfer payments
            payable(auction.seller).transfer(sellerAmount);
            payable(platformWallet).transfer(platformFee);
            
            emit AuctionEnded(_auctionId, auction.highestBidder, auction.currentBid);
        } else {
            // No bids, return land to normal state
            landParcels[landId].price = 0;
            emit AuctionEnded(_auctionId, address(0), 0);
        }
    }
    
    // NEW FEATURE: List land for rent
    function listLandForRent(uint256 _landId, uint256 _rentPrice, uint256 _duration) 
        public 
        validLandId(_landId) 
        onlyLandOwner(_landId) 
    {
        require(_rentPrice > 0, "Rent price must be greater than zero");
        require(_duration >= 1 days && _duration <= 365 days, "Invalid duration");
        require(landParcels[_landId].tenant == address(0), "Land is already rented");
        
        landParcels[_landId].isForRent = true;
        landParcels[_landId].rentPrice = _rentPrice;
        landParcels[_landId].rentEndTime = _duration;
    }
    
    // NEW FEATURE: Rent land
    function rentLand(uint256 _landId) public payable validLandId(_landId) {
        LandParcel storage land = landParcels[_landId];
        require(land.isForRent, "Land is not for rent");
        require(land.tenant == address(0), "Land is already rented");
        require(msg.value >= land.rentPrice, "Insufficient rent payment");
        require(msg.sender != land.owner, "Cannot rent own land");
        
        uint256 rentPrice = land.rentPrice;
        uint256 duration = land.rentEndTime;
        
        // Calculate platform fee
        uint256 platformFee = (rentPrice * platformFeePercent) / 100;
        uint256 ownerAmount = rentPrice - platformFee;
        
        land.tenant = msg.sender;
        land.rentStartTime = block.timestamp;
        land.rentEndTime = block.timestamp + duration;
        land.isForRent = false;
        
        // Transfer payments
        payable(land.owner).transfer(ownerAmount);
        payable(platformWallet).transfer(platformFee);
        
        // Refund excess
        if (msg.value > rentPrice) {
            payable(msg.sender).transfer(msg.value - rentPrice);
        }
        
        emit LandRented(_landId, msg.sender, rentPrice, duration);
    }
    
    // NEW FEATURE: End rental
    function endRental(uint256 _landId) public validLandId(_landId) onlyLandOwner(_landId) {
        LandParcel storage land = landParcels[_landId];
        require(land.tenant != address(0), "Land is not rented");
        require(block.timestamp >= land.rentEndTime, "Rental period not ended");
        
        address tenant = land.tenant;
        land.tenant = address(0);
        land.rentStartTime = 0;
        land.rentEndTime = 0;
        land.rentPrice = 0;
        
        emit RentEnded(_landId, tenant);
    }
    
    // NEW FEATURE: Pay land tax
    function payLandTax(uint256 _landId) public payable validLandId(_landId) onlyLandOwner(_landId) {
        LandParcel storage land = landParcels[_landId];
        
        uint256 timeSinceLastPayment = block.timestamp - land.lastTaxPayment;
        uint256 landValue = land.size * uint256(land.rarity + 1) * 1000;
        uint256 taxDue = (landValue * taxRatePerYear * timeSinceLastPayment) / (100 * TAX_PERIOD);
        
        require(msg.value >= taxDue, "Insufficient tax payment");
        
        land.lastTaxPayment = block.timestamp;
        land.taxBalance = 0;
        
        payable(platformWallet).transfer(taxDue);
        
        if (msg.value > taxDue) {
            payable(msg.sender).transfer(msg.value - taxDue);
        }
        
        emit TaxPaid(_landId, taxDue);
    }
    
    // NEW FEATURE: Enable private sale
    function setPrivateSale(uint256 _landId, bool _isPrivate) 
        public 
        validLandId(_landId) 
        onlyLandOwner(_landId) 
    {
        landParcels[_landId].isPrivateSale = _isPrivate;
    }
    
    // NEW FEATURE: Update whitelist
    function updateWhitelist(uint256 _landId, address _user, bool _status) 
        public 
        validLandId(_landId) 
        onlyLandOwner(_landId) 
    {
        landParcels[_landId].whitelist[_user] = _status;
        emit WhitelistUpdated(_landId, _user, _status);
    }
    
    // NEW FEATURE: Check if address is whitelisted
    function isWhitelisted(uint256 _landId, address _user) 
        public 
        view 
        validLandId(_landId) 
        returns (bool) 
    {
        return landParcels[_landId].whitelist[_user];
    }
    
    // Merge lands function
    function mergeLands(uint256[] memory _landIds, string memory _newLocation) public returns (uint256) {
        require(_landIds.length >= 2 && _landIds.length <= 10, "Must merge 2-10 lands");
        
        uint256 totalSize = 0;
        uint256 avgResourceLevel = 0;
        uint256 maxDevelopmentStage = 0;
        bool mergedHasWater = false;
        bool mergedHasMinerals = false;
        bool mergedHasEnergy = false;
        
        for (uint256 i = 0; i < _landIds.length; i++) {
            require(landParcels[_landIds[i]].owner == msg.sender, "Must own all lands");
            require(!landParcels[_landIds[i]].isForSale, "Cannot merge lands for sale");
            require(landParcels[_landIds[i]].tenant == address(0), "Cannot merge rented lands");
            
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
        
        RarityLevel newRarity = RarityLevel.Uncommon;
        if (_landIds.length >= 5) newRarity = RarityLevel.Rare;
        if (_landIds.length >= 8) newRarity = RarityLevel.Epic;
        
        totalParcels++;
        string[] memory ownerHistory = new string[](1);
        ownerHistory[0] = addressToString(msg.sender);
        
        LandParcel storage newLand = landParcels[totalParcels];
        newLand.id = totalParcels;
        newLand.owner = msg.sender;
        newLand.location = _newLocation;
        newLand.size = totalSize;
        newLand.category = landParcels[_landIds[0]].category;
        newLand.rarity = newRarity;
        newLand.terrain = landParcels[_landIds[0]].terrain;
        newLand.resourceLevel = avgResourceLevel;
        newLand.hasWater = mergedHasWater;
        newLand.hasMinerals = mergedHasMinerals;
        newLand.hasEnergy = mergedHasEnergy;
        newLand.developmentStage = maxDevelopmentStage;
        newLand.registrationTime = block.timestamp;
        newLand.previousOwners = ownerHistory;
        newLand.lastTaxPayment = block.timestamp;
        
        for (uint256 i = 0; i < _landIds.length; i++) {
            delete landParcels[_landIds[i]];
            removeFromUserLands(msg.sender, _landIds[i]);
        }
        
        userLands[msg.sender].push(totalParcels);
        
        emit LandsMerged(totalParcels, _landIds, msg.sender);
        return totalParcels;
    }
    
    // Split land function
    function splitLand(uint256 _landId, uint256[] memory _sizes, string[] memory _locations) 
        public 
        validLandId(_landId) 
        onlyLandOwner(_landId) 
        returns (uint256[] memory) 
    {
        require(_sizes.length >= 2 && _sizes.length <= 10, "Must split into 2-10 parcels");
        require(_sizes.length == _locations.length, "Sizes and locations must match");
        require(!landParcels[_landId].isForSale, "Cannot split land for sale");
        require(landParcels[_landId].tenant == address(0), "Cannot split rented land");
        
        uint256 totalSizeCheck = 0;
        for (uint256 i = 0; i < _sizes.length; i++) {
            totalSizeCheck += _sizes[i];
        }
        require(totalSizeCheck == landParcels[_landId].size, "Total sizes must equal original");
        
        LandParcel memory originalLand = landParcels[_landId];
        uint256[] memory newLandIds = new uint256[](_sizes.length);
        
        for (uint256 i = 0; i < _sizes.length; i++) {
            totalParcels++;
            
            string[] memory ownerHistory = new string[](1);
            ownerHistory[0] = addressToString(msg.sender);
            
            uint256 splitResourceLevel = originalLand.resourceLevel * 80 / 100;
            
            LandParcel storage newLand = landParcels[totalParcels];
            newLand.id = totalParcels;
            newLand.owner = msg.sender;
            newLand.location = _locations[i];
            newLand.size = _sizes[i];
            newLand.category = originalLand.category;
            newLand.rarity = RarityLevel.Common;
            newLand.terrain = originalLand.terrain;
            newLand.resourceLevel = splitResourceLevel;
            newLand.hasWater = originalLand.hasWater;
            newLand.hasMinerals = originalLand.hasMinerals;
            newLand.hasEnergy = originalLand.hasEnergy;
            newLand.registrationTime = block.timestamp;
            newLand.previousOwners = ownerHistory;
            newLand.lastTaxPayment = block.timestamp;
            
            userLands[msg.sender].push(totalParcels);
            newLandIds[i] = totalParcels;
        }
        
        delete landParcels[_landId];
        removeFromUserLands(msg.sender, _landId);
        
        emit LandSplit(_landId, newLandIds, msg.sender);
        return newLandIds;
    }
    
    // Develop land
    function developLand(uint256 _landId) public validLandId(_landId) onlyLandOwner(_landId) {
        require(landParcels[_landId].developmentStage < 10, "Land is fully developed");
        
        landParcels[_landId].developmentStage++;
        
        if (landParcels[_landId].resourceLevel < 95) {
            landParcels[_landId].resourceLevel += 5;
        }
        
        emit LandAttributesUpdated(_landId, landParcels[_landId].resourceLevel, landParcels[_landId].developmentStage);
    }
    
    // Create neighborhood
    function createNeighborhood(string memory _name, uint256[] memory _landIds) public returns (uint256) {
        require(_landIds.length > 0, "Neighborhood must have at least one land");
        
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
        
        for (uint256 i = 0; i < _landIds.length; i++) {
            landToNeighborhood[_landIds[i]] = totalNeighborhoods;
        }
        
        emit NeighborhoodCreated(totalNeighborhoods, _name, msg.sender);
        return totalNeighborhoods;
    }
    
    // Add land to neighborhood
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
    
    // NEW FEATURE: Get all active bids for a land
    function getLandBids(uint256 _landId) public view validLandId(_landId) returns (
        address[] memory bidders,
        uint256[] memory amounts,
        uint256[] memory timestamps
    ) {
        uint256 activeBidCount = 0;
        
        // Count active bids
        for (uint256 i = 0; i < landBids[_landId].length; i++) {
            if (landBids[_landId][i].active) {
                activeBidCount++;
            }
        }
        
        bidders = new address[](activeBidCount);
        amounts = new uint256[](activeBidCount);
        timestamps = new uint256[](activeBidCount);
        
        uint256 index = 0;
        for (uint256 i = 0; i < landBids[_landId].length; i++) {
            if (landBids[_landId][i].active) {
                bidders[index] = landBids[_landId][i].bidder;
                amounts[index] = landBids[_landId][i].amount;
                timestamps[index] = landBids[_landId][i].timestamp;
                index++;
            }
        }
        
        return (bidders, amounts, timestamps);
    }
    
    // NEW FEATURE: Get auction details
    function getAuctionDetails(uint256 _auctionId) public view returns (
        uint256 landId,
        address seller,
        uint256 startPrice,
        uint256 currentBid,
        address highestBidder,
        uint256 startTime,
        uint256 endTime,
        AuctionStatus status,
        bool ended
    ) {
        require(_auctionId > 0 && _auctionId <= totalAuctions, "Invalid auction ID");
        Auction memory auction = auctions[_auctionId];
        return (
            auction.landId,
            auction.seller,
            auction.startPrice,
            auction.currentBid,
            auction.highestBidder,
            auction.startTime,
            auction.endTime,
            auction.status,
            auction.ended
        );
    }
    
    // NEW FEATURE: Calculate tax due for a land
    function calculateTaxDue(uint256 _landId) public view validLandId(_landId) returns (uint256) {
        LandParcel storage land = landParcels[_landId];
        uint256 timeSinceLastPayment = block.timestamp - land.lastTaxPayment;
        uint256 landValue = land.size * uint256(land.rarity + 1) * 1000;
        uint256 taxDue = (landValue * taxRatePerYear * timeSinceLastPayment) / (100 * TAX_PERIOD);
        return taxDue;
    }
    
    // NEW FEATURE: Get rental info
    function getRentalInfo(uint256 _landId) public view validLandId(_landId) returns (
        bool isForRent,
        uint256 rentPrice,
        address tenant,
        uint256 rentStartTime,
        uint256 rentEndTime
    ) {
        LandParcel storage land = landParcels[_landId];
        return (land.isForRent, land.rentPrice, land.tenant, land.rentStartTime, land.rentEndTime);
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
        LandParcel storage land = landParcels[_landId];
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
        LandParcel storage land = landParcels[_landId];
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
    
    // NEW FEATURE: Get all active auctions
    function getActiveAuctions() public view returns (uint256[] memory) {
        uint256 activeCount = 0;
        
        for (uint256 i = 1; i <= totalAuctions; i++) {
            if (auctions[i].status == AuctionStatus.Active && block.timestamp < auctions[i].endTime) {
                activeCount++;
            }
        }
        
        uint256[] memory activeAuctionIds = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 1; i <= totalAuctions; i++) {
            if (auctions[i].status == AuctionStatus.Active && block.timestamp < auctions[i].endTime) {
                activeAuctionIds[index] = i;
                index++;
            }
        }
        
        return activeAuctionIds;
    }
    
    // NEW FEATURE: Update platform fee (only owner)
    function updatePlatformFee(uint256 _newFeePercent) public onlyOwner {
        require(_newFeePercent <= 10, "Fee cannot exceed 10%");
        platformFeePercent = _newFeePercent;
    }
    
    // NEW FEATURE: Update tax rate (only owner)
    function updateTaxRate(uint256 _newTaxRate) public onlyOwner {
        require(_newTaxRate <= 5, "Tax rate cannot exceed 5%");
        taxRatePerYear = _newTaxRate;
    }
    
    // NEW FEATURE: Update platform wallet (only owner)
    function updatePlatformWallet(address _newWallet) public onlyOwner {
        require(_newWallet != address(0), "Invalid wallet address");
        platformWallet = _newWallet;
    }
    
    // NEW FEATURE: Emergency pause auction (only owner)
    function cancelAuction(uint256 _auctionId) public onlyOwner {
        require(_auctionId > 0 && _auctionId <= totalAuctions, "Invalid auction ID");
        Auction storage auction = auctions[_auctionId];
        require(auction.status == AuctionStatus.Active, "Auction is not active");
        
        auction.status = AuctionStatus.Cancelled;
        auction.ended = true;
        
        landParcels[auction.landId].isForSale = false;
        landParcels[auction.landId].price = 0;
        
        // Refund highest bidder if exists
        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.currentBid);
        }
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
