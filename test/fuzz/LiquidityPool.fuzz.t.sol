// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {ProjectSetUp} from "test/unit/ProjectSetUp.t.sol";

contract LiquidityPoolFuzzTest is ProjectSetUp {
    uint256 constant INITIAL_LIQUIDITY = 1000 ether;

    function _seedLiquidity() internal {
        tokenA.mint(address(this), INITIAL_LIQUIDITY);
        tokenB.mint(address(this), INITIAL_LIQUIDITY);
        assertTrue(tokenA.transfer(address(pool), INITIAL_LIQUIDITY));
        assertTrue(tokenB.transfer(address(pool), INITIAL_LIQUIDITY));
        pool.mint(address(this));
    }

    function testFuzz_swapInvariant(uint256 amountIn) public {
        _seedLiquidity();
        vm.assume(amountIn > 0.01 ether && amountIn < 100 ether);
        address another = makeAddr("another");
        uint256 amountOut = pool.getAmountOut(amountIn, pool.reserve0(), pool.reserve1());
        uint256 kBefore = pool.reserve0() * pool.reserve1();

        tokenA.mint(another, amountIn);

        vm.startPrank(another);

        bool isTrue = tokenA.transfer(address(pool), amountIn);
        assertTrue(isTrue);

        pool.swap(0, amountOut, another);

        assertGe(pool.reserve0() * pool.reserve1(), kBefore);
    }
}
