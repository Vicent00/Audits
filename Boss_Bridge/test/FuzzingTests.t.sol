// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { ECDSA } from "openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { L1BossBridge, L1Vault } from "../src/L1BossBridge.sol";
import { IERC20 } from "openzeppelin/contracts/interfaces/IERC20.sol";
import { L1Token } from "../src/L1Token.sol";

contract FuzzingTests is Test {
    address deployer = makeAddr("deployer");
    address user = makeAddr("user");
    address user2 = makeAddr("user2");
    Account operator = makeAccount("operator");

    L1Token token;
    L1BossBridge bridge;
    L1Vault vault;

    function setUp() public {
        vm.startPrank(deployer);

        // Deploy token and transfer initial balance
        token = new L1Token();
        token.transfer(address(user), 1000e18);
        token.transfer(address(user2), 1000e18);

        // Deploy bridge
        bridge = new L1BossBridge(IERC20(token));
        vault = bridge.vault();

        // Add signer
        bridge.setSigner(operator.addr, true);

        vm.stopPrank();
    }

    // ============================================================================
    // FUZZING TESTS PARA ECHIDNA
    // ============================================================================

    function echidna_deposit_limit() public view returns (bool) {
        // Propiedad: Vault balance nunca debe exceder DEPOSIT_LIMIT
        uint256 vaultBalance = token.balanceOf(address(vault));
        return vaultBalance <= bridge.DEPOSIT_LIMIT();
    }

    function echidna_total_supply_constant() public view returns (bool) {
        // Propiedad: Total supply debe ser constante
        uint256 initialSupply = 1_000_000 * 10**18;
        return token.totalSupply() == initialSupply;
    }

    function echidna_owner_valid() public view returns (bool) {
        // Propiedad: Owner nunca debe ser address(0)
        return bridge.owner() != address(0);
    }

    function echidna_token_valid() public view returns (bool) {
        // Propiedad: Token address debe ser válido
        return address(bridge.token()) != address(0);
    }

    function echidna_vault_valid() public view returns (bool) {
        // Propiedad: Vault address debe ser válido
        return address(bridge.vault()) != address(0);
    }

    function echidna_signers_authorized() public view returns (bool) {
        // Propiedad: Solo signers autorizados
        return bridge.signers(operator.addr) && !bridge.signers(user);
    }

    function echidna_pause_state() public view returns (bool) {
        // Propiedad: Estado de pausa debe ser booleano válido
        bool isPaused = bridge.paused();
        return isPaused == true || isPaused == false;
    }

    // ============================================================================
    // FUZZING TESTS PARA MEDUSA
    // ============================================================================

    function medusa_deposit_withdrawal_cycle(uint256 amount) public {
        // Propiedad: Ciclo completo de depósito y retiro
        vm.assume(amount > 0 && amount <= bridge.DEPOSIT_LIMIT() && amount <= token.balanceOf(user));
        
        uint256 initialVaultBalance = token.balanceOf(address(vault));
        uint256 initialUserBalance = token.balanceOf(user);
        
        // 1. Depositar
        vm.prank(user);
        token.approve(address(bridge), amount);
        bridge.depositTokensToL2(user, user2, amount);
        
        // 2. Verificar depósito
        assertEq(token.balanceOf(address(vault)), initialVaultBalance + amount);
        assertEq(token.balanceOf(user), initialUserBalance - amount);
        
        // 3. Retirar
        (uint8 v, bytes32 r, bytes32 s) = _signMessage(_getTokenWithdrawalMessage(user, amount), operator.key);
        bridge.withdrawTokensToL1(user, amount, v, r, s);
        
        // 4. Verificar retiro
        assertEq(token.balanceOf(address(vault)), initialVaultBalance);
        assertEq(token.balanceOf(user), initialUserBalance);
    }

    function medusa_multiple_deposits(uint256 amount1, uint256 amount2) public {
        // Propiedad: Múltiples depósitos
        vm.assume(amount1 > 0 && amount1 <= bridge.DEPOSIT_LIMIT() / 2);
        vm.assume(amount2 > 0 && amount2 <= bridge.DEPOSIT_LIMIT() / 2);
        vm.assume(amount1 + amount2 <= bridge.DEPOSIT_LIMIT());
        vm.assume(amount1 + amount2 <= token.balanceOf(user));
        
        uint256 initialVaultBalance = token.balanceOf(address(vault));
        
        // Primer depósito
        vm.prank(user);
        token.approve(address(bridge), amount1);
        bridge.depositTokensToL2(user, user2, amount1);
        
        // Segundo depósito
        vm.prank(user);
        token.approve(address(bridge), amount2);
        bridge.depositTokensToL2(user, user2, amount2);
        
        // Verificar total
        assertEq(token.balanceOf(address(vault)), initialVaultBalance + amount1 + amount2);
    }

    function medusa_signature_replay_protection(uint256 amount) public {
        // Propiedad: Protección contra replay de firmas
        vm.assume(amount > 0 && amount <= bridge.DEPOSIT_LIMIT() && amount <= token.balanceOf(user));
        
        // 1. Depositar
        vm.prank(user);
        token.approve(address(bridge), amount);
        bridge.depositTokensToL2(user, user2, amount);
        
        // 2. Generar firma
        (uint8 v, bytes32 r, bytes32 s) = _signMessage(_getTokenWithdrawalMessage(user, amount), operator.key);
        
        // 3. Usar firma primera vez
        bridge.withdrawTokensToL1(user, amount, v, r, s);
        
        // 4. Intentar usar la misma firma segunda vez
        // NOTA: En el contrato actual esto NO está protegido
        // Este test demuestra la vulnerabilidad
        bridge.withdrawTokensToL1(user, amount, v, r, s);
    }

    // ============================================================================
    // FUZZING TESTS PARA HALMOS
    // ============================================================================

    function invariant_vault_balance_symbolic() public view {
        // Propiedad simbólica: Vault balance debe estar en rango válido
        uint256 vaultBalance = token.balanceOf(address(vault));
        assert(vaultBalance >= 0);
        assert(vaultBalance <= bridge.DEPOSIT_LIMIT());
    }

    function invariant_total_supply_symbolic() public view {
        // Propiedad simbólica: Total supply debe ser constante
        uint256 initialSupply = 1_000_000 * 10**18;
        assert(token.totalSupply() == initialSupply);
    }

    function invariant_token_transfers_symbolic() public view {
        // Propiedad simbólica: Transferencias no cambian total supply
        uint256 totalSupply = token.totalSupply();
        // Esta propiedad se mantiene para cualquier transferencia
        assert(totalSupply == 1_000_000 * 10**18);
    }

    function invariant_bridge_state_symbolic() public view {
        // Propiedad simbólica: Estado del bridge debe ser válido
        assert(bridge.owner() != address(0));
        assert(address(bridge.token()) != address(0));
        assert(address(bridge.vault()) != address(0));
    }

    // ============================================================================
    // FUZZING TESTS PARA VULNERABILIDADES
    // ============================================================================

    function fuzz_arbitrary_call_execution(bytes memory callData) public {
        // Propiedad: sendToL1 puede ejecutar llamadas arbitrarias
        vm.assume(callData.length > 0);
        
        // Crear mensaje arbitrario
        bytes memory arbitraryMessage = abi.encode(
            address(0x123), // target arbitrario
            0,              // value
            callData        // datos arbitrarios
        );
        
        // Firmar mensaje
        (uint8 v, bytes32 r, bytes32 s) = _signMessage(arbitraryMessage, operator.key);
        
        // Ejecutar llamada arbitraria
        // NOTA: Esto demuestra la vulnerabilidad de arbitrary call
        bridge.sendToL1(v, r, s, arbitraryMessage);
    }

    function fuzz_signature_malleability(uint256 amount) public {
        // Propiedad: Firmas malleables
        vm.assume(amount > 0 && amount <= bridge.DEPOSIT_LIMIT() && amount <= token.balanceOf(user));
        
        // 1. Depositar
        vm.prank(user);
        token.approve(address(bridge), amount);
        bridge.depositTokensToL2(user, user2, amount);
        
        // 2. Generar firma válida
        (uint8 v, bytes32 r, bytes32 s) = _signMessage(_getTokenWithdrawalMessage(user, amount), operator.key);
        
        // 3. Crear firma malleable
        bytes32 sMalleable = bytes32(uint256(0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141) - uint256(s));
        
        // 4. Usar firma malleable
        bridge.withdrawTokensToL1(user, amount, v, r, sMalleable);
    }

    function fuzz_zero_address_withdraw(uint256 amount) public {
        // Propiedad: Retiros a address(0)
        vm.assume(amount > 0 && amount <= bridge.DEPOSIT_LIMIT() && amount <= token.balanceOf(user));
        
        // 1. Depositar
        vm.prank(user);
        token.approve(address(bridge), amount);
        bridge.depositTokensToL2(user, user2, amount);
        
        // 2. Intentar retirar a address(0)
        (uint8 v, bytes32 r, bytes32 s) = _signMessage(_getTokenWithdrawalMessage(address(0), amount), operator.key);
        
        // 3. Ejecutar retiro a address(0)
        // NOTA: Esto demuestra la vulnerabilidad de falta de validación
        bridge.withdrawTokensToL1(address(0), amount, v, r, s);
    }

    function fuzz_pause_bypass(uint256 amount) public {
        // Propiedad: Bypass de pausa en withdrawTokensToL1
        vm.assume(amount > 0 && amount <= bridge.DEPOSIT_LIMIT() && amount <= token.balanceOf(user));
        
        // 1. Depositar
        vm.prank(user);
        token.approve(address(bridge), amount);
        bridge.depositTokensToL2(user, user2, amount);
        
        // 2. Pausar bridge
        vm.prank(deployer);
        bridge.pause();
        
        // 3. Intentar retirar mientras está pausado
        (uint8 v, bytes32 r, bytes32 s) = _signMessage(_getTokenWithdrawalMessage(user, amount), operator.key);
        
        // 4. Ejecutar retiro (debería fallar pero NO falla)
        // NOTA: Esto demuestra la vulnerabilidad de falta de whenNotPaused
        bridge.withdrawTokensToL1(user, amount, v, r, s);
    }

    // ============================================================================
    // FUNCIONES AUXILIARES
    // ============================================================================

    function _getTokenWithdrawalMessage(address to, uint256 amount) internal view returns (bytes memory) {
        return abi.encode(
            address(token),
            0, // value
            abi.encodeCall(IERC20.transferFrom, (address(vault), to, amount))
        );
    }

    function _signMessage(bytes memory message, uint256 privateKey) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 messageHash = keccak256(message);
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        
        (v, r, s) = vm.sign(privateKey, ethSignedMessageHash);
    }
} 