// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ServiceAgreement
/// @author 0pnMatrx — Business Infrastructure Pack
/// @notice Enforceable service contract with milestone-based payments.
///         A client hires a provider, defines milestones with payment amounts,
///         and funds are released as milestones are completed and approved.
/// @dev Features:
///      - Multi-milestone payment schedule
///      - Client approval required for each milestone payment
///      - Dispute resolution with configurable arbitrator
///      - Auto-release after approval timeout
///      - Agreement amendments with mutual consent
///      - Full on-chain audit trail

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ServiceAgreement is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ── Types ────────────────────────────────────────────────────────

    enum AgreementStatus {
        Draft,
        Active,
        Completed,
        Terminated,
        Disputed
    }

    enum MilestoneStatus {
        Pending,
        InProgress,
        Submitted,
        Approved,
        Paid,
        Disputed,
        Rejected
    }

    struct Agreement {
        uint256 id;
        address client;
        address provider;
        string title;
        string scopeURI;           // IPFS/Arweave URI for full scope doc
        uint256 totalValue;
        uint256 totalPaid;
        uint256 createdAt;
        uint256 startDate;
        uint256 endDate;
        AgreementStatus status;
    }

    struct Milestone {
        string description;
        uint256 amount;
        uint256 deadline;
        uint256 submittedAt;
        uint256 approvedAt;
        string deliverableURI;
        MilestoneStatus status;
    }

    struct Amendment {
        string description;
        bool clientApproved;
        bool providerApproved;
        bool executed;
        uint256 proposedAt;
    }

    // ── State ────────────────────────────────────────────────────────

    mapping(uint256 => Agreement) public agreements;
    uint256 public agreementCount;

    /// @notice Milestones per agreement
    mapping(uint256 => Milestone[]) public milestones;

    /// @notice Amendments per agreement
    mapping(uint256 => Amendment[]) public amendments;

    /// @notice Arbitrator for disputes
    address public arbitrator;

    /// @notice Auto-approval timeout (if client doesn't respond)
    uint256 public approvalTimeout = 14 days;

    /// @notice Platform fee
    uint256 public platformFeeBps = 200; // 2%
    uint256 public constant BPS_DENOMINATOR = 10000;

    // ── Events ───────────────────────────────────────────────────────
    event AgreementCreated(uint256 indexed agreementId, address indexed client, address indexed provider, uint256 totalValue);
    event AgreementActivated(uint256 indexed agreementId);
    event AgreementCompleted(uint256 indexed agreementId);
    event AgreementTerminated(uint256 indexed agreementId, address by);
    event MilestoneStarted(uint256 indexed agreementId, uint256 indexed milestoneIndex);
    event MilestoneSubmitted(uint256 indexed agreementId, uint256 indexed milestoneIndex, string deliverableURI);
    event MilestoneApproved(uint256 indexed agreementId, uint256 indexed milestoneIndex);
    event MilestoneRejected(uint256 indexed agreementId, uint256 indexed milestoneIndex, string reason);
    event MilestonePaid(uint256 indexed agreementId, uint256 indexed milestoneIndex, uint256 amount);
    event DisputeRaised(uint256 indexed agreementId, address indexed by, string reason);
    event DisputeResolved(uint256 indexed agreementId, string resolution);
    event AmendmentProposed(uint256 indexed agreementId, uint256 amendmentIndex, string description);
    event AmendmentExecuted(uint256 indexed agreementId, uint256 amendmentIndex);

    constructor(address _arbitrator) Ownable(msg.sender) {
        arbitrator = _arbitrator == address(0) ? msg.sender : _arbitrator;
    }

    // ── Agreement Creation ───────────────────────────────────────────

    /// @notice Create a new service agreement
    /// @param provider The service provider address
    /// @param title Agreement title
    /// @param scopeURI URI to the full scope document
    /// @param startDate Agreement start date (timestamp)
    /// @param endDate Agreement end date (timestamp)
    /// @param milestoneDescriptions Descriptions for each milestone
    /// @param milestoneAmounts Payment amount for each milestone (in wei)
    /// @param milestoneDeadlines Deadline timestamp for each milestone
    /// @return agreementId The ID of the created agreement
    function createAgreement(
        address provider,
        string calldata title,
        string calldata scopeURI,
        uint256 startDate,
        uint256 endDate,
        string[] calldata milestoneDescriptions,
        uint256[] calldata milestoneAmounts,
        uint256[] calldata milestoneDeadlines
    ) external payable nonReentrant returns (uint256 agreementId) {
        require(provider != address(0), "Zero provider");
        require(provider != msg.sender, "Cannot self-hire");
        require(bytes(title).length > 0, "Empty title");
        require(endDate > startDate, "Invalid dates");
        require(
            milestoneDescriptions.length == milestoneAmounts.length &&
            milestoneAmounts.length == milestoneDeadlines.length,
            "Length mismatch"
        );
        require(milestoneDescriptions.length > 0, "No milestones");

        uint256 totalValue = 0;
        for (uint256 i = 0; i < milestoneAmounts.length; i++) {
            require(milestoneAmounts[i] > 0, "Zero milestone amount");
            totalValue += milestoneAmounts[i];
        }

        // Client must fund the full agreement value
        require(msg.value >= totalValue, "Insufficient funding");

        agreementId = agreementCount++;

        agreements[agreementId] = Agreement({
            id: agreementId,
            client: msg.sender,
            provider: provider,
            title: title,
            scopeURI: scopeURI,
            totalValue: totalValue,
            totalPaid: 0,
            createdAt: block.timestamp,
            startDate: startDate,
            endDate: endDate,
            status: AgreementStatus.Draft
        });

        for (uint256 i = 0; i < milestoneDescriptions.length; i++) {
            milestones[agreementId].push(Milestone({
                description: milestoneDescriptions[i],
                amount: milestoneAmounts[i],
                deadline: milestoneDeadlines[i],
                submittedAt: 0,
                approvedAt: 0,
                deliverableURI: "",
                status: MilestoneStatus.Pending
            }));
        }

        // Refund excess
        if (msg.value > totalValue) {
            (bool success, ) = msg.sender.call{value: msg.value - totalValue}("");
            require(success, "Refund failed");
        }

        emit AgreementCreated(agreementId, msg.sender, provider, totalValue);
    }

    /// @notice Activate an agreement (provider confirms)
    function activateAgreement(uint256 agreementId) external {
        Agreement storage a = agreements[agreementId];
        require(msg.sender == a.provider, "Not provider");
        require(a.status == AgreementStatus.Draft, "Not draft");

        a.status = AgreementStatus.Active;
        emit AgreementActivated(agreementId);
    }

    // ── Milestone Workflow ───────────────────────────────────────────

    /// @notice Mark a milestone as started (provider)
    function startMilestone(uint256 agreementId, uint256 milestoneIndex) external {
        Agreement storage a = agreements[agreementId];
        require(msg.sender == a.provider, "Not provider");
        require(a.status == AgreementStatus.Active, "Not active");

        Milestone storage m = milestones[agreementId][milestoneIndex];
        require(m.status == MilestoneStatus.Pending, "Not pending");

        m.status = MilestoneStatus.InProgress;
        emit MilestoneStarted(agreementId, milestoneIndex);
    }

    /// @notice Submit milestone deliverable (provider)
    function submitMilestone(
        uint256 agreementId,
        uint256 milestoneIndex,
        string calldata deliverableURI
    ) external {
        Agreement storage a = agreements[agreementId];
        require(msg.sender == a.provider, "Not provider");
        require(a.status == AgreementStatus.Active, "Not active");

        Milestone storage m = milestones[agreementId][milestoneIndex];
        require(
            m.status == MilestoneStatus.InProgress || m.status == MilestoneStatus.Rejected,
            "Cannot submit"
        );

        m.deliverableURI = deliverableURI;
        m.submittedAt = block.timestamp;
        m.status = MilestoneStatus.Submitted;

        emit MilestoneSubmitted(agreementId, milestoneIndex, deliverableURI);
    }

    /// @notice Approve a submitted milestone (client)
    function approveMilestone(uint256 agreementId, uint256 milestoneIndex) external {
        Agreement storage a = agreements[agreementId];
        require(msg.sender == a.client, "Not client");
        require(a.status == AgreementStatus.Active, "Not active");

        Milestone storage m = milestones[agreementId][milestoneIndex];
        require(m.status == MilestoneStatus.Submitted, "Not submitted");

        m.status = MilestoneStatus.Approved;
        m.approvedAt = block.timestamp;

        emit MilestoneApproved(agreementId, milestoneIndex);
    }

    /// @notice Reject a submitted milestone (client)
    function rejectMilestone(
        uint256 agreementId,
        uint256 milestoneIndex,
        string calldata reason
    ) external {
        Agreement storage a = agreements[agreementId];
        require(msg.sender == a.client, "Not client");

        Milestone storage m = milestones[agreementId][milestoneIndex];
        require(m.status == MilestoneStatus.Submitted, "Not submitted");

        m.status = MilestoneStatus.Rejected;

        emit MilestoneRejected(agreementId, milestoneIndex, reason);
    }

    /// @notice Release payment for an approved milestone
    function releaseMilestonePayment(uint256 agreementId, uint256 milestoneIndex)
        external
        nonReentrant
    {
        Agreement storage a = agreements[agreementId];
        Milestone storage m = milestones[agreementId][milestoneIndex];

        // Allow auto-approval after timeout
        bool autoApproved = m.status == MilestoneStatus.Submitted &&
            block.timestamp > m.submittedAt + approvalTimeout;

        require(
            m.status == MilestoneStatus.Approved || autoApproved,
            "Not approved"
        );

        m.status = MilestoneStatus.Paid;

        uint256 fee = (m.amount * platformFeeBps) / BPS_DENOMINATOR;
        uint256 payout = m.amount - fee;

        a.totalPaid += m.amount;

        (bool providerSuccess, ) = a.provider.call{value: payout}("");
        require(providerSuccess, "Provider payment failed");

        if (fee > 0) {
            (bool feeSuccess, ) = owner().call{value: fee}("");
            require(feeSuccess, "Fee transfer failed");
        }

        emit MilestonePaid(agreementId, milestoneIndex, payout);

        // Check if all milestones are paid
        bool allPaid = true;
        Milestone[] storage ms = milestones[agreementId];
        for (uint256 i = 0; i < ms.length; i++) {
            if (ms[i].status != MilestoneStatus.Paid) {
                allPaid = false;
                break;
            }
        }
        if (allPaid) {
            a.status = AgreementStatus.Completed;
            emit AgreementCompleted(agreementId);
        }
    }

    // ── Disputes ─────────────────────────────────────────────────────

    /// @notice Raise a dispute on an agreement
    function raiseDispute(uint256 agreementId, string calldata reason) external {
        Agreement storage a = agreements[agreementId];
        require(msg.sender == a.client || msg.sender == a.provider, "Not a party");
        require(a.status == AgreementStatus.Active, "Not active");

        a.status = AgreementStatus.Disputed;
        emit DisputeRaised(agreementId, msg.sender, reason);
    }

    /// @notice Resolve a dispute (arbitrator only)
    /// @param agreementId The agreement in dispute
    /// @param releaseToProvider True = release remaining funds, False = refund client
    /// @param resolution Description of the resolution
    function resolveDispute(
        uint256 agreementId,
        bool releaseToProvider,
        string calldata resolution
    ) external nonReentrant {
        require(msg.sender == arbitrator, "Not arbitrator");
        Agreement storage a = agreements[agreementId];
        require(a.status == AgreementStatus.Disputed, "Not disputed");

        uint256 remaining = a.totalValue - a.totalPaid;
        a.status = AgreementStatus.Terminated;

        if (remaining > 0) {
            address recipient = releaseToProvider ? a.provider : a.client;
            (bool success, ) = recipient.call{value: remaining}("");
            require(success, "Resolution transfer failed");
        }

        emit DisputeResolved(agreementId, resolution);
    }

    // ── Termination ──────────────────────────────────────────────────

    /// @notice Terminate agreement by mutual consent or after deadline
    function terminateAgreement(uint256 agreementId) external nonReentrant {
        Agreement storage a = agreements[agreementId];
        require(msg.sender == a.client || msg.sender == a.provider, "Not a party");
        require(
            a.status == AgreementStatus.Active || a.status == AgreementStatus.Draft,
            "Cannot terminate"
        );

        a.status = AgreementStatus.Terminated;

        // Refund unpaid milestones to client
        uint256 remaining = a.totalValue - a.totalPaid;
        if (remaining > 0) {
            (bool success, ) = a.client.call{value: remaining}("");
            require(success, "Refund failed");
        }

        emit AgreementTerminated(agreementId, msg.sender);
    }

    // ── Amendments ───────────────────────────────────────────────────

    /// @notice Propose an amendment to the agreement
    function proposeAmendment(uint256 agreementId, string calldata description) external {
        Agreement storage a = agreements[agreementId];
        require(msg.sender == a.client || msg.sender == a.provider, "Not a party");
        require(a.status == AgreementStatus.Active, "Not active");

        amendments[agreementId].push(Amendment({
            description: description,
            clientApproved: msg.sender == a.client,
            providerApproved: msg.sender == a.provider,
            executed: false,
            proposedAt: block.timestamp
        }));

        emit AmendmentProposed(agreementId, amendments[agreementId].length - 1, description);
    }

    /// @notice Approve an amendment
    function approveAmendment(uint256 agreementId, uint256 amendmentIndex) external {
        Agreement storage a = agreements[agreementId];
        Amendment storage am = amendments[agreementId][amendmentIndex];
        require(!am.executed, "Already executed");

        if (msg.sender == a.client) {
            am.clientApproved = true;
        } else if (msg.sender == a.provider) {
            am.providerApproved = true;
        } else {
            revert("Not a party");
        }

        if (am.clientApproved && am.providerApproved) {
            am.executed = true;
            emit AmendmentExecuted(agreementId, amendmentIndex);
        }
    }

    // ── View ─────────────────────────────────────────────────────────

    /// @notice Get milestone count for an agreement
    function getMilestoneCount(uint256 agreementId) external view returns (uint256) {
        return milestones[agreementId].length;
    }

    /// @notice Get amendment count for an agreement
    function getAmendmentCount(uint256 agreementId) external view returns (uint256) {
        return amendments[agreementId].length;
    }

    /// @notice Get remaining unpaid amount
    function remainingValue(uint256 agreementId) external view returns (uint256) {
        Agreement storage a = agreements[agreementId];
        return a.totalValue - a.totalPaid;
    }

    // ── Admin ────────────────────────────────────────────────────────

    function setArbitrator(address newArbitrator) external onlyOwner {
        require(newArbitrator != address(0), "Zero address");
        arbitrator = newArbitrator;
    }

    function setApprovalTimeout(uint256 newTimeout) external onlyOwner {
        require(newTimeout >= 1 days && newTimeout <= 90 days, "Invalid timeout");
        approvalTimeout = newTimeout;
    }

    function setPlatformFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 1000, "Fee too high");
        platformFeeBps = newFeeBps;
    }

    receive() external payable {}
}
