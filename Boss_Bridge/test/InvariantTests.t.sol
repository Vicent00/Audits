// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { ECDSA } from "openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { L1BossBridge, L1Vault } from "../src/L1BossBridge.sol";
import { IERC20 } from "openzeppelin/contracts/interfaces/IERC20.sol";
import { L1Token } from "../src/L1Token.sol";

contract InvariantTests is Test {
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
    // INVARIANTES DE BALANCE Y SUPPLY
    // ============================================================================

    function test_invariant_vault_balance() public {
        // Invariante: Vault balance >= 0 && <= DEPOSIT_LIMIT
        uint256 vaultBalance = token.balanceOf(address(vault));
        assertTrue(vaultBalance >= 0, "Vault balance cannot be negative");
        assertTrue(vaultBalance <= bridge.DEPOSIT_LIMIT(), "Vault balance cannot exceed deposit limit");
    }

    function test_invariant_total_supply() public {
        // Invariante: Total supply debe ser constante
        uint256 initialSupply = 1_000_000 * 10**18;
        assertEq(token.totalSupply(), initialSupply, "Total supply must remain constant");
    }

    function test_invariant_token_transfers() public {
        // Invariante: Transferencias no deben cambiar total supply
        uint256 initialSupply = token.totalSupply();
        
        // Simular transferencias
        vm.prank(user);
        token.transfer(user2, 100e18);
        
        assertEq(token.totalSupply(), initialSupply, "Token transfers must not change total supply");
    }

    // ============================================================================
    // INVARIANTES DE SEGURIDAD
    // ============================================================================

    function test_invariant_owner_valid() public {
        // Invariante: Owner nunca debe ser address(0)
        assertTrue(bridge.owner() != address(0), "Owner cannot be zero address");
    }

    function test_invariant_token_valid() public {
        // Invariante: Token address debe ser válido
        assertTrue(address(bridge.token()) != address(0), "Token address cannot be zero");
    }

    function test_invariant_vault_valid() public {
        // Invariante: Vault address debe ser válido
        assertTrue(address(bridge.vault()) != address(0), "Vault address cannot be zero");
    }

    function test_invariant_signers_authorized() public {
        // Invariante: Solo signers autorizados pueden firmar
        assertTrue(bridge.signers(operator.addr), "Operator should be authorized signer");
        
        // Verificar que usuarios normales no son signers
        assertFalse(bridge.signers(user), "User should not be authorized signer");
        assertFalse(bridge.signers(user2), "User2 should not be authorized signer");
    }

    // ============================================================================
    // INVARIANTES ESPECÍFICAS DEL BRIDGE
    // ============================================================================

    function test_invariant_deposit_limit() public {
        // Invariante: Depósitos no deben exceder límite
        uint256 vaultBalance = token.balanceOf(address(vault));
        assertTrue(vaultBalance <= bridge.DEPOSIT_LIMIT(), "Vault balance cannot exceed deposit limit");
    }

    function test_invariant_pause_state() public {
        // Invariante: Estado de pausa debe ser consistente
        bool isPaused = bridge.paused();
        
        if (isPaused) {
            // Si está pausado, ciertas operaciones no deben ser posibles
            // (esto se prueba en otros tests)
        } else {
            // Si no está pausado, el bridge debe funcionar normalmente
            assertFalse(bridge.paused(), "Bridge should not be paused");
        }
    }

    function test_invariant_bridge_functionality() public {
        // Invariante: Bridge debe mantener funcionalidad básica
        assertTrue(address(bridge) != address(0), "Bridge address must be valid");
        assertTrue(address(vault) != address(0), "Vault address must be valid");
        assertTrue(address(token) != address(0), "Token address must be valid");
    }

    // ============================================================================
    // INVARIANTES DE NEGOCIO
    // ============================================================================

    function test_invariant_token_compatibility() public {
        // Invariante: Solo el token autorizado debe ser usado
        assertEq(address(bridge.token()), address(token), "Bridge must use correct token");
        assertEq(address(vault.token()), address(token), "Vault must use correct token");
    }

    function test_invariant_vault_approval() public {
        // Invariante: Vault debe tener aprobación infinita para el bridge
        assertEq(
            token.allowance(address(vault), address(bridge)),
            type(uint256).max,
            "Vault must have infinite allowance for bridge"
        );
    }

    // ============================================================================
    // INVARIANTES PARA FUZZING
    // ============================================================================

    function test_invariant_vault_balance_fuzz(uint256 amount) public {
        // Fuzz test para vault balance
        vm.assume(amount > 0 && amount <= bridge.DEPOSIT_LIMIT());
        
        uint256 initialBalance = token.balanceOf(address(vault));
        
        // Simular depósito
        vm.prank(user);
        token.approve(address(bridge), amount);
        bridge.depositTokensToL2(user, user2, amount);
        
        uint256 finalBalance = token.balanceOf(address(vault));
        assertTrue(finalBalance >= initialBalance, "Vault balance should not decrease");
        assertTrue(finalBalance <= bridge.DEPOSIT_LIMIT(), "Vault balance cannot exceed limit");
    }

    function test_invariant_total_supply_fuzz(uint256 amount) public {
        // Fuzz test para total supply
        vm.assume(amount > 0 && amount <= token.balanceOf(user));
        
        uint256 initialSupply = token.totalSupply();
        
        // Simular transferencia
        vm.prank(user);
        token.transfer(user2, amount);
        
        uint256 finalSupply = token.totalSupply();
        assertEq(finalSupply, initialSupply, "Total supply must remain constant");
    }

    // ============================================================================
    // INVARIANTES PARA ECHIDNA
    // ============================================================================

    function echidna_vault_balance() public view returns (bool) {
        uint256 vaultBalance = token.balanceOf(address(vault));
        return vaultBalance >= 0 && vaultBalance <= bridge.DEPOSIT_LIMIT();
    }

    function echidna_total_supply() public view returns (bool) {
        uint256 initialSupply = 1_000_000 * 10**18;
        return token.totalSupply() == initialSupply;
    }

    function echidna_owner_valid() public view returns (bool) {
        return bridge.owner() != address(0);
    }

    function echidna_deposit_limit() public view returns (bool) {
        uint256 vaultBalance = token.balanceOf(address(vault));
        return vaultBalance <= bridge.DEPOSIT_LIMIT();
    }

    // ============================================================================
    // INVARIANTES PARA HALMOS
    // ============================================================================

    function invariant_vault_balance_symbolic() public view {
        uint256 vaultBalance = token.balanceOf(address(vault));
        assert(vaultBalance >= 0);
        assert(vaultBalance <= bridge.DEPOSIT_LIMIT());
    }

    function invariant_total_supply_symbolic() public view {
        uint256 initialSupply = 1_000_000 * 10**18;
        assert(token.totalSupply() == initialSupply);
    }

    function invariant_owner_valid_symbolic() public view {
        assert(bridge.owner() != address(0));
    }

    function invariant_deposit_limit_symbolic() public view {
        uint256 vaultBalance = token.balanceOf(address(vault));
        assert(vaultBalance <= bridge.DEPOSIT_LIMIT());
    }
} 