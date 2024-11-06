// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Factory address: 0x642265eDC037e230E78C5c4443F294EE00fCe05E
interface IUUPSProxyFactory {
    /// @notice Deploy a new proxy contract with auto-generated salt
    /// @param implementation The implementation contract address
    /// @param initData The initialization data
    /// @return proxy The deployed proxy contract address
    function deployProxyWithAutoSalt(
        address implementation,
        bytes calldata initData
    )
        external
        returns (address proxy);

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
        returns (address proxy);

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
        returns (bool isDeployed);

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
        external
        view
        returns (address predicted);
}
