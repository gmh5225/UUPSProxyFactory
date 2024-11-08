// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
// import { UUPSProxyFactory } from "../src/UUPSProxyFactory.sol";
import { IUUPSProxyFactory } from "../src/interface/IUUPSProxyFactory.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import { ReentrancyGuardTransientUpgradeable } from
    "@openzeppelin-upgradeable/contracts/utils/ReentrancyGuardTransientUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin-upgradeable/contracts/utils/PausableUpgradeable.sol";

contract TestImplementation is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public value;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner_, uint256 value_) public initializer {
        __Ownable_init(initialOwner_);
        __UUPSUpgradeable_init();
        value = value_;
    }

    function setValue(uint256 value_) public {
        value = value_ + 1;
    }

    // authorize upgrade(only owner)
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}

contract TestImplementationV2 is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    uint256 public value;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner_, uint256 value_) public reinitializer(2) {
        __Ownable_init(initialOwner_);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        value = value_;
    }

    function setValue(uint256 value_) public nonReentrant whenNotPaused {
        value = value_ + 2;
    }

    // authorize upgrade(only owner)
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}

contract TestImplementationV3 is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardTransientUpgradeable,
    PausableUpgradeable
{
    uint256 public value;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner_, uint256 value_) public reinitializer(3) {
        __Ownable_init(initialOwner_);
        __UUPSUpgradeable_init();
        __ReentrancyGuardTransient_init();
        value = value_;
    }

    function setValue(uint256 value_) public nonReentrant whenNotPaused {
        value = value_;
    }

    // authorize upgrade(only owner)
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}

contract UUPSProxyFactoryTest is Test {
    bytes32 salt = keccak256(abi.encodePacked("salt"));

    // UUPSProxyFactory factory;
    IUUPSProxyFactory factory;
    TestImplementation implementation;
    TestImplementationV2 implementationV2;
    TestImplementationV3 implementationV3;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        // factory = new UUPSProxyFactory();
        factory = IUUPSProxyFactory(deployCode("../src/abi/UUPSProxyFactory.sol:UUPSProxyFactory"));
        implementation = new TestImplementation();
        implementationV2 = new TestImplementationV2();
        implementationV3 = new TestImplementationV3();
    }

    function test_DeployProxyAndUpgrade() public {
        bytes memory initData = abi.encodeWithSelector(TestImplementation.initialize.selector, alice, uint256(100));

        console2.log("Alice address:", alice);

        vm.startPrank(alice);

        bool isDeployed = factory.isProxyDeployed(address(implementation), initData, salt);
        console2.log("Is proxy deployed:", isDeployed);
        assertEq(isDeployed, false, "Proxy should not be deployed before deployment");

        address proxy = factory.deployProxy(address(implementation), initData, salt);

        // proxy contract decompiled as below
        /**
         * // Decompiled by library.dedaub.com
         * // 2024.11.07 09:26 UTC
         * // Compiled using the solidity compiler version 0.8.28
         *
         *
         * // Data structures and variables inferred from the use of storage instructions
         * address ___function_selector__; //
         * STORAGE[0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc] bytes 0 to 19
         *
         *
         *
         * // Note: The function selector is not present in the original solidity code.
         * // However, we display it for the sake of completeness.
         *
         * function __function_selector__() private {
         * MEM[64] = 128;
         * CALLDATACOPY(0, 0, msg.data.length);
         * v0 = ___function_selector__.delegatecall(MEM[0:msg.data.length], MEM[0:0]).gas(msg.gas);
         * require(v0, 0, RETURNDATASIZE()); // checks call status, propagates error data on error
         * return ;
         * }
         */
        bool isDeployedAfter = factory.isProxyDeployed(address(implementation), initData, salt);
        console2.log("Is proxy deployed after:", isDeployedAfter);
        assertEq(isDeployedAfter, true, "Proxy should be deployed after deployment");

        address predictedProxy = factory.predictProxyAddress(address(implementation), initData, salt);

        assertTrue(proxy != address(0), "Proxy deployment failed");
        assertTrue(proxy.code.length > 0, "Proxy has no code");
        assertTrue(proxy == predictedProxy, "Proxy address mismatch");

        console2.log("Proxy address:", proxy);
        console2.log("Predicted proxy address:", predictedProxy);

        TestImplementation impl = TestImplementation(proxy);

        console2.log("Actual owner:", impl.owner());

        impl.setValue(200);

        assertEq(impl.value(), 201, "Initialization failed");
        assertEq(impl.owner(), alice, "Owner not set correctly");

        vm.stopPrank();

        // upgrade to v2
        vm.startPrank(alice);
        TestImplementationV2(proxy).upgradeToAndCall(
            address(implementationV2),
            abi.encodeWithSelector(TestImplementationV2.initialize.selector, alice, uint256(100))
        );
        vm.stopPrank();

        TestImplementationV2 implV2 = TestImplementationV2(proxy);
        implV2.setValue(200);
        assertEq(implV2.value(), 202, "Upgrade failed");

        // pause
        vm.startPrank(alice);
        implV2.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        implV2.setValue(200);

        // unpause
        implV2.unpause();
        implV2.setValue(200);
        assertEq(implV2.value(), 202, "Upgrade failed");
        vm.stopPrank();

        // upgrade to v3
        vm.startPrank(alice);
        TestImplementationV2(proxy).upgradeToAndCall(
            address(implementationV3),
            abi.encodeWithSelector(TestImplementationV3.initialize.selector, alice, uint256(100))
        );

        TestImplementationV3 implV3 = TestImplementationV3(proxy);
        implV3.setValue(200);
        assertEq(implV3.value(), 200, "Upgrade failed");

        vm.stopPrank();
    }
}
