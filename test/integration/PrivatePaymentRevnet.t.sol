// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {ERC5564Announcer} from "../../src/ERC5564Announcer.sol";
import {PaymentRelayPool} from "../../src/PaymentRelayPool.sol";
import {IERC5564Announcer} from "../../src/interfaces/IERC5564Announcer.sol";

/// @notice End-to-end test: private payment to a revnet via PaymentRelayPool.
/// @dev REVDeployer has no data hook extension point, so announcements come from the relay pool.
contract PrivatePaymentRevnetTest is Test {
    ERC5564Announcer announcer;
    PaymentRelayPool relayPool;

    function setUp() public {
        announcer = new ERC5564Announcer();
        relayPool = new PaymentRelayPool(IERC5564Announcer(address(announcer)));

        // TODO: Fork or deploy a revnet with privacy tiers.
        // 1. Deploy revnet via REVDeployer with 721 hook
        // 2. Split operator adds privacy tiers (0.1, 1, 10 ETH) via adjustTiers()
        // 3. Set preventOverspending = true in hook flags
    }

    function test_revnet_privatePayment_viaRelayPool() public {
        // 1. Payer calls relayPool.relayPaymentWithAnnouncement() with:
        //    - Stealth address as beneficiary
        //    - Privacy tier IDs in metadata
        //    - Ephemeral public key + view tag for announcement
        // 2. Verify Pay event payer = relayPool
        // 3. Verify NFT minted to stealth address
        // 4. Verify Announcement event emitted by relayPool (via announcer)
    }

    function test_revnet_splitOperator_canAddPrivacyTiers() public {
        // 1. Verify split operator has ADJUST_721_TIERS permission
        // 2. Add privacy-denomination tiers
        // 3. Verify tiers are mintable
    }

    function test_revnet_forcePrivacyFalse_dontAddTiers() public {
        // 1. Deploy revnet with preventSplitOperatorAdjustingTiers = true
        // 2. Verify split operator CANNOT add privacy tiers
        // 3. This effectively forces privacy: false
    }
}
