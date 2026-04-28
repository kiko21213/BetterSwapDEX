// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {ProjectSetUp} from "test/unit/ProjectSetUp.t.sol";
import {LiquidityPool} from "src/core/LiquidityPool.sol";
import {PoolFactory} from "src/core/PoolFactory.sol";
import {MockERC20} from "src/mocks/MockERC20.sol";

contract PoolFactoryTest is ProjectSetUp {
    function _sortedTokens() internal view returns (address t0, address t1) {
        return
            address(tokenA) < address(tokenB) ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));
    }

    function test_createPool_happyPath() public {
        factory.createPool(address(tokenA), address(tokenB));
        (address t0, address t1) = _sortedTokens();
        address pool = factory.getPools(t0, t1);
        assertTrue(pool != address(0));
        assertEq(factory.allPools(0), pool);
    }

    function test_createPool_sortTokens() public {
        factory.createPool(address(tokenB), address(tokenA));
        (address t0, address t1) = _sortedTokens();
        address poolAddr = factory.getPools(t0, t1);
        LiquidityPool createdPool = LiquidityPool(poolAddr);

        assertEq(createdPool.token0(), t0);
        assertEq(createdPool.token1(), t1);
    }

    function test_createPool_symmetricMapping() public {
        factory.createPool(address(tokenA), address(tokenB));
        address poolAB = factory.getPools(address(tokenA), address(tokenB));
        address poolBA = factory.getPools(address(tokenB), address(tokenA));

        assertEq(poolAB, poolBA);
        assertTrue(poolAB != address(0));
    }

    function test_createPool_revertTokensEqual() public {
        vm.expectRevert(PoolFactory.PoolFactory__TokensAreEqual.selector);
        factory.createPool(address(tokenA), address(tokenA));
    }

    function test_createPool_revertZeroAddress() public {
        vm.expectRevert(PoolFactory.PoolFactory__ZeroAddress.selector);
        factory.createPool(address(0), address(tokenB));

        vm.expectRevert(PoolFactory.PoolFactory__ZeroAddress.selector);
        factory.createPool(address(tokenA), address(0));
    }

    function test_createPool_revertAlreadyExist() public {
        factory.createPool(address(tokenA), address(tokenB));

        vm.expectRevert(PoolFactory.PoolFactory__AlreadyExist.selector);
        factory.createPool(address(tokenA), address(tokenB));

        vm.expectRevert(PoolFactory.PoolFactory__AlreadyExist.selector);
        factory.createPool(address(tokenB), address(tokenA));
    }

    function test_createPool_emitsEvent() public {
        (address t0, address t1) = _sortedTokens();
        vm.expectEmit(true, false, false, false, address(factory));
        emit PoolFactory.PoolAdded(address(this), t0, t1, address(0));
        factory.createPool(address(tokenA), address(tokenB));
    }

    function test_createPool_addsToAllPools() public {
        MockERC20 tokenC = new MockERC20("Token C", "TKC");
        factory.createPool(address(tokenA), address(tokenB));
        factory.createPool(address(tokenA), address(tokenC));
        assertTrue(factory.allPools(0) != address(0));
        assertTrue(factory.allPools(1) != address(0));
        assertTrue(factory.allPools(0) != factory.allPools(1));

        vm.expectRevert();
        factory.allPools(2);
    }
}
