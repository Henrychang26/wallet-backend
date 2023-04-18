// SPDX-License-identifier: MIT;

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import { DataTypes } from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";

// interface IUniswapV3SwapCallback {
//     function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata data) external;
// }

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
  IUniswapV3Pool public iUniswapV3Pool =
    IUniswapV3Pool(0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8);
  // Tokens[] public tokens;
  IPool public iPool = IPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
  // IERC20 public ierc20 = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

  //Struct

  struct Balance {
    uint256 underlying;
    uint256 collateral;
    uint256 debt;
  }

  //Constructor
  constructor() {
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

  modifier isSupportedToken(address token) {
    require(supportedList(token));
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
    // TransferHelper.safeTransferFrom(
    //   tokenIn,
    //   msg.sender,
    //   address(this),
    //   amountIn
    // );

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

  function supplyAaveV2(
    address token,
    uint256 amount
  ) public payable isSupportedToken(token) {
    if (amount <= 0) {
      revert MoreThanZero();
    }
    iPool.supply(token, amount, msg.sender, 0);
    balance[token].underlying += amount;
    balance[token].collateral += amount;

    tokenBalance[token] -= amount;
    //No need for event(original contract already emits )
    // emit SupplyToken(token, amount);
  }

  function borrowAaveV2(
    address token,
    uint256 amount,
    uint256 interestRateMode
  ) public isSupportedToken(token) {
    if (amount <= 0) {
      revert MoreThanZero();
    }
    iPool.borrow(token, amount, interestRateMode, 0, msg.sender);
    balance[token].debt += amount;
    tokenBalance[token] += amount;
  }

  function repayAaveV2(
    address token,
    uint256 amount,
    uint256 interestRateMode
  ) public isSupportedToken(token) {
    uint256 amountRepaid = iPool.repay(
      token,
      amount,
      interestRateMode,
      msg.sender
    );
    balance[token].debt -= amountRepaid;

    tokenBalance[token] -= amount;
  }

  function withdrawAaveV2(
    address token,
    uint256 amount
  ) public isSupportedToken(token) {
    if (amount <= 0) {
      revert MoreThanZero();
    }
    uint256 amountWithdrawn = iPool.withdraw(token, amount, msg.sender);
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

  function supportedList(address token) public view returns (bool) {
    // IPool.ReserveData memory reserveData = IPool.getReserveData(token);
    DataTypes.ReserveData memory reserveData = iPool.getReserveData(token);
    return
      iPool.getReserveData(token).configuration.data & 0x1 == 1 &&
      reserveData.configuration.data & 0x2 == 0x2;
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
