// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IJBRulesetDataHook} from "@bananapus/core-v6/src/interfaces/IJBRulesetDataHook.sol";
import {JBBeforePayRecordedContext} from "@bananapus/core-v6/src/structs/JBBeforePayRecordedContext.sol";
import {JBBeforeCashOutRecordedContext} from "@bananapus/core-v6/src/structs/JBBeforeCashOutRecordedContext.sol";
import {JBCashOutHookSpecification} from "@bananapus/core-v6/src/structs/JBCashOutHookSpecification.sol";
import {JBPayHookSpecification} from "@bananapus/core-v6/src/structs/JBPayHookSpecification.sol";
import {JBRuleset} from "@bananapus/core-v6/src/structs/JBRuleset.sol";
import {JBMetadataResolver} from "@bananapus/core-v6/src/libraries/JBMetadataResolver.sol";
import {StealthAnnouncementHook} from "./StealthAnnouncementHook.sol";

/// @notice Data hook wrapper that delegates to an optional inner hook and appends the
/// StealthAnnouncementHook when stealth metadata is present in the payer's metadata.
///
/// @dev Two usage patterns:
/// 1. Core direct: `PrivacyDataHookWrapper(innerHook=JB721TiersHook)` — set as `metadata.dataHook`.
/// 2. Omnichain extra hook: `PrivacyDataHookWrapper(innerHook=address(0))` — passed as extra data hook
///    via `rulesetConfigurations[i].metadata.dataHook` before calling the omnichain deployer.
contract PrivacyDataHookWrapper is IJBRulesetDataHook {
    /// @notice The inner data hook to delegate to, or address(0) for standalone operation.
    IJBRulesetDataHook public immutable INNER_HOOK;

    /// @notice The stealth announcement hook appended to pay specs when privacy metadata is present.
    StealthAnnouncementHook public immutable ANNOUNCEMENT_HOOK;

    /// @notice 4-byte metadata ID for privacy instructions.
    bytes4 public immutable PRIVACY_METADATA_ID;

    constructor(IJBRulesetDataHook innerHook, StealthAnnouncementHook announcementHook, address metadataIdTarget) {
        INNER_HOOK = innerHook;
        ANNOUNCEMENT_HOOK = announcementHook;
        PRIVACY_METADATA_ID = JBMetadataResolver.getId("stealth", metadataIdTarget);
    }

    /// @notice ERC165 interface support.
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        if (interfaceId == type(IJBRulesetDataHook).interfaceId || interfaceId == type(IERC165).interfaceId) {
            return true;
        }
        if (address(INNER_HOOK) != address(0)) return INNER_HOOK.supportsInterface(interfaceId);
        return false;
    }

    /// @notice Delegates to the inner hook, then appends the announcement hook if stealth metadata is present.
    function beforePayRecordedWith(JBBeforePayRecordedContext calldata context)
        external
        view
        override
        returns (uint256 weight, JBPayHookSpecification[] memory hookSpecifications)
    {
        // Delegate to inner hook if present.
        if (address(INNER_HOOK) != address(0)) {
            (weight, hookSpecifications) = INNER_HOOK.beforePayRecordedWith(context);
        } else {
            weight = context.weight;
            hookSpecifications = new JBPayHookSpecification[](0);
        }

        // Check for stealth privacy metadata.
        (bool hasPrivacy,) = JBMetadataResolver.getDataFor({id: PRIVACY_METADATA_ID, metadata: context.metadata});

        // If present, append the announcement hook.
        if (hasPrivacy) {
            JBPayHookSpecification[] memory augmented = new JBPayHookSpecification[](hookSpecifications.length + 1);

            for (uint256 i; i < hookSpecifications.length; i++) {
                augmented[i] = hookSpecifications[i];
            }

            augmented[hookSpecifications.length] =
                JBPayHookSpecification({hook: ANNOUNCEMENT_HOOK, noop: false, amount: 0, metadata: bytes("")});

            hookSpecifications = augmented;
        }

        return (weight, hookSpecifications);
    }

    /// @notice Pure delegation to inner hook for cash outs.
    function beforeCashOutRecordedWith(JBBeforeCashOutRecordedContext calldata context)
        external
        view
        override
        returns (
            uint256 cashOutTaxRate,
            uint256 cashOutCount,
            uint256 totalSupply,
            JBCashOutHookSpecification[] memory hookSpecifications
        )
    {
        if (address(INNER_HOOK) != address(0)) {
            return INNER_HOOK.beforeCashOutRecordedWith(context);
        }
        return (context.cashOutTaxRate, context.cashOutCount, context.totalSupply, hookSpecifications);
    }

    /// @notice Delegates mint permission check to inner hook.
    function hasMintPermissionFor(
        uint256 projectId,
        JBRuleset memory ruleset,
        address addr
    )
        external
        view
        override
        returns (bool)
    {
        if (address(INNER_HOOK) != address(0)) {
            return INNER_HOOK.hasMintPermissionFor(projectId, ruleset, addr);
        }
        return false;
    }
}
