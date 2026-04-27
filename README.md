# BetterSwap

A Uniswap-V2-style AMM in Solidity / Foundry — built from scratch as a portfolio project, with a focus on faithful reproduction of V2 mechanics and on-chain invariant safety.

> **Stack:** Solidity ^0.8.29 · Foundry · OpenZeppelin
> **Status:** actively developed (LiquidityPool + PoolFactory functional · Router pending)

---

## Overview

BetterSwap implements the core building blocks of a Uniswap-V2-style decentralized exchange:

- A **constant-product AMM pool** with the canonical 0.3% trading fee
- A **factory** that deploys and tracks pools
- A **fuzz test** that asserts the `k = x · y` invariant survives random swap sequences

This is a learning project written and tested as a "live product" with a realistic commit history. It is **not** a production-ready DEX and should not be deployed with real value.

---

## Architecture

```
PoolFactory ──createPool(tokenA, tokenB)──► LiquidityPool (one per pair)
                                              │
                                              ├── ERC-20 LP token (BSW-LP)
                                              ├── reserves: reserve0, reserve1
                                              └── swap / add / remove liquidity
```

| Contract | Lines | Status |
|---|---:|---|
| [`src/core/LiquidityPool.sol`](./src/core/LiquidityPool.sol) | 120 | functional |
| [`src/core/PoolFactory.sol`](./src/core/PoolFactory.sol) | 27 | functional |
| [`src/periphery/Router.sol`](./src/periphery/Router.sol) | 4 | stub (multi-hop routing not yet implemented) |

---

## LiquidityPool — key features

- **Constant-product curve** (`x · y = k`)
- **0.3% trading fee** via the canonical Uniswap V2 formula:
  ```
  amountInWithFee = amountIn * 997
  amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee)
  ```
- **First mint:** geometric mean — `Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY`
- **`MINIMUM_LIQUIDITY = 1000`** burned to `address(1)` on first mint — protection against the first-LP attack
- **Subsequent mints:** proportional via `Math.min(...)`
- **Inline invariant check** inside `swap()`:
  ```solidity
  if (balance0Adjusted * balance1Adjusted < reserve0 * reserve1 * 1000 * 1000) {
      revert LiquidityPool__InvariantBroken();
  }
  ```
  This is the same post-swap k-check Uniswap V2 uses, adjusted for the 0.3% fee.
- **ERC-20 LP token** (`BSW-LP`) inheriting OpenZeppelin ERC-20
- **ReentrancyGuard** on `addLiquidity`, `removeLiquidity`, `swap`
- **SafeERC20** for all token transfers
- **Anti-griefing:** swap reverts if `to == token0 || to == token1`
- **Custom errors:** `LiquidityPool__ZeroAddress`, `LiquidityPool__CantBeZero`, `LiquidityPool__PoolIsVoid`, `LiquidityPool__AddressToken`, `LiquidityPool__InvariantBroken`
- **Events:** `LiquidityAdded`, `LiquidityRemoved`, `Swap`

---

## PoolFactory — key features

- `createPool(tokenA, tokenB)` deploys a new `LiquidityPool` for the pair
- `getPools[tokenA][tokenB]` returns the existing pool or `address(0)`
- `allPools` array enumerates all created pools
- Errors: `PoolFactory__ZeroAddress`, `PoolFactory__AlreadyExist`
- Event: `PoolAdded(owner, tokenA, tokenB, pool)`

---

## Testing

```bash
forge test                                       # all tests
forge test -vvv                                  # verbose
forge test --match-contract LiquidityPoolFuzzTest  # fuzz only
```

| Test type | What it covers |
|---|---|
| **Unit** (`test/unit/`) | LP minting, reserve updates, ERC-20 LP token behavior, project setup |
| **Fuzz** (`test/fuzz/LiquidityPool.fuzz.t.sol`) | `testFuzz_swapInvariant` — bounded random `amountIn` (0.01–100 ether); asserts `pool.reserve0() * pool.reserve1() >= kBefore` after every swap |

The fuzz test is the most interesting one: it verifies — across many random trade sequences — that the constant-product invariant is never violated by the swap implementation.

---

## Build & Run

```bash
git clone https://github.com/kiko21213/BetterSwap
cd BetterSwap
forge install
forge build
forge test
```

---

## Roadmap

🚧 **In progress:**
- Router for multi-hop swaps and exact-input / exact-output helpers

📋 **Planned:**
- Price oracle / TWAP (cumulative price tracking)
- Configurable protocol fee (separate from the 0.3% trading fee)
- Multi-hop routing through `Router`

❌ **Out of scope (intentionally):**
- Flash loans
- Concentrated liquidity (V3 mechanics)
- Cross-chain bridge integration

---

## Security Considerations

This pool implements Uniswap-V2 patterns including:
- ReentrancyGuard on state-changing functions
- SafeERC20 for all transfers
- Inline post-swap k-invariant check
- MINIMUM_LIQUIDITY first-mint burn (anti first-LP attack)
- Anti-griefing checks on swap recipient

### Known Limitations

Honest accounting of what this project does **not** cover yet — useful for any reviewer before assuming production readiness:

- **Not professionally audited.** Open-source portfolio code. Do not deploy with real value without a third-party audit.
- **No price oracle / TWAP** — anyone integrating this pool for off-chain pricing must handle that externally.
- **Single-pair pool only** — no multi-hop routing without a Router (which is currently a stub).
- **No protocol fee switch** — only the built-in 0.3% trading fee accrues to LPs.
- **No fee-on-transfer token support** — pools assume standard ERC-20 transfer semantics.

---

## License

MIT — see [LICENSE](./LICENSE)

---

## Author

**0xkiko** — Solidity Developer, security-focused
- GitHub: [@kiko21213](https://github.com/kiko21213)
- Telegram: [@engineer_web3](https://t.me/engineer_web3)
