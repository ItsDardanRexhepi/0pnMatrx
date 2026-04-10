// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CollateralizedLoan
/// @author 0pnMatrx — DeFi Primitives Pack
/// @notice Full collateralized lending protocol with liquidation mechanics.
///         Borrowers deposit ETH as collateral and borrow against it.
///         If collateral ratio drops below 150%, anyone can liquidate.
/// @dev Deploy this contract, then users can:
///      1. depositCollateral() — send ETH as collateral
///      2. borrow(amount) — borrow up to 66% of collateral value
///      3. repay(amount) — repay loan + interest
///      4. liquidate(borrower) — liquidate undercollateralized positions

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract CollateralizedLoan is Ownable, ReentrancyGuard {
    using Math for uint256;

    // ── Constants ────────────────────────────────────────────────────
    uint256 public constant COLLATERAL_RATIO = 150;     // 150% minimum
    uint256 public constant LIQUIDATION_BONUS = 10;     // 10% bonus for liquidators
    uint256 public constant INTEREST_RATE_BPS = 500;    // 5% annual interest
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365.25 days;

    // ── State ────────────────────────────────────────────────────────
    struct Loan {
        uint256 collateralAmount;   // ETH deposited as collateral
        uint256 borrowedAmount;     // Amount borrowed
        uint256 interestAccrued;    // Accumulated interest
        uint256 lastAccrualTime;    // Last interest calculation timestamp
        bool active;
    }

    mapping(address => Loan) public loans;
    uint256 public totalCollateral;
    uint256 public totalBorrowed;

    // ── Events ───────────────────────────────────────────────────────
    event CollateralDeposited(address indexed borrower, uint256 amount);
    event CollateralWithdrawn(address indexed borrower, uint256 amount);
    event LoanCreated(address indexed borrower, uint256 amount);
    event LoanRepaid(address indexed borrower, uint256 amount, uint256 interest);
    event LoanLiquidated(address indexed borrower, address indexed liquidator, uint256 collateralSeized);

    constructor() Ownable(msg.sender) {}

    /// @notice Deposit ETH as collateral
    function depositCollateral() external payable nonReentrant {
        require(msg.value > 0, "Must deposit collateral");
        Loan storage loan = loans[msg.sender];
        loan.collateralAmount += msg.value;
        loan.active = true;
        if (loan.lastAccrualTime == 0) {
            loan.lastAccrualTime = block.timestamp;
        }
        totalCollateral += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }

    /// @notice Borrow against deposited collateral
    /// @param amount The amount to borrow in wei
    function borrow(uint256 amount) external nonReentrant {
        Loan storage loan = loans[msg.sender];
        require(loan.active, "No active collateral");
        _accrueInterest(msg.sender);

        uint256 maxBorrow = (loan.collateralAmount * 100) / COLLATERAL_RATIO;
        uint256 totalDebt = loan.borrowedAmount + loan.interestAccrued + amount;
        require(totalDebt <= maxBorrow, "Exceeds collateral ratio");
        require(address(this).balance >= amount, "Insufficient liquidity");

        loan.borrowedAmount += amount;
        totalBorrowed += amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        emit LoanCreated(msg.sender, amount);
    }

    /// @notice Repay borrowed amount plus interest
    function repay() external payable nonReentrant {
        Loan storage loan = loans[msg.sender];
        require(loan.active, "No active loan");
        _accrueInterest(msg.sender);

        uint256 totalDebt = loan.borrowedAmount + loan.interestAccrued;
        uint256 payment = msg.value > totalDebt ? totalDebt : msg.value;
        uint256 interestPaid = payment > loan.interestAccrued
            ? loan.interestAccrued
            : payment;
        uint256 principalPaid = payment - interestPaid;

        loan.interestAccrued -= interestPaid;
        loan.borrowedAmount -= principalPaid;
        totalBorrowed -= principalPaid;

        // Refund overpayment
        if (msg.value > totalDebt) {
            (bool success, ) = msg.sender.call{value: msg.value - totalDebt}("");
            require(success, "Refund failed");
        }

        emit LoanRepaid(msg.sender, principalPaid, interestPaid);
    }

    /// @notice Withdraw excess collateral (maintaining ratio)
    /// @param amount Amount of collateral to withdraw
    function withdrawCollateral(uint256 amount) external nonReentrant {
        Loan storage loan = loans[msg.sender];
        require(loan.active, "No active collateral");
        _accrueInterest(msg.sender);

        uint256 totalDebt = loan.borrowedAmount + loan.interestAccrued;
        uint256 requiredCollateral = (totalDebt * COLLATERAL_RATIO) / 100;
        uint256 excessCollateral = loan.collateralAmount > requiredCollateral
            ? loan.collateralAmount - requiredCollateral
            : 0;
        require(amount <= excessCollateral, "Would break collateral ratio");

        loan.collateralAmount -= amount;
        totalCollateral -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal failed");
        emit CollateralWithdrawn(msg.sender, amount);
    }

    /// @notice Liquidate an undercollateralized position
    /// @param borrower The address to liquidate
    function liquidate(address borrower) external payable nonReentrant {
        Loan storage loan = loans[borrower];
        require(loan.active, "No active loan");
        _accrueInterest(borrower);

        uint256 totalDebt = loan.borrowedAmount + loan.interestAccrued;
        require(totalDebt > 0, "No outstanding debt");

        uint256 currentRatio = (loan.collateralAmount * 100) / totalDebt;
        require(currentRatio < COLLATERAL_RATIO, "Position is healthy");

        // Liquidator must repay the debt
        require(msg.value >= totalDebt, "Must cover full debt");

        // Liquidator receives collateral + bonus
        uint256 bonus = (loan.collateralAmount * LIQUIDATION_BONUS) / 100;
        uint256 collateralToSeize = loan.collateralAmount;

        // Reset loan
        totalCollateral -= loan.collateralAmount;
        totalBorrowed -= loan.borrowedAmount;
        delete loans[borrower];

        // Pay liquidator
        (bool success, ) = msg.sender.call{value: collateralToSeize}("");
        require(success, "Liquidation payout failed");

        // Refund excess payment
        if (msg.value > totalDebt) {
            (bool refundSuccess, ) = msg.sender.call{value: msg.value - totalDebt}("");
            require(refundSuccess, "Refund failed");
        }

        emit LoanLiquidated(borrower, msg.sender, collateralToSeize);
    }

    /// @notice Get the health factor of a position (>150 is healthy)
    function getHealthFactor(address borrower) external view returns (uint256) {
        Loan storage loan = loans[borrower];
        if (!loan.active || loan.borrowedAmount == 0) return type(uint256).max;
        uint256 totalDebt = loan.borrowedAmount + loan.interestAccrued;
        return (loan.collateralAmount * 100) / totalDebt;
    }

    // ── Internal ─────────────────────────────────────────────────────

    function _accrueInterest(address borrower) internal {
        Loan storage loan = loans[borrower];
        if (loan.borrowedAmount == 0 || loan.lastAccrualTime == 0) {
            loan.lastAccrualTime = block.timestamp;
            return;
        }
        uint256 elapsed = block.timestamp - loan.lastAccrualTime;
        uint256 interest = (loan.borrowedAmount * INTEREST_RATE_BPS * elapsed)
            / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
        loan.interestAccrued += interest;
        loan.lastAccrualTime = block.timestamp;
    }

    receive() external payable {}
}
