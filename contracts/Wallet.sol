// SPDX-License-identifier: MIT;

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import { DataTypes } from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";
import { IPoolAddressesProvider } from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

error NotOwner();
error MoreThanZero();
error InsufficientFund();
error InsufficientAllowance();

contract Wallet {
  //State Variables

  address public owner;
  ISwapRouter public immutable swapRouter =
    ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
  IPool public iPool;
  IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
  IUniswapV3Factory public uniswapFactory =
    IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
  IUniswapV3Pool public UniswapPool;

  //Struct

  struct Balance {
    uint256 underlying;
    uint256 collateral;
    uint256 debt;
  }

  struct Pool {
    address token0;
    address token1;
    uint24 fee;
  }

  //Constructor
  constructor(address _addressProvider) {
    ADDRESSES_PROVIDER = IPoolAddressesProvider(_addressProvider);
    iPool = IPool(ADDRESSES_PROVIDER.getPool());
    owner = msg.sender;
    getSupportedList();
  }

  //Mapping
  //account->token->balance
  mapping(address => uint256) public tokenBalance;
  mapping(address => Balance) public balance;
  mapping(address => bool) public isSupportedToken;

  mapping(address => mapping(address => mapping(uint24 => address)))
    public getPool;

  //Events
  event Deposit(address indexed token, uint indexed amount);
  event Withdraw(
    address indexed account,
    address indexed token,
    uint256 indexed amount
  );
  event SwapSuccess(
    address tokenIn,
    address tokenOut,
    uint256 indexed amountOut
  );

  //modifiers

  modifier SupportedToken(address token) {
    require(isSupportedToken[token] == true, "Not Supported");
    _;
  }

  modifier onlyOwner() {
    if (owner != msg.sender) {
      revert NotOwner();
    }
    _;
  }

  receive() external payable {}

  function deposit(address token, uint256 amount) external {
    if (amount <= 0) {
      revert MoreThanZero();
    }

    bool success = IERC20(token).transferFrom(
      msg.sender,
      address(this),
      amount
    );
    if (!success) {
      revert InsufficientAllowance();
    }

    tokenBalance[token] += amount;
    emit Deposit(token, amount);
  }

  function withdraw(address token, uint256 amount) public payable {
    if (amount <= 0) {
      revert MoreThanZero();
    }
    if (amount > tokenBalance[token]) {
      revert InsufficientFund();
    }
    require(msg.sender != address(0));

    bool success = IERC20(token).transfer(msg.sender, amount);
    require(success);
    tokenBalance[token] -= amount;
    emit Withdraw(msg.sender, token, amount);
  }

  function swap(
    address tokenIn,
    address tokenOut,
    uint24 fee,
    uint256 amountIn,
    uint256 amountOutMin
  ) public returns (uint256 amountOut) {
    TransferHelper.safeApprove(tokenIn, address(swapRouter), amountIn);

    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
      .ExactInputSingleParams({
        tokenIn: tokenIn,
        tokenOut: tokenOut,
        fee: fee,
        recipient: msg.sender,
        deadline: block.timestamp + 60 seconds,
        amountIn: amountIn,
        amountOutMinimum: amountOutMin,
        sqrtPriceLimitX96: 0
      });

    amountOut = swapRouter.exactInputSingle(params);
    tokenBalance[tokenIn] -= amountIn;
    emit SwapSuccess(tokenIn, tokenOut, amountOut);
  }

  function supplyAaveV3(
    address token,
    uint256 amount
  ) public SupportedToken(token) {
    if (amount <= 0) {
      revert MoreThanZero();
    }
    require(approvePool(token, amount));

    address onBehalfOf = address(this);
    uint16 referralCode = 0;

    iPool.supply(token, amount, onBehalfOf, referralCode);
    (address aTokenAddress, ) = getAaveTokenAddress(token);

    balance[token].underlying += amount;
    balance[token].collateral += amount;

    tokenBalance[token] -= amount;
    tokenBalance[aTokenAddress] += amount;

    //No need for event(original contract already emits )
    // emit SupplyToken(token, amount);
  }

  function borrowAaveV3(
    address token,
    uint256 amount,
    uint256 interestRateMode
  ) public SupportedToken(token) {
    if (amount <= 0) {
      revert MoreThanZero();
    }
    require(approvePool(token, amount));
    uint16 referralCode = 0;
    address onBehalfOf = address(this);

    iPool.borrow(token, amount, interestRateMode, referralCode, onBehalfOf);

    (, address variableDebtTokenAddress) = getAaveTokenAddress(token);

    balance[token].debt += amount;
    tokenBalance[token] += amount;
    tokenBalance[variableDebtTokenAddress] += amount;
  }

  function repayAaveV3(
    address token,
    uint256 amount,
    uint256 interestRateMode
  ) public {
    address onBehalfOf = address(this);
    uint256 amountRepaid = iPool.repay(
      token,
      amount,
      interestRateMode,
      onBehalfOf
    );
    (, address variableDebtTokenAddress) = getAaveTokenAddress(token);

    balance[token].debt -= amountRepaid;

    tokenBalance[token] -= amount;
    tokenBalance[variableDebtTokenAddress] -= amount;
  }

  function withdrawAaveV3(address token, uint256 amount) public {
    if (amount <= 0) {
      revert MoreThanZero();
    }
    address to = address(this);

    uint256 amountWithdrawn = iPool.withdraw(token, amount, to);

    (address aTokenAddress, ) = getAaveTokenAddress(token);
    balance[token].underlying -= amount;
    balance[token].collateral -= amount;
    tokenBalance[token] += amountWithdrawn;
    tokenBalance[aTokenAddress] -= amount;
  }

  function getAaveTokenAddress(
    address token
  )
    public
    view
    returns (address aTokenAddress, address variableDebtTokenAddress)
  {
    aTokenAddress = iPool.getReserveData(token).aTokenAddress;
    variableDebtTokenAddress = iPool
      .getReserveData(token)
      .variableDebtTokenAddress;
  }

  function approvePool(address token, uint256 amount) public returns (bool) {
    address provider = ADDRESSES_PROVIDER.getPool();
    return IERC20(token).approve(provider, amount);
  }

  function getUserData(
    address _user
  )
    public
    view
    returns (
      uint256 totalCollateralBase,
      uint256 totalDebtBase,
      uint256 availableBorrowsBase,
      uint256 currentLiquidationThreshold,
      uint256 ltv,
      uint256 healthFactor
    )
  {
    (
      totalCollateralBase,
      totalDebtBase,
      availableBorrowsBase,
      currentLiquidationThreshold,
      ltv,
      healthFactor
    ) = iPool.getUserAccountData(_user);
  }

  function enableReserveAsCollateral(address token) public {
    iPool.setUserUseReserveAsCollateral(token, true);
  }

  //Swap debtToken to different interest mode
  function enableStableRateMode(address token) public {
    iPool.swapBorrowRateMode(token, 1);
  }

  function enableVariableRateMode(address token) public {
    iPool.swapBorrowRateMode(token, 2);
  }

  function getOwner() public view returns (address) {
    return owner;
  }

  function getTokenBalance(
    address token
  ) public view onlyOwner returns (uint256) {
    return tokenBalance[token];
  }

  function getUnderlying(
    address token
  ) public view onlyOwner returns (uint256) {
    return balance[token].underlying;
  }

  function getCollateral(
    address token
  ) public view onlyOwner returns (uint256) {
    return balance[token].collateral;
  }

  function getDebt(address token) public view onlyOwner returns (uint256) {
    return balance[token].debt;
  }

  function getSupportedList() public {
    address[] memory supportedList = iPool.getReservesList();
    for (uint256 i = 0; i < supportedList.length; i++) {
      address tokenAddress = supportedList[i];
      isSupportedToken[tokenAddress] = true;
      // console.log(tokenAddress);
      // console.log(isSupportedToken[wmaticAddress]);
    }
  }

  //Uniswap v3 add liquidity

  function creatPool(
    address token0,
    address token1,
    uint24 fee
  ) public returns (address poolAddress) {
    poolAddress = uniswapFactory.createPool(token0, token1, fee);
    getPool[token0][token1][fee] = poolAddress;
    getPool[token1][token0][fee] = poolAddress;
  }

  function addPosition(
    address token0,
    address token1,
    uint24 fee,
    address recipient,
    int24 tickLower, // 900 - 1.01
    int24 tickUpper, //1100 - 1.
    uint128 amount,
    bytes calldata data
  ) public returns (uint256 amount0, uint256 amount1) {
    if (amount <= 0) {
      revert MoreThanZero();
    }

    address poolAddress = getPool[token0][token1][fee];
    TransferHelper.safeApprove(token0, poolAddress, amount);
    TransferHelper.safeApprove(token1, poolAddress, amount);

    (amount0, amount1) = IUniswapV3Pool(poolAddress).mint(
      recipient,
      tickLower,
      tickUpper,
      amount,
      data
    );

    tokenBalance[token0] -= amount0;
    tokenBalance[token1] -= amount1;
  }

  function removePosition(
    address token0,
    address token1,
    uint24 fee,
    int24 tickLower,
    int24 tickUpper,
    uint128 amount
  ) public {
    if (amount <= 0) {
      revert MoreThanZero();
    }
    address poolAddress = getPool[token0][token1][fee];
    (uint256 amount0, uint256 amount1) = IUniswapV3Pool(poolAddress).burn(
      tickLower,
      tickUpper,
      amount
    );

    tokenBalance[token0] += amount0;
    tokenBalance[token1] += amount1;
  }

  function updatePosition(
    address token0,
    address token1,
    uint24 fee,
    address recipient,
    int24 tickLower,
    int24 tickUpper,
    uint128 amount,
    bytes calldata data
  ) public {
    if (amount <= 0) {
      revert MoreThanZero();
    }
    addPosition(
      token0,
      token1,
      fee,
      recipient,
      tickLower,
      tickUpper,
      amount,
      data
    );
  }

  function poolLiquidity(
    address token0,
    address token1,
    uint24 fee
  ) public view returns (uint128 liquidity) {
    address poolAddress = getPool[token0][token1][fee];
    liquidity = IUniswapV3Pool(poolAddress).liquidity();
  }
}
