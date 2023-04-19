// SPDX-License-identifier: MIT;

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
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
  ISwapRouter public swapRouter =
    ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
  // address public IUniswapV3Pool =
  // IUniswapV3Pool public iUniswapV3Pool =
  //   IUniswapV3Pool(0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8);
  // Tokens[] public tokens;
  IPool public iPool;
  IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
  // IERC20 public ierc20 = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

  //Struct

  struct Balance {
    uint256 underlying;
    uint256 collateral;
    uint256 debt;
  }

  //Constructor
  constructor(address _addressProvider) {
    ADDRESSES_PROVIDER = IPoolAddressesProvider(_addressProvider);
    iPool = IPool(ADDRESSES_PROVIDER.getPool());
    owner = msg.sender;
  }

  //Mapping
  //account->token->balance
  mapping(address => uint256) public tokenBalance;
  mapping(address => Balance) public balance;

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

  // modifier isSupportedToken(address token) {
  //   require(supportedList(token));
  //   _;
  // }

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
  ) public returns (address aTokenAddress, address debtTokenAddress) {
    if (amount <= 0) {
      revert MoreThanZero();
    }
    require(approvePool(token, amount));

    address onBehalfOf = address(this);
    uint16 referralCode = 0;

    iPool.supply(token, amount, onBehalfOf, referralCode);
    (aTokenAddress, debtTokenAddress) = getAaveTokenAddress(token);

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
  ) public {
    if (amount <= 0) {
      revert MoreThanZero();
    }
    require(approvePool(token, amount));
    uint16 referralCode = 0;
    address onBehalfOf = address(this);

    iPool.borrow(token, amount, interestRateMode, referralCode, onBehalfOf);
    balance[token].debt += amount;
    tokenBalance[token] += amount;
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
    balance[token].debt -= amountRepaid;

    tokenBalance[token] -= amount;
  }

  function withdrawAaveV3(address token, uint256 amount) public {
    if (amount <= 0) {
      revert MoreThanZero();
    }
    address to = address(this);
    uint256 amountWithdrawn = iPool.withdraw(token, amount, to);
    balance[token].underlying -= amount;
    balance[token].collateral -= amount;
    tokenBalance[token] += amountWithdrawn;
  }

  function getAaveTokenAddress(
    address token
  ) public view returns (address aTokenAddress, address debtTokenAddress) {
    aTokenAddress = iPool.getReserveData(token).aTokenAddress;
    debtTokenAddress = iPool.getReserveData(token).variableDebtTokenAddress;
  }

  function approvePool(address token, uint256 amount) public returns (bool) {
    address provider = ADDRESSES_PROVIDER.getPool();
    return IERC20(token).approve(provider, amount);
  }

  // function supportedList(address token) public view returns (bool) {
  //   // IPool.ReserveData memory reserveData = IPool.getReserveData(token);
  //   DataTypes.ReserveData memory reserveData = iPool.getReserveData(token);
  //   return
  //     iPool.getReserveData(token).configuration.data & 0x1 == 1 &&
  //     reserveData.configuration.data & 0x2 == 0x2;
  // }

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

  // function getsSwapRouter() public view returns(address){
  //     return address(swapRouter);
  // }
}
