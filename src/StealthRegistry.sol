// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IStealthRegistry} from "./interfaces/IStealthRegistry.sol";

/// @notice Stores EIP-5564 stealth meta-addresses. Accounts register their own meta-addresses;
/// payers look them up to compute stealth addresses off-chain.
contract StealthRegistry is IStealthRegistry {
    /// @notice stealth meta-address storage: account => schemeId => encoded meta-address.
    mapping(address => mapping(uint256 => bytes)) internal _stealthMetaAddresses;

    /// @inheritdoc IStealthRegistry
    function register(uint256 schemeId, bytes calldata stealthMetaAddress) external override {
        _stealthMetaAddresses[msg.sender][schemeId] = stealthMetaAddress;
        emit StealthMetaAddressSet(msg.sender, schemeId, stealthMetaAddress);
    }

    /// @inheritdoc IStealthRegistry
    function stealthMetaAddressOf(address account, uint256 schemeId) external view override returns (bytes memory) {
        return _stealthMetaAddresses[account][schemeId];
    }
}
