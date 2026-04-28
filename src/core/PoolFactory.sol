// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {LiquidityPool} from "src/core/LiquidityPool.sol";

contract PoolFactory {
    address[] public allPools;

    mapping(address => mapping(address => address)) public getPools;

    event PoolAdded(address indexed owner, address token0, address token1, address pool);

    error PoolFactory__ZeroAddress();
    error PoolFactory__AlreadyExist();
    error PoolFactory__TokensAreEqual();

    function createPool(address tokenA, address tokenB) external {
        if (tokenA == tokenB) revert PoolFactory__TokensAreEqual();
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert PoolFactory__ZeroAddress();
        if (getPools[token0][token1] != address(0)) revert PoolFactory__AlreadyExist();
        LiquidityPool pool = new LiquidityPool(token0, token1);
        address poolAddress = address(pool);

        getPools[token0][token1] = poolAddress;
        getPools[token1][token0] = poolAddress;
        allPools.push(poolAddress);

        emit PoolAdded(msg.sender, token0, token1, poolAddress);
    }
}
