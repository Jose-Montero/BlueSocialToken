// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BlueSocialToken is ERC20, Ownable {
    constructor(address initialOwner)
        ERC20("Blue Social Token", "BLUE")
        Ownable(initialOwner)
    {
        _mint(initialOwner, 2_500_000_000 * 10 ** decimals());
    }
}
