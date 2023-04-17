// SPDX-License-identifier: MIT;

pragma solidity ^0.8.0;


import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract Wmatic is ERC20 {
  constructor() ERC20('Wmatic', 'Wrapped MATIC') {
    _mint(msg.sender, 5000);
  }
}