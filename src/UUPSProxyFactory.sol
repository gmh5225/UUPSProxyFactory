// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IUUPSProxyFactory } from "./interface/IUUPSProxyFactory.sol";

contract UUPSProxyFactory is IUUPSProxyFactory {
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
        bytes32 salt = keccak256(abi.encodePacked(implementation, initData, msg.sender, block.timestamp));
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

        address predictedAddress = predictProxyAddress(implementation, initData, salt);
        if (predictedAddress.code.length != 0) revert ProxyAlreadyExists();

        // Deploy proxy contract with user provided salt
        proxy = address(new ERC1967Proxy{ salt: salt }(implementation, initData));
        if (proxy == address(0) || proxy.code.length == 0) revert ProxyDeployFailed();

        emit ProxyDeployed(msg.sender, proxy, implementation, salt);
    }

    /// @notice Check if a proxy is already deployed
    /// @param implementation The implementation contract address
    /// @param initData The initialization data
    /// @param salt The salt value
    /// @return isDeployed True if proxy is already deployed
    function isProxyDeployed(
        address implementation,
        bytes calldata initData,
        bytes32 salt
    )
        external
        view
        returns (bool isDeployed)
    {
        address predictedAddress = predictProxyAddress(implementation, initData, salt);
        return predictedAddress.code.length != 0;
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
        bytes32 bytecodeHash =
            keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, initData)));

        predicted =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash)))));
    }

    /// @notice Check if the contract is UUPS compatible
    /// @param implementation The implementation contract address to check
    /// @return True if the contract is UUPS compatible
    function _isUUPSContract(address implementation) internal view returns (bool) {
        try UUPSUpgradeable(implementation).proxiableUUID() returns (bytes32 uuid) {
            return uuid == bytes32(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc);
        } catch {
            return false;
        }
    }
}
