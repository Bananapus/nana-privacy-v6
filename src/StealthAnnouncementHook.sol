// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IJBPayHook} from "@bananapus/core-v6/src/interfaces/IJBPayHook.sol";
import {JBAfterPayRecordedContext} from "@bananapus/core-v6/src/structs/JBAfterPayRecordedContext.sol";
import {JBMetadataResolver} from "@bananapus/core-v6/src/libraries/JBMetadataResolver.sol";
import {IERC5564Announcer} from "./interfaces/IERC5564Announcer.sol";

/// @notice Pay hook that emits an EIP-5564 stealth address announcement after a payment is recorded.
/// @dev Returns no funds — the terminal forwards 0 ETH to this hook. It only reads payer metadata
/// and emits an event via the ERC5564Announcer singleton.
contract StealthAnnouncementHook is IJBPayHook {
    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    /// @notice The EIP-5564 announcer contract.
    IERC5564Announcer public immutable ANNOUNCER;

    /// @notice The 4-byte metadata ID for stealth data lookups.
    bytes4 public immutable STEALTH_METADATA_ID;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param announcer The ERC5564Announcer singleton.
    /// @param metadataIdTarget The address used to compute the metadata ID (shared with data hook wrapper / relay
    /// pool).
    constructor(IERC5564Announcer announcer, address metadataIdTarget) {
        ANNOUNCER = announcer;
        STEALTH_METADATA_ID = JBMetadataResolver.getId("stealth", metadataIdTarget);
    }

    //*********************************************************************//
    // ----------------------- external views ---------------------------- //
    //*********************************************************************//

    /// @notice ERC165 interface support.
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IJBPayHook).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Called by the terminal after a payment is recorded. Emits the EIP-5564 announcement if stealth
    /// metadata is present. No-ops gracefully for non-privacy payments.
    /// @param context The after-pay context containing payer metadata with stealth data.
    function afterPayRecordedWith(JBAfterPayRecordedContext calldata context) external payable override {
        // Extract stealth data from payer metadata. Returns (false, "") if not present.
        (bool found, bytes memory stealthData) =
            JBMetadataResolver.getDataFor({id: STEALTH_METADATA_ID, metadata: context.payerMetadata});

        // Not a privacy payment — nothing to announce.
        if (!found) return;

        // Decode: (schemeId, ephemeralPubKey, viewTag).
        (uint256 schemeId, bytes memory ephemeralPubKey, bytes memory viewTag) =
            abi.decode(stealthData, (uint256, bytes, bytes));

        // Emit EIP-5564 announcement so the recipient can scan for their payment.
        ANNOUNCER.announce({
            schemeId: schemeId, stealthAddress: context.beneficiary, ephemeralPubKey: ephemeralPubKey, metadata: viewTag
        });
    }
}
