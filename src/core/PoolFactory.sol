// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {LiquidityPool} from "src/core/LiquidityPool.sol";

contract PoolFactory {
    address[] public allPools;

    mapping(address => mapping(address => address)) public getPools;

    event PoolAdded(address indexed owner, address tokenA, address tokenB, address pool);

    error PoolFactory__ZeroAddress();
    error PoolFactory__AlreadyExist();

    function createPool(address tokenA, address tokenB) external {
        if (tokenA == address(0) || tokenB == address(0)) revert PoolFactory__ZeroAddress();
        if (getPools[tokenA][tokenB] != address(0)) revert PoolFactory__AlreadyExist();
        LiquidityPool pool = new LiquidityPool(tokenA, tokenB);
        address poolAddress = address(pool);

        getPools[tokenA][tokenB] = poolAddress;
        allPools.push(poolAddress);

        emit PoolAdded(msg.sender, tokenA, tokenB, poolAddress);
    }
}
