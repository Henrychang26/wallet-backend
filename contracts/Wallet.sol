// SPDX-License-identifier: MIT;

pragma solidity ^0.8.0;


import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import {DataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";


error NotOwner();
error MoreThanZero();
error InsufficientFund();

contract Wallet {

    //State Variables
    address public owner;
    ISwapRouter public swapRouter=ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    // address public IUniswapV3Pool = 
    IUniswapV3Pool public iUniswapV3Pool = IUniswapV3Pool(0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8);
    // Tokens[] public tokens;
    IPool public iPool = IPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);


    //Struct

    struct Balance {
        uint256 underlying;
        uint256 collateral;
        uint256 debt; 
    }

    //Constructor
    constructor(){
        owner= msg.sender;
    }   

    //Mapping
    //account->token->balance
    mapping(address => uint256) public tokenBalance;
    mapping (address => Balance) public balance;

    //Events
    event Deposit (address indexed token, uint indexed amount);
    event Withdraw(address indexed account, address indexed token, uint256 indexed amount);
    event SwapSuccess(address tokenIn, address tokenOut, uint256 indexed amountOut);

    //modifiers

    modifier isSupportedToken (address token){
        require(supportedList(token));
        _;
    }

    modifier onlyOwner(){
        if(owner != msg.sender){
            revert NotOwner(); 
        }
        _;
    }

    receive() external payable{
    }

    function deposit(address token, uint256 amount) external {
        tokenBalance[token] += amount;
        emit Deposit(token, amount);
    }

    function withdraw(address token, uint256 amount) public payable{
        if(amount <= 0){
            revert MoreThanZero();
        } 
        if(amount > tokenBalance[token]){
            revert InsufficientFund();
        }

        (bool success, )= payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        emit Withdraw(msg.sender, token, amount);
    }

    function swap(address tokenIn, address tokenOut, uint24 fee, uint256 amountIn, uint256 amountOutMin) public returns(uint256 amountOut){
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
         });

        amountOut = swapRouter.exactInputSingle(params);
        tokenBalance[tokenOut] += amountOut;
        emit SwapSuccess(tokenIn, tokenOut, amountOut);
    }

    function supplyAaveV2(address token, uint256 amount) public payable isSupportedToken(token) {
        if(amount <= 0){
            revert MoreThanZero();
        }   
        iPool.supply(token, amount, msg.sender, 0);
        balance[token].underlying += amount;
        balance[token].collateral += amount;

        tokenBalance[token] -= amount;
        //No need for event(original contract already emits )
        // emit SupplyToken(token, amount);
    }

    function borrowAaveV2(address token, uint256 amount, uint256 interestRateMode) public isSupportedToken(token){
        if(amount <= 0 ){
            revert MoreThanZero();
        }
        iPool.borrow(token, amount, interestRateMode, 0, msg.sender);
        balance[token].debt += amount;
        tokenBalance[token] += amount;
    }

    function repayAaveV2(address token, uint256 amount, uint256 interestRateMode) public isSupportedToken(token){
        uint256 amountRepaid = iPool.repay(token, amount, interestRateMode, msg.sender);
        balance[token].debt -= amountRepaid;

        tokenBalance[token] -= amount;
    }

    function withdrawAaveV2(address token, uint256 amount) public isSupportedToken(token) {
        if(amount <= 0){
            revert MoreThanZero();
        }
        uint256 amountWithdrawn = iPool.withdraw(token, amount, msg.sender);
        balance[token].underlying -= amount;
        balance[token].collateral -= amount;
        tokenBalance[token] += amountWithdrawn;
    }

    function getAaveTokenAddress(address token ) public view returns(address aTokenAddress, address debtTokenAddress){
        aTokenAddress = iPool.getReserveData(token).aTokenAddress;
        debtTokenAddress = iPool.getReserveData(token).variableDebtTokenAddress;
 
    }

    function supportedList(address token) public view returns(bool){
        // IPool.ReserveData memory reserveData = IPool.getReserveData(token);
        DataTypes.ReserveData memory reserveData = iPool.getReserveData(token);
        return iPool.getReserveData(token).configuration.data & 0x1 == 1 && reserveData.configuration.data & 0x2 == 0x2;
    }
}

    // function approve(address spender, uint256 amount) external returns (bool);

//     interface IUniswapV3Pool {
//     function tickSpacing() external view returns (int24);
//     function tickAt(int24 tickCumulative) external pure returns (int24);
//     function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 feeProtocol, uint16 unlocked);
// }

// interface IUniswapV3SwapCallback {
//     function uniswapV3SwapCallback(
//         int256 amount0Delta,
//         int256 amount1Delta,
//         bytes calldata data
//     ) external;
// }

// interface IUniswapV3SwapRouter {
//     function exactInputSingle(
//         uint256 amountIn,
//         uint256 amountOutMinimum,
//         uint24 fee,
//         address recipient,
//         uint256 deadline,
//         uint160 sqrtPriceLimitX96
//     ) external payable returns (uint256 amountOut);
// }

// contract UniswapV3Example {
//     address private constant UNISWAP_POOL_ADDRESS = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
//     address private constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
//     address private constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

//     function swapWETHtoDAI(uint256 amountIn, uint160 sqrtPriceLimitX96) external {
//         IERC20(WETH_ADDRESS).approve(UNISWAP_POOL_ADDRESS, amountIn);

//         IUniswapV3Pool uniswapPool = IUniswapV3Pool(UNISWAP_POOL_ADDRESS);

//         (uint160 sqrtPriceX96, , , ) = uniswapPool.slot0();
//         int24 tick = uniswapPool.tickAt(int24(sqrtPriceX96));

//         int24 tickSpacing = uniswapPool.tickSpacing();
//         int24 tickLimit = int24(sqrtPriceLimitX96 >> 64);

//         if (tick < tickLimit) {
//             tick = tickLimit - tickSpacing;
//         } else if (tick > tickLimit) {
//             tick = tickLimit + tickSpacing;
//         }

//         (uint256 amount0Out, uint256 amount1Out) = uniswapPool.swap(
//             address(this),
//             false,
//             int256(amountIn),
//             int256(0),
//             abi.encode(
//                 IUniswapV3SwapCallback(address(this)).uniswapV3SwapCallback.selector,
//                 msg.sender
//             )
//         );

//         IERC20(DAI_ADDRESS).transfer(msg.sender, amount1Out);
//     }

// }

// interface IUniswapV3Factory {
//     function allPairsLength() external view returns (uint256);
//     function allPairs(uint256 index) external view returns (address pair);
// }

// contract UniswapV3TokenList {
//     address public uniswapFactoryAddress = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // Replace with actual Uniswap V3 factory address

//     function getTokenList() public view returns (address[] memory) {
//         uint256 length = IUniswapV3Factory(uniswapFactoryAddress).allPairsLength();
//         address[] memory tokenList = new address[](length);

//         for (uint256 i = 0; i < length; i++) {
//             address pair = IUniswapV3Factory(uniswapFactoryAddress).allPairs(i);
//             (address token0, address token1, ) = IUniswapV3Pool(pair).slot0();
            
//             if (!contains(tokenList, token0)) {
//                 tokenList[i] = token0;
//             }
//             if (!contains(tokenList, token1)) {
//                 tokenList[i] = token1;
//             }
//         }

//         return tokenList;
//     }

//     function contains(address[] memory array, address item) internal pure returns (bool) {
//         for (uint256 i = 0; i < array.length; i++) {
//             if (array[i] == item) {
//                 return true;
//             }
//         }
//         return false;
//     }
// }