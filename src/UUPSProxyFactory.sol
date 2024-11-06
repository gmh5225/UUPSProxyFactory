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
    error EmptyInitData();

    // events
    event ProxyDeployed(address indexed deployer, address indexed proxy, address indexed implementation, bytes32 salt);

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
        external
        returns (address proxy)
    {
        // Check if implementation address is valid
        if (implementation == address(0)) revert InvalidImplementation();

        // Check if implementation is UUPS compatible
        if (!_isUUPSContract(implementation)) revert NotUUPSImplementation();

        // Check if proxy contract already exists
        address predictedAddress = predictProxyAddress(implementation, initData, salt);
        if (predictedAddress.code.length > 0) revert ProxyAlreadyExists();

        // Check if initialization data is not empty
        if (initData.length == 0) revert EmptyInitData();

        // Deploy proxy contract with user provided salt
        proxy = address(new ERC1967Proxy{ salt: salt }(implementation, initData));
        if (proxy == address(0)) revert ProxyDeployFailed();

        // Verify the proxy was deployed successfully
        if (proxy.code.length == 0) revert ProxyDeployFailed();

        // Emit event
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
        bytes memory creationCode = type(ERC1967Proxy).creationCode;
        bytes memory bytecode = abi.encodePacked(creationCode, abi.encode(implementation, initData));

        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));

        predicted = address(uint160(uint256(hash)));
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
