pragma solidity ^0.8.0;

import "./OZ/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {

  constructor(string memory name, string memory symbol, uint decimals) ERC20(name, symbol, decimals) { }

  function mint(address account, uint amount) external returns (bool) {
    _mint(account, amount);
    return true;
  }

}
