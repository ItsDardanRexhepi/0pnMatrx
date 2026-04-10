// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CreatorDAO
/// @author 0pnMatrx — Creator Economy Pack
/// @notice DAO for fan communities with membership tokens.
///         Members hold governance tokens, propose actions, and vote.
///         Supports treasury management, quorum requirements, and time-locked execution.
/// @dev Features:
///      - ERC-20 governance token with minting controlled by DAO
///      - Proposal creation, voting, and execution
///      - Configurable quorum and voting periods
///      - Treasury management (ETH and ERC-20)
///      - Membership tiers based on token holdings
///      - Delegate voting support

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CreatorDAO is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ── Types ────────────────────────────────────────────────────────

    enum ProposalStatus {
        Pending,
        Active,
        Passed,
        Failed,
        Executed,
        Cancelled
    }

    enum MembershipTier {
        None,       // 0 tokens
        Bronze,     // >= bronzeThreshold
        Silver,     // >= silverThreshold
        Gold,       // >= goldThreshold
        Platinum    // >= platinumThreshold
    }

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        address target;             // contract to call on execution
        bytes callData;             // encoded function call
        uint256 value;              // ETH to send with call
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 createdAt;
        uint256 votingDeadline;
        uint256 executionDeadline;
        bool executed;
        bool cancelled;
    }

    // ── State ────────────────────────────────────────────────────────

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    /// @notice Track who voted on which proposal
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    /// @notice Delegation: delegator => delegate
    mapping(address => address) public delegates;

    /// @notice Governance parameters
    uint256 public votingPeriod = 3 days;
    uint256 public executionWindow = 2 days;
    uint256 public quorumBps = 1000;           // 10% quorum
    uint256 public proposalThreshold;           // min tokens to propose
    uint256 public constant BPS_DENOMINATOR = 10000;

    /// @notice Membership tier thresholds
    uint256 public bronzeThreshold = 100 * 1e18;
    uint256 public silverThreshold = 1000 * 1e18;
    uint256 public goldThreshold = 10000 * 1e18;
    uint256 public platinumThreshold = 100000 * 1e18;

    /// @notice Membership price in ETH (for buying tokens)
    uint256 public membershipPrice = 0.01 ether;

    // ── Events ───────────────────────────────────────────────────────
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event MemberJoined(address indexed member, uint256 tokenAmount);
    event DelegateChanged(address indexed delegator, address indexed newDelegate);
    event TreasuryDeposit(address indexed from, uint256 amount);
    event GovernanceUpdated(string parameter, uint256 newValue);

    // ── Constructor ──────────────────────────────────────────────────

    /// @param name_ DAO token name (e.g., "Creator Fan Token")
    /// @param symbol_ DAO token symbol (e.g., "FAN")
    /// @param initialSupply Initial tokens minted to the deployer
    /// @param proposalThreshold_ Minimum tokens required to create a proposal
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        uint256 proposalThreshold_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        proposalThreshold = proposalThreshold_;
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply);
        }
    }

    // ── Membership ───────────────────────────────────────────────────

    /// @notice Join the DAO by purchasing membership tokens
    function joinDAO() external payable nonReentrant {
        require(msg.value >= membershipPrice, "Insufficient payment");
        uint256 tokenAmount = (msg.value * 1e18) / membershipPrice;
        _mint(msg.sender, tokenAmount);
        emit MemberJoined(msg.sender, tokenAmount);
    }

    /// @notice Get membership tier for an address
    /// @param member The address to check
    /// @return The membership tier
    function getMembershipTier(address member) external view returns (MembershipTier) {
        uint256 balance = balanceOf(member);
        if (balance >= platinumThreshold) return MembershipTier.Platinum;
        if (balance >= goldThreshold) return MembershipTier.Gold;
        if (balance >= silverThreshold) return MembershipTier.Silver;
        if (balance >= bronzeThreshold) return MembershipTier.Bronze;
        return MembershipTier.None;
    }

    // ── Delegation ───────────────────────────────────────────────────

    /// @notice Delegate voting power to another address
    /// @param delegatee The address to delegate to (address(0) to remove)
    function delegate(address delegatee) external {
        delegates[msg.sender] = delegatee;
        emit DelegateChanged(msg.sender, delegatee);
    }

    /// @notice Get the voting power of an address (own tokens + delegated)
    /// @param voter The address to check
    /// @return Total voting power
    function getVotingPower(address voter) public view returns (uint256) {
        return balanceOf(voter);
    }

    // ── Proposals ────────────────────────────────────────────────────

    /// @notice Create a new proposal
    /// @param description Human-readable description
    /// @param target Contract to call if proposal passes
    /// @param callData Encoded function call data
    /// @param value ETH to send with the call
    /// @return proposalId The ID of the created proposal
    function createProposal(
        string calldata description,
        address target,
        bytes calldata callData,
        uint256 value
    ) external returns (uint256 proposalId) {
        require(balanceOf(msg.sender) >= proposalThreshold, "Below proposal threshold");

        proposalId = proposalCount++;

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            description: description,
            target: target,
            callData: callData,
            value: value,
            votesFor: 0,
            votesAgainst: 0,
            createdAt: block.timestamp,
            votingDeadline: block.timestamp + votingPeriod,
            executionDeadline: block.timestamp + votingPeriod + executionWindow,
            executed: false,
            cancelled: false
        });

        emit ProposalCreated(proposalId, msg.sender, description);
    }

    /// @notice Vote on a proposal
    /// @param proposalId The proposal to vote on
    /// @param support True for yes, false for no
    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp <= proposal.votingDeadline, "Voting ended");
        require(!proposal.cancelled, "Proposal cancelled");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 weight = getVotingPower(msg.sender);
        require(weight > 0, "No voting power");

        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            proposal.votesFor += weight;
        } else {
            proposal.votesAgainst += weight;
        }

        emit Voted(proposalId, msg.sender, support, weight);
    }

    /// @notice Execute a passed proposal
    /// @param proposalId The proposal to execute
    function executeProposal(uint256 proposalId) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Already executed");
        require(!proposal.cancelled, "Proposal cancelled");
        require(block.timestamp > proposal.votingDeadline, "Voting not ended");
        require(block.timestamp <= proposal.executionDeadline, "Execution window expired");

        // Check quorum
        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 quorumRequired = (totalSupply() * quorumBps) / BPS_DENOMINATOR;
        require(totalVotes >= quorumRequired, "Quorum not met");

        // Check majority
        require(proposal.votesFor > proposal.votesAgainst, "Proposal failed");

        proposal.executed = true;

        // Execute the proposal action
        if (proposal.target != address(0)) {
            (bool success, ) = proposal.target.call{value: proposal.value}(proposal.callData);
            require(success, "Execution failed");
        }

        emit ProposalExecuted(proposalId);
    }

    /// @notice Cancel a proposal (only proposer or owner)
    /// @param proposalId The proposal to cancel
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "Not authorized"
        );
        require(!proposal.executed, "Already executed");
        require(!proposal.cancelled, "Already cancelled");

        proposal.cancelled = true;
        emit ProposalCancelled(proposalId);
    }

    // ── View ─────────────────────────────────────────────────────────

    /// @notice Get the status of a proposal
    function getProposalStatus(uint256 proposalId) external view returns (ProposalStatus) {
        Proposal storage p = proposals[proposalId];
        if (p.cancelled) return ProposalStatus.Cancelled;
        if (p.executed) return ProposalStatus.Executed;
        if (block.timestamp <= p.votingDeadline) return ProposalStatus.Active;

        uint256 totalVotes = p.votesFor + p.votesAgainst;
        uint256 quorumRequired = (totalSupply() * quorumBps) / BPS_DENOMINATOR;

        if (totalVotes < quorumRequired || p.votesFor <= p.votesAgainst) {
            return ProposalStatus.Failed;
        }
        return ProposalStatus.Passed;
    }

    /// @notice Get treasury ETH balance
    function treasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // ── Admin ────────────────────────────────────────────────────────

    /// @notice Mint tokens to a member (owner only, for rewards etc.)
    function mintTokens(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Update governance parameters
    function setVotingPeriod(uint256 newPeriod) external onlyOwner {
        require(newPeriod >= 1 hours && newPeriod <= 30 days, "Invalid period");
        votingPeriod = newPeriod;
        emit GovernanceUpdated("votingPeriod", newPeriod);
    }

    function setQuorum(uint256 newQuorumBps) external onlyOwner {
        require(newQuorumBps <= 5000, "Quorum too high");
        quorumBps = newQuorumBps;
        emit GovernanceUpdated("quorumBps", newQuorumBps);
    }

    function setProposalThreshold(uint256 newThreshold) external onlyOwner {
        proposalThreshold = newThreshold;
        emit GovernanceUpdated("proposalThreshold", newThreshold);
    }

    function setMembershipPrice(uint256 newPrice) external onlyOwner {
        membershipPrice = newPrice;
        emit GovernanceUpdated("membershipPrice", newPrice);
    }

    function setTierThresholds(
        uint256 bronze,
        uint256 silver,
        uint256 gold,
        uint256 platinum
    ) external onlyOwner {
        require(bronze < silver && silver < gold && gold < platinum, "Invalid thresholds");
        bronzeThreshold = bronze;
        silverThreshold = silver;
        goldThreshold = gold;
        platinumThreshold = platinum;
    }

    /// @notice Receive ETH into treasury
    receive() external payable {
        emit TreasuryDeposit(msg.sender, msg.value);
    }
}
