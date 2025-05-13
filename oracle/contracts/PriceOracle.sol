// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Ownable.sol";

/**
 * @title PriceOracle
 * @dev Smart contract that manages and stores token prices for different currency pairs.
 * This contract acts as the central price oracle for the system, allowing price updates
 * from authorized sources and price queries from consumers.
 */
contract PriceOracle is Ownable {
    // Constants
    uint256 public constant MIN_UPDATE_INTERVAL = 1 minutes;
    uint256 public constant MAX_PRICE_AGE = 24 hours;
    uint8 public constant MAX_PRICE_DEVIATION = 20;
    uint256 public constant PRICE_PRECISION = 1e8;
    
    /**
     * @dev Structure to store price data including the value and last update timestamp
     * @param value Price value scaled by 1e8 for precision
     * @param updatedAt Timestamp of the last price update
     */
    struct PriceData {
        uint256 value; // scaled by 1e8
        uint256 updatedAt;
    }

    /**
     * @dev Structure to represent a price request
     * @param symbol Token symbol (e.g., "BTC", "ETH")
     * @param currency Currency symbol (e.g., "USD", "EUR")
     */
    struct Request {
        bytes32 symbol;
        bytes32 currency;
    }

    // Mapping to store price data for each symbol/currency pair
    mapping(bytes32 => PriceData) public prices;

    // Mapping to track pending price update requests
    mapping(bytes32 => bool) public pendingRequests;
    
    // Mapping to track last update time for each price pair
    mapping(bytes32 => uint256) public lastUpdateTime;

    // Events
    event PriceUpdated(string symbol, string currency, uint256 price);
    event PriceUpdateRequested(address requester, string symbol, string currency);
    event PriceUpdateRejected(string symbol, string currency, string reason);

    /**
     * @dev Modifier to validate address is not zero
     */
    modifier validAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }

    /**
     * @dev Internal function to convert string to bytes32
     */
    function _stringToBytes32(string memory source) internal pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
        require(tempEmptyStringTest.length <= 32, "String too long");
        assembly {
            result := mload(add(source, 32))
        }
    }

    /**
     * @dev Internal function to generate a unique key for price requests
     */
    function _requestKey(address requester, string memory symbol, string memory currency)
        internal pure returns (bytes32)
    {
        return keccak256(abi.encodePacked(requester, _stringToBytes32(symbol), _stringToBytes32(currency)));
    }

    /**
     * @dev Internal function to generate a unique key for price data
     */
    function _priceKey(string memory symbol, string memory currency)
        internal pure returns (bytes32)
    {
        return keccak256(abi.encodePacked(_stringToBytes32(symbol), _stringToBytes32(currency)));
    }

    /**
     * @dev External function to request a price update for a specific token/currency pair
     */
    function requestPriceUpdate(string memory symbol, string memory currency) 
        external 
        whenNotPaused 
        validAddress(msg.sender)
    {
        bytes32 key = _requestKey(msg.sender, symbol, currency);
        require(!pendingRequests[key], "Request already pending");
        
        bytes32 priceKey = _priceKey(symbol, currency);
        require(block.timestamp >= lastUpdateTime[priceKey] + MIN_UPDATE_INTERVAL, "Update too soon");
        
        pendingRequests[key] = true;
        emit PriceUpdateRequested(msg.sender, symbol, currency);
    }

    /**
     * @dev External function to update the price for a specific token/currency pair
     */
    function updatePrice(
        address requester,
        string memory symbol,
        string memory currency,
        uint256 price
    ) external onlyOwner whenNotPaused validAddress(requester) {
        bytes32 reqKey = _requestKey(requester, symbol, currency);
        require(pendingRequests[reqKey], "No pending request");

        bytes32 priceKey = _priceKey(symbol, currency);
        
        // Validate price
        require(price > 0, "Price must be greater than 0");
        
        // Check price deviation
        PriceData storage currentData = prices[priceKey];
        if (currentData.value > 0) {
            uint256 deviation = price > currentData.value ? 
                ((price - currentData.value) * 100) / currentData.value :
                ((currentData.value - price) * 100) / currentData.value;
                
            if (deviation > MAX_PRICE_DEVIATION) {
                emit PriceUpdateRejected(symbol, currency, "Price deviation too high");
                return;
            }
        }

        currentData.value = price;
        currentData.updatedAt = block.timestamp;
        lastUpdateTime[priceKey] = block.timestamp;
        delete pendingRequests[reqKey];

        emit PriceUpdated(symbol, currency, price);
    }

    /**
     * @dev External function to get the current price for a specific token/currency pair
     */
    function getPrice(string memory symbol, string memory currency)
        external view returns (uint256, uint256)
    {
        bytes32 priceKey = _priceKey(symbol, currency);
        PriceData memory data = prices[priceKey];
        require(data.updatedAt > 0, "Price not available");
        require(block.timestamp <= data.updatedAt + MAX_PRICE_AGE, "Price too old");
        return (data.value, data.updatedAt);
    }
}
