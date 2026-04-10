// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Vesting
/// @author 0pnMatrx — DeFi Primitives Pack
/// @notice Token vesting contract with cliff period and linear release schedule.
///         Commonly used for team tokens, investor allocations, and advisor grants.
///         After the cliff period, tokens vest linearly over the remaining duration.
/// @dev Lifecycle:
///      1. Owner creates a vesting schedule for a beneficiary
///      2. Beneficiary waits through the cliff period (no tokens released)
///      3. After cliff, tokens vest linearly per second
///      4. Beneficiary calls release() to claim vested tokens
///      5. Owner can revoke unvested tokens (if schedule is revocable)

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Vesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ── State ────────────────────────────────────────────────────────

    struct VestingSchedule {
        address beneficiary;       // who receives the tokens
        IERC20 token;              // the ERC-20 token being vested
        uint256 totalAmount;       // total tokens allocated
        uint256 released;          // tokens already claimed
        uint256 startTime;         // vesting start timestamp
        uint256 cliffDuration;     // cliff period in seconds
        uint256 vestingDuration;   // total vesting period in seconds (includes cliff)
        bool revocable;            // can owner revoke unvested tokens?
        bool revoked;              // has the schedule been revoked?
    }

    /// @notice All vesting schedules, indexed by ID
    mapping(uint256 => VestingSchedule) public schedules;

    /// @notice Total number of schedules created
    uint256 public scheduleCount;

    /// @notice Map beneficiary => list of their schedule IDs
    mapping(address => uint256[]) public beneficiarySchedules;

    /// @notice Total tokens held per token address (for accounting)
    mapping(IERC20 => uint256) public totalTokensHeld;

    // ── Events ───────────────────────────────────────────────────────
    event ScheduleCreated(
        uint256 indexed scheduleId,
        address indexed beneficiary,
        address indexed token,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    );
    event TokensReleased(uint256 indexed scheduleId, address indexed beneficiary, uint256 amount);
    event ScheduleRevoked(uint256 indexed scheduleId, uint256 unvestedReturned);

    constructor() Ownable(msg.sender) {}

    // ── Schedule Management ──────────────────────────────────────────

    /// @notice Create a new vesting schedule
    /// @param beneficiary Address that will receive vested tokens
    /// @param token The ERC-20 token to vest
    /// @param totalAmount Total number of tokens to vest
    /// @param startTime When vesting begins (use block.timestamp for immediate)
    /// @param cliffDuration Cliff period in seconds before any tokens vest
    /// @param vestingDuration Total vesting duration in seconds (must be >= cliffDuration)
    /// @param revocable Whether the owner can revoke unvested tokens
    /// @return scheduleId The ID of the created schedule
    function createSchedule(
        address beneficiary,
        IERC20 token,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    ) external onlyOwner returns (uint256 scheduleId) {
        require(beneficiary != address(0), "Zero beneficiary");
        require(totalAmount > 0, "Zero amount");
        require(vestingDuration > 0, "Zero duration");
        require(vestingDuration >= cliffDuration, "Cliff exceeds duration");
        require(startTime >= block.timestamp, "Start in the past");

        // Transfer tokens into this contract
        token.safeTransferFrom(msg.sender, address(this), totalAmount);

        scheduleId = scheduleCount++;

        schedules[scheduleId] = VestingSchedule({
            beneficiary: beneficiary,
            token: token,
            totalAmount: totalAmount,
            released: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revocable: revocable,
            revoked: false
        });

        beneficiarySchedules[beneficiary].push(scheduleId);
        totalTokensHeld[token] += totalAmount;

        emit ScheduleCreated(
            scheduleId,
            beneficiary,
            address(token),
            totalAmount,
            startTime,
            cliffDuration,
            vestingDuration,
            revocable
        );
    }

    // ── Token Release ────────────────────────────────────────────────

    /// @notice Release vested tokens for a specific schedule
    /// @param scheduleId The schedule to release tokens from
    function release(uint256 scheduleId) external nonReentrant {
        VestingSchedule storage schedule = schedules[scheduleId];
        require(schedule.beneficiary == msg.sender, "Not beneficiary");
        require(!schedule.revoked, "Schedule revoked");

        uint256 releasable = _releasableAmount(scheduleId);
        require(releasable > 0, "Nothing to release");

        schedule.released += releasable;
        totalTokensHeld[schedule.token] -= releasable;

        schedule.token.safeTransfer(schedule.beneficiary, releasable);

        emit TokensReleased(scheduleId, schedule.beneficiary, releasable);
    }

    /// @notice Release vested tokens from all schedules for the caller
    function releaseAll() external nonReentrant {
        uint256[] storage ids = beneficiarySchedules[msg.sender];
        require(ids.length > 0, "No schedules");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 scheduleId = ids[i];
            VestingSchedule storage schedule = schedules[scheduleId];
            if (schedule.revoked) continue;

            uint256 releasable = _releasableAmount(scheduleId);
            if (releasable == 0) continue;

            schedule.released += releasable;
            totalTokensHeld[schedule.token] -= releasable;

            schedule.token.safeTransfer(schedule.beneficiary, releasable);

            emit TokensReleased(scheduleId, schedule.beneficiary, releasable);
        }
    }

    // ── Revocation ───────────────────────────────────────────────────

    /// @notice Revoke a vesting schedule and return unvested tokens to owner
    /// @param scheduleId The schedule to revoke
    function revoke(uint256 scheduleId) external onlyOwner {
        VestingSchedule storage schedule = schedules[scheduleId];
        require(schedule.revocable, "Not revocable");
        require(!schedule.revoked, "Already revoked");

        // Release any vested but unclaimed tokens to beneficiary first
        uint256 releasable = _releasableAmount(scheduleId);
        if (releasable > 0) {
            schedule.released += releasable;
            totalTokensHeld[schedule.token] -= releasable;
            schedule.token.safeTransfer(schedule.beneficiary, releasable);
            emit TokensReleased(scheduleId, schedule.beneficiary, releasable);
        }

        // Return unvested tokens to owner
        uint256 unvested = schedule.totalAmount - schedule.released;
        schedule.revoked = true;

        if (unvested > 0) {
            totalTokensHeld[schedule.token] -= unvested;
            schedule.token.safeTransfer(owner(), unvested);
        }

        emit ScheduleRevoked(scheduleId, unvested);
    }

    // ── View Functions ───────────────────────────────────────────────

    /// @notice Get the amount of tokens currently releasable
    /// @param scheduleId The schedule ID
    /// @return The number of tokens that can be released now
    function releasableAmount(uint256 scheduleId) external view returns (uint256) {
        return _releasableAmount(scheduleId);
    }

    /// @notice Get the total amount vested so far (released + releasable)
    /// @param scheduleId The schedule ID
    /// @return The number of tokens vested to date
    function vestedAmount(uint256 scheduleId) external view returns (uint256) {
        return _vestedAmount(scheduleId);
    }

    /// @notice Get all schedule IDs for a beneficiary
    /// @param beneficiary The beneficiary address
    /// @return Array of schedule IDs
    function getScheduleIds(address beneficiary) external view returns (uint256[] memory) {
        return beneficiarySchedules[beneficiary];
    }

    /// @notice Get schedule details
    /// @param scheduleId The schedule ID
    /// @return beneficiary The beneficiary address
    /// @return token The token address
    /// @return totalAmount Total tokens in the schedule
    /// @return released Tokens already released
    /// @return startTime Vesting start time
    /// @return cliffEnd When the cliff ends
    /// @return endTime When vesting fully completes
    /// @return revocable Whether the schedule is revocable
    /// @return revoked Whether the schedule has been revoked
    function getScheduleInfo(uint256 scheduleId)
        external
        view
        returns (
            address beneficiary,
            address token,
            uint256 totalAmount,
            uint256 released,
            uint256 startTime,
            uint256 cliffEnd,
            uint256 endTime,
            bool revocable,
            bool revoked
        )
    {
        VestingSchedule storage s = schedules[scheduleId];
        return (
            s.beneficiary,
            address(s.token),
            s.totalAmount,
            s.released,
            s.startTime,
            s.startTime + s.cliffDuration,
            s.startTime + s.vestingDuration,
            s.revocable,
            s.revoked
        );
    }

    // ── Internal ─────────────────────────────────────────────────────

    function _releasableAmount(uint256 scheduleId) internal view returns (uint256) {
        VestingSchedule storage schedule = schedules[scheduleId];
        if (schedule.revoked) return 0;
        return _vestedAmount(scheduleId) - schedule.released;
    }

    function _vestedAmount(uint256 scheduleId) internal view returns (uint256) {
        VestingSchedule storage schedule = schedules[scheduleId];

        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            // Still in cliff period
            return 0;
        } else if (block.timestamp >= schedule.startTime + schedule.vestingDuration) {
            // Fully vested
            return schedule.totalAmount;
        } else {
            // Linear vesting after cliff
            uint256 elapsed = block.timestamp - schedule.startTime;
            return (schedule.totalAmount * elapsed) / schedule.vestingDuration;
        }
    }
}
