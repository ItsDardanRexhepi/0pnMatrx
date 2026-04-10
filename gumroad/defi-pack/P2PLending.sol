// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title P2PLending
/// @author 0pnMatrx — DeFi Primitives Pack
/// @notice Peer-to-peer lending protocol with on-chain reputation scoring.
///         Lenders create loan offers, borrowers accept them, and both parties
///         build reputation based on successful completions and defaults.
/// @dev Flow:
///      1. Lender calls createOffer() to post a loan offer with terms
///      2. Borrower calls acceptOffer() to take the loan (must meet collateral req)
///      3. Borrower calls repayLoan() before the deadline
///      4. If borrower defaults, lender calls claimDefault() to seize collateral
///      Reputation scores update automatically on repayment or default.

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract P2PLending is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ── Types ────────────────────────────────────────────────────────

    enum LoanStatus {
        Open,           // Offer posted, waiting for borrower
        Active,         // Loan accepted, funds disbursed
        Repaid,         // Successfully repaid
        Defaulted,      // Borrower failed to repay on time
        Cancelled       // Offer cancelled by lender
    }

    struct LoanOffer {
        address lender;
        address borrower;            // address(0) until accepted
        uint256 principalAmount;     // amount lent in wei
        uint256 interestAmount;      // total interest due in wei
        uint256 collateralRequired;  // collateral the borrower must post
        uint256 collateralDeposited; // actual collateral posted
        uint256 duration;            // loan duration in seconds
        uint256 createdAt;
        uint256 acceptedAt;
        uint256 repaidAt;
        LoanStatus status;
    }

    struct Reputation {
        uint256 loansCompleted;    // successful repayments
        uint256 loansDefaulted;    // defaults
        uint256 totalLent;         // cumulative amount lent
        uint256 totalBorrowed;     // cumulative amount borrowed
        uint256 score;             // 0-1000 reputation score
    }

    // ── State ────────────────────────────────────────────────────────

    mapping(uint256 => LoanOffer) public loans;
    uint256 public loanCount;

    mapping(address => Reputation) public reputations;
    mapping(address => uint256[]) public userLoansAsLender;
    mapping(address => uint256[]) public userLoansAsBorrower;

    uint256 public constant INITIAL_REPUTATION = 500;
    uint256 public constant MAX_REPUTATION = 1000;
    uint256 public constant REPUTATION_GAIN = 25;
    uint256 public constant REPUTATION_LOSS = 100;

    uint256 public platformFeeBps = 100; // 1% platform fee
    uint256 public constant BPS_DENOMINATOR = 10000;

    // ── Events ───────────────────────────────────────────────────────
    event OfferCreated(uint256 indexed loanId, address indexed lender, uint256 principal, uint256 interest, uint256 duration);
    event OfferCancelled(uint256 indexed loanId);
    event LoanAccepted(uint256 indexed loanId, address indexed borrower);
    event LoanRepaid(uint256 indexed loanId, uint256 totalPaid);
    event LoanDefaulted(uint256 indexed loanId, uint256 collateralSeized);
    event ReputationUpdated(address indexed user, uint256 newScore);

    constructor() Ownable(msg.sender) {}

    // ── Lender Functions ─────────────────────────────────────────────

    /// @notice Create a new loan offer
    /// @param interestAmount Total interest the borrower must pay
    /// @param collateralRequired ETH collateral the borrower must post
    /// @param duration Loan duration in seconds
    /// @return loanId The ID of the created offer
    function createOffer(
        uint256 interestAmount,
        uint256 collateralRequired,
        uint256 duration
    ) external payable nonReentrant returns (uint256 loanId) {
        require(msg.value > 0, "Must send principal");
        require(duration > 0, "Zero duration");
        require(duration <= 365 days, "Duration too long");

        loanId = loanCount++;

        loans[loanId] = LoanOffer({
            lender: msg.sender,
            borrower: address(0),
            principalAmount: msg.value,
            interestAmount: interestAmount,
            collateralRequired: collateralRequired,
            collateralDeposited: 0,
            duration: duration,
            createdAt: block.timestamp,
            acceptedAt: 0,
            repaidAt: 0,
            status: LoanStatus.Open
        });

        userLoansAsLender[msg.sender].push(loanId);
        _ensureReputation(msg.sender);

        emit OfferCreated(loanId, msg.sender, msg.value, interestAmount, duration);
    }

    /// @notice Cancel an open loan offer and reclaim funds
    /// @param loanId The offer to cancel
    function cancelOffer(uint256 loanId) external nonReentrant {
        LoanOffer storage loan = loans[loanId];
        require(loan.lender == msg.sender, "Not lender");
        require(loan.status == LoanStatus.Open, "Not open");

        loan.status = LoanStatus.Cancelled;

        (bool success, ) = msg.sender.call{value: loan.principalAmount}("");
        require(success, "Refund failed");

        emit OfferCancelled(loanId);
    }

    // ── Borrower Functions ───────────────────────────────────────────

    /// @notice Accept a loan offer by posting required collateral
    /// @param loanId The offer to accept
    function acceptOffer(uint256 loanId) external payable nonReentrant {
        LoanOffer storage loan = loans[loanId];
        require(loan.status == LoanStatus.Open, "Not open");
        require(msg.sender != loan.lender, "Cannot self-lend");
        require(msg.value >= loan.collateralRequired, "Insufficient collateral");

        loan.borrower = msg.sender;
        loan.collateralDeposited = msg.value;
        loan.acceptedAt = block.timestamp;
        loan.status = LoanStatus.Active;

        userLoansAsBorrower[msg.sender].push(loanId);
        _ensureReputation(msg.sender);

        // Disburse principal to borrower
        (bool success, ) = msg.sender.call{value: loan.principalAmount}("");
        require(success, "Disbursement failed");

        emit LoanAccepted(loanId, msg.sender);
    }

    /// @notice Repay a loan (principal + interest)
    /// @param loanId The loan to repay
    function repayLoan(uint256 loanId) external payable nonReentrant {
        LoanOffer storage loan = loans[loanId];
        require(loan.borrower == msg.sender, "Not borrower");
        require(loan.status == LoanStatus.Active, "Not active");
        require(block.timestamp <= loan.acceptedAt + loan.duration, "Loan expired");

        uint256 totalDue = loan.principalAmount + loan.interestAmount;
        require(msg.value >= totalDue, "Insufficient repayment");

        loan.status = LoanStatus.Repaid;
        loan.repaidAt = block.timestamp;

        // Calculate platform fee from interest
        uint256 platformFee = (loan.interestAmount * platformFeeBps) / BPS_DENOMINATOR;
        uint256 lenderPayout = totalDue - platformFee;

        // Pay lender (principal + interest - fee)
        (bool lenderSuccess, ) = loan.lender.call{value: lenderPayout}("");
        require(lenderSuccess, "Lender payment failed");

        // Return collateral to borrower
        (bool collateralSuccess, ) = msg.sender.call{value: loan.collateralDeposited}("");
        require(collateralSuccess, "Collateral return failed");

        // Refund overpayment
        if (msg.value > totalDue) {
            (bool refundSuccess, ) = msg.sender.call{value: msg.value - totalDue}("");
            require(refundSuccess, "Refund failed");
        }

        // Update reputations
        _updateReputation(msg.sender, true);
        _updateReputation(loan.lender, true);

        reputations[loan.lender].totalLent += loan.principalAmount;
        reputations[msg.sender].totalBorrowed += loan.principalAmount;

        emit LoanRepaid(loanId, totalDue);
    }

    // ── Default Handling ─────────────────────────────────────────────

    /// @notice Claim collateral from a defaulted loan
    /// @param loanId The loan that has defaulted
    function claimDefault(uint256 loanId) external nonReentrant {
        LoanOffer storage loan = loans[loanId];
        require(loan.lender == msg.sender, "Not lender");
        require(loan.status == LoanStatus.Active, "Not active");
        require(block.timestamp > loan.acceptedAt + loan.duration, "Not expired yet");

        loan.status = LoanStatus.Defaulted;

        // Lender receives collateral
        (bool success, ) = msg.sender.call{value: loan.collateralDeposited}("");
        require(success, "Collateral transfer failed");

        // Update reputations
        _updateReputation(loan.borrower, false);

        emit LoanDefaulted(loanId, loan.collateralDeposited);
    }

    // ── View Functions ───────────────────────────────────────────────

    /// @notice Get reputation details for an address
    /// @param user The user address
    /// @return score The reputation score (0-1000)
    /// @return completed Number of completed loans
    /// @return defaulted Number of defaults
    /// @return lent Total amount lent
    /// @return borrowed Total amount borrowed
    function getReputation(address user)
        external
        view
        returns (
            uint256 score,
            uint256 completed,
            uint256 defaulted,
            uint256 lent,
            uint256 borrowed
        )
    {
        Reputation storage rep = reputations[user];
        return (rep.score, rep.loansCompleted, rep.loansDefaulted, rep.totalLent, rep.totalBorrowed);
    }

    /// @notice Get loan IDs where user is lender
    function getLenderLoans(address user) external view returns (uint256[] memory) {
        return userLoansAsLender[user];
    }

    /// @notice Get loan IDs where user is borrower
    function getBorrowerLoans(address user) external view returns (uint256[] memory) {
        return userLoansAsBorrower[user];
    }

    /// @notice Check if a loan has expired
    /// @param loanId The loan to check
    /// @return True if the loan deadline has passed
    function isExpired(uint256 loanId) external view returns (bool) {
        LoanOffer storage loan = loans[loanId];
        if (loan.status != LoanStatus.Active) return false;
        return block.timestamp > loan.acceptedAt + loan.duration;
    }

    /// @notice Get time remaining on an active loan
    /// @param loanId The loan to check
    /// @return Seconds remaining (0 if expired)
    function timeRemaining(uint256 loanId) external view returns (uint256) {
        LoanOffer storage loan = loans[loanId];
        if (loan.status != LoanStatus.Active) return 0;
        uint256 deadline = loan.acceptedAt + loan.duration;
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }

    // ── Admin ────────────────────────────────────────────────────────

    /// @notice Update the platform fee (max 5%)
    /// @param newFeeBps New fee in basis points
    function setPlatformFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 500, "Fee too high");
        platformFeeBps = newFeeBps;
    }

    /// @notice Withdraw accumulated platform fees
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    // ── Internal ─────────────────────────────────────────────────────

    function _ensureReputation(address user) internal {
        if (reputations[user].score == 0) {
            reputations[user].score = INITIAL_REPUTATION;
        }
    }

    function _updateReputation(address user, bool positive) internal {
        Reputation storage rep = reputations[user];
        if (positive) {
            rep.loansCompleted++;
            rep.score = rep.score + REPUTATION_GAIN > MAX_REPUTATION
                ? MAX_REPUTATION
                : rep.score + REPUTATION_GAIN;
        } else {
            rep.loansDefaulted++;
            rep.score = rep.score > REPUTATION_LOSS
                ? rep.score - REPUTATION_LOSS
                : 0;
        }
        emit ReputationUpdated(user, rep.score);
    }

    receive() external payable {}
}
