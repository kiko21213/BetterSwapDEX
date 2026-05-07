// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {ProjectSetUp} from "test/unit/ProjectSetUp.t.sol";
import {LiquidityPool} from "src/core/LiquidityPool.sol";
import {Router} from "src/periphery/Router.sol";
import {MockERC20} from "src/mocks/MockERC20.sol";
import {console} from "forge-std/console.sol";

contract RouterTest is ProjectSetUp {
    function setUp() public override {
        super.setUp();
        factory.createPool(address(tokenA), address(tokenB));
        pool = LiquidityPool(factory.getPools(address(tokenA), address(tokenB)));
    }

    function _seedRouter(uint256 amount0, uint256 amount1) internal {
        tokenA.mint(address(this), amount0);
        tokenB.mint(address(this), amount1);
        tokenA.approve(address(router), amount0);
        tokenB.approve(address(router), amount1);

        router.addLiquidity(address(tokenA), address(tokenB), amount0, amount1, 0, 0, address(this), block.timestamp);
    }

    function test_addLiquidity_firstMint() public {
        uint256 amount = 1000 ether;

        tokenA.mint(address(this), amount);
        tokenB.mint(address(this), amount);

        tokenA.approve(address(router), amount);
        tokenB.approve(address(router), amount);

        (uint256 amountA, uint256 amountB, uint256 liquidity) =
            router.addLiquidity(address(tokenA), address(tokenB), amount, amount, 0, 0, address(this), block.timestamp);

        assertGt(liquidity, 0);
        assertEq(amountA, amount);
        assertEq(amountB, amount);
        assertEq(pool.balanceOf(address(this)), liquidity);
        assertEq(tokenA.balanceOf(address(this)), 0);
        assertEq(tokenB.balanceOf(address(this)), 0);
        assertEq(pool.reserve0() + pool.reserve1(), 2 * amount);
    }

    function test_addLiquidity_mintOptimalB() public {
        _seedRouter(100 ether, 200 ether);

        uint256 desiredA = 50 ether;
        uint256 desiredB = 200 ether;
        tokenA.mint(address(this), desiredA);
        tokenB.mint(address(this), desiredB);
        tokenA.approve(address(router), desiredA);
        tokenB.approve(address(router), desiredB);

        (uint256 amountA, uint256 amountB,) = router.addLiquidity(
            address(tokenA), address(tokenB), desiredA, desiredB, 0, 0, address(this), block.timestamp
        );

        assertEq(amountA, 50 ether);
        assertEq(amountB, 100 ether);

        assertEq(tokenB.balanceOf(address(this)), 100 ether);
        assertEq(tokenA.balanceOf(address(this)), 0);
    }

    function test_addLiquidity_mintOptimalA() public {
        _seedRouter(100 ether, 200 ether);

        uint256 desiredA = 200 ether;
        uint256 desiredB = 200 ether;

        tokenA.mint(address(this), desiredA);
        tokenB.mint(address(this), desiredB);
        tokenA.approve(address(router), desiredA);
        tokenB.approve(address(router), desiredB);

        (uint256 amountA, uint256 amountB,) = router.addLiquidity(
            address(tokenA), address(tokenB), desiredA, desiredB, 0, 0, address(this), block.timestamp
        );
        assertEq(amountA, 100 ether);
        assertEq(amountB, 200 ether);
        assertEq(tokenA.balanceOf(address(this)), 100 ether);
        assertEq(tokenB.balanceOf(address(this)), 0);
    }

    function test_addLiquidity_revertSlippageB() public {
        _seedRouter(100 ether, 200 ether);

        tokenA.mint(address(this), 50 ether);
        tokenB.mint(address(this), 200 ether);
        tokenA.approve(address(router), 50 ether);
        tokenB.approve(address(router), 200 ether);

        vm.expectRevert(Router.Router__InsufficientBAmount.selector);
        router.addLiquidity(
            address(tokenA), address(tokenB), 50 ether, 200 ether, 0, 120 ether, address(this), block.timestamp
        );
    }

    function test_addLiquidity_revertSlippageA() public {
        _seedRouter(100 ether, 200 ether);

        tokenA.mint(address(this), 200 ether);
        tokenB.mint(address(this), 200 ether);
        tokenA.approve(address(router), 200 ether);
        tokenB.approve(address(router), 200 ether);

        vm.expectRevert(Router.Router__InsufficientAAmount.selector);
        router.addLiquidity(
            address(tokenA), address(tokenB), 200 ether, 200 ether, 150 ether, 0, address(this), block.timestamp
        );
    }

    function test_addLiquidity_revertPoolNotFound() public {
        MockERC20 tokenC = new MockERC20("Token C", "TKC");

        vm.expectRevert(Router.Router__PoolNotFound.selector);
        router.addLiquidity(address(tokenA), address(tokenC), 50 ether, 200 ether, 0, 0, address(this), block.timestamp);
    }

    function test_removeLiquidity_happyPath() public {
        _seedRouter(100 ether, 200 ether);
        uint256 liquidity = pool.balanceOf(address(this));
        pool.approve(address(router), liquidity);
        (uint256 amountA, uint256 amountB) =
            router.removeLiquidity(address(tokenA), address(tokenB), liquidity, 0, 0, address(this), block.timestamp);

        assertApproxEqAbs(amountA, 100 ether, 1500);
        assertApproxEqAbs(amountB, 200 ether, 1500);
        assertEq(pool.balanceOf(address(this)), 0);
        assertApproxEqAbs(tokenA.balanceOf(address(this)), 100 ether, 1500);
        assertApproxEqAbs(tokenB.balanceOf(address(this)), 200 ether, 1500);
    }

    function test_removeLiquidity_revertPoolNotFound() public {
        MockERC20 tokenC = new MockERC20("Token C", "TKC");
        uint256 liquidity = pool.balanceOf(address(this));
        pool.approve(address(router), liquidity);
        vm.expectRevert(Router.Router__PoolNotFound.selector);
        router.removeLiquidity(address(tokenA), address(tokenC), liquidity, 0, 0, address(this), block.timestamp);
    }

    function test_removeLiquidity_revertInsufficientAAmount() public {
        _seedRouter(100 ether, 200 ether);
        uint256 liquidity = pool.balanceOf(address(this));
        pool.approve(address(router), liquidity);
        vm.expectRevert(Router.Router__InsufficientAAmount.selector);
        router.removeLiquidity(
            address(tokenA), address(tokenB), liquidity, 150 ether, 0, address(this), block.timestamp
        );
    }

    function test_removeLiquidity_revertInsufficientBAmount() public {
        _seedRouter(100 ether, 200 ether);
        uint256 liquidity = pool.balanceOf(address(this));
        pool.approve(address(router), liquidity);
        vm.expectRevert(Router.Router__InsufficientBAmount.selector);
        router.removeLiquidity(
            address(tokenA), address(tokenB), liquidity, 0, 250 ether, address(this), block.timestamp
        );
    }

    function test_swap_happyPath() public {
        _seedRouter(100 ether, 200 ether);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        tokenA.mint(address(this), 10 ether);
        tokenA.approve(address(router), 10 ether);
        uint256 amountOut = router.swapExactTokensForTokens(10 ether, 0, path, address(this), block.timestamp);

        assertEq(tokenA.balanceOf(address(this)), 0);
        assertGt(tokenB.balanceOf(address(this)), 0);
        assertGt(amountOut, 0);
        assertGt(pool.reserve0(), 100 ether);
    }

    function test_swap_revertPoolNotFound() public {
        MockERC20 tokenC = new MockERC20("Token C", "TKC");
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenC);
        vm.expectRevert(Router.Router__PoolNotFound.selector);
        router.swapExactTokensForTokens(1 ether, 0, path, address(this), block.timestamp);
    }

    function test_swap_revertInsufficientAAmount() public {
        _seedRouter(100 ether, 200 ether);
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        tokenA.mint(address(this), 1 ether);
        tokenA.approve(address(router), 1 ether);
        vm.expectRevert(Router.Router__InsufficientAAmount.selector);
        router.swapExactTokensForTokens(1 ether, 100 ether, path, address(this), block.timestamp);
    }

    function test_swap_amountOutWithFee() public {
        _seedRouter(100 ether, 200 ether);
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        tokenA.mint(address(this), 10 ether);
        tokenA.approve(address(router), 10 ether);

        uint256 amountOutWithFee = 10 ether * 997;

        uint256 expectedOut = (amountOutWithFee * 200 ether) / (100 ether * 1000 + amountOutWithFee);
        uint256 amountOut = router.swapExactTokensForTokens(10 ether, 0, path, address(this), block.timestamp);

        assertEq(amountOut, expectedOut);
    }

    function test_swap_multiHop_exactAmountOut() public {
        MockERC20 tokenC = new MockERC20("Token C", "TKC");
        factory.createPool(address(tokenB), address(tokenC));

        _seedRouter(100 ether, 200 ether);

        tokenA.mint(address(this), 10 ether);
        tokenA.approve(address(router), 10 ether);
        tokenB.mint(address(this), 200 ether);
        tokenB.approve(address(router), 200 ether);
        tokenC.mint(address(this), 300 ether);
        tokenC.approve(address(router), 300 ether);

        router.addLiquidity(
            address(tokenB), address(tokenC), 200 ether, 300 ether, 0, 0, address(this), block.timestamp
        );
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);

        uint256 amountInWithFee1 = 10 ether * 997;
        uint256 amountOut1 = (amountInWithFee1 * 200 ether) / (100 ether * 1000 + amountInWithFee1);

        uint256 amountInWithFee2 = amountOut1 * 997;
        uint256 expectedOut = (amountInWithFee2 * 300 ether) / (200 ether * 1000 + amountInWithFee2);

        uint256 amountOut = router.swapExactTokensForTokens(10 ether, 0, path, address(this), block.timestamp);

        assertEq(amountOut, expectedOut);
        assertEq(tokenA.balanceOf(address(this)), 0);
        assertEq(tokenB.balanceOf(address(this)), 0);
        assertEq(tokenC.balanceOf(address(this)), expectedOut);
    }

    function test_swap_multiHop_revertSlippage() public {
        MockERC20 tokenC = new MockERC20("Token C", "TKC");
        factory.createPool(address(tokenB), address(tokenC));

        _seedRouter(100 ether, 200 ether);

        tokenA.mint(address(this), 10 ether);
        tokenA.approve(address(router), 10 ether);
        tokenB.mint(address(this), 200 ether);
        tokenB.approve(address(router), 200 ether);
        tokenC.mint(address(this), 300 ether);
        tokenC.approve(address(router), 300 ether);

        router.addLiquidity(
            address(tokenB), address(tokenC), 200 ether, 300 ether, 0, 0, address(this), block.timestamp
        );
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);

        vm.expectRevert(Router.Router__InsufficientAAmount.selector);
        router.swapExactTokensForTokens(10 ether, 1000 ether, path, address(this), block.timestamp);
    }

    function test_swap_multiHop_reservesUpdated() public {
        MockERC20 tokenC = new MockERC20("Token C", "TKC");
        factory.createPool(address(tokenB), address(tokenC));

        _seedRouter(100 ether, 200 ether);

        tokenA.mint(address(this), 10 ether);
        tokenA.approve(address(router), 10 ether);
        tokenB.mint(address(this), 200 ether);
        tokenB.approve(address(router), 200 ether);
        tokenC.mint(address(this), 300 ether);
        tokenC.approve(address(router), 300 ether);

        router.addLiquidity(
            address(tokenB), address(tokenC), 200 ether, 300 ether, 0, 0, address(this), block.timestamp
        );
        LiquidityPool poolBC = LiquidityPool(factory.getPools(address(tokenB), address(tokenC)));

        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);

        uint256 amountInWithFee1 = 10 ether * 997;
        uint256 amountOut1 = (amountInWithFee1 * 200 ether) / (100 ether * 1000 + amountInWithFee1);

        uint256 amountInWithFee2 = amountOut1 * 997;
        uint256 expectedOut = (amountInWithFee2 * 300 ether) / (200 ether * 1000 + amountInWithFee2);

        router.swapExactTokensForTokens(10 ether, 0, path, address(this), block.timestamp);

        assertEq(tokenA.balanceOf(address(pool)), 100 ether + 10 ether);
        assertEq(tokenB.balanceOf(address(pool)), 200 ether - amountOut1);
        assertEq(tokenB.balanceOf(address(poolBC)), 200 ether + amountOut1);
        assertEq(tokenC.balanceOf(address(poolBC)), 300 ether - expectedOut);
    }

    function test_addLiquidity_revertExpired() public {
        vm.warp(1 minutes);

        vm.expectRevert(Router.Router__Expired.selector);
        router.addLiquidity(address(tokenA), address(tokenB), 1 ether, 1 ether, 0, 0, address(this), 1 minutes - 1);
    }

    function test_swap_revertExpired() public {
        vm.warp(1 minutes);
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        vm.expectRevert(Router.Router__Expired.selector);
        router.swapExactTokensForTokens(10 ether, 0, path, address(this), 1 minutes - 1);
    }

    function test_removeLiquidity_revertExpired() public {
        vm.warp(1 minutes);
        vm.expectRevert(Router.Router__Expired.selector);
        router.removeLiquidity(address(tokenA), address(tokenB), 0, 0, 0, address(this), 1 minutes - 1);
    }
}
