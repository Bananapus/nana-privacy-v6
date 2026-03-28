// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {ERC5564Announcer} from "../../src/ERC5564Announcer.sol";
import {StealthAnnouncementHook} from "../../src/StealthAnnouncementHook.sol";
import {PrivacyDataHookWrapper} from "../../src/PrivacyDataHookWrapper.sol";
import {PaymentRelayPool} from "../../src/PaymentRelayPool.sol";
import {IERC5564Announcer} from "../../src/interfaces/IERC5564Announcer.sol";
import {IJBRulesetDataHook} from "@bananapus/core-v6/src/interfaces/IJBRulesetDataHook.sol";

/// @notice End-to-end test: private payment to an omnichain project.
/// @dev The PrivacyDataHookWrapper is the "extra data hook" in JBOmnichainDeployer.
contract PrivatePaymentOmnichainTest is Test {
    ERC5564Announcer announcer;
    StealthAnnouncementHook announcementHook;
    PrivacyDataHookWrapper privacyWrapper;
    PaymentRelayPool relayPool;
    address metadataIdTarget;

    function setUp() public {
        announcer = new ERC5564Announcer();
        metadataIdTarget = makeAddr("privacyTarget");
        announcementHook = new StealthAnnouncementHook(IERC5564Announcer(address(announcer)), metadataIdTarget);
        relayPool = new PaymentRelayPool(IERC5564Announcer(address(announcer)));

        // Standalone wrapper (no inner hook) — acts as extra data hook.
        privacyWrapper = new PrivacyDataHookWrapper(IJBRulesetDataHook(address(0)), announcementHook, metadataIdTarget);

        // TODO: Deploy project via JBOmnichainDeployer with:
        //   - rulesetConfigurations[0].metadata.dataHook = address(privacyWrapper)
        //   - rulesetConfigurations[0].metadata.useDataHookForPay = true
        //   - 721 tiers including privacy denominations
    }

    function test_omnichain_privatePayment() public {
        // 1. Payer calls relayPool.relayPaymentWithAnnouncement()
        // 2. Terminal calls OmnichainDeployer.beforePayRecordedWith()
        //    -> OmnichainDeployer delegates to 721 hook + privacyWrapper
        //    -> privacyWrapper returns StealthAnnouncementHook in specs
        // 3. Terminal fulfills hooks: 721 mints NFT, announcement hook emits event
        // 4. Verify Pay event payer = relayPool
        // 5. Verify Announcement event emitted
    }
}
