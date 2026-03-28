// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice EIP-5564 stealth address announcement interface.
interface IERC5564Announcer {
    /// @notice Emitted when a stealth address payment is announced.
    /// @param schemeId The stealth address scheme (1 = secp256k1 per EIP-5564).
    /// @param stealthAddress The generated stealth address.
    /// @param caller The address that called announce.
    /// @param ephemeralPubKey The ephemeral public key used to derive the stealth address.
    /// @param metadata View tag and any additional data for fast scanning.
    event Announcement(
        uint256 indexed schemeId,
        address indexed stealthAddress,
        address indexed caller,
        bytes ephemeralPubKey,
        bytes metadata
    );

    /// @notice Announce a stealth address payment.
    /// @param schemeId The stealth address scheme.
    /// @param stealthAddress The stealth address receiving the payment.
    /// @param ephemeralPubKey The ephemeral public key for the recipient to derive the private key.
    /// @param metadata View tag and any additional data.
    function announce(
        uint256 schemeId,
        address stealthAddress,
        bytes calldata ephemeralPubKey,
        bytes calldata metadata
    )
        external;
}
