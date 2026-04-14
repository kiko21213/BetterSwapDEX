// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {ProjectSetUp} from "test/unit/ProjectSetUp.t.sol";

contract DEXTokenTest is ProjectSetUp {
    function test_mintWorks() public {
        token.mint(address(this), 1000 * 1e18);
        assertEq(token.balanceOf(address(this)), 1000 * 1e18);
    }

    function test_MintRevertsIfNotMinter() public {
        vm.prank(address(1));
        vm.expectRevert();
        token.mint(address(1), 1000 * 1e18);
    }

    function test_MintReversMaxSupply() public {
        vm.expectRevert();
        token.mint(address(this), 100_000_001 * 1e18);
    }

    function test_burnWorks() public {
        token.mint(address(this), 1000 * 1e18);
        token.burn(100 * 1e18);
        assertEq(token.totalSupply(), 900 * 1e18);
    }
}
