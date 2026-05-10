// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {UQ112x112} from "src/libraries/UQ112x112.sol";

contract LiquidityPool is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using UQ112x112 for uint224;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    event LiquidityAdded(address indexed provider, uint256 amount0, uint256 amount1, uint256 lpAmount);
    event LiquidityRemoved(address indexed provider, uint256 amount0, uint256 amount1, uint256 lpAmount);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    error LiquidityPool__ZeroAddress();
    error LiquidityPool__CantBeZero();
    error LiquidityPool__PoolIsVoid();
    error LiquidityPool__AddressToken();
    error LiquidityPool__InvariantBroken();
    error LiquidityPool__Overflow();

    constructor(address _token0, address _token1) ERC20("BSW-LP", "BSW-LP") {
        if (_token0 == address(0)) revert LiquidityPool__ZeroAddress();
        if (_token1 == address(0)) revert LiquidityPool__ZeroAddress();
        token0 = _token0;
        token1 = _token1;
    }

    function mint(address to) external nonReentrant returns (uint256 lpAmount) {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0 = balance0 - reserve0;
        uint256 amount1 = balance1 - reserve1;
        if (amount0 == 0 || amount1 == 0) revert LiquidityPool__CantBeZero();
        if (totalSupply() == 0) {
            lpAmount = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(1), MINIMUM_LIQUIDITY);
        } else {
            lpAmount = Math.min(amount0 * totalSupply() / reserve0, amount1 * totalSupply() / reserve1);
        }
        if (lpAmount == 0) revert LiquidityPool__CantBeZero();

        _mint(to, lpAmount);
        _update(balance0, balance1);
        emit LiquidityAdded(msg.sender, amount0, amount1, lpAmount);
    }

    function _update(uint256 balance0, uint256 balance1) internal {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) revert LiquidityPool__Overflow();

        uint32 blockTimestamp = uint32(block.timestamp);

        unchecked {
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;

            if (timeElapsed > 0 && reserve0 != 0 && reserve1 != 0) {
                price0CumulativeLast += uint256(UQ112x112.encode(reserve1).uqdiv(reserve0)) * timeElapsed;
                price1CumulativeLast += uint256(UQ112x112.encode(reserve0).uqdiv(reserve1)) * timeElapsed;
            }
        }
        // casting to uint112 is safe: overflow is checked above
        // forge-lint: disable-next-line(unsafe-typecast)
        reserve0 = uint112(balance0);
        // forge-lint: disable-next-line(unsafe-typecast)
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(block.timestamp);
    }

    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        uint256 liquidity = balanceOf(address(this));

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        amount0 = liquidity * balance0 / totalSupply();
        amount1 = liquidity * balance1 / totalSupply();

        if (amount0 == 0 || amount1 == 0) revert LiquidityPool__CantBeZero();
        _burn(address(this), liquidity);
        IERC20(token0).safeTransfer(to, amount0);
        IERC20(token1).safeTransfer(to, amount1);
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
        emit LiquidityRemoved(msg.sender, amount0, amount1, liquidity);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert LiquidityPool__CantBeZero();
        if (reserveIn == 0) revert LiquidityPool__CantBeZero();
        if (reserveOut == 0) revert LiquidityPool__CantBeZero();

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestamp) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestamp = blockTimestampLast;
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to) external nonReentrant {
        if (amount0Out == 0 && amount1Out == 0) revert LiquidityPool__CantBeZero();
        if (to == address(0)) revert LiquidityPool__ZeroAddress();
        if (to == token0 || to == token1) revert LiquidityPool__AddressToken();
        if (amount0Out >= reserve0 || amount1Out >= reserve1) revert LiquidityPool__PoolIsVoid();

        if (amount0Out > 0) {
            IERC20(token0).safeTransfer(to, amount0Out);
        }
        if (amount1Out > 0) {
            IERC20(token1).safeTransfer(to, amount1Out);
        }

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0In = balance0 > reserve0 - amount0Out ? balance0 - (reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > reserve1 - amount1Out ? balance1 - (reserve1 - amount1Out) : 0;
        if (amount0In == 0 && amount1In == 0) revert LiquidityPool__CantBeZero();
        uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
        uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;

        if (balance0Adjusted * balance1Adjusted < uint256(reserve0) * uint256(reserve1) * 1000 * 1000) {
            revert LiquidityPool__InvariantBroken();
        }

        _update(balance0, balance1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }
}
