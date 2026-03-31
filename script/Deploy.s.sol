// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {ERC5564Announcer} from "../src/ERC5564Announcer.sol";
import {StealthRegistry} from "../src/StealthRegistry.sol";
import {StealthAnnouncementHook} from "../src/StealthAnnouncementHook.sol";
import {IERC5564Announcer} from "../src/interfaces/IERC5564Announcer.sol";

/// @notice Deploy privacy singleton contracts.
/// @dev IMPORTANT: All contracts that read/write stealth metadata must agree on the same
/// `metadataIdTarget`. This script uses `address(announcer)` as the canonical target.
/// REVDeployer and JBOmnichainDeployer must use the same value when integrating StealthAnnouncementHook.
contract DeployPrivacy is Script {
    function run() public {
        vm.startBroadcast();

        // 1. Singletons (one per chain).
        ERC5564Announcer announcer = new ERC5564Announcer();
        StealthRegistry registry = new StealthRegistry();

        // 2. Canonical metadataIdTarget = address(announcer).
        //    All hooks and deployers must use this same target for metadata ID consistency.
        address metadataIdTarget = address(announcer);

        StealthAnnouncementHook announcementHook =
            new StealthAnnouncementHook(IERC5564Announcer(address(announcer)), metadataIdTarget);

        vm.stopBroadcast();

        // Log deployed addresses.
        console.log("ERC5564Announcer:", address(announcer));
        console.log("StealthRegistry:", address(registry));
        console.log("StealthAnnouncementHook:", address(announcementHook));
        console.log("metadataIdTarget:", metadataIdTarget);
    }
}
