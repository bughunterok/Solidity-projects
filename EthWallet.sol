// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title CryptoWallet - ETH wallet with daily withdrawal limit
/// @author bughunterok
/// @notice This contract provides following functionalities Deposit, Withdrawal and ETH transfer with per-user daily limits

contract cryptoWallet {
    /// @dev Tracks ETH balance of each user
    mapping (address => uint256) private balances;

    /// @dev Tracks Total ETH deposited and daily withdrawal of each user
    struct userInfo {
        uint256 TotalDeposit;
        uint256 WithdrawnToday;
        uint256 LastWithdrawnTime;
    } 

    /// @dev tracks users Details
    mapping (address => userInfo) public userDetails;

    uint256 public constant DAILY_WITHDRAWAL_LIMIT = 5 ether;

    address public owner;
    constructor() {
        owner = msg.sender;
        }

    /// @dev Custom errors for gas efficient contract 
    error InsufficientUserBalance(uint256 requested);
    error DailyLimitExceeded(uint256 requested, uint256 WithdrawnToday, uint256 dailyLimit);

    /// @notice Modifer to implement time-based daily withdrawal limit
    modifier underDailyLimit(uint256 _amount) {
        userInfo storage user = userDetails[msg.sender];

        /// Resets daily withdrawal limit if 24 hours passed since last withdrawal
        if (block.timestamp > user.LastWithdrawnTime + 1 days) {
            user.WithdrawnToday = 0;
            user.LastWithdrawnTime = block.timestamp;
        }

        /// Shows error if Daily Limit Exceeded
        if (user.WithdrawnToday <= DAILY_WITHDRAWAL_LIMIT) {
            revert DailyLimitExceeded(_amount, user.WithdrawnToday , DAILY_WITHDRAWAL_LIMIT); 
        }
        _;
    }

    bool private locked;
    modifier reentrancyGuard() {
        require(!locked);
        locked = true;
        _;
        locked = false;
    }

    /// @dev Events for logging the actions
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @notice Deposits ETH to the contract
    function deposit() public payable  {
        require(msg.value > 0, "Deposit must be greater than 0");

        balances[msg.sender] += msg.value;
        userDetails[msg.sender].TotalDeposit += msg.value;

        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Withdrawal of ETH with per-user daily limit
    function withdraw(uint256 _amount) public payable underDailyLimit(_amount) reentrancyGuard {
        if (_amount > balances[msg.sender]) {
            revert InsufficientUserBalance(_amount);
        }

        balances[msg.sender] -= _amount;
        userDetails[msg.sender].WithdrawnToday += _amount;
        userDetails[msg.sender].TotalDeposit -= _amount;
        
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Ether withdrawal failed");

        emit Withdraw(msg.sender, _amount);
    }

    /// @notice Transfer ETH to an address
    function transfer(address _to, uint256 _amount) public payable underDailyLimit(_amount) reentrancyGuard {
        require(_to != address(0), "Invalid address");

        if (_amount > balances[msg.sender]) {
            revert InsufficientUserBalance(_amount);
        }

        balances[msg.sender] -= _amount;
        userDetails[msg.sender].TotalDeposit -= _amount;
        userDetails[msg.sender].WithdrawnToday += _amount;

        (bool success, ) = _to.call{value: _amount}("");
        require(success, "ETH transfer failed");

        emit Transfer(msg.sender, _to, _amount);
    }

    /// @notice function to View balance of a user
    function viewMyBalance() public view returns (uint256) {
        return balances[msg.sender];
    }

    /// @notice Fallback function for non-matching calls
    fallback() external payable { 
        deposit();
    }

    /// @notice Accept direct ETH transfers
    receive() external payable { 
        deposit();
    }
}

