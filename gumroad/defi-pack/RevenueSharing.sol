// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title RevenueSharing
/// @author 0pnMatrx — DeFi Primitives Pack
/// @notice Automatic revenue distribution to multiple parties with configurable shares.
///         Revenue (ETH) sent to this contract is split among payees according to their
///         assigned share weights. Payees can claim their accumulated balance at any time.
/// @dev Supports:
///      - Adding/removing payees (owner only)
///      - Updating share allocations
///      - Pull-based withdrawals (each payee claims their own funds)
///      - ERC-20 token revenue splitting
///      - Full accounting transparency via events

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract RevenueSharing is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ── Constants ────────────────────────────────────────────────────
    uint256 public constant MAX_PAYEES = 50;
    uint256 public constant SHARE_DENOMINATOR = 10000; // basis points

    // ── State ────────────────────────────────────────────────────────
    struct Payee {
        address account;
        uint256 shares;          // share weight in basis points
        uint256 ethReleased;     // total ETH already withdrawn
        bool active;
    }

    mapping(address => Payee) public payees;
    address[] public payeeList;

    uint256 public totalShares;
    uint256 public totalEthReceived;
    uint256 public totalEthReleased;

    // ERC-20 tracking: token => total received
    mapping(IERC20 => uint256) public totalTokenReceived;
    // ERC-20 tracking: token => account => amount released
    mapping(IERC20 => mapping(address => uint256)) public tokenReleased;
    // ERC-20 tracking: token => total released
    mapping(IERC20 => uint256) public totalTokenReleased;

    // ── Events ───────────────────────────────────────────────────────
    event PayeeAdded(address indexed account, uint256 shares);
    event PayeeRemoved(address indexed account);
    event SharesUpdated(address indexed account, uint256 oldShares, uint256 newShares);
    event RevenueReceived(address indexed from, uint256 amount);
    event ETHReleased(address indexed account, uint256 amount);
    event TokenReleased(IERC20 indexed token, address indexed account, uint256 amount);

    // ── Constructor ──────────────────────────────────────────────────

    /// @param _payees Initial list of payee addresses
    /// @param _shares Corresponding share weights (must sum to <= SHARE_DENOMINATOR)
    constructor(
        address[] memory _payees,
        uint256[] memory _shares
    ) Ownable(msg.sender) {
        require(_payees.length == _shares.length, "Length mismatch");
        require(_payees.length <= MAX_PAYEES, "Too many payees");

        uint256 shareSum = 0;
        for (uint256 i = 0; i < _payees.length; i++) {
            require(_payees[i] != address(0), "Zero address");
            require(_shares[i] > 0, "Zero shares");
            require(!payees[_payees[i]].active, "Duplicate payee");

            payees[_payees[i]] = Payee({
                account: _payees[i],
                shares: _shares[i],
                ethReleased: 0,
                active: true
            });
            payeeList.push(_payees[i]);
            shareSum += _shares[i];

            emit PayeeAdded(_payees[i], _shares[i]);
        }

        require(shareSum <= SHARE_DENOMINATOR, "Shares exceed 100%");
        totalShares = shareSum;
    }

    // ── Receive Revenue ──────────────────────────────────────────────

    /// @notice Receive ETH revenue
    receive() external payable {
        require(msg.value > 0, "No value sent");
        totalEthReceived += msg.value;
        emit RevenueReceived(msg.sender, msg.value);
    }

    // ── ETH Withdrawals ──────────────────────────────────────────────

    /// @notice Claim accumulated ETH revenue
    function releaseETH() external nonReentrant {
        Payee storage payee = payees[msg.sender];
        require(payee.active, "Not a payee");

        uint256 owed = _pendingETH(msg.sender);
        require(owed > 0, "Nothing to claim");

        payee.ethReleased += owed;
        totalEthReleased += owed;

        (bool success, ) = msg.sender.call{value: owed}("");
        require(success, "ETH transfer failed");

        emit ETHReleased(msg.sender, owed);
    }

    /// @notice View pending ETH for a payee
    /// @param account The payee address
    /// @return The amount of ETH available to claim
    function pendingETH(address account) external view returns (uint256) {
        return _pendingETH(account);
    }

    // ── ERC-20 Withdrawals ───────────────────────────────────────────

    /// @notice Claim accumulated ERC-20 token revenue
    /// @param token The ERC-20 token to claim
    function releaseToken(IERC20 token) external nonReentrant {
        Payee storage payee = payees[msg.sender];
        require(payee.active, "Not a payee");

        // Sync total received by checking current balance + already released
        uint256 currentBalance = token.balanceOf(address(this));
        uint256 totalReceived = currentBalance + totalTokenReleased[token];
        totalTokenReceived[token] = totalReceived;

        uint256 owed = _pendingToken(token, msg.sender);
        require(owed > 0, "Nothing to claim");

        tokenReleased[token][msg.sender] += owed;
        totalTokenReleased[token] += owed;

        token.safeTransfer(msg.sender, owed);

        emit TokenReleased(token, msg.sender, owed);
    }

    /// @notice View pending ERC-20 tokens for a payee
    /// @param token The ERC-20 token address
    /// @param account The payee address
    /// @return The amount of tokens available to claim
    function pendingToken(IERC20 token, address account) external view returns (uint256) {
        return _pendingToken(token, account);
    }

    // ── Admin Functions ──────────────────────────────────────────────

    /// @notice Add a new payee
    /// @param account The payee address
    /// @param shares The share weight to assign
    function addPayee(address account, uint256 shares) external onlyOwner {
        require(account != address(0), "Zero address");
        require(shares > 0, "Zero shares");
        require(!payees[account].active, "Already a payee");
        require(payeeList.length < MAX_PAYEES, "Max payees reached");
        require(totalShares + shares <= SHARE_DENOMINATOR, "Exceeds max shares");

        payees[account] = Payee({
            account: account,
            shares: shares,
            ethReleased: 0,
            active: true
        });
        payeeList.push(account);
        totalShares += shares;

        emit PayeeAdded(account, shares);
    }

    /// @notice Update shares for an existing payee
    /// @param account The payee address
    /// @param newShares The new share weight
    function updateShares(address account, uint256 newShares) external onlyOwner {
        Payee storage payee = payees[account];
        require(payee.active, "Not a payee");
        require(newShares > 0, "Zero shares");

        uint256 oldShares = payee.shares;
        uint256 newTotalShares = totalShares - oldShares + newShares;
        require(newTotalShares <= SHARE_DENOMINATOR, "Exceeds max shares");

        payee.shares = newShares;
        totalShares = newTotalShares;

        emit SharesUpdated(account, oldShares, newShares);
    }

    /// @notice Remove a payee (they can still claim pending funds)
    /// @param account The payee address to remove
    function removePayee(address account) external onlyOwner {
        Payee storage payee = payees[account];
        require(payee.active, "Not a payee");

        totalShares -= payee.shares;
        payee.shares = 0;
        payee.active = false;

        // Remove from list
        for (uint256 i = 0; i < payeeList.length; i++) {
            if (payeeList[i] == account) {
                payeeList[i] = payeeList[payeeList.length - 1];
                payeeList.pop();
                break;
            }
        }

        emit PayeeRemoved(account);
    }

    // ── View Helpers ─────────────────────────────────────────────────

    /// @notice Get the number of payees
    function payeeCount() external view returns (uint256) {
        return payeeList.length;
    }

    /// @notice Get all payee addresses
    function getPayees() external view returns (address[] memory) {
        return payeeList;
    }

    // ── Internal ─────────────────────────────────────────────────────

    function _pendingETH(address account) internal view returns (uint256) {
        Payee storage payee = payees[account];
        if (!payee.active || totalShares == 0) return 0;
        uint256 totalOwed = (totalEthReceived * payee.shares) / totalShares;
        return totalOwed > payee.ethReleased ? totalOwed - payee.ethReleased : 0;
    }

    function _pendingToken(IERC20 token, address account) internal view returns (uint256) {
        Payee storage payee = payees[account];
        if (!payee.active || totalShares == 0) return 0;

        // Calculate total received including current balance
        uint256 currentBalance = token.balanceOf(address(this));
        uint256 totalReceived = currentBalance + totalTokenReleased[token];

        uint256 totalOwed = (totalReceived * payee.shares) / totalShares;
        uint256 alreadyReleased = tokenReleased[token][account];
        return totalOwed > alreadyReleased ? totalOwed - alreadyReleased : 0;
    }
}
