// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {IERC5564Announcer} from "../src/interfaces/IERC5564Announcer.sol";
import {ERC5564Announcer} from "../src/ERC5564Announcer.sol";

contract ERC5564AnnouncerTest is Test {
    ERC5564Announcer announcer;

    function setUp() public {
        announcer = new ERC5564Announcer();
    }

    function test_announce_emitsEvent() public {
        uint256 schemeId = 1;
        address stealthAddress = makeAddr("stealth");
        bytes memory ephemeralPubKey = hex"abcdef";
        bytes memory metadata = hex"01"; // 1-byte view tag

        vm.expectEmit(true, true, true, true);
        emit IERC5564Announcer.Announcement(schemeId, stealthAddress, address(this), ephemeralPubKey, metadata);

        announcer.announce(schemeId, stealthAddress, ephemeralPubKey, metadata);
    }

    function test_announce_anyoneCanCall() public {
        address caller = makeAddr("randomCaller");
        vm.prank(caller);

        vm.expectEmit(true, true, true, true);
        emit IERC5564Announcer.Announcement(1, makeAddr("stealth"), caller, hex"ab", hex"01");

        announcer.announce(1, makeAddr("stealth"), hex"ab", hex"01");
    }
}
