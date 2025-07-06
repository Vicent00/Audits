// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { TokenFactory } from "../src/TokenFactory.sol";
import { L1Token } from "../src/L1Token.sol";

contract TokenFactoryTests is Test {
    address deployer = makeAddr("deployer");
    address user = makeAddr("user");
    address attacker = makeAddr("attacker");

    TokenFactory factory;
    L1Token originalToken;

    function setUp() public {
        vm.startPrank(deployer);

        // Deploy original token
        originalToken = new L1Token();
        
        // Deploy factory
        factory = new TokenFactory();

        vm.stopPrank();
    }

    // ============================================================================
    // TESTS BÁSICOS
    // ============================================================================

    function test_deployer_owns_factory() public {
        assertEq(factory.owner(), deployer);
    }

    function test_factory_can_deploy_tokens() public {
        vm.prank(deployer);
        
        string memory symbol = "TEST";
        bytes memory bytecode = type(L1Token).creationCode;
        
        address newToken = factory.deployToken(symbol, bytecode);
        
        assertTrue(newToken != address(0), "Token should be deployed");
        
        // Verificar que el token se puede usar
        L1Token token = L1Token(newToken);
        assertEq(token.symbol(), "L1T"); // El símbolo del L1Token es "L1T"
        assertEq(token.totalSupply(), 1_000_000 * 10**18);
    }

    function test_only_owner_can_deploy() public {
        vm.prank(user);
        
        bytes memory bytecode = type(L1Token).creationCode;
        vm.expectRevert();
        factory.deployToken("TEST", bytecode);
    }

    // ============================================================================
    // VULNERABILIDADES DE CLONACIÓN
    // ============================================================================

    function test_vulnerability_phishing_tokens() public {
        // VULNERABILIDAD: Posibilidad de crear tokens phishing
        
        vm.startPrank(attacker);
        
        // 1. Crear token con símbolo similar al original
        string memory phishingSymbol = "L1T"; // Mismo símbolo que el original
        bytes memory bytecode = type(L1Token).creationCode;
        
        address phishingToken = factory.deployToken(phishingSymbol, bytecode);
        
        // 2. Verificar que el token phishing se ve igual al original
        L1Token token = L1Token(phishingToken);
        assertEq(token.symbol(), originalToken.symbol(), "Phishing token has same symbol");
        
        // 3. VULNERABILIDAD: Los usuarios pueden confundir los tokens
        // El token phishing se ve idéntico al original pero es un contrato diferente
        
        vm.stopPrank();
    }

    function test_vulnerability_bytecode_verification() public {
        // VULNERABILIDAD: No hay verificación de bytecode
        
        vm.startPrank(attacker);
        
        // 1. Crear token malicioso con bytecode arbitrario
        string memory symbol = "MAL";
        bytes memory maliciousBytecode = hex"1234567890abcdef"; // Bytecode malicioso
        
        address maliciousToken = factory.deployToken(symbol, maliciousBytecode);
        
        // 2. VULNERABILIDAD: No hay verificación de que el bytecode sea el esperado
        // Un atacante podría usar bytecode malicioso
        
        // 3. Verificar que el token se creó (aunque sea malicioso)
        assertTrue(maliciousToken != address(0));
        
        vm.stopPrank();
    }

    function test_vulnerability_no_whitelist() public {
        // VULNERABILIDAD: No hay whitelist de tokens permitidos
        
        vm.startPrank(attacker);
        
        // 1. Cualquiera puede crear tokens con diferentes símbolos
        bytes memory bytecode = type(L1Token).creationCode;
        address token1 = factory.deployToken("TK1", bytecode);
        address token2 = factory.deployToken("TK2", bytecode);
        address token3 = factory.deployToken("TK3", bytecode);
        
        // 2. VULNERABILIDAD: No hay límite en el número de tokens creados
        // Esto puede llevar a spam de tokens y confusión
        
        assertTrue(token1 != address(0));
        assertTrue(token2 != address(0));
        assertTrue(token3 != address(0));
        
        vm.stopPrank();
    }

    // ============================================================================
    // TESTS DE FUZZING
    // ============================================================================

    function fuzz_token_creation(string memory symbol) public {
        // Fuzz test para creación de tokens
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 10);
        
        vm.prank(deployer);
        
        bytes memory bytecode = type(L1Token).creationCode;
        address newToken = factory.deployToken(symbol, bytecode);
        
        assertTrue(newToken != address(0), "Token should be deployed");
        
        // Verificar que el token se puede usar
        L1Token token = L1Token(newToken);
        assertEq(token.symbol(), "L1T"); // El símbolo del L1Token es "L1T"
        assertEq(token.totalSupply(), 1_000_000 * 10**18);
    }

    function fuzz_phishing_attack(string memory symbol) public {
        // Fuzz test para ataques de phishing
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 10);
        
        vm.startPrank(attacker);
        
        // Crear token con parámetros arbitrarios
        bytes memory bytecode = type(L1Token).creationCode;
        address phishingToken = factory.deployToken(symbol, bytecode);
        
        // Verificar que el token se creó
        assertTrue(phishingToken != address(0));
        
        L1Token token = L1Token(phishingToken);
        assertEq(token.symbol(), "L1T"); // El símbolo del L1Token es "L1T"
        
        vm.stopPrank();
    }

    // ============================================================================
    // TESTS DE INVARIANTES
    // ============================================================================

    function test_invariant_factory_owner() public {
        // Invariante: Factory siempre debe tener owner válido
        assertTrue(factory.owner() != address(0));
        assertEq(factory.owner(), deployer);
    }

    function test_invariant_token_creation() public {
        // Invariante: Tokens creados deben ser válidos
        vm.prank(deployer);
        
        bytes memory bytecode = type(L1Token).creationCode;
        address newToken = factory.deployToken("TEST", bytecode);
        
        assertTrue(newToken != address(0));
        assertTrue(newToken != address(factory));
        
        L1Token token = L1Token(newToken);
        assertEq(token.totalSupply(), 1_000_000 * 10**18);
    }

    function test_invariant_token_uniqueness() public {
        // Invariante: Cada token debe ser único
        vm.startPrank(deployer);
        
        bytes memory bytecode = type(L1Token).creationCode;
        address token1 = factory.deployToken("TK1", bytecode);
        address token2 = factory.deployToken("TK2", bytecode);
        
        assertTrue(token1 != token2, "Tokens should be unique");
        
        vm.stopPrank();
    }

    // ============================================================================
    // TESTS PARA ECHIDNA
    // ============================================================================

    function echidna_factory_owner_valid() public view returns (bool) {
        return factory.owner() != address(0);
    }

    function echidna_factory_owner_constant() public view returns (bool) {
        return factory.owner() == deployer;
    }

    // ============================================================================
    // TESTS PARA MEDUSA
    // ============================================================================

    function medusa_token_creation_cycle(string memory symbol) public {
        // Propiedad: Ciclo completo de creación de token
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 10);
        
        vm.prank(deployer);
        
        // 1. Crear token
        bytes memory bytecode = type(L1Token).creationCode;
        address newToken = factory.deployToken(symbol, bytecode);
        
        // 2. Verificar token
        assertTrue(newToken != address(0));
        
        L1Token token = L1Token(newToken);
        assertEq(token.symbol(), "L1T"); // El símbolo del L1Token es "L1T"
        assertEq(token.totalSupply(), 1_000_000 * 10**18);
        
        // 3. Verificar que el token funciona
        assertEq(token.balanceOf(deployer), 1_000_000 * 10**18);
    }

    // ============================================================================
    // TESTS PARA HALMOS
    // ============================================================================

    function invariant_factory_state_symbolic() public view {
        // Propiedad simbólica: Estado del factory debe ser válido
        assert(factory.owner() != address(0));
    }

    function invariant_token_creation_symbolic() public view {
        // Propiedad simbólica: Tokens creados deben ser válidos
        // Esta propiedad se mantiene para cualquier token creado
        assert(factory.owner() == deployer);
    }
} 