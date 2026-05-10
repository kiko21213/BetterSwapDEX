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
        (uint112 r0, uint112 r1,) = pool.getReserves();
        uint256 amountOut = pool.getAmountOut(amountIn, r0, r1);
        uint256 kBefore = uint256(r0) * uint256(r1);

        tokenA.mint(another, amountIn);

        vm.startPrank(another);

        bool isTrue = tokenA.transfer(address(pool), amountIn);
        assertTrue(isTrue);

        pool.swap(0, amountOut, another);
        (uint112 afterR0, uint112 afterR1,) = pool.getReserves();
        assertGe(uint256(afterR0) * uint256(afterR1), kBefore);
    }
}
