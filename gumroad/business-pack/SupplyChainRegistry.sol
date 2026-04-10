// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SupplyChainRegistry
/// @author 0pnMatrx — Business Infrastructure Pack
/// @notice Product provenance tracking on-chain. Register products, record supply chain
///         events (manufacture, ship, receive, inspect), and verify authenticity.
///         Supports multi-party supply chains with role-based access.
/// @dev Features:
///      - Product registration with unique identifiers
///      - Supply chain event recording (manufacture, ship, receive, inspect, sell)
///      - Multi-party participation with role management
///      - Product authenticity verification
///      - Batch operations for efficiency
///      - Full event history and audit trail

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SupplyChainRegistry is Ownable, AccessControl {

    // ── Roles ────────────────────────────────────────────────────────
    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER_ROLE");
    bytes32 public constant INSPECTOR_ROLE = keccak256("INSPECTOR_ROLE");

    // ── Types ────────────────────────────────────────────────────────

    enum ProductStatus {
        Registered,
        Manufactured,
        InTransit,
        Received,
        Inspected,
        OnShelf,
        Sold,
        Recalled
    }

    enum EventType {
        Manufactured,
        QualityChecked,
        Shipped,
        Received,
        Inspected,
        Stored,
        OnShelf,
        Sold,
        Returned,
        Recalled,
        Destroyed,
        Custom
    }

    struct Product {
        uint256 id;
        string name;
        string sku;                 // stock keeping unit
        string batchId;
        address manufacturer;
        bytes32 contentHash;        // hash of product details/specs
        string metadataURI;         // IPFS URI for product details
        uint256 registeredAt;
        uint256 lastUpdated;
        address currentHolder;
        ProductStatus status;
        bool authentic;             // verified authentic
    }

    struct SupplyChainEvent {
        uint256 eventId;
        uint256 productId;
        EventType eventType;
        address actor;
        string location;
        string notes;
        bytes32 documentHash;       // supporting document hash
        uint256 timestamp;
        int256 temperature;         // optional: temp in Celsius * 100
        int256 humidity;            // optional: humidity * 100
    }

    struct Participant {
        address account;
        string name;
        string role;
        string location;
        bool active;
        uint256 registeredAt;
    }

    // ── State ────────────────────────────────────────────────────────

    mapping(uint256 => Product) public products;
    uint256 public productCount;

    mapping(uint256 => SupplyChainEvent[]) public productEvents;
    uint256 public totalEventCount;

    mapping(address => Participant) public participants;
    address[] public participantList;

    /// @notice SKU to product ID mapping for lookups
    mapping(string => uint256) public skuToProduct;

    /// @notice Batch ID to product IDs
    mapping(string => uint256[]) public batchProducts;

    // ── Events ───────────────────────────────────────────────────────
    event ProductRegistered(uint256 indexed productId, string sku, address indexed manufacturer);
    event SupplyChainEventRecorded(uint256 indexed productId, uint256 eventId, EventType eventType, address indexed actor);
    event ProductTransferred(uint256 indexed productId, address indexed from, address indexed to);
    event ProductRecalled(uint256 indexed productId, string reason);
    event ParticipantRegistered(address indexed account, string name, string role);
    event ParticipantDeactivated(address indexed account);
    event AuthenticityVerified(uint256 indexed productId, bool authentic);

    constructor() Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANUFACTURER_ROLE, msg.sender);
    }

    // ── Participant Management ───────────────────────────────────────

    /// @notice Register a supply chain participant
    /// @param account Participant address
    /// @param name Organization name
    /// @param role Role description
    /// @param location Physical location
    /// @param roleHash AccessControl role to grant
    function registerParticipant(
        address account,
        string calldata name,
        string calldata role,
        string calldata location,
        bytes32 roleHash
    ) external onlyOwner {
        require(account != address(0), "Zero address");
        require(!participants[account].active, "Already registered");

        participants[account] = Participant({
            account: account,
            name: name,
            role: role,
            location: location,
            active: true,
            registeredAt: block.timestamp
        });

        participantList.push(account);
        _grantRole(roleHash, account);

        emit ParticipantRegistered(account, name, role);
    }

    /// @notice Deactivate a participant
    function deactivateParticipant(address account) external onlyOwner {
        require(participants[account].active, "Not active");
        participants[account].active = false;
        emit ParticipantDeactivated(account);
    }

    // ── Product Registration ─────────────────────────────────────────

    /// @notice Register a new product
    /// @param name Product name
    /// @param sku Stock keeping unit (unique identifier)
    /// @param batchId Batch or lot number
    /// @param contentHash Hash of product specifications
    /// @param metadataURI URI for full product details
    /// @return productId The ID of the registered product
    function registerProduct(
        string calldata name,
        string calldata sku,
        string calldata batchId,
        bytes32 contentHash,
        string calldata metadataURI
    ) external onlyRole(MANUFACTURER_ROLE) returns (uint256 productId) {
        require(bytes(name).length > 0, "Empty name");
        require(bytes(sku).length > 0, "Empty SKU");
        require(skuToProduct[sku] == 0, "SKU exists");

        productId = ++productCount; // Start from 1

        products[productId] = Product({
            id: productId,
            name: name,
            sku: sku,
            batchId: batchId,
            manufacturer: msg.sender,
            contentHash: contentHash,
            metadataURI: metadataURI,
            registeredAt: block.timestamp,
            lastUpdated: block.timestamp,
            currentHolder: msg.sender,
            status: ProductStatus.Registered,
            authentic: true
        });

        skuToProduct[sku] = productId;
        if (bytes(batchId).length > 0) {
            batchProducts[batchId].push(productId);
        }

        // Record registration event
        _recordEvent(productId, EventType.Manufactured, "", "Product registered", bytes32(0), 0, 0);

        emit ProductRegistered(productId, sku, msg.sender);
    }

    /// @notice Register multiple products in a batch
    /// @param names Product names
    /// @param skus SKUs
    /// @param batchId Shared batch ID
    /// @param contentHash Shared content hash
    /// @param metadataURI Shared metadata URI
    /// @return ids Array of product IDs
    function batchRegister(
        string[] calldata names,
        string[] calldata skus,
        string calldata batchId,
        bytes32 contentHash,
        string calldata metadataURI
    ) external onlyRole(MANUFACTURER_ROLE) returns (uint256[] memory ids) {
        require(names.length == skus.length, "Length mismatch");
        require(names.length <= 100, "Too many products");

        ids = new uint256[](names.length);

        for (uint256 i = 0; i < names.length; i++) {
            require(bytes(skus[i]).length > 0, "Empty SKU");
            require(skuToProduct[skus[i]] == 0, "SKU exists");

            uint256 productId = ++productCount;

            products[productId] = Product({
                id: productId,
                name: names[i],
                sku: skus[i],
                batchId: batchId,
                manufacturer: msg.sender,
                contentHash: contentHash,
                metadataURI: metadataURI,
                registeredAt: block.timestamp,
                lastUpdated: block.timestamp,
                currentHolder: msg.sender,
                status: ProductStatus.Registered,
                authentic: true
            });

            skuToProduct[skus[i]] = productId;
            if (bytes(batchId).length > 0) {
                batchProducts[batchId].push(productId);
            }

            ids[i] = productId;
            emit ProductRegistered(productId, skus[i], msg.sender);
        }
    }

    // ── Supply Chain Events ──────────────────────────────────────────

    /// @notice Record a supply chain event
    /// @param productId The product ID
    /// @param eventType Type of event
    /// @param location Where the event occurred
    /// @param notes Additional notes
    /// @param documentHash Supporting document hash
    /// @param temperature Temperature reading (Celsius * 100, 0 if not applicable)
    /// @param humidity Humidity reading (* 100, 0 if not applicable)
    function recordEvent(
        uint256 productId,
        EventType eventType,
        string calldata location,
        string calldata notes,
        bytes32 documentHash,
        int256 temperature,
        int256 humidity
    ) external {
        require(products[productId].id != 0, "Product not found");
        require(participants[msg.sender].active || msg.sender == owner(), "Not a participant");

        _recordEvent(productId, eventType, location, notes, documentHash, temperature, humidity);

        // Update product status based on event type
        _updateProductStatus(productId, eventType);
    }

    /// @notice Transfer product custody to another participant
    /// @param productId The product ID
    /// @param to The new holder address
    function transferCustody(uint256 productId, address to) external {
        Product storage p = products[productId];
        require(p.currentHolder == msg.sender, "Not current holder");
        require(participants[to].active, "Recipient not active");

        address from = p.currentHolder;
        p.currentHolder = to;
        p.lastUpdated = block.timestamp;

        _recordEvent(productId, EventType.Received, "", "Custody transferred", bytes32(0), 0, 0);

        emit ProductTransferred(productId, from, to);
    }

    /// @notice Recall a product
    /// @param productId The product ID
    /// @param reason Reason for recall
    function recallProduct(uint256 productId, string calldata reason) external onlyOwner {
        Product storage p = products[productId];
        require(p.id != 0, "Product not found");
        require(p.status != ProductStatus.Recalled, "Already recalled");

        p.status = ProductStatus.Recalled;
        p.lastUpdated = block.timestamp;

        _recordEvent(productId, EventType.Recalled, "", reason, bytes32(0), 0, 0);

        emit ProductRecalled(productId, reason);
    }

    /// @notice Recall all products in a batch
    /// @param batchId The batch ID
    /// @param reason Reason for recall
    function recallBatch(string calldata batchId, string calldata reason) external onlyOwner {
        uint256[] storage ids = batchProducts[batchId];
        for (uint256 i = 0; i < ids.length; i++) {
            Product storage p = products[ids[i]];
            if (p.status != ProductStatus.Recalled) {
                p.status = ProductStatus.Recalled;
                p.lastUpdated = block.timestamp;
                emit ProductRecalled(ids[i], reason);
            }
        }
    }

    // ── Verification ─────────────────────────────────────────────────

    /// @notice Verify product authenticity
    /// @param productId The product ID
    /// @param contentHash The hash to verify against
    /// @return isAuthentic Whether the product hash matches
    /// @return manufacturer The original manufacturer address
    /// @return registeredAt When the product was registered
    function verifyAuthenticity(uint256 productId, bytes32 contentHash)
        external
        view
        returns (bool isAuthentic, address manufacturer, uint256 registeredAt)
    {
        Product storage p = products[productId];
        require(p.id != 0, "Product not found");

        return (
            p.contentHash == contentHash && p.authentic,
            p.manufacturer,
            p.registeredAt
        );
    }

    /// @notice Get the full event history for a product
    /// @param productId The product ID
    /// @return Array of supply chain events
    function getProductHistory(uint256 productId)
        external
        view
        returns (SupplyChainEvent[] memory)
    {
        return productEvents[productId];
    }

    /// @notice Get the event count for a product
    function getEventCount(uint256 productId) external view returns (uint256) {
        return productEvents[productId].length;
    }

    /// @notice Look up a product by SKU
    function getProductBySKU(string calldata sku) external view returns (uint256) {
        return skuToProduct[sku];
    }

    /// @notice Get all products in a batch
    function getBatchProducts(string calldata batchId) external view returns (uint256[] memory) {
        return batchProducts[batchId];
    }

    /// @notice Get participant count
    function getParticipantCount() external view returns (uint256) {
        return participantList.length;
    }

    // ── Internal ─────────────────────────────────────────────────────

    function _recordEvent(
        uint256 productId,
        EventType eventType,
        string memory location,
        string memory notes,
        bytes32 documentHash,
        int256 temperature,
        int256 humidity
    ) internal {
        uint256 eventId = totalEventCount++;

        productEvents[productId].push(SupplyChainEvent({
            eventId: eventId,
            productId: productId,
            eventType: eventType,
            actor: msg.sender,
            location: location,
            notes: notes,
            documentHash: documentHash,
            timestamp: block.timestamp,
            temperature: temperature,
            humidity: humidity
        }));

        emit SupplyChainEventRecorded(productId, eventId, eventType, msg.sender);
    }

    function _updateProductStatus(uint256 productId, EventType eventType) internal {
        Product storage p = products[productId];

        if (eventType == EventType.Manufactured) {
            p.status = ProductStatus.Manufactured;
        } else if (eventType == EventType.Shipped) {
            p.status = ProductStatus.InTransit;
        } else if (eventType == EventType.Received) {
            p.status = ProductStatus.Received;
        } else if (eventType == EventType.Inspected) {
            p.status = ProductStatus.Inspected;
        } else if (eventType == EventType.OnShelf) {
            p.status = ProductStatus.OnShelf;
        } else if (eventType == EventType.Sold) {
            p.status = ProductStatus.Sold;
        } else if (eventType == EventType.Recalled) {
            p.status = ProductStatus.Recalled;
        }

        p.lastUpdated = block.timestamp;
    }

    /// @notice Override required for AccessControl + Ownable compatibility
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
