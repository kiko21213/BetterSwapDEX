// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;
import {PoolFactory} from "src/core/PoolFactory.sol";
import {LiquidityPool} from "src/core/LiquidityPool.sol";

contract Router {
    PoolFactory public immutable factory;

    error Router__PoolNotFound();
    error Router__ZeroAddress();
    error Router__CantBeZero();
    error Router__InsufficientBAmount();
    error Router__InsufficientAAmount();

    constructor(address _factory) {
        if (_factory == address(0)) revert Router__ZeroAddress();
        factory = PoolFactory(_factory);
    }

    function _quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB) {
        if (amountA == 0) revert Router__CantBeZero();
        if (reserveA == 0 || reserveB == 0) revert Router__CantBeZero();
        amountB = amountA * reserveB / reserveA;
    }

    function _getReserves(address pair, address tokenA, address tokenB)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        address token0 = tokenA < tokenB ? tokenA : tokenB;
        uint256 reserve0 = LiquidityPool(pair).reserve0();
        uint256 reserve1 = LiquidityPool(pair).reserve1();
        if (tokenA == token0) {
            (reserveA, reserveB) = (reserve0, reserve1);
        } else {
            (reserveA, reserveB) = (reserve1, reserve0);
        }
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB, address pair) {
        pair = factory.getPools(tokenA, tokenB);
        if (pair == address(0)) revert Router__PoolNotFound();
        (uint256 reserveA, uint256 reserveB) = _getReserves(pair, tokenA, tokenB);

        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = _quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                if (amountBOptimal < amountBMin) revert Router__InsufficientBAmount();
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = _quote(amountBDesired, reserveB, reserveA);
                if (amountAOptimal < amountAMin) revert Router__InsufficientAAmount();
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
}
