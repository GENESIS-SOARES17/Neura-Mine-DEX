// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IERC20.sol";
import "./FeePool.sol";

contract PredictionMarket {
    address public owner;
    FeePool public feePool;
    address public priceOracle;
    
    struct Bet {
        address user;
        address token;
        uint256 amount;
        uint256 initialPrice;
        uint256 finalPrice;
        uint256 startTime;
        uint256 endTime;
        bool predictUp;
        BetStatus status;
    }
    
    enum BetStatus { Active, Won, Lost, Cancelled }
    
    mapping(address => bool) public allowedTokens;
    address[] public tokenList;
    mapping(address => uint256) public currentPrices;
    mapping(address => uint256) public lastPriceUpdate;
    mapping(uint256 => Bet) public bets;
    uint256 public betCounter;
    mapping(address => uint256[]) public userBets;
    
    uint256 public minBetAmount = 1e15;
    uint256 public maxBetAmount = 1000e18;
    uint256 public minDuration = 60;
    uint256 public maxDuration = 86400;
    
    uint256 public totalBets;
    uint256 public totalVolume;
    uint256 public activeBets;
    
    event BetPlaced(uint256 indexed betId, address indexed user, address token, uint256 amount, bool predictUp, uint256 duration);
    event BetResolved(uint256 indexed betId, address indexed user, bool won, uint256 reward);
    event PriceUpdated(address indexed token, uint256 price, uint256 timestamp);
    event TokenAdded(address indexed token);
    
    bool private locked;
    modifier nonReentrant() {
        require(!locked, "Reentrancy");
        locked = true;
        _;
        locked = false;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    modifier onlyOracle() {
        require(msg.sender == priceOracle || msg.sender == owner, "Only oracle");
        _;
    }
    
    constructor(address _feePool) {
        owner = msg.sender;
        priceOracle = msg.sender;
        feePool = FeePool(_feePool);
    }
    
    function addAllowedToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(!allowedTokens[token], "Token already added");
        allowedTokens[token] = true;
        tokenList.push(token);
        emit TokenAdded(token);
    }
    
    function setPriceOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid address");
        priceOracle = _oracle;
    }
    
    function updatePrice(address token, uint256 price) external onlyOracle {
        require(allowedTokens[token], "Token not allowed");
        require(price > 0, "Invalid price");
        currentPrices[token] = price;
        lastPriceUpdate[token] = block.timestamp;
        emit PriceUpdated(token, price, block.timestamp);
    }
    
    function updatePrices(address[] calldata tokens, uint256[] calldata prices) external onlyOracle {
        require(tokens.length == prices.length, "Length mismatch");
        for (uint256 i = 0; i < tokens.length; i++) {
            if (allowedTokens[tokens[i]] && prices[i] > 0) {
                currentPrices[tokens[i]] = prices[i];
                lastPriceUpdate[tokens[i]] = block.timestamp;
                emit PriceUpdated(tokens[i], prices[i], block.timestamp);
            }
        }
    }
    
    function placeBet(
        address token,
        uint256 amount,
        bool predictUp,
        uint256 duration
    ) external nonReentrant returns (uint256 betId) {
        require(allowedTokens[token], "Token not allowed");
        require(amount >= minBetAmount && amount <= maxBetAmount, "Invalid amount");
        require(duration >= minDuration && duration <= maxDuration, "Invalid duration");
        require(currentPrices[token] > 0, "Price not available");
        require(block.timestamp - lastPriceUpdate[token] < 3600, "Price too old");
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        betId = betCounter++;
        bets[betId] = Bet({
            user: msg.sender,
            token: token,
            amount: amount,
            initialPrice: currentPrices[token],
            finalPrice: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            predictUp: predictUp,
            status: BetStatus.Active
        });
        userBets[msg.sender].push(betId);
        totalBets++;
        totalVolume += amount;
        activeBets++;
        emit BetPlaced(betId, msg.sender, token, amount, predictUp, duration);
        return betId;
    }
    
    function resolveBet(uint256 betId) external nonReentrant {
        Bet storage bet = bets[betId];
        require(bet.status == BetStatus.Active, "Bet not active");
        require(block.timestamp >= bet.endTime, "Bet not ended");
        require(currentPrices[bet.token] > 0, "Price not available");
        bet.finalPrice = currentPrices[bet.token];
        bool priceWentUp = bet.finalPrice > bet.initialPrice;
        bool won = (bet.predictUp && priceWentUp) || (!bet.predictUp && !priceWentUp);
        uint256 reward = 0;
        if (won) {
            bet.status = BetStatus.Won;
            require(IERC20(bet.token).transfer(bet.user, bet.amount), "Transfer failed");
            reward = feePool.distributeReward(bet.user, bet.token);
        } else {
            bet.status = BetStatus.Lost;
            IERC20(bet.token).approve(address(feePool), bet.amount);
            feePool.depositFee(bet.token, bet.amount);
        }
        activeBets--;
        emit BetResolved(betId, bet.user, won, reward);
    }
    
    function cancelBet(uint256 betId) external nonReentrant {
        Bet storage bet = bets[betId];
        require(bet.user == msg.sender, "Not your bet");
        require(bet.status == BetStatus.Active, "Bet not active");
        require(block.timestamp < bet.endTime, "Bet already ended");
        bet.status = BetStatus.Cancelled;
        uint256 penalty = bet.amount / 10;
        uint256 refund = bet.amount - penalty;
        if (penalty > 0) {
            IERC20(bet.token).approve(address(feePool), penalty);
            feePool.depositFee(bet.token, penalty);
        }
        require(IERC20(bet.token).transfer(msg.sender, refund), "Transfer failed");
        activeBets--;
        emit BetResolved(betId, msg.sender, false, 0);
    }
    
    function getBet(uint256 betId) external view returns (
        address user,
        address token,
        uint256 amount,
        uint256 initialPrice,
        uint256 finalPrice,
        uint256 startTime,
        uint256 endTime,
        bool predictUp,
        BetStatus status
    ) {
        Bet storage bet = bets[betId];
        return (bet.user, bet.token, bet.amount, bet.initialPrice, bet.finalPrice, bet.startTime, bet.endTime, bet.predictUp, bet.status);
    }
    
    function getUserBets(address user) external view returns (uint256[] memory) {
        return userBets[user];
    }
    
    function getActiveBetsCount() external view returns (uint256) {
        return activeBets;
    }
    
    function getPrice(address token) external view returns (uint256 price, uint256 lastUpdate) {
        return (currentPrices[token], lastPriceUpdate[token]);
    }
    
    function getAllowedTokens() external view returns (address[] memory) {
        return tokenList;
    }
    
    function updateLimits(
        uint256 _minBet,
        uint256 _maxBet,
        uint256 _minDuration,
        uint256 _maxDuration
    ) external onlyOwner {
        minBetAmount = _minBet;
        maxBetAmount = _maxBet;
        minDuration = _minDuration;
        maxDuration = _maxDuration;
    }
    
    function setFeePool(address _feePool) external onlyOwner {
        require(_feePool != address(0), "Invalid address");
        feePool = FeePool(_feePool);
    }
}