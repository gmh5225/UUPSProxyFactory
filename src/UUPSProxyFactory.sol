// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UUPSProxyFactory {
    // custom errors
    error ProxyDeployFailed();
    error InvalidImplementation();
    error ProxyAlreadyExists();
    error NotUUPSImplementation();
    error InvalidInitData();

    // events
    event ProxyDeployed(address indexed deployer, address indexed proxy, address indexed implementation, bytes32 salt);

    /// @notice Deploy a new proxy contract with auto-generated salt
    /// @param implementation The implementation contract address
    /// @param initData The initialization data
    /// @return proxy The deployed proxy contract address
    function deployProxyWithAutoSalt(
        address implementation,
        bytes calldata initData
    )
        external
        returns (address proxy)
    {
        bytes32 salt;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, implementation)
            mstore(add(ptr, 0x20), calldataload(initData.offset))
            mstore(add(ptr, 0x40), caller())
            mstore(add(ptr, 0x60), timestamp())
            salt := keccak256(ptr, 0x80)
        }
        return deployProxy(implementation, initData, salt);
    }

    /// @notice Deploy a new proxy contract
    /// @param implementation The implementation contract address
    /// @param initData The initialization data
    /// @param salt The salt value provided by user
    /// @return proxy The deployed proxy contract address
    function deployProxy(
        address implementation,
        bytes calldata initData,
        bytes32 salt
    )
        public
        returns (address proxy)
    {
        if (implementation == address(0) || implementation.code.length == 0) {
            revert InvalidImplementation();
        }
        unchecked {
            if (initData.length < 4) revert InvalidInitData();
        }
        if (!_isUUPSContract(implementation)) revert NotUUPSImplementation();

        // calculate the address of the proxy
        proxy = predictProxyAddress(implementation, initData, salt);
        if (proxy.code.length != 0) revert ProxyAlreadyExists();

        // deploy the proxy contract
        assembly {
            // create the creation code of the proxy
            let ptr := mload(0x40)
            mstore(ptr, implementation)
            mstore(add(ptr, 0x20), initData)

            // deploy the proxy contract with create2
            proxy := create2(0, ptr, add(0x40, calldatasize()), salt)
        }

        // check the deployment result
        if (proxy == address(0)) revert ProxyDeployFailed();

        emit ProxyDeployed(msg.sender, proxy, implementation, salt);
    }

    /// @notice Predict the proxy contract address before deployment
    /// @param implementation The implementation contract address
    /// @param initData The initialization data
    /// @param salt The salt value provided by user
    /// @return predicted The predicted proxy contract address
    function predictProxyAddress(
        address implementation,
        bytes calldata initData,
        bytes32 salt
    )
        public
        view
        returns (address predicted)
    {
        assembly {
            // calculate the bytecode hash
            let ptr := mload(0x40)
            mstore(ptr, implementation)
            mstore(add(ptr, 0x20), initData)
            let bytecodeHash := keccak256(ptr, add(0x40, calldatasize()))

            // calculate the create2 address
            let data :=
                add(0xff000000000000000000000000000000000000000000000000000000000000000000000000000000, address())
            mstore(ptr, data)
            mstore(add(ptr, 0x20), salt)
            mstore(add(ptr, 0x40), bytecodeHash)
            predicted := and(keccak256(ptr, 0x60), 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }

    /// @notice Check if the contract is UUPS compatible
    /// @param implementation The implementation contract address to check
    /// @return isUUPS True if the contract is UUPS compatible
    function _isUUPSContract(address implementation) internal view returns (bool) {
        try UUPSUpgradeable(implementation).proxiableUUID() returns (bytes32 uuid) {
            return uuid == 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        } catch {
            return false;
        }
    }
}
