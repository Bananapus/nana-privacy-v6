// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IJBPayHook} from "@bananapus/core-v6/src/interfaces/IJBPayHook.sol";
import {JBAfterPayRecordedContext} from "@bananapus/core-v6/src/structs/JBAfterPayRecordedContext.sol";
import {JBTokenAmount} from "@bananapus/core-v6/src/structs/JBTokenAmount.sol";
import {JBMetadataResolver} from "@bananapus/core-v6/src/libraries/JBMetadataResolver.sol";
import {IERC5564Announcer} from "../src/interfaces/IERC5564Announcer.sol";
import {ERC5564Announcer} from "../src/ERC5564Announcer.sol";
import {StealthAnnouncementHook} from "../src/StealthAnnouncementHook.sol";

contract StealthAnnouncementHookTest is Test {
    ERC5564Announcer announcer;
    StealthAnnouncementHook hook;
    address metadataIdTarget = makeAddr("metadataIdTarget");

    function setUp() public {
        announcer = new ERC5564Announcer();
        hook = new StealthAnnouncementHook(IERC5564Announcer(address(announcer)), metadataIdTarget);
    }

    function test_supportsInterface_IJBPayHook() public view {
        assertTrue(hook.supportsInterface(type(IJBPayHook).interfaceId));
    }

    function test_supportsInterface_IERC165() public view {
        assertTrue(hook.supportsInterface(type(IERC165).interfaceId));
    }

    function test_afterPayRecordedWith_emitsAnnouncement() public {
        address stealthAddr = makeAddr("stealth");
        bytes memory ephemeralPubKey = hex"04aabbccdd";
        bytes memory viewTag = hex"01";
        uint256 schemeId = 1;

        // Encode stealth data into payer metadata using JBMetadataResolver format.
        bytes memory stealthPayload = abi.encode(schemeId, ephemeralPubKey, viewTag);
        bytes memory payerMetadata = _encodeMetadata(hook.STEALTH_METADATA_ID(), stealthPayload);

        JBAfterPayRecordedContext memory context = _makePayContext(stealthAddr, payerMetadata);

        vm.expectEmit(true, true, true, true);
        emit IERC5564Announcer.Announcement(schemeId, stealthAddr, address(hook), ephemeralPubKey, viewTag);

        hook.afterPayRecordedWith(context);
    }

    // --- Helpers ---

    function _makePayContext(
        address beneficiary,
        bytes memory payerMetadata
    )
        internal
        pure
        returns (JBAfterPayRecordedContext memory)
    {
        return JBAfterPayRecordedContext({
            payer: address(0), // Not used by hook
            projectId: 1,
            rulesetId: 1,
            amount: JBTokenAmount({token: address(0), value: 1 ether, decimals: 18, currency: 0}),
            forwardedAmount: JBTokenAmount({token: address(0), value: 0, decimals: 18, currency: 0}),
            weight: 0,
            newlyIssuedTokenCount: 0,
            beneficiary: beneficiary,
            hookMetadata: bytes(""),
            payerMetadata: payerMetadata
        });
    }

    /// @dev Encode a single metadata entry using the canonical JBMetadataResolver library.
    function _encodeMetadata(bytes4 id, bytes memory data) internal pure returns (bytes memory) {
        bytes4[] memory ids = new bytes4[](1);
        bytes[] memory datas = new bytes[](1);
        ids[0] = id;
        datas[0] = data; // Already abi.encoded (32-byte padded) by caller.
        return JBMetadataResolver.createMetadata(ids, datas);
    }
}
