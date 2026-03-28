// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IJBRulesetDataHook} from "@bananapus/core-v6/src/interfaces/IJBRulesetDataHook.sol";
import {IJBPayHook} from "@bananapus/core-v6/src/interfaces/IJBPayHook.sol";
import {JBBeforePayRecordedContext} from "@bananapus/core-v6/src/structs/JBBeforePayRecordedContext.sol";
import {JBBeforeCashOutRecordedContext} from "@bananapus/core-v6/src/structs/JBBeforeCashOutRecordedContext.sol";
import {JBPayHookSpecification} from "@bananapus/core-v6/src/structs/JBPayHookSpecification.sol";
import {JBCashOutHookSpecification} from "@bananapus/core-v6/src/structs/JBCashOutHookSpecification.sol";
import {JBTokenAmount} from "@bananapus/core-v6/src/structs/JBTokenAmount.sol";
import {JBRuleset} from "@bananapus/core-v6/src/structs/JBRuleset.sol";
import {JBMetadataResolver} from "@bananapus/core-v6/src/libraries/JBMetadataResolver.sol";
import {ERC5564Announcer} from "../src/ERC5564Announcer.sol";
import {StealthAnnouncementHook} from "../src/StealthAnnouncementHook.sol";
import {PrivacyDataHookWrapper} from "../src/PrivacyDataHookWrapper.sol";
import {IERC5564Announcer} from "../src/interfaces/IERC5564Announcer.sol";

contract PrivacyDataHookWrapperTest is Test {
    ERC5564Announcer announcer;
    StealthAnnouncementHook announcementHook;
    PrivacyDataHookWrapper wrapper;
    PrivacyDataHookWrapper wrapperNoInner; // For omnichain / standalone usage
    address metadataIdTarget;

    function setUp() public {
        announcer = new ERC5564Announcer();
        // Use a deterministic metadataIdTarget for consistent metadata ID computation.
        metadataIdTarget = makeAddr("privacyTarget");
        announcementHook = new StealthAnnouncementHook(IERC5564Announcer(address(announcer)), metadataIdTarget);

        // Mock inner hook that returns weight=100 and one spec.
        MockInnerHook innerHook = new MockInnerHook();

        wrapper = new PrivacyDataHookWrapper(IJBRulesetDataHook(address(innerHook)), announcementHook, metadataIdTarget);

        wrapperNoInner = new PrivacyDataHookWrapper(IJBRulesetDataHook(address(0)), announcementHook, metadataIdTarget);
    }

    function test_supportsInterface() public view {
        assertTrue(wrapper.supportsInterface(type(IJBRulesetDataHook).interfaceId));
        assertTrue(wrapper.supportsInterface(type(IERC165).interfaceId));
    }

    function test_beforePay_withoutPrivacyMetadata_delegatesOnly() public {
        JBBeforePayRecordedContext memory context = _makeBeforePayContext(bytes(""));

        (uint256 weight, JBPayHookSpecification[] memory specs) = wrapper.beforePayRecordedWith(context);

        // Inner hook returns weight=100 and 1 spec.
        assertEq(weight, 100);
        assertEq(specs.length, 1);
    }

    function test_beforePay_withPrivacyMetadata_appendsAnnouncementHook() public {
        bytes memory stealthPayload = abi.encode(uint256(1), hex"04aabb", hex"01");
        bytes memory payerMetadata = _encodeMetadata(wrapper.PRIVACY_METADATA_ID(), stealthPayload);

        JBBeforePayRecordedContext memory context = _makeBeforePayContext(payerMetadata);

        (uint256 weight, JBPayHookSpecification[] memory specs) = wrapper.beforePayRecordedWith(context);

        // Inner hook's 1 spec + announcement hook = 2 specs.
        assertEq(weight, 100);
        assertEq(specs.length, 2);
        assertEq(address(specs[1].hook), address(announcementHook));
        assertEq(specs[1].amount, 0); // Announcement hook receives no funds.
        assertFalse(specs[1].noop);
    }

    function test_beforePay_noInnerHook_withPrivacyMetadata() public {
        bytes memory stealthPayload = abi.encode(uint256(1), hex"04aabb", hex"01");
        bytes memory payerMetadata = _encodeMetadata(wrapperNoInner.PRIVACY_METADATA_ID(), stealthPayload);

        JBBeforePayRecordedContext memory context = _makeBeforePayContext(payerMetadata);

        (, JBPayHookSpecification[] memory specs) = wrapperNoInner.beforePayRecordedWith(context);

        // No inner hook specs, only announcement hook = 1 spec.
        assertEq(specs.length, 1);
        assertEq(address(specs[0].hook), address(announcementHook));
    }

    function test_beforePay_noInnerHook_withoutPrivacyMetadata() public {
        JBBeforePayRecordedContext memory context = _makeBeforePayContext(bytes(""));

        (, JBPayHookSpecification[] memory specs) = wrapperNoInner.beforePayRecordedWith(context);

        // No inner hook, no privacy metadata = 0 specs.
        assertEq(specs.length, 0);
    }

    function test_beforeCashOut_delegatesToInnerHook() public {
        JBBeforeCashOutRecordedContext memory context; // Zero-initialized context.
        (uint256 taxRate,,,) = wrapper.beforeCashOutRecordedWith(context);
        assertEq(taxRate, 500); // MockInnerHook returns 500.
    }

    // --- Helpers ---

    function _makeBeforePayContext(bytes memory metadata) internal pure returns (JBBeforePayRecordedContext memory) {
        return JBBeforePayRecordedContext({
            terminal: address(0),
            payer: address(0),
            amount: JBTokenAmount({token: address(0), decimals: 18, currency: 0, value: 1 ether}),
            projectId: 1,
            rulesetId: 1,
            beneficiary: address(0xBEEF),
            weight: 100,
            reservedPercent: 0,
            metadata: metadata
        });
    }

    /// @dev Encode a single metadata entry using the canonical JBMetadataResolver library.
    function _encodeMetadata(bytes4 id, bytes memory data) internal pure returns (bytes memory) {
        bytes4[] memory ids = new bytes4[](1);
        bytes[] memory datas = new bytes[](1);
        ids[0] = id;
        datas[0] = data;
        return JBMetadataResolver.createMetadata(ids, datas);
    }
}

/// @dev Mock inner data hook that returns weight=100 and a single pay hook spec.
contract MockInnerHook is IJBRulesetDataHook {
    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }

    function beforePayRecordedWith(JBBeforePayRecordedContext calldata)
        external
        pure
        returns (uint256 weight, JBPayHookSpecification[] memory specs)
    {
        weight = 100;
        specs = new JBPayHookSpecification[](1);
        specs[0] = JBPayHookSpecification({
            hook: IJBPayHook(address(1)), // Dummy address
            noop: false,
            amount: 0.5 ether,
            metadata: bytes("")
        });
    }

    function beforeCashOutRecordedWith(JBBeforeCashOutRecordedContext calldata)
        external
        pure
        returns (uint256, uint256, uint256, JBCashOutHookSpecification[] memory)
    {
        return (500, 0, 0, new JBCashOutHookSpecification[](0));
    }

    function hasMintPermissionFor(uint256, JBRuleset memory, address) external pure returns (bool) {
        return false;
    }
}
