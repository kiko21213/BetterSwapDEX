// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {LiquidityPool} from "src/core/LiquidityPool.sol";

contract PoolFactory {
    address[] public allPools;

    mapping(address => mapping(address => address)) public getPools;

    address public feeTo;
    address public feeToSetter;

    event PoolAdded(address indexed owner, address token0, address token1, address pool);
    event FeeToChanged(address indexed previousFeeTo, address indexed newFeeTo);
    event FeeToSetterChanged(address indexed previousSetter, address indexed newSetter);

    error PoolFactory__ZeroAddress();
    error PoolFactory__AlreadyExist();
    error PoolFactory__TokensAreEqual();
    error PoolFactory__ForbiddenAddress();

    constructor(address _feeToSetter) {
        if (_feeToSetter == address(0)) revert PoolFactory__ZeroAddress();
        feeToSetter = _feeToSetter;
    }

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

    function setFeeTo(address _feeTo) external {
        if (msg.sender != feeToSetter) revert PoolFactory__ForbiddenAddress();
        address feeToOld = feeTo;
        feeTo = _feeTo;
        emit FeeToChanged(feeToOld, _feeTo);
    }

    function setFeeToSetter(address _feeToSetter) external {
        if (msg.sender != feeToSetter) revert PoolFactory__ForbiddenAddress();
        address oldSetter = feeToSetter;
        feeToSetter = _feeToSetter;
        emit FeeToSetterChanged(oldSetter, _feeToSetter);
    }
}
