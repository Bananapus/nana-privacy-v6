// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {IERC5564Announcer} from "../src/interfaces/IERC5564Announcer.sol";
import {ERC5564Announcer} from "../src/ERC5564Announcer.sol";
import {PaymentRelayPool, RelayWithAnnouncementParams} from "../src/PaymentRelayPool.sol";

/// @dev Mock terminal that records pay() calls.
contract MockTerminal {
    address public lastMsgSender;
    uint256 public lastMsgValue;
    address public lastBeneficiary;
    uint256 public lastProjectId;

    function pay(
        uint256 projectId,
        address,
        uint256,
        address beneficiary,
        uint256,
        string calldata,
        bytes calldata
    )
        external
        payable
        returns (uint256)
    {
        lastMsgSender = msg.sender;
        lastMsgValue = msg.value;
        lastBeneficiary = beneficiary;
        lastProjectId = projectId;
        return 1;
    }
}

contract PaymentRelayPoolTest is Test {
    ERC5564Announcer announcer;
    PaymentRelayPool pool;
    MockTerminal terminal;

    address constant NATIVE_TOKEN = address(0x000000000000000000000000000000000000EEEe);

    function setUp() public {
        announcer = new ERC5564Announcer();
        pool = new PaymentRelayPool(IERC5564Announcer(address(announcer)));
        terminal = new MockTerminal();
    }

    function test_relayPayment_nativeToken_forwardsCorrectly() public {
        address stealth = makeAddr("stealth");

        pool.relayPayment{value: 1 ether}({
            terminal: address(terminal),
            projectId: 1,
            token: NATIVE_TOKEN,
            amount: 1 ether,
            beneficiary: stealth,
            minReturnedTokens: 0,
            memo: "",
            metadata: bytes("")
        });

        assertEq(terminal.lastMsgSender(), address(pool)); // Pool is the payer!
        assertEq(terminal.lastMsgValue(), 1 ether);
        assertEq(terminal.lastBeneficiary(), stealth);
    }

    function test_relayPayment_nativeToken_revertsMsgValueMismatch() public {
        vm.expectRevert(PaymentRelayPool.PaymentRelayPool_MsgValueMismatch.selector);
        pool.relayPayment{value: 0.5 ether}({
            terminal: address(terminal),
            projectId: 1,
            token: NATIVE_TOKEN,
            amount: 1 ether,
            beneficiary: makeAddr("stealth"),
            minReturnedTokens: 0,
            memo: "",
            metadata: bytes("")
        });
    }

    function test_relayPaymentWithAnnouncement_emitsAndPays() public {
        address stealth = makeAddr("stealth");
        bytes memory ephemeralPubKey = hex"04aabb";
        bytes memory viewTag = hex"01";

        vm.expectEmit(true, true, true, true);
        emit IERC5564Announcer.Announcement(1, stealth, address(pool), ephemeralPubKey, viewTag);

        pool.relayPaymentWithAnnouncement{value: 1 ether}(
            RelayWithAnnouncementParams({
                terminal: address(terminal),
                projectId: 1,
                token: NATIVE_TOKEN,
                amount: 1 ether,
                beneficiary: stealth,
                minReturnedTokens: 0,
                memo: "",
                metadata: bytes(""),
                schemeId: 1,
                ephemeralPubKey: ephemeralPubKey,
                announcementMetadata: viewTag
            })
        );

        // Also verify the payment went through.
        assertEq(terminal.lastMsgSender(), address(pool));
        assertEq(terminal.lastBeneficiary(), stealth);
    }

    function test_relayPayment_hidesRealPayer() public {
        address realPayer = makeAddr("realPayer");
        vm.deal(realPayer, 10 ether);

        vm.prank(realPayer);
        pool.relayPayment{value: 1 ether}({
            terminal: address(terminal),
            projectId: 1,
            token: NATIVE_TOKEN,
            amount: 1 ether,
            beneficiary: makeAddr("stealth"),
            minReturnedTokens: 0,
            memo: "",
            metadata: bytes("")
        });

        // The terminal sees the pool as the payer, NOT realPayer.
        assertEq(terminal.lastMsgSender(), address(pool));
        assertTrue(terminal.lastMsgSender() != realPayer);
    }
}
