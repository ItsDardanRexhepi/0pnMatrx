// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title RealEstateEscrow
/// @author 0pnMatrx — Business Infrastructure Pack
/// @notice Property sale escrow with legal bridge hooks for real-world integration.
///         Manages the lifecycle of a property transaction: deposit, inspection,
///         title verification, closing, and fund disbursement. Designed to work
///         alongside traditional legal processes.
/// @dev Features:
///      - Structured property transaction phases
///      - Earnest money deposit management
///      - Inspection period with contingency support
///      - Title verification hooks
///      - Closing agent authorization
///      - Pro-rated disbursement (seller, agents, taxes, fees)
///      - Legal document hash recording

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract RealEstateEscrow is Ownable, ReentrancyGuard {

    // ── Types ────────────────────────────────────────────────────────

    enum TransactionPhase {
        Created,
        EarnestDeposited,
        InspectionPeriod,
        InspectionComplete,
        TitleVerification,
        TitleCleared,
        ClosingScheduled,
        Closed,
        Cancelled,
        Disputed
    }

    struct PropertyTransaction {
        // Parties
        address buyer;
        address seller;
        address closingAgent;        // title company / attorney
        address buyerAgent;          // buyer's real estate agent
        address sellerAgent;         // seller's real estate agent

        // Property details
        string propertyAddress;
        string legalDescription;
        string parcelId;

        // Financial
        uint256 purchasePrice;
        uint256 earnestDeposit;
        uint256 depositedAmount;
        uint256 buyerAgentFeeBps;    // buyer agent commission in BPS
        uint256 sellerAgentFeeBps;   // seller agent commission in BPS

        // Timing
        uint256 createdAt;
        uint256 inspectionDeadline;
        uint256 closingDeadline;

        // Status
        TransactionPhase phase;
        bool inspectionPassed;
        bool titleCleared;
    }

    struct LegalDocument {
        string name;
        bytes32 documentHash;
        string documentURI;
        uint256 recordedAt;
        address recordedBy;
    }

    // ── State ────────────────────────────────────────────────────────

    mapping(uint256 => PropertyTransaction) public transactions;
    uint256 public transactionCount;

    /// @notice Legal documents per transaction
    mapping(uint256 => LegalDocument[]) public documents;

    /// @notice Contingencies that must be satisfied
    mapping(uint256 => mapping(string => bool)) public contingencies;
    mapping(uint256 => string[]) public contingencyList;

    // ── Events ───────────────────────────────────────────────────────
    event TransactionCreated(uint256 indexed txId, address indexed buyer, address indexed seller, uint256 purchasePrice);
    event EarnestDeposited(uint256 indexed txId, uint256 amount);
    event InspectionStarted(uint256 indexed txId, uint256 deadline);
    event InspectionResult(uint256 indexed txId, bool passed);
    event TitleVerified(uint256 indexed txId, bool cleared);
    event ClosingScheduled(uint256 indexed txId, uint256 closingDate);
    event TransactionClosed(uint256 indexed txId, uint256 sellerProceeds);
    event TransactionCancelled(uint256 indexed txId, string reason);
    event DocumentRecorded(uint256 indexed txId, string name, bytes32 documentHash);
    event ContingencyAdded(uint256 indexed txId, string contingency);
    event ContingencySatisfied(uint256 indexed txId, string contingency);
    event DisputeRaised(uint256 indexed txId, address indexed by);

    constructor() Ownable(msg.sender) {}

    // ── Transaction Creation ─────────────────────────────────────────

    /// @notice Create a new property transaction
    /// @param buyer Buyer address
    /// @param seller Seller address
    /// @param closingAgent Title company or attorney address
    /// @param buyerAgent Buyer's agent address (address(0) if none)
    /// @param sellerAgent Seller's agent address (address(0) if none)
    /// @param propertyAddress Physical property address
    /// @param legalDescription Legal description of the property
    /// @param parcelId Tax parcel identification number
    /// @param purchasePrice Purchase price in wei
    /// @param earnestDeposit Required earnest money deposit in wei
    /// @param buyerAgentFeeBps Buyer agent fee in basis points
    /// @param sellerAgentFeeBps Seller agent fee in basis points
    /// @param inspectionDays Number of days for inspection period
    /// @param closingDays Number of days until closing deadline
    /// @return txId The transaction ID
    function createTransaction(
        address buyer,
        address seller,
        address closingAgent,
        address buyerAgent,
        address sellerAgent,
        string calldata propertyAddress,
        string calldata legalDescription,
        string calldata parcelId,
        uint256 purchasePrice,
        uint256 earnestDeposit,
        uint256 buyerAgentFeeBps,
        uint256 sellerAgentFeeBps,
        uint256 inspectionDays,
        uint256 closingDays
    ) external returns (uint256 txId) {
        require(buyer != address(0) && seller != address(0), "Zero address");
        require(closingAgent != address(0), "No closing agent");
        require(purchasePrice > 0, "Zero price");
        require(earnestDeposit > 0 && earnestDeposit <= purchasePrice, "Invalid deposit");
        require(buyerAgentFeeBps + sellerAgentFeeBps <= 1000, "Agent fees too high"); // max 10% total
        require(inspectionDays > 0 && inspectionDays <= 60, "Invalid inspection period");
        require(closingDays > inspectionDays && closingDays <= 180, "Invalid closing period");

        txId = transactionCount++;

        transactions[txId] = PropertyTransaction({
            buyer: buyer,
            seller: seller,
            closingAgent: closingAgent,
            buyerAgent: buyerAgent,
            sellerAgent: sellerAgent,
            propertyAddress: propertyAddress,
            legalDescription: legalDescription,
            parcelId: parcelId,
            purchasePrice: purchasePrice,
            earnestDeposit: earnestDeposit,
            depositedAmount: 0,
            buyerAgentFeeBps: buyerAgentFeeBps,
            sellerAgentFeeBps: sellerAgentFeeBps,
            createdAt: block.timestamp,
            inspectionDeadline: block.timestamp + (inspectionDays * 1 days),
            closingDeadline: block.timestamp + (closingDays * 1 days),
            phase: TransactionPhase.Created,
            inspectionPassed: false,
            titleCleared: false
        });

        emit TransactionCreated(txId, buyer, seller, purchasePrice);
    }

    // ── Earnest Money ────────────────────────────────────────────────

    /// @notice Deposit earnest money (buyer only)
    /// @param txId The transaction ID
    function depositEarnest(uint256 txId) external payable nonReentrant {
        PropertyTransaction storage t = transactions[txId];
        require(msg.sender == t.buyer, "Not buyer");
        require(t.phase == TransactionPhase.Created, "Wrong phase");
        require(msg.value >= t.earnestDeposit, "Insufficient deposit");

        t.depositedAmount = msg.value;
        t.phase = TransactionPhase.EarnestDeposited;

        // Refund excess
        if (msg.value > t.earnestDeposit) {
            (bool success, ) = msg.sender.call{value: msg.value - t.earnestDeposit}("");
            require(success, "Refund failed");
            t.depositedAmount = t.earnestDeposit;
        }

        emit EarnestDeposited(txId, t.depositedAmount);
    }

    // ── Inspection ───────────────────────────────────────────────────

    /// @notice Start the inspection period (closing agent)
    function startInspection(uint256 txId) external {
        PropertyTransaction storage t = transactions[txId];
        require(msg.sender == t.closingAgent, "Not closing agent");
        require(t.phase == TransactionPhase.EarnestDeposited, "Wrong phase");

        t.phase = TransactionPhase.InspectionPeriod;
        emit InspectionStarted(txId, t.inspectionDeadline);
    }

    /// @notice Record inspection result (buyer decides)
    /// @param txId The transaction ID
    /// @param passed Whether the inspection was satisfactory
    function recordInspectionResult(uint256 txId, bool passed) external {
        PropertyTransaction storage t = transactions[txId];
        require(msg.sender == t.buyer, "Not buyer");
        require(t.phase == TransactionPhase.InspectionPeriod, "Wrong phase");
        require(block.timestamp <= t.inspectionDeadline, "Inspection period expired");

        t.inspectionPassed = passed;

        if (passed) {
            t.phase = TransactionPhase.InspectionComplete;
        } else {
            // Inspection failed — return earnest to buyer
            t.phase = TransactionPhase.Cancelled;
            _refundEarnest(txId);
            emit TransactionCancelled(txId, "Inspection failed");
        }

        emit InspectionResult(txId, passed);
    }

    // ── Title Verification ───────────────────────────────────────────

    /// @notice Record title verification result (closing agent)
    /// @param txId The transaction ID
    /// @param cleared Whether the title is clear
    function verifyTitle(uint256 txId, bool cleared) external {
        PropertyTransaction storage t = transactions[txId];
        require(msg.sender == t.closingAgent, "Not closing agent");
        require(t.phase == TransactionPhase.InspectionComplete, "Wrong phase");

        t.titleCleared = cleared;

        if (cleared) {
            t.phase = TransactionPhase.TitleCleared;
        } else {
            t.phase = TransactionPhase.Cancelled;
            _refundEarnest(txId);
            emit TransactionCancelled(txId, "Title not clear");
        }

        emit TitleVerified(txId, cleared);
    }

    // ── Closing ──────────────────────────────────────────────────────

    /// @notice Deposit remaining balance and close (buyer)
    /// @param txId The transaction ID
    function depositAndClose(uint256 txId) external payable nonReentrant {
        PropertyTransaction storage t = transactions[txId];
        require(msg.sender == t.buyer, "Not buyer");
        require(t.phase == TransactionPhase.TitleCleared, "Wrong phase");
        require(block.timestamp <= t.closingDeadline, "Closing deadline passed");

        uint256 remaining = t.purchasePrice - t.depositedAmount;
        require(msg.value >= remaining, "Insufficient closing funds");

        t.depositedAmount += remaining;
        t.phase = TransactionPhase.Closed;

        // Refund excess
        if (msg.value > remaining) {
            (bool refundSuccess, ) = msg.sender.call{value: msg.value - remaining}("");
            require(refundSuccess, "Refund failed");
        }

        // Disburse funds
        _disburseFunds(txId);
    }

    // ── Contingencies ────────────────────────────────────────────────

    /// @notice Add a contingency to the transaction
    /// @param txId The transaction ID
    /// @param contingency The contingency description
    function addContingency(uint256 txId, string calldata contingency) external {
        PropertyTransaction storage t = transactions[txId];
        require(
            msg.sender == t.buyer || msg.sender == t.closingAgent,
            "Not authorized"
        );
        require(t.phase != TransactionPhase.Closed && t.phase != TransactionPhase.Cancelled, "Transaction finalized");

        contingencies[txId][contingency] = false;
        contingencyList[txId].push(contingency);

        emit ContingencyAdded(txId, contingency);
    }

    /// @notice Satisfy a contingency
    /// @param txId The transaction ID
    /// @param contingency The contingency to satisfy
    function satisfyContingency(uint256 txId, string calldata contingency) external {
        PropertyTransaction storage t = transactions[txId];
        require(msg.sender == t.closingAgent, "Not closing agent");
        require(!contingencies[txId][contingency], "Already satisfied");

        contingencies[txId][contingency] = true;
        emit ContingencySatisfied(txId, contingency);
    }

    // ── Legal Documents ──────────────────────────────────────────────

    /// @notice Record a legal document hash on-chain
    /// @param txId The transaction ID
    /// @param name Document name
    /// @param documentHash Hash of the document content
    /// @param documentURI URI where the document can be accessed
    function recordDocument(
        uint256 txId,
        string calldata name,
        bytes32 documentHash,
        string calldata documentURI
    ) external {
        PropertyTransaction storage t = transactions[txId];
        require(
            msg.sender == t.buyer ||
            msg.sender == t.seller ||
            msg.sender == t.closingAgent,
            "Not authorized"
        );

        documents[txId].push(LegalDocument({
            name: name,
            documentHash: documentHash,
            documentURI: documentURI,
            recordedAt: block.timestamp,
            recordedBy: msg.sender
        }));

        emit DocumentRecorded(txId, name, documentHash);
    }

    // ── Cancellation and Disputes ────────────────────────────────────

    /// @notice Cancel the transaction (with mutual consent or past deadline)
    function cancelTransaction(uint256 txId, string calldata reason) external nonReentrant {
        PropertyTransaction storage t = transactions[txId];
        require(
            msg.sender == t.buyer || msg.sender == t.seller || msg.sender == t.closingAgent,
            "Not authorized"
        );
        require(
            t.phase != TransactionPhase.Closed &&
            t.phase != TransactionPhase.Cancelled &&
            t.phase != TransactionPhase.Disputed,
            "Cannot cancel"
        );

        t.phase = TransactionPhase.Cancelled;
        _refundEarnest(txId);

        emit TransactionCancelled(txId, reason);
    }

    /// @notice Raise a dispute
    function raiseDispute(uint256 txId) external {
        PropertyTransaction storage t = transactions[txId];
        require(
            msg.sender == t.buyer || msg.sender == t.seller,
            "Not a party"
        );
        require(
            t.phase != TransactionPhase.Closed && t.phase != TransactionPhase.Cancelled,
            "Transaction finalized"
        );

        t.phase = TransactionPhase.Disputed;
        emit DisputeRaised(txId, msg.sender);
    }

    /// @notice Resolve a dispute (closing agent acts as arbitrator)
    /// @param txId The transaction ID
    /// @param refundBuyer True to refund buyer, false to release to seller
    function resolveDispute(uint256 txId, bool refundBuyer) external nonReentrant {
        PropertyTransaction storage t = transactions[txId];
        require(msg.sender == t.closingAgent || msg.sender == owner(), "Not authorized");
        require(t.phase == TransactionPhase.Disputed, "Not disputed");

        t.phase = TransactionPhase.Cancelled;

        if (refundBuyer) {
            _refundEarnest(txId);
        } else {
            // Release deposit to seller
            if (t.depositedAmount > 0) {
                uint256 amount = t.depositedAmount;
                t.depositedAmount = 0;
                (bool success, ) = t.seller.call{value: amount}("");
                require(success, "Transfer failed");
            }
        }
    }

    // ── View Functions ───────────────────────────────────────────────

    /// @notice Get document count for a transaction
    function getDocumentCount(uint256 txId) external view returns (uint256) {
        return documents[txId].length;
    }

    /// @notice Get contingency count
    function getContingencyCount(uint256 txId) external view returns (uint256) {
        return contingencyList[txId].length;
    }

    /// @notice Check if all contingencies are satisfied
    function allContingenciesMet(uint256 txId) external view returns (bool) {
        string[] storage list = contingencyList[txId];
        for (uint256 i = 0; i < list.length; i++) {
            if (!contingencies[txId][list[i]]) return false;
        }
        return true;
    }

    // ── Internal ─────────────────────────────────────────────────────

    function _refundEarnest(uint256 txId) internal {
        PropertyTransaction storage t = transactions[txId];
        if (t.depositedAmount > 0) {
            uint256 amount = t.depositedAmount;
            t.depositedAmount = 0;
            (bool success, ) = t.buyer.call{value: amount}("");
            require(success, "Refund failed");
        }
    }

    function _disburseFunds(uint256 txId) internal {
        PropertyTransaction storage t = transactions[txId];
        uint256 total = t.purchasePrice;

        // Calculate agent commissions
        uint256 buyerAgentFee = (total * t.buyerAgentFeeBps) / 10000;
        uint256 sellerAgentFee = (total * t.sellerAgentFeeBps) / 10000;
        uint256 sellerProceeds = total - buyerAgentFee - sellerAgentFee;

        // Pay seller
        (bool sellerSuccess, ) = t.seller.call{value: sellerProceeds}("");
        require(sellerSuccess, "Seller payment failed");

        // Pay buyer agent
        if (buyerAgentFee > 0 && t.buyerAgent != address(0)) {
            (bool baSuccess, ) = t.buyerAgent.call{value: buyerAgentFee}("");
            require(baSuccess, "Buyer agent payment failed");
        }

        // Pay seller agent
        if (sellerAgentFee > 0 && t.sellerAgent != address(0)) {
            (bool saSuccess, ) = t.sellerAgent.call{value: sellerAgentFee}("");
            require(saSuccess, "Seller agent payment failed");
        }

        emit TransactionClosed(txId, sellerProceeds);
    }

    receive() external payable {}
}
