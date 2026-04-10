// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title EmploymentContract
/// @author 0pnMatrx — Business Infrastructure Pack
/// @notice On-chain employment terms with automatic salary payment.
///         Employers create contracts, employees accept, and salary is paid
///         automatically on a configurable schedule (weekly, biweekly, monthly).
/// @dev Features:
///      - Configurable pay periods (weekly, biweekly, monthly)
///      - Automatic salary calculation and disbursement
///      - Employer pre-funding of payroll
///      - PTO (paid time off) tracking
///      - Performance bonus disbursement
///      - Termination with notice period
///      - Employment verification

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract EmploymentContract is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ── Types ────────────────────────────────────────────────────────

    enum PayFrequency {
        Weekly,         // every 7 days
        BiWeekly,       // every 14 days
        Monthly         // every 30 days
    }

    enum ContractStatus {
        Offered,        // employer created, awaiting employee acceptance
        Active,
        OnNotice,       // termination notice given
        Terminated,
        Completed       // contract end date reached
    }

    struct Employment {
        uint256 id;
        address employer;
        address employee;
        string title;                // job title
        string termsURI;             // IPFS URI for full employment terms
        uint256 salary;              // salary per pay period (in wei or token units)
        PayFrequency payFrequency;
        IERC20 paymentToken;         // address(0) = ETH payments
        uint256 startDate;
        uint256 endDate;             // 0 = indefinite
        uint256 noticePeriod;        // notice period in seconds
        uint256 lastPaymentTime;
        uint256 totalPaid;
        uint256 periodsCompleted;
        ContractStatus status;
    }

    struct PTOBalance {
        uint256 accrued;             // total PTO hours accrued
        uint256 used;                // PTO hours used
        uint256 accrualRate;         // hours accrued per pay period
    }

    // ── State ────────────────────────────────────────────────────────

    mapping(uint256 => Employment) public contracts;
    uint256 public contractCount;

    /// @notice PTO balances per contract
    mapping(uint256 => PTOBalance) public ptoBalances;

    /// @notice Employer => list of contract IDs
    mapping(address => uint256[]) public employerContracts;

    /// @notice Employee => list of contract IDs
    mapping(address => uint256[]) public employeeContracts;

    /// @notice Employer funding balances (employer => token => balance)
    mapping(address => mapping(address => uint256)) public employerFunding;

    /// @notice Platform fee
    uint256 public platformFeeBps = 50; // 0.5%
    uint256 public constant BPS_DENOMINATOR = 10000;

    // ── Events ───────────────────────────────────────────────────────
    event ContractOffered(uint256 indexed contractId, address indexed employer, address indexed employee, uint256 salary);
    event ContractAccepted(uint256 indexed contractId);
    event SalaryPaid(uint256 indexed contractId, uint256 amount, uint256 periodNumber);
    event BonusPaid(uint256 indexed contractId, uint256 amount, string reason);
    event NoticeGiven(uint256 indexed contractId, address by, uint256 effectiveDate);
    event ContractTerminated(uint256 indexed contractId, string reason);
    event ContractCompleted(uint256 indexed contractId);
    event PTORequested(uint256 indexed contractId, uint256 hours);
    event FundsDeposited(address indexed employer, address token, uint256 amount);
    event FundsWithdrawn(address indexed employer, address token, uint256 amount);

    constructor() Ownable(msg.sender) {}

    // ── Contract Creation ────────────────────────────────────────────

    /// @notice Create an employment contract offer
    /// @param employee Employee address
    /// @param title Job title
    /// @param termsURI IPFS URI for full employment terms
    /// @param salary Salary per pay period
    /// @param payFrequency Payment frequency
    /// @param paymentToken ERC-20 token for salary (address(0) for ETH)
    /// @param startDate Employment start date
    /// @param endDate Employment end date (0 for indefinite)
    /// @param noticePeriodDays Notice period in days
    /// @param ptoAccrualRate PTO hours accrued per pay period
    /// @return contractId The contract ID
    function createContract(
        address employee,
        string calldata title,
        string calldata termsURI,
        uint256 salary,
        PayFrequency payFrequency,
        address paymentToken,
        uint256 startDate,
        uint256 endDate,
        uint256 noticePeriodDays,
        uint256 ptoAccrualRate
    ) external returns (uint256 contractId) {
        require(employee != address(0), "Zero employee");
        require(employee != msg.sender, "Cannot self-employ");
        require(salary > 0, "Zero salary");
        require(startDate >= block.timestamp, "Start in past");
        if (endDate > 0) {
            require(endDate > startDate, "End before start");
        }

        contractId = contractCount++;

        contracts[contractId] = Employment({
            id: contractId,
            employer: msg.sender,
            employee: employee,
            title: title,
            termsURI: termsURI,
            salary: salary,
            payFrequency: payFrequency,
            paymentToken: IERC20(paymentToken),
            startDate: startDate,
            endDate: endDate,
            noticePeriod: noticePeriodDays * 1 days,
            lastPaymentTime: startDate,
            totalPaid: 0,
            periodsCompleted: 0,
            status: ContractStatus.Offered
        });

        ptoBalances[contractId] = PTOBalance({
            accrued: 0,
            used: 0,
            accrualRate: ptoAccrualRate
        });

        employerContracts[msg.sender].push(contractId);
        employeeContracts[employee].push(contractId);

        emit ContractOffered(contractId, msg.sender, employee, salary);
    }

    /// @notice Accept an employment contract offer
    /// @param contractId The contract to accept
    function acceptContract(uint256 contractId) external {
        Employment storage c = contracts[contractId];
        require(msg.sender == c.employee, "Not employee");
        require(c.status == ContractStatus.Offered, "Not offered");

        c.status = ContractStatus.Active;
        emit ContractAccepted(contractId);
    }

    // ── Funding ──────────────────────────────────────────────────────

    /// @notice Deposit ETH to fund employee salaries
    function depositFundsETH() external payable {
        require(msg.value > 0, "Zero deposit");
        employerFunding[msg.sender][address(0)] += msg.value;
        emit FundsDeposited(msg.sender, address(0), msg.value);
    }

    /// @notice Deposit ERC-20 tokens to fund employee salaries
    /// @param token The token to deposit
    /// @param amount The amount to deposit
    function depositFundsToken(IERC20 token, uint256 amount) external {
        require(amount > 0, "Zero amount");
        token.safeTransferFrom(msg.sender, address(this), amount);
        employerFunding[msg.sender][address(token)] += amount;
        emit FundsDeposited(msg.sender, address(token), amount);
    }

    /// @notice Withdraw unused funds
    /// @param token Token address (address(0) for ETH)
    /// @param amount Amount to withdraw
    function withdrawFunds(address token, uint256 amount) external nonReentrant {
        require(employerFunding[msg.sender][token] >= amount, "Insufficient balance");

        employerFunding[msg.sender][token] -= amount;

        if (token == address(0)) {
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "ETH withdrawal failed");
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }

        emit FundsWithdrawn(msg.sender, token, amount);
    }

    // ── Salary Payment ───────────────────────────────────────────────

    /// @notice Process salary payment for a contract
    /// @param contractId The employment contract ID
    function processSalary(uint256 contractId) external nonReentrant {
        Employment storage c = contracts[contractId];
        require(
            c.status == ContractStatus.Active || c.status == ContractStatus.OnNotice,
            "Not active"
        );

        uint256 periodLength = _getPeriodLength(c.payFrequency);
        require(
            block.timestamp >= c.lastPaymentTime + periodLength,
            "Too early"
        );

        // Calculate number of periods to pay
        uint256 elapsed = block.timestamp - c.lastPaymentTime;
        uint256 periods = elapsed / periodLength;
        if (periods == 0) return;

        uint256 totalPayment = c.salary * periods;
        address tokenAddr = address(c.paymentToken);

        // Check employer funding
        require(
            employerFunding[c.employer][tokenAddr] >= totalPayment,
            "Employer underfunded"
        );

        // Calculate fee
        uint256 fee = (totalPayment * platformFeeBps) / BPS_DENOMINATOR;
        uint256 netPayment = totalPayment - fee;

        // Deduct from employer balance
        employerFunding[c.employer][tokenAddr] -= totalPayment;

        // Pay employee
        if (tokenAddr == address(0)) {
            (bool success, ) = c.employee.call{value: netPayment}("");
            require(success, "Salary transfer failed");
            if (fee > 0) {
                (bool feeSuccess, ) = owner().call{value: fee}("");
                require(feeSuccess, "Fee transfer failed");
            }
        } else {
            c.paymentToken.safeTransfer(c.employee, netPayment);
            if (fee > 0) {
                c.paymentToken.safeTransfer(owner(), fee);
            }
        }

        c.lastPaymentTime += periods * periodLength;
        c.totalPaid += totalPayment;
        c.periodsCompleted += periods;

        // Accrue PTO
        PTOBalance storage pto = ptoBalances[contractId];
        pto.accrued += pto.accrualRate * periods;

        emit SalaryPaid(contractId, netPayment, c.periodsCompleted);

        // Check if contract end date reached
        if (c.endDate > 0 && block.timestamp >= c.endDate) {
            c.status = ContractStatus.Completed;
            emit ContractCompleted(contractId);
        }
    }

    /// @notice Pay a bonus to an employee
    /// @param contractId The employment contract ID
    /// @param amount Bonus amount
    /// @param reason Reason for the bonus
    function payBonus(uint256 contractId, uint256 amount, string calldata reason)
        external
        nonReentrant
    {
        Employment storage c = contracts[contractId];
        require(msg.sender == c.employer, "Not employer");
        require(
            c.status == ContractStatus.Active || c.status == ContractStatus.OnNotice,
            "Not active"
        );
        require(amount > 0, "Zero bonus");

        address tokenAddr = address(c.paymentToken);
        require(
            employerFunding[c.employer][tokenAddr] >= amount,
            "Insufficient funds"
        );

        employerFunding[c.employer][tokenAddr] -= amount;

        if (tokenAddr == address(0)) {
            (bool success, ) = c.employee.call{value: amount}("");
            require(success, "Bonus transfer failed");
        } else {
            c.paymentToken.safeTransfer(c.employee, amount);
        }

        c.totalPaid += amount;

        emit BonusPaid(contractId, amount, reason);
    }

    // ── PTO ──────────────────────────────────────────────────────────

    /// @notice Request PTO (employee only)
    /// @param contractId The contract ID
    /// @param hours Number of PTO hours to use
    function requestPTO(uint256 contractId, uint256 hours) external {
        Employment storage c = contracts[contractId];
        require(msg.sender == c.employee, "Not employee");
        require(c.status == ContractStatus.Active, "Not active");

        PTOBalance storage pto = ptoBalances[contractId];
        require(pto.accrued - pto.used >= hours, "Insufficient PTO");

        pto.used += hours;
        emit PTORequested(contractId, hours);
    }

    /// @notice Get available PTO hours
    function availablePTO(uint256 contractId) external view returns (uint256) {
        PTOBalance storage pto = ptoBalances[contractId];
        return pto.accrued - pto.used;
    }

    // ── Termination ──────────────────────────────────────────────────

    /// @notice Give notice of termination
    /// @param contractId The contract to terminate
    function giveNotice(uint256 contractId) external {
        Employment storage c = contracts[contractId];
        require(
            msg.sender == c.employer || msg.sender == c.employee,
            "Not a party"
        );
        require(c.status == ContractStatus.Active, "Not active");

        c.status = ContractStatus.OnNotice;

        uint256 effectiveDate = block.timestamp + c.noticePeriod;
        emit NoticeGiven(contractId, msg.sender, effectiveDate);
    }

    /// @notice Finalize termination after notice period
    /// @param contractId The contract to finalize
    /// @param reason Reason for termination
    function finalizeTermination(uint256 contractId, string calldata reason) external {
        Employment storage c = contracts[contractId];
        require(
            msg.sender == c.employer || msg.sender == c.employee || msg.sender == owner(),
            "Not authorized"
        );
        require(c.status == ContractStatus.OnNotice, "Not on notice");

        c.status = ContractStatus.Terminated;
        emit ContractTerminated(contractId, reason);
    }

    /// @notice Immediate termination (employer only, for cause)
    /// @param contractId The contract to terminate
    /// @param reason Reason for immediate termination
    function immediateTermination(uint256 contractId, string calldata reason) external {
        Employment storage c = contracts[contractId];
        require(msg.sender == c.employer, "Not employer");
        require(
            c.status == ContractStatus.Active || c.status == ContractStatus.OnNotice,
            "Not active"
        );

        c.status = ContractStatus.Terminated;
        emit ContractTerminated(contractId, reason);
    }

    // ── Verification ─────────────────────────────────────────────────

    /// @notice Verify employment status (for external parties)
    /// @param employee The employee address
    /// @param contractId The contract ID to verify
    /// @return employed Whether the person is currently employed
    /// @return employer The employer address
    /// @return title The job title
    /// @return startDate Employment start date
    /// @return status Current contract status
    function verifyEmployment(address employee, uint256 contractId)
        external
        view
        returns (
            bool employed,
            address employer,
            string memory title,
            uint256 startDate,
            ContractStatus status
        )
    {
        Employment storage c = contracts[contractId];
        require(c.employee == employee, "Employee mismatch");

        return (
            c.status == ContractStatus.Active,
            c.employer,
            c.title,
            c.startDate,
            c.status
        );
    }

    // ── View ─────────────────────────────────────────────────────────

    /// @notice Get pending salary amount
    function pendingSalary(uint256 contractId) external view returns (uint256) {
        Employment storage c = contracts[contractId];
        if (c.status != ContractStatus.Active && c.status != ContractStatus.OnNotice) {
            return 0;
        }

        uint256 periodLength = _getPeriodLength(c.payFrequency);
        uint256 elapsed = block.timestamp - c.lastPaymentTime;
        uint256 periods = elapsed / periodLength;

        return c.salary * periods;
    }

    /// @notice Get next payment date
    function nextPaymentDate(uint256 contractId) external view returns (uint256) {
        Employment storage c = contracts[contractId];
        uint256 periodLength = _getPeriodLength(c.payFrequency);
        return c.lastPaymentTime + periodLength;
    }

    /// @notice Get employer's contracts
    function getEmployerContracts(address employer) external view returns (uint256[] memory) {
        return employerContracts[employer];
    }

    /// @notice Get employee's contracts
    function getEmployeeContracts(address employee) external view returns (uint256[] memory) {
        return employeeContracts[employee];
    }

    /// @notice Get employer funding balance
    function getEmployerBalance(address employer, address token) external view returns (uint256) {
        return employerFunding[employer][token];
    }

    // ── Admin ────────────────────────────────────────────────────────

    function setPlatformFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 500, "Fee too high");
        platformFeeBps = newFeeBps;
    }

    // ── Internal ─────────────────────────────────────────────────────

    function _getPeriodLength(PayFrequency freq) internal pure returns (uint256) {
        if (freq == PayFrequency.Weekly) return 7 days;
        if (freq == PayFrequency.BiWeekly) return 14 days;
        return 30 days; // Monthly
    }

    receive() external payable {}
}
