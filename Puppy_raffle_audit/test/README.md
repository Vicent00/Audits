# PuppyRaffle Vulnerability Tests

Este directorio contiene tests de proof-of-concept que demuestran las vulnerabilidades identificadas en el contrato PuppyRaffle.

## Vulnerabilidades Demostradas

### 🔴 CRÍTICAS (C-01, C-02)
- **Reentrancy en `refund()`**: Demuestra cómo un atacante puede drenar fondos llamando `refund()` múltiples veces
- **Reentrancy en `selectWinner()`**: Muestra el riesgo de reentrancy durante la distribución de premios

### 🟠 ALTAS (H-01, H-02, H-03)
- **PRNG Débil**: Demuestra que los números aleatorios son predecibles
- **Ganador Nulo**: Muestra cómo se pueden perder premios si el ganador es `address(0)`
- **Access Control Bypass**: Demuestra que cualquiera puede retirar comisiones

### 🟡 MEDIAS (M-01, M-02)
- **Integer Overflow**: Demuestra el riesgo de overflow en `totalFees`
- **Fondos Bloqueados**: Muestra cómo los fondos pueden quedar bloqueados en `withdrawFees()`

### 🔵 BAJAS (L-02)
- **Ineficiencia de Gas**: Demuestra el alto costo de gas en verificación de duplicados

## Cómo Ejecutar los Tests

### Ejecutar todos los tests:
```bash
forge test --match-contract PuppyRaffleVulnerabilities -vvv
```

### Ejecutar tests específicos:

#### Test de Reentrancy en Refund:
```bash
forge test --match-test testReentrancyInRefund -vvv
```

#### Test de PRNG Débil:
```bash
forge test --match-test testWeakPRNGIsPredictable -vvv
```

#### Test de Access Control Bypass:
```bash
forge test --match-test testWithdrawFeesAccessControlBypass -vvv
```

#### Test de Fondos Bloqueados:
```bash
forge test --match-test testWithdrawFeesCanLockFunds -vvv
```

#### Test de Ineficiencia de Gas:
```bash
forge test --match-test testDuplicateCheckInefficiency -vvv
```

## Interpretación de Resultados

### Tests que DEBEN pasar (demuestran vulnerabilidades):
- `testWeakPRNGIsPredictable`: Debe pasar para mostrar que el PRNG es predecible
- `testNullWinnerLosesPrize`: Debe pasar para mostrar pérdida de premios
- `testWithdrawFeesCanLockFunds`: Debe fallar con el mensaje esperado
- `testReentrancyInRefund`: Debe pasar para mostrar el ataque de reentrancy
- `testReentrancyInSelectWinner`: Debe pasar para mostrar el riesgo de reentrancy
- `testWithdrawFeesAccessControlBypass`: Debe pasar para mostrar bypass de acceso
- `testIntegerOverflowRisk`: Debe pasar para mostrar riesgo de overflow
- `testDuplicateCheckInefficiency`: Debe pasar para mostrar ineficiencia

### Output Esperado:
Los tests mostrarán logs detallados explicando:
- Cómo se ejecuta cada ataque
- Qué valores se obtienen
- Por qué las vulnerabilidades son explotables
- El impacto potencial de cada vulnerabilidad

## Notas Importantes

1. **Estos tests están diseñados para DEMOSTRAR vulnerabilidades**, no para validar funcionalidad correcta
2. **Los tests de reentrancy muestran el riesgo**, aunque algunos pueden fallar por verificaciones existentes
3. **El output de gas muestra la ineficiencia** del algoritmo O(n²)
4. **Los tests de access control demuestran** que las funciones no están protegidas correctamente

## Uso en Reportes de Auditoría

Estos tests sirven como:
- **Proof-of-Concept** para demostrar explotabilidad
- **Documentación técnica** de las vulnerabilidades
- **Validación** de que los fixes propuestos funcionan
- **Educación** para el equipo de desarrollo

## Ejecutar Tests con Gas Reporting:
```bash
forge test --match-contract PuppyRaffleVulnerabilities --gas-report
```

Esto mostrará el costo de gas de cada función, útil para demostrar la ineficiencia del código.

# Tests de Vulnerabilidad de Reentrancy - PuppyRaffle

Este directorio contiene tests que demuestran la vulnerabilidad de reentrancy en el contrato PuppyRaffle.

## Vulnerabilidad Explotada

La función `refund()` en PuppyRaffle tiene una vulnerabilidad de reentrancy porque:

1. **Hace el external call ANTES de actualizar el estado**
2. **No implementa el patrón checks-effects-interactions**
3. **No tiene protección contra reentrancy**

```solidity
function refund(uint256 playerIndex) public {
    address playerAddress = players[playerIndex];
    require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
    require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");
    
    // ❌ EXTERNAL CALL ANTES DE ACTUALIZAR ESTADO
    payable(msg.sender).sendValue(entranceFee);
    
    // ✅ ESTADO SE ACTUALIZA DESPUÉS
    players[playerIndex] = address(0);
    emit RaffleRefunded(playerAddress);
}
```

## Cómo Funciona el Ataque

1. **Setup**: El atacante entra a la rifa con 1 ETH
2. **Ataque inicial**: Llama a `refund()` para obtener su reembolso
3. **Reentrancy**: Cuando recibe el ETH, se ejecuta `receive()`
4. **Explotación**: En `receive()`, llama a `refund()` de nuevo ANTES de que se actualice el estado
5. **Repetición**: Esto se repite hasta alcanzar `maxAttacks`

## Archivos

- `ReentrancyAttacker.sol` - Contrato malicioso que explota la vulnerabilidad
- `PuppyRaffleTest.t.sol` - Tests que demuestran el ataque

## Ejecutar los Tests

### Test Básico
```bash
forge test --match-test testReentrancyInRefund -vvv
```

### Test Detallado
```bash
forge test --match-test testReentrancyInRefundDetailed -vvv
```

### Test con Diferentes Contadores
```bash
forge test --match-test testReentrancyAttackWithDifferentCounts -vvv
```

### Test con Eventos (Más Detallado)
```bash
forge test --match-test testReentrancyAttackWithEvents -vvv
```

### Ejecutar Todos los Tests de Reentrancy
```bash
forge test --match-contract PuppyRaffleTest --match-test testReentrancy -vvv
```

## Resultados Esperados

### Test Básico
```
=== INICIO DEL ATAQUE DE REENTRANCY ===
Balance antes del ataque: 0
Índice del jugador: 0
Estado inicial del jugador: 0x...
=== RESULTADOS DEL ATAQUE ===
Balance después del ataque: 3000000000000000000
Cantidad robada: 3000000000000000000
Refund esperado (1x): 1000000000000000000
Refunds reales: 3000000000000000000
Multiplicador: 3
Estado final del jugador: 0x0000000000000000000000000000000000000000
✅ Ataque de reentrancy completado exitosamente!
El atacante robó 3 veces más ETH del que debería
```

### Test con Eventos
```
=== ATAQUE DE REENTRANCY CON MONITOREO DE EVENTOS ===
Estado inicial:
- Índice del jugador: 0
- Contador de ataques: 0
- Máximo de ataques: 5
- Balance inicial: 0

=== EVENTOS CAPTURADOS ===
Evento AttackStarted - Índice: 0
Evento ReentrancyExecuted - Ataque # 1 - Balance: 1000000000000000000
Evento ReentrancyExecuted - Ataque # 2 - Balance: 2000000000000000000
Evento ReentrancyExecuted - Ataque # 3 - Balance: 3000000000000000000
Evento ReentrancyExecuted - Ataque # 4 - Balance: 4000000000000000000
Evento ReentrancyExecuted - Ataque # 5 - Balance: 5000000000000000000
Evento AttackCompleted - Total robado: 5000000000000000000

=== RESULTADOS FINALES ===
Balance antes: 0
Balance después: 5000000000000000000
Cantidad robada: 5000000000000000000
Refunds esperados: 1000000000000000000
Refunds reales: 5000000000000000000
Multiplicador: 5
✅ Ataque de reentrancy con eventos completado exitosamente!
El atacante robó 5 veces más ETH del que debería
```

## Explicación del Ataque

### Flujo del Ataque

1. **Entrada a la rifa**: El atacante entra con 1 ETH
2. **Primera llamada**: Llama a `refund(playerIndex)`
3. **External call**: PuppyRaffle envía 1 ETH al atacante
4. **Función receive()**: Se ejecuta automáticamente cuando recibe ETH
5. **Reentrancy**: En `receive()`, llama a `refund(playerIndex)` de nuevo
6. **Estado no actualizado**: Como el estado aún no se actualizó, puede obtener otro refund
7. **Repetición**: Esto se repite hasta `maxAttacks`

### Por Qué Funciona

```solidity
// En PuppyRaffle.refund()
payable(msg.sender).sendValue(entranceFee);  // ❌ External call primero
players[playerIndex] = address(0);           // ✅ Estado se actualiza después
```

El problema es que el external call se hace ANTES de actualizar el estado. Esto permite que el atacante llame a `refund()` múltiples veces antes de que se marque como reembolsado.

### Solución

Implementar el patrón **checks-effects-interactions**:

```solidity
function refund(uint256 playerIndex) public {
    address playerAddress = players[playerIndex];
    require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
    require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");
    
    // ✅ 1. CHECKS (ya hecho arriba)
    
    // ✅ 2. EFFECTS - Actualizar estado ANTES del external call
    players[playerIndex] = address(0);
    emit RaffleRefunded(playerAddress);
    
    // ✅ 3. INTERACTIONS - External call DESPUÉS de actualizar estado
    payable(msg.sender).sendValue(entranceFee);
}
```

## Impacto de la Vulnerabilidad

- **Pérdida de fondos**: Los atacantes pueden drenar el contrato
- **Escalabilidad**: El ataque puede repetirse múltiples veces
- **Severidad**: CRÍTICA - Puede resultar en pérdida total de fondos

## Prevención

1. **Patrón checks-effects-interactions**
2. **ReentrancyGuard de OpenZeppelin**
3. **Pull over push pattern**
4. **Validación de estado antes de external calls**