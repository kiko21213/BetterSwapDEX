// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;
import {PoolFactory} from "src/core/PoolFactory.sol";
import {LiquidityPool} from "src/core/LiquidityPool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Router {
    using SafeERC20 for IERC20;
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

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        address pair;
        (amountA, amountB, pair) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        IERC20(tokenA).safeTransferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pair, amountB);
        liquidity = LiquidityPool(pair).mint(to);
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

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) external returns (uint256 amountA, uint256 amountB) {
        address pair = factory.getPools(tokenA, tokenB);
        if (pair == address(0)) revert Router__PoolNotFound();

        IERC20(pair).safeTransferFrom(msg.sender, pair, liquidity);
        (uint256 amount0, uint256 amount1) = LiquidityPool(pair).burn(to);
        (amountA, amountB) = tokenA < tokenB ? (amount0, amount1) : (amount1, amount0);
        if (amountA < amountAMin) revert Router__InsufficientAAmount();
        if (amountB < amountBMin) revert Router__InsufficientBAmount();
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        uint256 amountInWithFee = amountIn * 997;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
    }

    function _getAmountsOut(uint256 amountIn, address[] memory path) internal view returns (uint256[] memory amounts) {
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) =
                _getReserves(factory.getPools(path[i], path[i + 1]), path[i], path[i + 1]);
            amounts[i + 1] = _getAmountOut(amounts[i], reserveIn, reserveOut);
        }
        return amounts;
    }

    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to)
        external
        returns (uint256 amountOut)
    {
        address pair = factory.getPools(path[0], path[1]);
        if (pair == address(0)) revert Router__PoolNotFound();

        uint256[] memory amounts = _getAmountsOut(amountIn, path);
        amountOut = amounts[amounts.length - 1];
        if (amountOut < amountOutMin) revert Router__InsufficientAAmount();
        IERC20(path[0]).safeTransferFrom(msg.sender, pair, amountIn);
        for (uint256 i; i < path.length - 1; i++) {
            address _pair = factory.getPools(path[i], path[i + 1]);
            address recipient = i < path.length - 2 ? factory.getPools(path[i + 1], path[i + 2]) : to;
            (uint256 amount0Out, uint256 amount1Out) =
                path[i] < path[i + 1] ? (uint256(0), amounts[i + 1]) : (amounts[i + 1], uint256(0));
            LiquidityPool(_pair).swap(amount0Out, amount1Out, recipient);
        }
    }
}
