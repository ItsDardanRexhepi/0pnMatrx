// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MultiSigEscrow
/// @author 0pnMatrx — Business Infrastructure Pack
/// @notice Multi-party escrow requiring N of M signatures to release funds.
///         Supports ETH and ERC-20 deposits, multiple concurrent escrows,
///         configurable approval thresholds, and dispute resolution.
/// @dev Features:
///      - Create escrows with configurable signer sets and thresholds
///      - Deposit ETH or ERC-20 tokens
///      - N-of-M approval to release funds
///      - Expiration-based auto-refund
///      - Dispute mechanism with arbitrator resolution
///      - Full audit trail via events

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MultiSigEscrow is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ── Types ────────────────────────────────────────────────────────

    enum EscrowStatus {
        Created,        // Escrow created, awaiting deposit
        Funded,         // Funds deposited
        PendingRelease, // Release requested, collecting approvals
        Released,       // Funds released to beneficiary
        Refunded,       // Funds returned to depositor
        Disputed,       // Under dispute
        Resolved        // Dispute resolved
    }

    struct Escrow {
        uint256 id;
        address depositor;
        address beneficiary;
        address tokenAddress;       // address(0) for ETH
        uint256 amount;
        uint256 depositedAmount;
        address[] signers;
        uint256 requiredApprovals;  // N of M
        uint256 approvalCount;
        uint256 createdAt;
        uint256 expiresAt;
        string description;
        EscrowStatus status;
    }

    // ── State ────────────────────────────────────────────────────────

    mapping(uint256 => Escrow) public escrows;
    uint256 public escrowCount;

    /// @notice Track approvals: escrowId => signer => approved
    mapping(uint256 => mapping(address => bool)) public approvals;

    /// @notice Track which addresses are signers for each escrow
    mapping(uint256 => mapping(address => bool)) public isSigner;

    /// @notice Arbitrator for dispute resolution
    address public arbitrator;

    /// @notice Platform fee in basis points
    uint256 public platformFeeBps = 100; // 1%
    uint256 public constant BPS_DENOMINATOR = 10000;

    // ── Events ───────────────────────────────────────────────────────
    event EscrowCreated(uint256 indexed escrowId, address indexed depositor, address indexed beneficiary, uint256 amount);
    event EscrowFunded(uint256 indexed escrowId, uint256 amount);
    event ApprovalGranted(uint256 indexed escrowId, address indexed signer, uint256 approvalCount);
    event ApprovalRevoked(uint256 indexed escrowId, address indexed signer, uint256 approvalCount);
    event FundsReleased(uint256 indexed escrowId, address indexed beneficiary, uint256 amount);
    event FundsRefunded(uint256 indexed escrowId, address indexed depositor, uint256 amount);
    event DisputeRaised(uint256 indexed escrowId, address indexed by);
    event DisputeResolved(uint256 indexed escrowId, bool releaseToBeneficiary);

    // ── Constructor ──────────────────────────────────────────────────

    constructor(address _arbitrator) Ownable(msg.sender) {
        arbitrator = _arbitrator == address(0) ? msg.sender : _arbitrator;
    }

    // ── Escrow Lifecycle ─────────────────────────────────────────────

    /// @notice Create a new escrow arrangement
    /// @param beneficiary Address that receives funds on release
    /// @param tokenAddress ERC-20 token address (address(0) for ETH)
    /// @param amount Expected deposit amount
    /// @param signers Array of authorized signer addresses
    /// @param requiredApprovals Number of approvals needed (N of M)
    /// @param durationDays Days until escrow expires
    /// @param description Human-readable description of the escrow purpose
    /// @return escrowId The ID of the created escrow
    function createEscrow(
        address beneficiary,
        address tokenAddress,
        uint256 amount,
        address[] calldata signers,
        uint256 requiredApprovals,
        uint256 durationDays,
        string calldata description
    ) external returns (uint256 escrowId) {
        require(beneficiary != address(0), "Zero beneficiary");
        require(amount > 0, "Zero amount");
        require(signers.length >= requiredApprovals, "Not enough signers");
        require(requiredApprovals > 0, "Zero approvals");
        require(signers.length <= 20, "Too many signers");
        require(durationDays > 0 && durationDays <= 365, "Invalid duration");

        escrowId = escrowCount++;

        Escrow storage e = escrows[escrowId];
        e.id = escrowId;
        e.depositor = msg.sender;
        e.beneficiary = beneficiary;
        e.tokenAddress = tokenAddress;
        e.amount = amount;
        e.signers = signers;
        e.requiredApprovals = requiredApprovals;
        e.createdAt = block.timestamp;
        e.expiresAt = block.timestamp + (durationDays * 1 days);
        e.description = description;
        e.status = EscrowStatus.Created;

        for (uint256 i = 0; i < signers.length; i++) {
            require(signers[i] != address(0), "Zero signer");
            isSigner[escrowId][signers[i]] = true;
        }

        emit EscrowCreated(escrowId, msg.sender, beneficiary, amount);
    }

    /// @notice Fund an escrow with ETH
    /// @param escrowId The escrow to fund
    function fundEscrowETH(uint256 escrowId) external payable nonReentrant {
        Escrow storage e = escrows[escrowId];
        require(e.status == EscrowStatus.Created, "Not in created state");
        require(e.tokenAddress == address(0), "Not an ETH escrow");
        require(msg.value >= e.amount, "Insufficient funds");

        e.depositedAmount = msg.value;
        e.status = EscrowStatus.Funded;

        // Refund excess
        if (msg.value > e.amount) {
            (bool success, ) = msg.sender.call{value: msg.value - e.amount}("");
            require(success, "Refund failed");
            e.depositedAmount = e.amount;
        }

        emit EscrowFunded(escrowId, e.depositedAmount);
    }

    /// @notice Fund an escrow with ERC-20 tokens
    /// @param escrowId The escrow to fund
    function fundEscrowToken(uint256 escrowId) external nonReentrant {
        Escrow storage e = escrows[escrowId];
        require(e.status == EscrowStatus.Created, "Not in created state");
        require(e.tokenAddress != address(0), "Not a token escrow");

        IERC20 token = IERC20(e.tokenAddress);
        token.safeTransferFrom(msg.sender, address(this), e.amount);

        e.depositedAmount = e.amount;
        e.status = EscrowStatus.Funded;

        emit EscrowFunded(escrowId, e.depositedAmount);
    }

    // ── Approval Process ─────────────────────────────────────────────

    /// @notice Approve fund release (signer only)
    /// @param escrowId The escrow to approve
    function approve(uint256 escrowId) external {
        Escrow storage e = escrows[escrowId];
        require(
            e.status == EscrowStatus.Funded || e.status == EscrowStatus.PendingRelease,
            "Cannot approve"
        );
        require(isSigner[escrowId][msg.sender], "Not a signer");
        require(!approvals[escrowId][msg.sender], "Already approved");
        require(block.timestamp <= e.expiresAt, "Escrow expired");

        approvals[escrowId][msg.sender] = true;
        e.approvalCount++;

        if (e.status == EscrowStatus.Funded) {
            e.status = EscrowStatus.PendingRelease;
        }

        emit ApprovalGranted(escrowId, msg.sender, e.approvalCount);

        // Auto-release if threshold met
        if (e.approvalCount >= e.requiredApprovals) {
            _releaseFunds(escrowId);
        }
    }

    /// @notice Revoke a previously granted approval
    /// @param escrowId The escrow to revoke approval from
    function revokeApproval(uint256 escrowId) external {
        Escrow storage e = escrows[escrowId];
        require(
            e.status == EscrowStatus.PendingRelease || e.status == EscrowStatus.Funded,
            "Cannot revoke"
        );
        require(approvals[escrowId][msg.sender], "Not approved");

        approvals[escrowId][msg.sender] = false;
        e.approvalCount--;

        if (e.approvalCount == 0) {
            e.status = EscrowStatus.Funded;
        }

        emit ApprovalRevoked(escrowId, msg.sender, e.approvalCount);
    }

    // ── Refunds ──────────────────────────────────────────────────────

    /// @notice Claim refund after escrow expiration
    /// @param escrowId The expired escrow
    function claimRefund(uint256 escrowId) external nonReentrant {
        Escrow storage e = escrows[escrowId];
        require(e.depositor == msg.sender, "Not depositor");
        require(
            e.status == EscrowStatus.Funded || e.status == EscrowStatus.PendingRelease,
            "Cannot refund"
        );
        require(block.timestamp > e.expiresAt, "Not expired yet");

        e.status = EscrowStatus.Refunded;

        if (e.tokenAddress == address(0)) {
            (bool success, ) = e.depositor.call{value: e.depositedAmount}("");
            require(success, "ETH refund failed");
        } else {
            IERC20(e.tokenAddress).safeTransfer(e.depositor, e.depositedAmount);
        }

        emit FundsRefunded(escrowId, e.depositor, e.depositedAmount);
    }

    // ── Dispute Resolution ───────────────────────────────────────────

    /// @notice Raise a dispute on an escrow
    /// @param escrowId The escrow to dispute
    function raiseDispute(uint256 escrowId) external {
        Escrow storage e = escrows[escrowId];
        require(
            msg.sender == e.depositor || msg.sender == e.beneficiary || isSigner[escrowId][msg.sender],
            "Not authorized"
        );
        require(
            e.status == EscrowStatus.Funded || e.status == EscrowStatus.PendingRelease,
            "Cannot dispute"
        );

        e.status = EscrowStatus.Disputed;
        emit DisputeRaised(escrowId, msg.sender);
    }

    /// @notice Resolve a dispute (arbitrator only)
    /// @param escrowId The disputed escrow
    /// @param releaseToBeneficiary True to release to beneficiary, false to refund depositor
    function resolveDispute(uint256 escrowId, bool releaseToBeneficiary) external nonReentrant {
        require(msg.sender == arbitrator, "Not arbitrator");
        Escrow storage e = escrows[escrowId];
        require(e.status == EscrowStatus.Disputed, "Not disputed");

        e.status = EscrowStatus.Resolved;

        if (releaseToBeneficiary) {
            _transferFunds(e.beneficiary, e.tokenAddress, e.depositedAmount);
            emit FundsReleased(escrowId, e.beneficiary, e.depositedAmount);
        } else {
            _transferFunds(e.depositor, e.tokenAddress, e.depositedAmount);
            emit FundsRefunded(escrowId, e.depositor, e.depositedAmount);
        }

        emit DisputeResolved(escrowId, releaseToBeneficiary);
    }

    // ── View Functions ───────────────────────────────────────────────

    /// @notice Get the signer list for an escrow
    function getSigners(uint256 escrowId) external view returns (address[] memory) {
        return escrows[escrowId].signers;
    }

    /// @notice Check if a specific signer has approved
    function hasApproved(uint256 escrowId, address signer) external view returns (bool) {
        return approvals[escrowId][signer];
    }

    /// @notice Get remaining approvals needed
    function remainingApprovals(uint256 escrowId) external view returns (uint256) {
        Escrow storage e = escrows[escrowId];
        if (e.approvalCount >= e.requiredApprovals) return 0;
        return e.requiredApprovals - e.approvalCount;
    }

    /// @notice Check if escrow has expired
    function isExpired(uint256 escrowId) external view returns (bool) {
        return block.timestamp > escrows[escrowId].expiresAt;
    }

    // ── Admin ────────────────────────────────────────────────────────

    /// @notice Update the arbitrator address
    function setArbitrator(address newArbitrator) external onlyOwner {
        require(newArbitrator != address(0), "Zero address");
        arbitrator = newArbitrator;
    }

    /// @notice Update platform fee
    function setPlatformFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 500, "Fee too high");
        platformFeeBps = newFeeBps;
    }

    // ── Internal ─────────────────────────────────────────────────────

    function _releaseFunds(uint256 escrowId) internal {
        Escrow storage e = escrows[escrowId];
        e.status = EscrowStatus.Released;

        uint256 fee = (e.depositedAmount * platformFeeBps) / BPS_DENOMINATOR;
        uint256 payout = e.depositedAmount - fee;

        _transferFunds(e.beneficiary, e.tokenAddress, payout);

        if (fee > 0) {
            _transferFunds(owner(), e.tokenAddress, fee);
        }

        emit FundsReleased(escrowId, e.beneficiary, payout);
    }

    function _transferFunds(address to, address tokenAddress, uint256 amount) internal {
        if (tokenAddress == address(0)) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(tokenAddress).safeTransfer(to, amount);
        }
    }

    receive() external payable {}
}
