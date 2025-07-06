# Data about Bross Bridge 

## Pesnamientos que tengo que podrían ser (humano)

- Tema de modificación del evento a la hora del hacer el deposito, posible falseo no lo se ya que no he visto el codigo

- Si hay muchos ataques o eventos y colapso de eventos podria colapasar la parte de L2 al hacer el acuñamiento

- Necesidad de operatos bridge aceptar podria sobrecalapse

- Mucho centralizacion en la pausa, y en otros aspectos como opertator bridge 

- Posible hackeo de back end off chain de su posible hackeo 

- Posible copia del token erc20




# Preguntas de profundización (2-3 por punto)

## Centralización

¿Existe multisig o timelock para funciones de pausa y gestión de signers?

¿Qué procedimientos limitan un uso malintencionado de la pausa?

## Claves de Signers

¿Cómo se crean, rotan y revocan las claves de firmantes?

¿Se exige hardware HSM o MPC (varias firmas) para emitir cada retiro?

## Límite de depósito

¿Está expresado en variable mutable? ¿Quién la puede cambiar y bajo qué proceso?

¿Se valida contra unidades del token (decimales) para evitar desbordes?

## Validaciones address 0 y mágicos

¿Se ha cuantificado el ahorro de gas vs. riesgo de pérdida de fondos?

¿Se documentarán escenarios de fallo y procedimientos de recuperación?

## Servicio off-chain

¿Qué garantías ofrece frente a censura o caídas prolongadas?

¿Cómo se verifica la correspondencia 1:1 entre eventos L1 y mint L2?

## Token malicioso

¿Existe whitelist on-chain del bytecode/salt de L1Token?

¿Cómo impedir que un atacante despliegue un clon con lógica oculta?

## Seguridad del Vault

¿Se auditaron funciones de rescate de tokens ajenos y transfer hooks?

¿El vault admite solo transferencias desde el bridge o cualquier transferFrom?

## Eventos

¿Se emplea chainId o nonce único para prevenir replays entre forks?

¿Se firma y almacena off-chain un hash completo de eventos procesados?

## Pausa / DoS

¿Existe un “circuit-breaker” granular (solo depósitos o solo retiros)?

¿Cuál es el timeout máximo antes de re-habilitar operaciones?

## Plan de incidentes y claves

¿Hay un run-book probado para compromiso de un signer u owner?

¿Se practican simulacros de pérdida completa de la clave del Owner?

# Posibles ataques 

## Vectores de riesgo adicionales (tendencias recientes)

Re-entrancy cross-chain: ataques tipo pools bridging (p.ej. incidentes 2024 en puentes X-Swap) donde un callback en L1 altera balances antes de emitir evento.

Replay entre testnet/mainnet: actores que duplican firmas o eventos en redes con chainId idéntico mal configurado.

Desincronización de gas y tarifas: congestión en L1 que retrase eventos y provoque mint desbalanceado en L2.

Fugas por permisos ERC-20 “permit”: si en el futuro se usa EIP-2612, riesgo de firmas offline reutilizadas.

Compromiso del backend: manipulación de payloads de retiro antes de ser firmados, equivalente a hot-wallet hack.

Configuraciones de fábrica (TokenFactory): posibilidad de desplegar tokens con supply inflado o con hooks.

Actualizaciones de L2: hard-forks o bugs de la nueva red que invaliden invariantes del puente.