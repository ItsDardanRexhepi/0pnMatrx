// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title YieldAggregator
/// @author 0pnMatrx — DeFi Primitives Pack
/// @notice Simple yield routing aggregator across multiple strategies.
///         Users deposit tokens, and the aggregator allocates them across
///         whitelisted strategy contracts to maximize yield.
/// @dev Architecture:
///      - Users deposit/withdraw a single asset (e.g., USDC)
///      - Owner registers strategy contracts implementing IStrategy
///      - Allocator (owner or keeper) rebalances across strategies
///      - Users receive vault shares proportional to their deposit
///      - Yield is auto-compounded on rebalance

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Interface that yield strategies must implement
interface IStrategy {
    /// @notice Deposit tokens into the strategy
    function deposit(uint256 amount) external;
    /// @notice Withdraw tokens from the strategy
    function withdraw(uint256 amount) external;
    /// @notice Get the total value held by this strategy (in asset terms)
    function totalValue() external view returns (uint256);
    /// @notice Harvest rewards and reinvest
    function harvest() external;
    /// @notice The underlying asset token
    function asset() external view returns (address);
}

contract YieldAggregator is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ── State ────────────────────────────────────────────────────────

    /// @notice The underlying asset token (e.g., USDC)
    IERC20 public immutable asset;

    struct StrategyInfo {
        bool active;              // is this strategy enabled?
        uint256 allocationBps;    // target allocation in basis points
        uint256 deposited;        // amount currently deposited
    }

    /// @notice Registered strategies
    mapping(address => StrategyInfo) public strategies;
    address[] public strategyList;

    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_STRATEGIES = 20;

    /// @notice Performance fee in basis points (charged on yield)
    uint256 public performanceFeeBps = 1000; // 10%
    address public feeRecipient;

    /// @notice Total assets under management (cached, updated on deposit/withdraw/rebalance)
    uint256 public totalAssetsManaged;

    /// @notice Deposit cap (0 = unlimited)
    uint256 public depositCap;

    // ── Events ───────────────────────────────────────────────────────
    event Deposited(address indexed user, uint256 assets, uint256 shares);
    event Withdrawn(address indexed user, uint256 assets, uint256 shares);
    event StrategyAdded(address indexed strategy, uint256 allocationBps);
    event StrategyRemoved(address indexed strategy);
    event AllocationUpdated(address indexed strategy, uint256 newAllocationBps);
    event Rebalanced(uint256 totalAssets);
    event Harvested(address indexed strategy, uint256 yieldGenerated);
    event PerformanceFeeCollected(uint256 amount);

    // ── Constructor ──────────────────────────────────────────────────

    /// @param _asset The underlying ERC-20 asset token
    /// @param _name Vault share token name (e.g., "Yield Vault USDC")
    /// @param _symbol Vault share token symbol (e.g., "yvUSDC")
    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        asset = _asset;
        feeRecipient = msg.sender;
    }

    // ── User Functions ───────────────────────────────────────────────

    /// @notice Deposit assets and receive vault shares
    /// @param amount The amount of asset tokens to deposit
    /// @return shares The number of vault shares minted
    function deposit(uint256 amount) external nonReentrant returns (uint256 shares) {
        require(amount > 0, "Zero deposit");
        if (depositCap > 0) {
            require(totalAssetsManaged + amount <= depositCap, "Deposit cap reached");
        }

        shares = _convertToShares(amount);
        require(shares > 0, "Zero shares");

        asset.safeTransferFrom(msg.sender, address(this), amount);
        totalAssetsManaged += amount;

        _mint(msg.sender, shares);

        emit Deposited(msg.sender, amount, shares);
    }

    /// @notice Withdraw assets by burning vault shares
    /// @param shares The number of shares to burn
    /// @return assets The amount of asset tokens returned
    function withdraw(uint256 shares) external nonReentrant returns (uint256 assets) {
        require(shares > 0, "Zero shares");
        require(balanceOf(msg.sender) >= shares, "Insufficient shares");

        assets = _convertToAssets(shares);
        require(assets > 0, "Zero assets");

        _burn(msg.sender, shares);

        // Ensure we have enough idle assets; if not, withdraw from strategies
        uint256 idle = asset.balanceOf(address(this));
        if (idle < assets) {
            _withdrawFromStrategies(assets - idle);
        }

        totalAssetsManaged -= assets;
        asset.safeTransfer(msg.sender, assets);

        emit Withdrawn(msg.sender, assets, shares);
    }

    // ── View Functions ───────────────────────────────────────────────

    /// @notice Preview how many shares a deposit would yield
    function previewDeposit(uint256 amount) external view returns (uint256) {
        return _convertToShares(amount);
    }

    /// @notice Preview how many assets a share redemption would yield
    function previewWithdraw(uint256 shares) external view returns (uint256) {
        return _convertToAssets(shares);
    }

    /// @notice Get total value of all assets (idle + in strategies)
    function totalAssets() public view returns (uint256 total) {
        total = asset.balanceOf(address(this));
        for (uint256 i = 0; i < strategyList.length; i++) {
            if (strategies[strategyList[i]].active) {
                total += IStrategy(strategyList[i]).totalValue();
            }
        }
    }

    /// @notice Get the current price per share (scaled by 1e18)
    function pricePerShare() external view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return 1e18;
        return (totalAssets() * 1e18) / supply;
    }

    /// @notice Get count of registered strategies
    function strategyCount() external view returns (uint256) {
        return strategyList.length;
    }

    /// @notice Get all strategy addresses
    function getStrategies() external view returns (address[] memory) {
        return strategyList;
    }

    // ── Strategy Management (Owner) ──────────────────────────────────

    /// @notice Register a new yield strategy
    /// @param strategy The strategy contract address
    /// @param allocationBps Target allocation in basis points
    function addStrategy(address strategy, uint256 allocationBps) external onlyOwner {
        require(strategy != address(0), "Zero address");
        require(!strategies[strategy].active, "Already registered");
        require(strategyList.length < MAX_STRATEGIES, "Max strategies");
        require(IStrategy(strategy).asset() == address(asset), "Asset mismatch");
        require(_totalAllocation() + allocationBps <= BPS_DENOMINATOR, "Allocation overflow");

        strategies[strategy] = StrategyInfo({
            active: true,
            allocationBps: allocationBps,
            deposited: 0
        });
        strategyList.push(strategy);

        // Approve strategy to pull tokens
        asset.approve(strategy, type(uint256).max);

        emit StrategyAdded(strategy, allocationBps);
    }

    /// @notice Remove a strategy (withdraws all funds first)
    /// @param strategy The strategy to remove
    function removeStrategy(address strategy) external onlyOwner {
        StrategyInfo storage info = strategies[strategy];
        require(info.active, "Not active");

        // Withdraw all funds from strategy
        uint256 value = IStrategy(strategy).totalValue();
        if (value > 0) {
            IStrategy(strategy).withdraw(value);
        }

        info.active = false;
        info.allocationBps = 0;
        info.deposited = 0;

        // Remove from list
        for (uint256 i = 0; i < strategyList.length; i++) {
            if (strategyList[i] == strategy) {
                strategyList[i] = strategyList[strategyList.length - 1];
                strategyList.pop();
                break;
            }
        }

        asset.approve(strategy, 0);

        emit StrategyRemoved(strategy);
    }

    /// @notice Update target allocation for a strategy
    /// @param strategy The strategy address
    /// @param newAllocationBps New target allocation in basis points
    function updateAllocation(address strategy, uint256 newAllocationBps) external onlyOwner {
        StrategyInfo storage info = strategies[strategy];
        require(info.active, "Not active");

        uint256 currentTotal = _totalAllocation() - info.allocationBps + newAllocationBps;
        require(currentTotal <= BPS_DENOMINATOR, "Allocation overflow");

        info.allocationBps = newAllocationBps;

        emit AllocationUpdated(strategy, newAllocationBps);
    }

    // ── Rebalancing (Owner / Keeper) ─────────────────────────────────

    /// @notice Rebalance assets across strategies according to target allocations
    function rebalance() external onlyOwner nonReentrant {
        uint256 total = totalAssets();
        if (total == 0) return;

        // Step 1: Withdraw everything from strategies
        for (uint256 i = 0; i < strategyList.length; i++) {
            address strat = strategyList[i];
            if (!strategies[strat].active) continue;

            uint256 value = IStrategy(strat).totalValue();
            if (value > 0) {
                IStrategy(strat).withdraw(value);
                strategies[strat].deposited = 0;
            }
        }

        // Step 2: Redistribute according to allocations
        uint256 available = asset.balanceOf(address(this));
        for (uint256 i = 0; i < strategyList.length; i++) {
            address strat = strategyList[i];
            StrategyInfo storage info = strategies[strat];
            if (!info.active || info.allocationBps == 0) continue;

            uint256 targetAmount = (available * info.allocationBps) / BPS_DENOMINATOR;
            if (targetAmount > 0) {
                IStrategy(strat).deposit(targetAmount);
                info.deposited = targetAmount;
            }
        }

        totalAssetsManaged = totalAssets();

        emit Rebalanced(totalAssetsManaged);
    }

    /// @notice Harvest yields from all strategies
    function harvestAll() external onlyOwner nonReentrant {
        uint256 beforeBalance = totalAssets();

        for (uint256 i = 0; i < strategyList.length; i++) {
            address strat = strategyList[i];
            if (!strategies[strat].active) continue;
            IStrategy(strat).harvest();
        }

        uint256 afterBalance = totalAssets();

        // Collect performance fee on yield
        if (afterBalance > beforeBalance) {
            uint256 yield_ = afterBalance - beforeBalance;
            uint256 fee = (yield_ * performanceFeeBps) / BPS_DENOMINATOR;
            if (fee > 0) {
                // Mint fee shares to fee recipient
                uint256 feeShares = _convertToShares(fee);
                if (feeShares > 0) {
                    _mint(feeRecipient, feeShares);
                    emit PerformanceFeeCollected(fee);
                }
            }
        }

        totalAssetsManaged = totalAssets();
    }

    // ── Admin ────────────────────────────────────────────────────────

    /// @notice Set the performance fee (max 20%)
    function setPerformanceFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 2000, "Fee too high");
        performanceFeeBps = newFeeBps;
    }

    /// @notice Set the fee recipient address
    function setFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Zero address");
        feeRecipient = newRecipient;
    }

    /// @notice Set or remove deposit cap
    function setDepositCap(uint256 newCap) external onlyOwner {
        depositCap = newCap;
    }

    // ── Internal ─────────────────────────────────────────────────────

    function _convertToShares(uint256 assets) internal view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return assets; // 1:1 on first deposit
        return (assets * supply) / totalAssets();
    }

    function _convertToAssets(uint256 shares) internal view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return shares;
        return (shares * totalAssets()) / supply;
    }

    function _withdrawFromStrategies(uint256 needed) internal {
        uint256 remaining = needed;
        for (uint256 i = 0; i < strategyList.length && remaining > 0; i++) {
            address strat = strategyList[i];
            if (!strategies[strat].active) continue;

            uint256 available = IStrategy(strat).totalValue();
            uint256 toWithdraw = remaining > available ? available : remaining;

            if (toWithdraw > 0) {
                IStrategy(strat).withdraw(toWithdraw);
                strategies[strat].deposited -= toWithdraw > strategies[strat].deposited
                    ? strategies[strat].deposited
                    : toWithdraw;
                remaining -= toWithdraw;
            }
        }
    }

    function _totalAllocation() internal view returns (uint256 total) {
        for (uint256 i = 0; i < strategyList.length; i++) {
            if (strategies[strategyList[i]].active) {
                total += strategies[strategyList[i]].allocationBps;
            }
        }
    }
}
