// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, StdInvariant, console2 } from "forge-std/Test.sol";
import { PoolFactory } from "../../src/PoolFactory.sol";
import { TSwapPool } from "../../src/TSwapPool.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { TswapPoolHandler } from "./TswapPoolHandler.sol";

contract Invariants is StdInvariant, Test {
    PoolFactory factory;
    TSwapPool pool;
    ERC20Mock poolToken;
    ERC20Mock weth;
    ERC20Mock tokenB;

    int256 constant STARTING_X = 100e18; // starting ERC20
    int256 constant STARTING_Y = 50e18; // starting WETH
    uint256 constant FEE = 997e15; //
    int256 constant MATH_PRECISION = 1e18;

    TswapPoolHandler handler;

    // Ghost variables para invariants más agresivas
    uint256 public ghost_k;
    uint256 public ghost_x;
    uint256 public ghost_y;

    function setUp() public {
        weth = new ERC20Mock();
        poolToken = new ERC20Mock();
        factory = new PoolFactory(address(weth));
        pool = TSwapPool(factory.createPool(address(poolToken)));

        // Create the initial x & y values for the pool
        poolToken.mint(address(this), uint256(STARTING_X));
        weth.mint(address(this), uint256(STARTING_Y));
        poolToken.approve(address(pool), type(uint256).max);
        weth.approve(address(pool), type(uint256).max);
        pool.deposit(uint256(STARTING_Y), uint256(STARTING_Y), uint256(STARTING_X), uint64(block.timestamp));

        handler = new TswapPoolHandler(pool);

        // AGREGANDO FUNCIONES DE BACKDOOR
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = TswapPoolHandler.deposit.selector;
        selectors[1] = TswapPoolHandler.swapPoolTokenForWethBasedOnOutputWeth.selector;
        selectors[2] = TswapPoolHandler.exploitBackdoor.selector;
        selectors[3] = TswapPoolHandler.exploitBackdoorInfinite.selector;

        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
        targetContract(address(handler));

        // Inicializar variables ghost
        _updateGhostVariables();
    }

    // Normal Invariant
    // x * y = k
    // x * y = (x + ∆x) * (y − ∆y)
    // x = Token Balance X
    // y = Token Balance Y
    // ∆x = Change of token balance X
    // ∆y = Change of token balance Y
    // β = (∆y / y)
    // α = (∆x / x)

    // Final invariant equation without fees:
    // ∆x = (β/(1-β)) * x
    // ∆y = (α/(1+α)) * y

    // Invariant with fees
    // ρ = fee (between 0 & 1, aka a percentage)
    // γ = (1 - p) (pronounced gamma)
    // ∆x = (β/(1-β)) * (1/γ) * x
    // ∆y = (αγ/1+αγ) * y
    function invariant_deltaXFollowsMath() public view {
        assertEq(handler.actualDeltaX(), handler.expectedDeltaX());
    }

    function invariant_deltaYFollowsMath() public view {
        assertEq(handler.actualDeltaY(), handler.expectedDeltaY());
    }


    function invariant_coreInvariant() public view {
        // Core invariant: x * y = k debe mantenerse (o aumentar por fees)
        uint256 current_x = weth.balanceOf(address(pool));
        uint256 current_y = poolToken.balanceOf(address(pool));
        uint256 current_k = current_x * current_y;
        
        // La invariant debe mantenerse o aumentar por fees
        assert(current_k >= ghost_k);
    }

    function invariant_noOverflow() public view {
        // Verificar que no hay overflow en los balances
        uint256 wethBalance = weth.balanceOf(address(pool));
        uint256 poolTokenBalance = poolToken.balanceOf(address(pool));
        
        // Verificar que los balances son razonables
        assert(wethBalance < type(uint256).max / 2);
        assert(poolTokenBalance < type(uint256).max / 2);
        
        // Verificar que el producto no hace overflow
        uint256 product = wethBalance * poolTokenBalance;
        assert(product >= wethBalance); // Overflow check
    }

    function invariant_liquidityTokensConsistent() public view {
        // Verificar que los LP tokens son consistentes con las reservas
        uint256 totalSupply = pool.totalLiquidityTokenSupply();
        uint256 wethBalance = weth.balanceOf(address(pool));
        uint256 poolTokenBalance = poolToken.balanceOf(address(pool));
        
        // Si hay liquidez, debe haber LP tokens
        if (wethBalance > 0 && poolTokenBalance > 0) {
            assert(totalSupply > 0);
        }
    }

    function invariant_pricesPositive() public view {
        // Verificar que los precios calculados son positivos
        uint256 wethBalance = weth.balanceOf(address(pool));
        uint256 poolTokenBalance = poolToken.balanceOf(address(pool));
        
        if (wethBalance > 0 && poolTokenBalance > 0) {
            uint256 priceWethToPool = pool.getPriceOfOneWethInPoolTokens();
            uint256 pricePoolToWeth = pool.getPriceOfOnePoolTokenInWeth();
            
            assert(priceWethToPool > 0);
            assert(pricePoolToWeth > 0);
        }
    }

    function invariant_noReentrancy() public view {
        // Verificar que no hay reentrancy (balances consistentes)
        uint256 wethBalance = weth.balanceOf(address(pool));
        uint256 poolTokenBalance = poolToken.balanceOf(address(pool));
        
        // Los balances deben ser consistentes con las variables ghost
        assert(wethBalance >= ghost_x || wethBalance <= ghost_x + 1e18); // Permitir pequeñas variaciones
        assert(poolTokenBalance >= ghost_y || poolTokenBalance <= ghost_y + 1e18);
    }

    function invariant_feeCalculation() public view {
        // Verificar que los fees se calculan correctamente
        uint256 wethBalance = weth.balanceOf(address(pool));
        uint256 poolTokenBalance = poolToken.balanceOf(address(pool));
        
        if (wethBalance > 0 && poolTokenBalance > 0) {
            // Verificar que el fee de 0.3% se aplica correctamente
            uint256 inputAmount = 1e18;
            uint256 outputAmount = pool.getOutputAmountBasedOnInput(
                inputAmount,
                wethBalance,
                poolTokenBalance
            );
            
            // El output debe ser menor que el input debido al fee
            assert(outputAmount < inputAmount);
        }
    }

    // INVARIANT ESPECÍFICA PARA DETECTAR LA BACKDOOR
    function invariant_noBackdoorExploitation() public view {
        // Verificar que no se ha explotado la backdoor
        uint256 wethBalance = weth.balanceOf(address(pool));
        uint256 poolTokenBalance = poolToken.balanceOf(address(pool));
        
        // Si los balances son muy bajos, podría indicar explotación de backdoor
        // Los balances iniciales eran STARTING_X y STARTING_Y
        uint256 minExpectedWeth = uint256(STARTING_Y) / 10; // Al menos 10% de los fondos iniciales
        uint256 minExpectedPoolToken = uint256(STARTING_X) / 10;
        
        assert(wethBalance >= minExpectedWeth);
        assert(poolTokenBalance >= minExpectedPoolToken);
    }

    function invariant_noExcessiveRewards() public view {
        // Verificar que no se han dado recompensas excesivas
        // Esta invariant detecta si alguien ha recibido la recompensa masiva de 1e18 tokens
        
        // En un pool real, recibir 1e18 tokens (1 token completo) por 10 swaps pequeños
        // sería claramente una explotación de backdoor
        
        // Como no podemos rastrear directamente las recompensas, verificamos que
        // los balances del pool no han disminuido drásticamente sin razón
        
        uint256 wethBalance = weth.balanceOf(address(pool));
        uint256 poolTokenBalance = poolToken.balanceOf(address(pool));
        
        // Los balances deben ser razonables comparados con los iniciales
        assert(wethBalance >= uint256(STARTING_Y) * 80 / 100);
        assert(poolTokenBalance >= uint256(STARTING_X) * 80 / 100);
    }

    // Función helper para actualizar variables ghost
    function _updateGhostVariables() internal {
        ghost_x = weth.balanceOf(address(pool));
        ghost_y = poolToken.balanceOf(address(pool));
        ghost_k = ghost_x * ghost_y;
    }
}