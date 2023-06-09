// SPDX-License-identifier: MIT;
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
  constructor() ERC20("TestToken", "TTC") {
    _mint(msg.sender, 100 * 1e18);
  }
}
