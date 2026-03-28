// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC5564Announcer} from "./interfaces/IERC5564Announcer.sol";

/// @notice Singleton contract that emits EIP-5564 stealth address announcements.
/// @dev Anyone can call `announce`. The contract holds no state — it only emits events.
contract ERC5564Announcer is IERC5564Announcer {
    /// @inheritdoc IERC5564Announcer
    function announce(
        uint256 schemeId,
        address stealthAddress,
        bytes calldata ephemeralPubKey,
        bytes calldata metadata
    )
        external
        override
    {
        emit Announcement(schemeId, stealthAddress, msg.sender, ephemeralPubKey, metadata);
    }
}
