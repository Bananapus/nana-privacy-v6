// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import {IJBRulesetDataHook} from "@bananapus/core-v6/src/interfaces/IJBRulesetDataHook.sol";
import {ERC5564Announcer} from "../src/ERC5564Announcer.sol";
import {StealthRegistry} from "../src/StealthRegistry.sol";
import {StealthAnnouncementHook} from "../src/StealthAnnouncementHook.sol";
import {PrivacyDataHookWrapper} from "../src/PrivacyDataHookWrapper.sol";
import {PaymentRelayPool} from "../src/PaymentRelayPool.sol";
import {IERC5564Announcer} from "../src/interfaces/IERC5564Announcer.sol";

/// @notice Deploy privacy singleton contracts.
/// @dev IMPORTANT: All contracts that read/write stealth metadata must agree on the same
/// `metadataIdTarget`. This script uses `address(announcer)` as the canonical target.
/// Per-project PrivacyDataHookWrapper instances wrapping a 721 hook must use the same value.
contract DeployPrivacy is Script {
    function run() public {
        vm.startBroadcast();

        // 1. Singletons (one per chain).
        ERC5564Announcer announcer = new ERC5564Announcer();
        StealthRegistry registry = new StealthRegistry();
        PaymentRelayPool relayPool = new PaymentRelayPool(IERC5564Announcer(address(announcer)));

        // 2. Canonical metadataIdTarget = address(announcer).
        //    All hooks and wrappers must use this same target for metadata ID consistency.
        address metadataIdTarget = address(announcer);

        StealthAnnouncementHook announcementHook =
            new StealthAnnouncementHook(IERC5564Announcer(address(announcer)), metadataIdTarget);

        // 3. Canonical standalone wrapper (no inner hook) for omnichain deployer extra hook slot.
        PrivacyDataHookWrapper standaloneWrapper =
            new PrivacyDataHookWrapper(IJBRulesetDataHook(address(0)), announcementHook, metadataIdTarget);

        vm.stopBroadcast();

        // Log deployed addresses.
        console.log("ERC5564Announcer:", address(announcer));
        console.log("StealthRegistry:", address(registry));
        console.log("PaymentRelayPool:", address(relayPool));
        console.log("StealthAnnouncementHook:", address(announcementHook));
        console.log("PrivacyDataHookWrapper (standalone):", address(standaloneWrapper));
        console.log("metadataIdTarget:", metadataIdTarget);
    }
}
