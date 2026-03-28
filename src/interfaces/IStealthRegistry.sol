// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Registry for EIP-5564 stealth meta-addresses.
interface IStealthRegistry {
    /// @notice Emitted when an account registers or updates a stealth meta-address.
    event StealthMetaAddressSet(address indexed account, uint256 indexed schemeId, bytes stealthMetaAddress);

    /// @notice Register a stealth meta-address for `msg.sender`.
    /// @param schemeId The stealth scheme (1 = secp256k1 with view tags per EIP-5564).
    /// @param stealthMetaAddress Encoded (spendingPubKey ++ viewingPubKey).
    function register(uint256 schemeId, bytes calldata stealthMetaAddress) external;

    /// @notice Look up a stealth meta-address.
    /// @param account The account to look up.
    /// @param schemeId The stealth scheme.
    /// @return stealthMetaAddress The registered meta-address, or empty bytes if none.
    function stealthMetaAddressOf(
        address account,
        uint256 schemeId
    )
        external
        view
        returns (bytes memory stealthMetaAddress);
}
