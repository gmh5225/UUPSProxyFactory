// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { UUPSProxyFactory } from "../src/UUPSProxyFactory.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract TestImplementation is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public value;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, uint256 _value) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        value = _value;
    }

    function setValue(uint256 _value) public {
        value = _value + 1;
    }

    // authorize upgrade(only owner)
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}

contract TestImplementationV2 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public value;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, uint256 _value) public reinitializer(2) {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        value = _value;
    }

    function setValue(uint256 _value) public {
        value = _value;
    }

    // authorize upgrade(only owner)
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}

contract UUPSProxyFactoryTest is Test {
    UUPSProxyFactory factory;
    TestImplementation implementation;
    TestImplementationV2 implementationV2;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        factory = new UUPSProxyFactory();
        implementation = new TestImplementation();
        implementationV2 = new TestImplementationV2();
    }

    function test_DeployProxyAndUpgrade() public {
        bytes memory initData = abi.encodeWithSelector(TestImplementation.initialize.selector, alice, uint256(100));

        console2.log("Alice address:", alice);

        vm.startPrank(alice);

        address proxy = factory.deployProxyWithAutoSalt(address(implementation), initData);

        assertTrue(proxy != address(0), "Proxy deployment failed");
        assertTrue(proxy.code.length > 0, "Proxy has no code");

        console2.log("Proxy address:", proxy);

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
        assertEq(implV2.value(), 200, "Upgrade failed");
    }
}
