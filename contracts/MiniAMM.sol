// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IERC20.sol";
import "./FeePool.sol";

contract MiniAMM {
    address public owner;
    FeePool public feePool;
    
    uint256 public constant FEE_NUMERATOR = 3;
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    
    struct Pair {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        bool exists;
    }
    
    struct LiquidityPosition {
        uint256 liquidity;
        uint256 depositedA;
        uint256 depositedB;
    }
    
    mapping(bytes32 => Pair) public pairs;
    bytes32[] public pairIds;
    mapping(bytes32 => mapping(address => LiquidityPosition)) public liquidityPositions;
    
    uint256 public totalSwapVolume;
    uint256 public totalFeesCollected;
    
    event PairCreated(bytes32 indexed pairId, address tokenA, address tokenB);
    event LiquidityAdded(bytes32 indexed pairId, address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(bytes32 indexed pairId, address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(bytes32 indexed pairId, address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, uint256 fee);
    
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
    
    constructor(address _feePool) {
        owner = msg.sender;
        feePool = FeePool(_feePool);
    }
    
    function getPairId(address tokenA, address tokenB) public pure returns (bytes32) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return keccak256(abi.encodePacked(token0, token1));
    }
    
    function createPair(address tokenA, address tokenB) external onlyOwner returns (bytes32) {
        require(tokenA != tokenB, "Identical tokens");
        require(tokenA != address(0) && tokenB != address(0), "Zero address");
        bytes32 pairId = getPairId(tokenA, tokenB);
        require(!pairs[pairId].exists, "Pair exists");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pairs[pairId] = Pair({
            tokenA: token0,
            tokenB: token1,
            reserveA: 0,
            reserveB: 0,
            totalLiquidity: 0,
            exists: true
        });
        pairIds.push(pairId);
        emit PairCreated(pairId, token0, token1);
        return pairId;
    }
    
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant returns (uint256 liquidity) {
        require(amountA > 0 && amountB > 0, "Amounts must be > 0");
        bytes32 pairId = getPairId(tokenA, tokenB);
        Pair storage pair = pairs[pairId];
        require(pair.exists, "Pair does not exist");
        (uint256 amount0, uint256 amount1) = tokenA < tokenB ? (amountA, amountB) : (amountB, amountA);
        require(IERC20(pair.tokenA).transferFrom(msg.sender, address(this), amount0), "Transfer A failed");
        require(IERC20(pair.tokenB).transferFrom(msg.sender, address(this), amount1), "Transfer B failed");
        if (pair.totalLiquidity == 0) {
            liquidity = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            require(liquidity > 0, "Insufficient initial liquidity");
        } else {
            uint256 liquidityA = (amount0 * pair.totalLiquidity) / pair.reserveA;
            uint256 liquidityB = (amount1 * pair.totalLiquidity) / pair.reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
        }
        require(liquidity > 0, "Insufficient liquidity minted");
        pair.reserveA += amount0;
        pair.reserveB += amount1;
        pair.totalLiquidity += liquidity;
        LiquidityPosition storage position = liquidityPositions[pairId][msg.sender];
        position.liquidity += liquidity;
        position.depositedA += amount0;
        position.depositedB += amount1;
        emit LiquidityAdded(pairId, msg.sender, amount0, amount1, liquidity);
        return liquidity;
    }
    
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidityAmount
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        bytes32 pairId = getPairId(tokenA, tokenB);
        Pair storage pair = pairs[pairId];
        require(pair.exists, "Pair does not exist");
        LiquidityPosition storage position = liquidityPositions[pairId][msg.sender];
        require(position.liquidity >= liquidityAmount, "Insufficient liquidity");
        require(liquidityAmount > 0, "Amount must be > 0");
        uint256 amount0 = (liquidityAmount * pair.reserveA) / pair.totalLiquidity;
        uint256 amount1 = (liquidityAmount * pair.reserveB) / pair.totalLiquidity;
        require(amount0 > 0 && amount1 > 0, "Insufficient amounts");
        pair.reserveA -= amount0;
        pair.reserveB -= amount1;
        pair.totalLiquidity -= liquidityAmount;
        position.liquidity -= liquidityAmount;
        require(IERC20(pair.tokenA).transfer(msg.sender, amount0), "Transfer A failed");
        require(IERC20(pair.tokenB).transfer(msg.sender, amount1), "Transfer B failed");
        emit LiquidityRemoved(pairId, msg.sender, amount0, amount1, liquidityAmount);
        return (amount0, amount1);
    }
    
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external nonReentrant returns (uint256 amountOut) {
        require(amountIn > 0, "Amount must be > 0");
        require(tokenIn != tokenOut, "Same token");
        bytes32 pairId = getPairId(tokenIn, tokenOut);
        Pair storage pair = pairs[pairId];
        require(pair.exists, "Pair does not exist");
        (uint256 reserveIn, uint256 reserveOut) = tokenIn == pair.tokenA ? (pair.reserveA, pair.reserveB) : (pair.reserveB, pair.reserveA);
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        uint256 fee = (amountIn * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 amountInAfterFee = amountIn - fee;
        amountOut = (amountInAfterFee * reserveOut) / (reserveIn + amountInAfterFee);
        require(amountOut > 0, "Insufficient output");
        require(amountOut < reserveOut, "Insufficient liquidity");
        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Transfer in failed");
        if (fee > 0) {
            IERC20(tokenIn).approve(address(feePool), fee);
            feePool.depositFee(tokenIn, fee);
            totalFeesCollected += fee;
        }
        require(IERC20(tokenOut).transfer(msg.sender, amountOut), "Transfer out failed");
        if (tokenIn == pair.tokenA) {
            pair.reserveA += amountInAfterFee;
            pair.reserveB -= amountOut;
        } else {
            pair.reserveB += amountInAfterFee;
            pair.reserveA -= amountOut;
        }
        totalSwapVolume += amountIn;
        emit Swap(pairId, msg.sender, tokenIn, tokenOut, amountIn, amountOut, fee);
        return amountOut;
    }
    
    function getReserves(address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB) {
        bytes32 pairId = getPairId(tokenA, tokenB);
        Pair storage pair = pairs[pairId];
        require(pair.exists, "Pair does not exist");
        if (tokenA == pair.tokenA) {
            return (pair.reserveA, pair.reserveB);
        } else {
            return (pair.reserveB, pair.reserveA);
        }
    }
    
    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut, uint256 fee) {
        bytes32 pairId = getPairId(tokenIn, tokenOut);
        Pair storage pair = pairs[pairId];
        require(pair.exists, "Pair does not exist");
        (uint256 reserveIn, uint256 reserveOut) = tokenIn == pair.tokenA ? (pair.reserveA, pair.reserveB) : (pair.reserveB, pair.reserveA);
        if (reserveIn == 0 || reserveOut == 0) return (0, 0);
        fee = (amountIn * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 amountInAfterFee = amountIn - fee;
        amountOut = (amountInAfterFee * reserveOut) / (reserveIn + amountInAfterFee);
        return (amountOut, fee);
    }
    
    function getAllPairs() external view returns (bytes32[] memory) {
        return pairIds;
    }
    
    function getPairInfo(bytes32 pairId) external view returns (
        address tokenA,
        address tokenB,
        uint256 reserveA,
        uint256 reserveB,
        uint256 totalLiquidity
    ) {
        Pair storage pair = pairs[pairId];
        require(pair.exists, "Pair does not exist");
        return (pair.tokenA, pair.tokenB, pair.reserveA, pair.reserveB, pair.totalLiquidity);
    }
    
    function getUserLiquidity(bytes32 pairId, address user) external view returns (
        uint256 liquidity,
        uint256 depositedA,
        uint256 depositedB
    ) {
        LiquidityPosition storage position = liquidityPositions[pairId][user];
        return (position.liquidity, position.depositedA, position.depositedB);
    }
    
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
    
    function setFeePool(address _feePool) external onlyOwner {
        require(_feePool != address(0), "Invalid address");
        feePool = FeePool(_feePool);
    }
}