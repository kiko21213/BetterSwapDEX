// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract DEXToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public constant MAX_SUPPLY = 100_000_000 * 1e18;

    event MintRewards(address indexed who, uint256 amount);
    event BurnToken(address indexed who, uint256 amount);

    error DEXToken__MaxSupplyExceeded();

    constructor(address defaultAdmin) ERC20("BetterSwap", "BSW") {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, defaultAdmin);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        if (totalSupply() + amount > MAX_SUPPLY) revert DEXToken__MaxSupplyExceeded();

        _mint(to, amount);
        emit MintRewards(to, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
        emit BurnToken(msg.sender, amount);
    }
}

