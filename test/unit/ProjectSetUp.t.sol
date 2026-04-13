// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LiquidityPool} from "src/core/LiquidityPool.sol";
import {PoolFactory} from "src/core/PoolFactory.sol";
import {Router} from "src/periphery/Router.sol";
import {MockERC20} from "src/mocks/MockERC20.sol";

contract ProjectSetupTest is Test {
    LiquidityPool internal pool;
    PoolFactory internal factory;
    Router internal router;
    MockERC20 internal tokenA;
    MockERC20 internal tokenB;

    function setUp() public {
        pool = new LiquidityPool();
        factory = new PoolFactory();
        router = new Router();
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
    }

    function test_ProjectBaseDeploys() public {
        assertTrue(address(pool) != address(0));
        assertTrue(address(factory) != address(0));
        assertTrue(address(router) != address(0));
        assertTrue(address(tokenA) != address(0));
        assertTrue(address(tokenB) != address(0));
    }
}
