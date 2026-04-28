// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {ProjectSetUp} from "test/unit/ProjectSetUp.t.sol";
import {LiquidityPool} from "src/core/LiquidityPool.sol";

contract LiquidityPoolTest is ProjectSetUp {
    uint256 constant INITIAL_LIQUIDITY = 1000 ether;

    function _seedLiquidity() internal {
        tokenA.mint(address(this), INITIAL_LIQUIDITY);
        tokenB.mint(address(this), INITIAL_LIQUIDITY);
        assertTrue(tokenA.transfer(address(pool), INITIAL_LIQUIDITY));
        assertTrue(tokenB.transfer(address(pool), INITIAL_LIQUIDITY));
        pool.mint(address(this));
    }

    function test_mint() public {
        _seedLiquidity();
        assertEq(pool.reserve0(), INITIAL_LIQUIDITY);
        assertEq(pool.reserve1(), INITIAL_LIQUIDITY);
        assertGt(pool.balanceOf(address(this)), 0);
    }

    function test_mint_revertZero() public {
        vm.expectRevert(LiquidityPool.LiquidityPool__CantBeZero.selector);
        pool.mint(address(this));
    }

    function test_mint_secondDeposit() public {
        _seedLiquidity();

        address another = makeAddr("Another");
        uint256 amount = 500 ether;

        tokenA.mint(another, amount);
        tokenB.mint(another, amount);
        vm.startPrank(another);
        assertTrue(tokenA.transfer(address(pool), amount));
        assertTrue(tokenB.transfer(address(pool), amount));
        pool.mint(another);
        vm.stopPrank();

        assertEq(pool.reserve0(), INITIAL_LIQUIDITY + amount);
        assertEq(pool.reserve1(), INITIAL_LIQUIDITY + amount);

        assertGt(pool.balanceOf(another), 0);
    }

    function test_burn() public {
        _seedLiquidity();
        uint256 lpBalance = pool.balanceOf(address(this));
        uint256 balanceABefore = tokenA.balanceOf(address(this));
        uint256 balanceBBefore = tokenB.balanceOf(address(this));

        assertTrue(pool.transfer(address(pool), lpBalance));
        pool.burn(address(this));

        assertEq(pool.balanceOf(address(this)), 0);

        assertGt(tokenA.balanceOf(address(this)), balanceABefore);
        assertGt(tokenB.balanceOf(address(this)), balanceBBefore);

        assertLt(pool.reserve0(), INITIAL_LIQUIDITY);
        assertLt(pool.reserve1(), INITIAL_LIQUIDITY);
    }

    function test_burn_revertCantBeZero() public {
        _seedLiquidity();
        vm.expectRevert(LiquidityPool.LiquidityPool__CantBeZero.selector);
        pool.burn(address(this));
    }

    function test_getAmountOut() public view {
        uint256 amountOut = pool.getAmountOut(100 ether, 1000 ether, 1000 ether);

        assertEq(amountOut, 90661089388014913158);
    }

    function test_getAmountOut_revertZero() public {
        vm.expectRevert(LiquidityPool.LiquidityPool__CantBeZero.selector);
        pool.getAmountOut(0, 1000 ether, 1000 ether);
    }

    function test_swap() public {
        _seedLiquidity();

        address another = makeAddr("another");
        uint256 amountIn = 100 ether;

        uint256 amountOut = pool.getAmountOut(amountIn, pool.reserve0(), pool.reserve1());

        tokenA.mint(another, amountIn);
        vm.startPrank(another);
        bool isTrue = tokenA.transfer(address(pool), amountIn);
        assertTrue(isTrue);
        pool.swap(0, amountOut, another);
        vm.stopPrank();

        assertEq(tokenB.balanceOf(another), amountOut);
        assertGt(pool.reserve0(), INITIAL_LIQUIDITY);
        assertLt(pool.reserve1(), INITIAL_LIQUIDITY);
    }

    function test_swap_revertBroken() public {
        _seedLiquidity();

        address another = makeAddr("another");
        uint256 amountIn = 100 ether;

        uint256 amountOut = pool.getAmountOut(amountIn, pool.reserve0(), pool.reserve1());

        tokenA.mint(another, amountIn);

        vm.startPrank(another);
        bool isTrue = tokenA.transfer(address(pool), amountIn);
        assertTrue(isTrue);

        vm.expectRevert(LiquidityPool.LiquidityPool__InvariantBroken.selector);
        pool.swap(10, amountOut + 1 ether, another);
    }
}
