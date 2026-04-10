// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IPRegistry
/// @author 0pnMatrx — Creator Economy Pack
/// @notice On-chain intellectual property registration with immutable timestamping.
///         Creators register works (art, music, code, writing) with content hashes
///         that prove existence at a specific point in time. Supports licensing,
///         ownership transfers, and dispute resolution.
/// @dev Features:
///      - Register IP with content hash (IPFS CID, SHA-256, etc.)
///      - Immutable timestamp proof of existence
///      - Ownership transfer and licensing
///      - Category classification
///      - Dispute filing and resolution
///      - Batch registration for portfolios

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract IPRegistry is Ownable, ReentrancyGuard {

    // ── Types ────────────────────────────────────────────────────────

    enum IPCategory {
        Art,
        Music,
        Literature,
        Software,
        Photography,
        Video,
        Design,
        Patent,
        Trademark,
        Other
    }

    enum LicenseType {
        AllRightsReserved,
        CreativeCommons,
        MIT,
        Apache2,
        GPL3,
        Commercial,
        Custom
    }

    enum DisputeStatus {
        Filed,
        UnderReview,
        Resolved,
        Dismissed
    }

    struct IPRecord {
        uint256 id;
        address owner;
        string title;
        string description;
        bytes32 contentHash;         // hash of the IP content
        string contentURI;           // IPFS or Arweave URI
        IPCategory category;
        LicenseType license;
        string customLicenseURI;     // for Custom license type
        uint256 registeredAt;
        uint256 updatedAt;
        bool active;
    }

    struct Dispute {
        uint256 id;
        uint256 ipId;
        address challenger;
        string reason;
        string evidenceURI;
        DisputeStatus status;
        string resolution;
        uint256 filedAt;
        uint256 resolvedAt;
    }

    // ── State ────────────────────────────────────────────────────────

    mapping(uint256 => IPRecord) public records;
    uint256 public recordCount;

    mapping(uint256 => Dispute) public disputes;
    uint256 public disputeCount;

    /// @notice Map content hash to IP record ID (ensures uniqueness)
    mapping(bytes32 => uint256) public hashToRecord;

    /// @notice Map owner to their IP record IDs
    mapping(address => uint256[]) public ownerRecords;

    /// @notice Registration fee (optional, set to 0 for free)
    uint256 public registrationFee;

    /// @notice Dispute filing fee
    uint256 public disputeFee = 0.01 ether;

    /// @notice Authorized arbitrators for dispute resolution
    mapping(address => bool) public arbitrators;

    // ── Events ───────────────────────────────────────────────────────
    event IPRegistered(
        uint256 indexed id,
        address indexed owner,
        bytes32 indexed contentHash,
        string title,
        IPCategory category,
        uint256 timestamp
    );
    event IPTransferred(uint256 indexed id, address indexed from, address indexed to);
    event IPUpdated(uint256 indexed id, string field);
    event IPDeactivated(uint256 indexed id);
    event LicenseChanged(uint256 indexed id, LicenseType license);
    event DisputeFiled(uint256 indexed disputeId, uint256 indexed ipId, address indexed challenger);
    event DisputeResolved(uint256 indexed disputeId, DisputeStatus status, string resolution);
    event ArbitratorUpdated(address indexed arbitrator, bool authorized);

    constructor() Ownable(msg.sender) {
        arbitrators[msg.sender] = true;
    }

    // ── Registration ─────────────────────────────────────────────────

    /// @notice Register a new intellectual property record
    /// @param title The title of the work
    /// @param description A description of the work
    /// @param contentHash Hash of the content (e.g., SHA-256 or IPFS CID as bytes32)
    /// @param contentURI URI where the content can be accessed
    /// @param category The category of IP
    /// @param license The license type
    /// @param customLicenseURI URI for custom license terms (if applicable)
    /// @return id The ID of the registered IP record
    function register(
        string calldata title,
        string calldata description,
        bytes32 contentHash,
        string calldata contentURI,
        IPCategory category,
        LicenseType license,
        string calldata customLicenseURI
    ) external payable nonReentrant returns (uint256 id) {
        require(bytes(title).length > 0, "Empty title");
        require(contentHash != bytes32(0), "Empty content hash");
        require(hashToRecord[contentHash] == 0 || !records[hashToRecord[contentHash]].active, "Hash already registered");

        if (registrationFee > 0) {
            require(msg.value >= registrationFee, "Insufficient fee");
        }

        id = ++recordCount; // Start from 1 so 0 means unregistered

        records[id] = IPRecord({
            id: id,
            owner: msg.sender,
            title: title,
            description: description,
            contentHash: contentHash,
            contentURI: contentURI,
            category: category,
            license: license,
            customLicenseURI: customLicenseURI,
            registeredAt: block.timestamp,
            updatedAt: block.timestamp,
            active: true
        });

        hashToRecord[contentHash] = id;
        ownerRecords[msg.sender].push(id);

        emit IPRegistered(id, msg.sender, contentHash, title, category, block.timestamp);
    }

    /// @notice Batch register multiple IP records
    /// @param titles Array of titles
    /// @param descriptions Array of descriptions
    /// @param contentHashes Array of content hashes
    /// @param contentURIs Array of content URIs
    /// @param categories Array of categories
    /// @param licenses Array of license types
    /// @return ids Array of created record IDs
    function batchRegister(
        string[] calldata titles,
        string[] calldata descriptions,
        bytes32[] calldata contentHashes,
        string[] calldata contentURIs,
        IPCategory[] calldata categories,
        LicenseType[] calldata licenses
    ) external payable nonReentrant returns (uint256[] memory ids) {
        uint256 count = titles.length;
        require(
            count == descriptions.length &&
            count == contentHashes.length &&
            count == contentURIs.length &&
            count == categories.length &&
            count == licenses.length,
            "Length mismatch"
        );
        require(count <= 50, "Too many records");

        if (registrationFee > 0) {
            require(msg.value >= registrationFee * count, "Insufficient fee");
        }

        ids = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            require(bytes(titles[i]).length > 0, "Empty title");
            require(contentHashes[i] != bytes32(0), "Empty hash");
            require(
                hashToRecord[contentHashes[i]] == 0 || !records[hashToRecord[contentHashes[i]]].active,
                "Hash already registered"
            );

            uint256 id = ++recordCount;

            records[id] = IPRecord({
                id: id,
                owner: msg.sender,
                title: titles[i],
                description: descriptions[i],
                contentHash: contentHashes[i],
                contentURI: contentURIs[i],
                category: categories[i],
                license: licenses[i],
                customLicenseURI: "",
                registeredAt: block.timestamp,
                updatedAt: block.timestamp,
                active: true
            });

            hashToRecord[contentHashes[i]] = id;
            ownerRecords[msg.sender].push(id);
            ids[i] = id;

            emit IPRegistered(id, msg.sender, contentHashes[i], titles[i], categories[i], block.timestamp);
        }
    }

    // ── Ownership ────────────────────────────────────────────────────

    /// @notice Transfer IP ownership to another address
    /// @param ipId The IP record ID
    /// @param newOwner The new owner address
    function transferIP(uint256 ipId, address newOwner) external {
        IPRecord storage record = records[ipId];
        require(record.active, "Record not active");
        require(record.owner == msg.sender, "Not owner");
        require(newOwner != address(0), "Zero address");

        address oldOwner = record.owner;
        record.owner = newOwner;
        record.updatedAt = block.timestamp;

        ownerRecords[newOwner].push(ipId);

        emit IPTransferred(ipId, oldOwner, newOwner);
    }

    /// @notice Update the license type for an IP record
    /// @param ipId The IP record ID
    /// @param newLicense The new license type
    /// @param customURI Custom license URI (if applicable)
    function updateLicense(uint256 ipId, LicenseType newLicense, string calldata customURI) external {
        IPRecord storage record = records[ipId];
        require(record.active, "Record not active");
        require(record.owner == msg.sender, "Not owner");

        record.license = newLicense;
        record.customLicenseURI = customURI;
        record.updatedAt = block.timestamp;

        emit LicenseChanged(ipId, newLicense);
    }

    /// @notice Update the content URI for an IP record
    /// @param ipId The IP record ID
    /// @param newURI The new content URI
    function updateContentURI(uint256 ipId, string calldata newURI) external {
        IPRecord storage record = records[ipId];
        require(record.active, "Record not active");
        require(record.owner == msg.sender, "Not owner");

        record.contentURI = newURI;
        record.updatedAt = block.timestamp;

        emit IPUpdated(ipId, "contentURI");
    }

    /// @notice Deactivate an IP record (soft delete)
    /// @param ipId The IP record ID
    function deactivate(uint256 ipId) external {
        IPRecord storage record = records[ipId];
        require(record.active, "Already inactive");
        require(record.owner == msg.sender || msg.sender == owner(), "Not authorized");

        record.active = false;
        record.updatedAt = block.timestamp;

        emit IPDeactivated(ipId);
    }

    // ── Disputes ─────────────────────────────────────────────────────

    /// @notice File a dispute against an IP registration
    /// @param ipId The IP record being disputed
    /// @param reason The reason for the dispute
    /// @param evidenceURI URI pointing to supporting evidence
    /// @return disputeId The ID of the filed dispute
    function fileDispute(
        uint256 ipId,
        string calldata reason,
        string calldata evidenceURI
    ) external payable nonReentrant returns (uint256 disputeId) {
        require(records[ipId].active, "Record not active");
        require(msg.value >= disputeFee, "Insufficient dispute fee");
        require(bytes(reason).length > 0, "Empty reason");

        disputeId = disputeCount++;

        disputes[disputeId] = Dispute({
            id: disputeId,
            ipId: ipId,
            challenger: msg.sender,
            reason: reason,
            evidenceURI: evidenceURI,
            status: DisputeStatus.Filed,
            resolution: "",
            filedAt: block.timestamp,
            resolvedAt: 0
        });

        emit DisputeFiled(disputeId, ipId, msg.sender);
    }

    /// @notice Resolve a dispute (arbitrator only)
    /// @param disputeId The dispute to resolve
    /// @param status The resolution status
    /// @param resolution Description of the resolution
    function resolveDispute(
        uint256 disputeId,
        DisputeStatus status,
        string calldata resolution
    ) external {
        require(arbitrators[msg.sender], "Not an arbitrator");
        Dispute storage dispute = disputes[disputeId];
        require(dispute.status == DisputeStatus.Filed || dispute.status == DisputeStatus.UnderReview, "Cannot resolve");
        require(status == DisputeStatus.Resolved || status == DisputeStatus.Dismissed, "Invalid status");

        dispute.status = status;
        dispute.resolution = resolution;
        dispute.resolvedAt = block.timestamp;

        // If resolved in challenger's favor, deactivate the IP
        if (status == DisputeStatus.Resolved) {
            records[dispute.ipId].active = false;
            emit IPDeactivated(dispute.ipId);
        }

        emit DisputeResolved(disputeId, status, resolution);
    }

    // ── View Functions ───────────────────────────────────────────────

    /// @notice Look up an IP record by content hash
    /// @param contentHash The hash to look up
    /// @return The IP record ID (0 if not found)
    function lookupByHash(bytes32 contentHash) external view returns (uint256) {
        return hashToRecord[contentHash];
    }

    /// @notice Get all IP records owned by an address
    /// @param owner_ The owner address
    /// @return Array of IP record IDs
    function getOwnerRecords(address owner_) external view returns (uint256[] memory) {
        return ownerRecords[owner_];
    }

    /// @notice Verify that a content hash was registered before a given timestamp
    /// @param contentHash The content hash to verify
    /// @param timestamp The timestamp to check against
    /// @return exists Whether the hash is registered
    /// @return registeredBefore Whether it was registered before the given timestamp
    /// @return registrationTime The actual registration timestamp
    function verifyTimestamp(bytes32 contentHash, uint256 timestamp)
        external
        view
        returns (bool exists, bool registeredBefore, uint256 registrationTime)
    {
        uint256 id = hashToRecord[contentHash];
        if (id == 0) return (false, false, 0);

        IPRecord storage record = records[id];
        return (true, record.registeredAt <= timestamp, record.registeredAt);
    }

    // ── Admin ────────────────────────────────────────────────────────

    /// @notice Set or remove an arbitrator
    function setArbitrator(address arbitrator, bool authorized) external onlyOwner {
        arbitrators[arbitrator] = authorized;
        emit ArbitratorUpdated(arbitrator, authorized);
    }

    /// @notice Update registration fee
    function setRegistrationFee(uint256 newFee) external onlyOwner {
        registrationFee = newFee;
    }

    /// @notice Update dispute fee
    function setDisputeFee(uint256 newFee) external onlyOwner {
        disputeFee = newFee;
    }

    /// @notice Withdraw accumulated fees
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees");
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdrawal failed");
    }
}
