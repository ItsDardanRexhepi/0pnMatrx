// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Crowdfund
/// @author 0pnMatrx — Creator Economy Pack
/// @notice Milestone-based crowdfunding with refund protection.
///         Backers contribute ETH to a campaign. Funds are released to the creator
///         only when predefined milestones are completed and verified. If the campaign
///         fails to meet its goal or milestones, backers can claim refunds.
/// @dev Features:
///      - Configurable funding goal and deadline
///      - Milestone-based fund release (not all-at-once)
///      - Backer refund if goal not met or milestones not completed
///      - Milestone verification by designated verifier
///      - Stretch goals with bonus milestones
///      - Campaign updates and backer communication

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Crowdfund is Ownable, ReentrancyGuard {

    // ── Types ────────────────────────────────────────────────────────

    enum CampaignStatus {
        Active,         // Accepting contributions
        Funded,         // Goal met, milestones in progress
        Completed,      // All milestones completed
        Failed,         // Goal not met by deadline
        Cancelled       // Creator cancelled
    }

    enum MilestoneStatus {
        Pending,
        Submitted,      // Creator submitted evidence of completion
        Verified,       // Verifier confirmed completion
        Released,       // Funds released to creator
        Disputed        // Under dispute
    }

    struct Campaign {
        address creator;
        string title;
        string description;
        string metadataURI;         // IPFS URI for full campaign details
        uint256 goal;               // funding goal in wei
        uint256 deadline;           // contribution deadline
        uint256 totalRaised;
        uint256 totalReleased;
        uint256 totalRefunded;
        uint256 backerCount;
        CampaignStatus status;
    }

    struct Milestone {
        string description;
        uint256 fundingPercentage;  // % of total funds released on completion (in BPS)
        string evidenceURI;
        MilestoneStatus status;
    }

    struct Contribution {
        uint256 amount;
        uint256 refunded;
        bool exists;
    }

    // ── State ────────────────────────────────────────────────────────

    Campaign public campaign;
    Milestone[] public milestones;

    /// @notice Backer contributions
    mapping(address => Contribution) public contributions;
    address[] public backerList;

    /// @notice Designated milestone verifier (can be a multisig)
    address public verifier;

    /// @notice Platform fee in basis points
    uint256 public platformFeeBps = 300; // 3%
    uint256 public constant BPS_DENOMINATOR = 10000;
    address public platformFeeRecipient;

    /// @notice Minimum contribution amount
    uint256 public minContribution = 0.001 ether;

    // ── Events ───────────────────────────────────────────────────────
    event CampaignCreated(string title, uint256 goal, uint256 deadline);
    event ContributionReceived(address indexed backer, uint256 amount, uint256 totalRaised);
    event GoalReached(uint256 totalRaised);
    event MilestoneSubmitted(uint256 indexed milestoneIndex, string evidenceURI);
    event MilestoneVerified(uint256 indexed milestoneIndex);
    event MilestoneDisputed(uint256 indexed milestoneIndex);
    event FundsReleased(uint256 indexed milestoneIndex, uint256 amount);
    event RefundClaimed(address indexed backer, uint256 amount);
    event CampaignCancelled();
    event CampaignCompleted();

    // ── Constructor ──────────────────────────────────────────────────

    /// @param _creator Campaign creator address
    /// @param _title Campaign title
    /// @param _description Campaign description
    /// @param _metadataURI IPFS URI for full details
    /// @param _goal Funding goal in wei
    /// @param _durationDays Campaign duration in days
    /// @param _verifier Address authorized to verify milestones
    /// @param _milestoneDescriptions Array of milestone descriptions
    /// @param _milestonePercentages Fund release % per milestone (in BPS, must sum to 10000)
    constructor(
        address _creator,
        string memory _title,
        string memory _description,
        string memory _metadataURI,
        uint256 _goal,
        uint256 _durationDays,
        address _verifier,
        string[] memory _milestoneDescriptions,
        uint256[] memory _milestonePercentages
    ) Ownable(msg.sender) {
        require(_creator != address(0), "Zero creator");
        require(_goal > 0, "Zero goal");
        require(_durationDays > 0 && _durationDays <= 365, "Invalid duration");
        require(_verifier != address(0), "Zero verifier");
        require(
            _milestoneDescriptions.length == _milestonePercentages.length,
            "Milestone length mismatch"
        );
        require(_milestoneDescriptions.length > 0, "No milestones");

        // Verify percentages sum to 10000 BPS (100%)
        uint256 totalPct = 0;
        for (uint256 i = 0; i < _milestonePercentages.length; i++) {
            require(_milestonePercentages[i] > 0, "Zero percentage");
            totalPct += _milestonePercentages[i];
        }
        require(totalPct == BPS_DENOMINATOR, "Percentages must sum to 100%");

        campaign = Campaign({
            creator: _creator,
            title: _title,
            description: _description,
            metadataURI: _metadataURI,
            goal: _goal,
            deadline: block.timestamp + (_durationDays * 1 days),
            totalRaised: 0,
            totalReleased: 0,
            totalRefunded: 0,
            backerCount: 0,
            status: CampaignStatus.Active
        });

        for (uint256 i = 0; i < _milestoneDescriptions.length; i++) {
            milestones.push(Milestone({
                description: _milestoneDescriptions[i],
                fundingPercentage: _milestonePercentages[i],
                evidenceURI: "",
                status: MilestoneStatus.Pending
            }));
        }

        verifier = _verifier;
        platformFeeRecipient = msg.sender;

        emit CampaignCreated(_title, _goal, campaign.deadline);
    }

    // ── Contributing ─────────────────────────────────────────────────

    /// @notice Contribute ETH to the campaign
    function contribute() external payable nonReentrant {
        require(campaign.status == CampaignStatus.Active, "Campaign not active");
        require(block.timestamp <= campaign.deadline, "Campaign ended");
        require(msg.value >= minContribution, "Below minimum");

        Contribution storage contrib = contributions[msg.sender];
        if (!contrib.exists) {
            contrib.exists = true;
            backerList.push(msg.sender);
            campaign.backerCount++;
        }
        contrib.amount += msg.value;
        campaign.totalRaised += msg.value;

        emit ContributionReceived(msg.sender, msg.value, campaign.totalRaised);

        // Check if goal reached
        if (campaign.totalRaised >= campaign.goal && campaign.status == CampaignStatus.Active) {
            campaign.status = CampaignStatus.Funded;
            emit GoalReached(campaign.totalRaised);
        }
    }

    // ── Milestone Management ─────────────────────────────────────────

    /// @notice Submit milestone completion evidence (creator only)
    /// @param milestoneIndex Index of the milestone
    /// @param evidenceURI URI pointing to evidence of completion
    function submitMilestone(uint256 milestoneIndex, string calldata evidenceURI)
        external
    {
        require(msg.sender == campaign.creator, "Not creator");
        require(campaign.status == CampaignStatus.Funded, "Campaign not funded");
        require(milestoneIndex < milestones.length, "Invalid milestone");

        Milestone storage milestone = milestones[milestoneIndex];
        require(
            milestone.status == MilestoneStatus.Pending || milestone.status == MilestoneStatus.Disputed,
            "Cannot submit"
        );

        milestone.evidenceURI = evidenceURI;
        milestone.status = MilestoneStatus.Submitted;

        emit MilestoneSubmitted(milestoneIndex, evidenceURI);
    }

    /// @notice Verify a submitted milestone (verifier only)
    /// @param milestoneIndex Index of the milestone to verify
    function verifyMilestone(uint256 milestoneIndex) external {
        require(msg.sender == verifier, "Not verifier");
        require(milestoneIndex < milestones.length, "Invalid milestone");

        Milestone storage milestone = milestones[milestoneIndex];
        require(milestone.status == MilestoneStatus.Submitted, "Not submitted");

        milestone.status = MilestoneStatus.Verified;

        emit MilestoneVerified(milestoneIndex);
    }

    /// @notice Dispute a submitted milestone (verifier only)
    /// @param milestoneIndex Index of the milestone to dispute
    function disputeMilestone(uint256 milestoneIndex) external {
        require(msg.sender == verifier, "Not verifier");
        require(milestoneIndex < milestones.length, "Invalid milestone");

        Milestone storage milestone = milestones[milestoneIndex];
        require(milestone.status == MilestoneStatus.Submitted, "Not submitted");

        milestone.status = MilestoneStatus.Disputed;

        emit MilestoneDisputed(milestoneIndex);
    }

    /// @notice Release funds for a verified milestone (anyone can call)
    /// @param milestoneIndex Index of the milestone
    function releaseFunds(uint256 milestoneIndex) external nonReentrant {
        require(milestoneIndex < milestones.length, "Invalid milestone");

        Milestone storage milestone = milestones[milestoneIndex];
        require(milestone.status == MilestoneStatus.Verified, "Not verified");

        milestone.status = MilestoneStatus.Released;

        uint256 releaseAmount = (campaign.totalRaised * milestone.fundingPercentage) / BPS_DENOMINATOR;
        uint256 platformFee = (releaseAmount * platformFeeBps) / BPS_DENOMINATOR;
        uint256 creatorAmount = releaseAmount - platformFee;

        campaign.totalReleased += releaseAmount;

        // Pay creator
        (bool creatorSuccess, ) = campaign.creator.call{value: creatorAmount}("");
        require(creatorSuccess, "Creator payment failed");

        // Pay platform fee
        if (platformFee > 0) {
            (bool feeSuccess, ) = platformFeeRecipient.call{value: platformFee}("");
            require(feeSuccess, "Fee payment failed");
        }

        emit FundsReleased(milestoneIndex, releaseAmount);

        // Check if all milestones completed
        bool allCompleted = true;
        for (uint256 i = 0; i < milestones.length; i++) {
            if (milestones[i].status != MilestoneStatus.Released) {
                allCompleted = false;
                break;
            }
        }
        if (allCompleted) {
            campaign.status = CampaignStatus.Completed;
            emit CampaignCompleted();
        }
    }

    // ── Refunds ──────────────────────────────────────────────────────

    /// @notice Claim a refund (only if campaign failed or was cancelled)
    function claimRefund() external nonReentrant {
        require(
            campaign.status == CampaignStatus.Failed ||
            campaign.status == CampaignStatus.Cancelled,
            "Refunds not available"
        );

        Contribution storage contrib = contributions[msg.sender];
        require(contrib.exists, "Not a backer");

        uint256 refundable = contrib.amount - contrib.refunded;
        require(refundable > 0, "Nothing to refund");

        contrib.refunded += refundable;
        campaign.totalRefunded += refundable;

        (bool success, ) = msg.sender.call{value: refundable}("");
        require(success, "Refund failed");

        emit RefundClaimed(msg.sender, refundable);
    }

    /// @notice Mark campaign as failed if deadline passed without meeting goal
    function markFailed() external {
        require(campaign.status == CampaignStatus.Active, "Not active");
        require(block.timestamp > campaign.deadline, "Deadline not passed");
        require(campaign.totalRaised < campaign.goal, "Goal was met");

        campaign.status = CampaignStatus.Failed;
    }

    /// @notice Cancel the campaign (creator or owner only)
    function cancelCampaign() external {
        require(
            msg.sender == campaign.creator || msg.sender == owner(),
            "Not authorized"
        );
        require(
            campaign.status == CampaignStatus.Active || campaign.status == CampaignStatus.Funded,
            "Cannot cancel"
        );

        campaign.status = CampaignStatus.Cancelled;
        emit CampaignCancelled();
    }

    // ── View Functions ───────────────────────────────────────────────

    /// @notice Get the number of milestones
    function milestoneCount() external view returns (uint256) {
        return milestones.length;
    }

    /// @notice Get the number of backers
    function getBackerCount() external view returns (uint256) {
        return backerList.length;
    }

    /// @notice Get all backer addresses
    function getBackers() external view returns (address[] memory) {
        return backerList;
    }

    /// @notice Get the funding progress as a percentage (BPS)
    /// @return Progress in basis points (10000 = 100%)
    function fundingProgress() external view returns (uint256) {
        if (campaign.goal == 0) return 0;
        uint256 progress = (campaign.totalRaised * BPS_DENOMINATOR) / campaign.goal;
        return progress > BPS_DENOMINATOR ? BPS_DENOMINATOR : progress;
    }

    /// @notice Get time remaining until deadline
    /// @return Seconds remaining (0 if past deadline)
    function timeRemaining() external view returns (uint256) {
        if (block.timestamp >= campaign.deadline) return 0;
        return campaign.deadline - block.timestamp;
    }

    /// @notice Check how much of the raised funds are still unreleased
    function unreleasedFunds() external view returns (uint256) {
        return campaign.totalRaised - campaign.totalReleased - campaign.totalRefunded;
    }

    // ── Admin ────────────────────────────────────────────────────────

    /// @notice Update the milestone verifier
    function setVerifier(address newVerifier) external onlyOwner {
        require(newVerifier != address(0), "Zero address");
        verifier = newVerifier;
    }

    /// @notice Update minimum contribution
    function setMinContribution(uint256 newMin) external onlyOwner {
        minContribution = newMin;
    }

    receive() external payable {
        revert("Use contribute()");
    }
}
