// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ContentSubscription
/// @author 0pnMatrx — Creator Economy Pack
/// @notice Recurring subscription payments for content creators.
///         Subscribers pay a periodic fee to access gated content. Supports multiple
///         subscription tiers, trial periods, and automatic revenue distribution.
/// @dev Features:
///      - Multiple subscription tiers with different prices and durations
///      - Prepaid subscriptions (pay upfront for the period)
///      - Grace period after expiration
///      - Trial periods for new subscribers
///      - Revenue splitting between creator and platform
///      - Subscriber management and status queries

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ContentSubscription is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ── Types ────────────────────────────────────────────────────────

    struct Tier {
        string name;
        uint256 price;           // price per period in wei (ETH) or token units
        uint256 period;          // subscription period in seconds
        uint256 trialPeriod;     // free trial duration (0 = no trial)
        bool active;
        uint256 subscriberCount;
    }

    struct Subscription {
        uint256 tierId;
        uint256 startedAt;
        uint256 expiresAt;
        uint256 totalPaid;
        bool trialUsed;
        bool active;
    }

    // ── State ────────────────────────────────────────────────────────

    /// @notice The content creator who receives payments
    address public creator;

    /// @notice Optional ERC-20 payment token (address(0) = ETH payments)
    IERC20 public paymentToken;

    /// @notice Subscription tiers
    mapping(uint256 => Tier) public tiers;
    uint256 public tierCount;

    /// @notice Subscriber data: subscriber address => tierId => Subscription
    mapping(address => mapping(uint256 => Subscription)) public subscriptions;

    /// @notice List of all subscriber addresses per tier
    mapping(uint256 => address[]) public tierSubscribers;

    /// @notice Grace period after expiration (subscriber can still access)
    uint256 public gracePeriod = 3 days;

    /// @notice Platform fee in basis points
    uint256 public platformFeeBps = 500; // 5%
    uint256 public constant BPS_DENOMINATOR = 10000;

    /// @notice Platform fee recipient
    address public platformFeeRecipient;

    /// @notice Total revenue collected
    uint256 public totalRevenue;

    // ── Events ───────────────────────────────────────────────────────
    event TierCreated(uint256 indexed tierId, string name, uint256 price, uint256 period);
    event TierUpdated(uint256 indexed tierId, uint256 newPrice, bool active);
    event Subscribed(address indexed subscriber, uint256 indexed tierId, uint256 expiresAt);
    event SubscriptionRenewed(address indexed subscriber, uint256 indexed tierId, uint256 newExpiresAt);
    event SubscriptionCancelled(address indexed subscriber, uint256 indexed tierId);
    event TrialStarted(address indexed subscriber, uint256 indexed tierId, uint256 expiresAt);
    event RevenueWithdrawn(address indexed to, uint256 amount);

    // ── Constructor ──────────────────────────────────────────────────

    /// @param _creator The content creator address
    /// @param _paymentToken ERC-20 token for payments (address(0) for ETH)
    /// @param _platformFeeRecipient Platform fee recipient
    constructor(
        address _creator,
        address _paymentToken,
        address _platformFeeRecipient
    ) Ownable(msg.sender) {
        require(_creator != address(0), "Zero creator");
        creator = _creator;
        paymentToken = IERC20(_paymentToken);
        platformFeeRecipient = _platformFeeRecipient == address(0) ? msg.sender : _platformFeeRecipient;
    }

    // ── Tier Management ──────────────────────────────────────────────

    /// @notice Create a new subscription tier
    /// @param name Tier name (e.g., "Basic", "Premium", "VIP")
    /// @param price Price per period
    /// @param period Subscription period in seconds
    /// @param trialPeriod Trial period in seconds (0 for no trial)
    /// @return tierId The ID of the created tier
    function createTier(
        string calldata name,
        uint256 price,
        uint256 period,
        uint256 trialPeriod
    ) external onlyOwner returns (uint256 tierId) {
        require(bytes(name).length > 0, "Empty name");
        require(price > 0, "Zero price");
        require(period > 0, "Zero period");

        tierId = tierCount++;

        tiers[tierId] = Tier({
            name: name,
            price: price,
            period: period,
            trialPeriod: trialPeriod,
            active: true,
            subscriberCount: 0
        });

        emit TierCreated(tierId, name, price, period);
    }

    /// @notice Update tier price and status
    /// @param tierId The tier to update
    /// @param newPrice New price (0 to keep current)
    /// @param active Whether the tier is open for new subscriptions
    function updateTier(uint256 tierId, uint256 newPrice, bool active) external onlyOwner {
        require(tierId < tierCount, "Invalid tier");
        Tier storage tier = tiers[tierId];

        if (newPrice > 0) {
            tier.price = newPrice;
        }
        tier.active = active;

        emit TierUpdated(tierId, tier.price, active);
    }

    // ── Subscription ─────────────────────────────────────────────────

    /// @notice Subscribe to a tier (or start free trial)
    /// @param tierId The tier to subscribe to
    function subscribe(uint256 tierId) external payable nonReentrant {
        require(tierId < tierCount, "Invalid tier");
        Tier storage tier = tiers[tierId];
        require(tier.active, "Tier not active");

        Subscription storage sub = subscriptions[msg.sender][tierId];

        // Check if eligible for trial
        if (tier.trialPeriod > 0 && !sub.trialUsed) {
            sub.tierId = tierId;
            sub.startedAt = block.timestamp;
            sub.expiresAt = block.timestamp + tier.trialPeriod;
            sub.trialUsed = true;
            sub.active = true;

            if (!_isInSubscriberList(tierId, msg.sender)) {
                tierSubscribers[tierId].push(msg.sender);
                tier.subscriberCount++;
            }

            emit TrialStarted(msg.sender, tierId, sub.expiresAt);
            return;
        }

        // Regular subscription payment
        _collectPayment(tier.price);

        uint256 newExpiry;
        if (sub.active && sub.expiresAt > block.timestamp) {
            // Extend existing subscription
            newExpiry = sub.expiresAt + tier.period;
        } else {
            // New subscription or expired
            newExpiry = block.timestamp + tier.period;
            sub.startedAt = block.timestamp;
        }

        sub.tierId = tierId;
        sub.expiresAt = newExpiry;
        sub.totalPaid += tier.price;
        sub.active = true;

        if (!_isInSubscriberList(tierId, msg.sender)) {
            tierSubscribers[tierId].push(msg.sender);
            tier.subscriberCount++;
        }

        totalRevenue += tier.price;

        emit Subscribed(msg.sender, tierId, newExpiry);
    }

    /// @notice Renew an existing subscription for additional periods
    /// @param tierId The tier to renew
    /// @param periods Number of periods to prepay
    function renew(uint256 tierId, uint256 periods) external payable nonReentrant {
        require(tierId < tierCount, "Invalid tier");
        require(periods > 0 && periods <= 12, "Invalid periods");
        Tier storage tier = tiers[tierId];
        require(tier.active, "Tier not active");

        Subscription storage sub = subscriptions[msg.sender][tierId];
        require(sub.active, "Not subscribed");

        uint256 totalCost = tier.price * periods;
        _collectPayment(totalCost);

        uint256 baseTime = sub.expiresAt > block.timestamp ? sub.expiresAt : block.timestamp;
        sub.expiresAt = baseTime + (tier.period * periods);
        sub.totalPaid += totalCost;

        totalRevenue += totalCost;

        emit SubscriptionRenewed(msg.sender, tierId, sub.expiresAt);
    }

    /// @notice Cancel a subscription (no refund, access until expiry)
    /// @param tierId The tier to cancel
    function cancelSubscription(uint256 tierId) external {
        Subscription storage sub = subscriptions[msg.sender][tierId];
        require(sub.active, "Not subscribed");

        sub.active = false;

        emit SubscriptionCancelled(msg.sender, tierId);
    }

    // ── Access Control ───────────────────────────────────────────────

    /// @notice Check if an address has an active subscription to a tier
    /// @param subscriber The address to check
    /// @param tierId The tier to check
    /// @return True if the subscription is active (including grace period)
    function hasAccess(address subscriber, uint256 tierId) external view returns (bool) {
        Subscription storage sub = subscriptions[subscriber][tierId];
        if (!sub.active && sub.expiresAt == 0) return false;
        return block.timestamp <= sub.expiresAt + gracePeriod;
    }

    /// @notice Check if subscription is in grace period
    /// @param subscriber The address to check
    /// @param tierId The tier to check
    /// @return True if in grace period
    function isInGracePeriod(address subscriber, uint256 tierId) external view returns (bool) {
        Subscription storage sub = subscriptions[subscriber][tierId];
        return block.timestamp > sub.expiresAt && block.timestamp <= sub.expiresAt + gracePeriod;
    }

    /// @notice Get time remaining on a subscription
    /// @param subscriber The subscriber address
    /// @param tierId The tier to check
    /// @return Seconds remaining (0 if expired)
    function timeRemaining(address subscriber, uint256 tierId) external view returns (uint256) {
        Subscription storage sub = subscriptions[subscriber][tierId];
        if (block.timestamp >= sub.expiresAt) return 0;
        return sub.expiresAt - block.timestamp;
    }

    // ── Revenue ──────────────────────────────────────────────────────

    /// @notice Withdraw accumulated revenue (creator only)
    function withdrawRevenue() external nonReentrant {
        require(msg.sender == creator || msg.sender == owner(), "Not authorized");

        uint256 balance;
        if (address(paymentToken) == address(0)) {
            balance = address(this).balance;
            require(balance > 0, "No revenue");

            uint256 platformFee = (balance * platformFeeBps) / BPS_DENOMINATOR;
            uint256 creatorAmount = balance - platformFee;

            if (platformFee > 0) {
                (bool feeSuccess, ) = platformFeeRecipient.call{value: platformFee}("");
                require(feeSuccess, "Fee transfer failed");
            }

            (bool success, ) = creator.call{value: creatorAmount}("");
            require(success, "Creator transfer failed");
        } else {
            balance = paymentToken.balanceOf(address(this));
            require(balance > 0, "No revenue");

            uint256 platformFee = (balance * platformFeeBps) / BPS_DENOMINATOR;
            uint256 creatorAmount = balance - platformFee;

            if (platformFee > 0) {
                paymentToken.safeTransfer(platformFeeRecipient, platformFee);
            }
            paymentToken.safeTransfer(creator, creatorAmount);
        }

        emit RevenueWithdrawn(creator, balance);
    }

    // ── View ─────────────────────────────────────────────────────────

    /// @notice Get the number of subscribers for a tier
    function getSubscriberCount(uint256 tierId) external view returns (uint256) {
        return tiers[tierId].subscriberCount;
    }

    /// @notice Get subscriber list for a tier
    function getTierSubscribers(uint256 tierId) external view returns (address[] memory) {
        return tierSubscribers[tierId];
    }

    // ── Admin ────────────────────────────────────────────────────────

    /// @notice Update the creator address
    function setCreator(address newCreator) external onlyOwner {
        require(newCreator != address(0), "Zero address");
        creator = newCreator;
    }

    /// @notice Update the grace period
    function setGracePeriod(uint256 newPeriod) external onlyOwner {
        require(newPeriod <= 30 days, "Too long");
        gracePeriod = newPeriod;
    }

    /// @notice Update platform fee
    function setPlatformFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 2000, "Fee too high");
        platformFeeBps = newFeeBps;
    }

    // ── Internal ─────────────────────────────────────────────────────

    function _collectPayment(uint256 amount) internal {
        if (address(paymentToken) == address(0)) {
            require(msg.value >= amount, "Insufficient ETH");
            // Refund overpayment
            if (msg.value > amount) {
                (bool success, ) = msg.sender.call{value: msg.value - amount}("");
                require(success, "Refund failed");
            }
        } else {
            paymentToken.safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function _isInSubscriberList(uint256 tierId, address subscriber) internal view returns (bool) {
        address[] storage subs = tierSubscribers[tierId];
        for (uint256 i = 0; i < subs.length; i++) {
            if (subs[i] == subscriber) return true;
        }
        return false;
    }

    receive() external payable {}
}
