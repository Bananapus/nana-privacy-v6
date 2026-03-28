# Juicebox Privacy

## Purpose

Standalone privacy layer for Juicebox V6. Hides payer identity (relay pool), recipient identity (EIP-5564 stealth addresses), and payment amounts (721 tier denominations) without modifying any existing contracts. Three independent layers that can be composed together or used individually.

## Contracts

| Contract | Role |
|----------|------|
| `ERC5564Announcer` | Singleton that emits EIP-5564 `Announcement` events. Stateless -- anyone can call `announce()`. One deployment per chain. |
| `StealthRegistry` | Stores stealth meta-addresses by account and scheme. Accounts register their `(spendingPubKey, viewingPubKey)` pairs so payers can compute stealth addresses via ECDH off-chain. |
| `StealthAnnouncementHook` | `IJBPayHook` that extracts stealth metadata from payer metadata via `JBMetadataResolver` and emits an EIP-5564 announcement. Receives 0 ETH from the terminal -- called purely for the event. |
| `PrivacyDataHookWrapper` | `IJBRulesetDataHook` wrapper. Delegates to an optional inner hook (typically `JB721TiersHook`) and appends `StealthAnnouncementHook` to pay hook specs when stealth metadata is present. Two modes: wrapping a 721 hook (core direct) or standalone (omnichain extra hook). |
| `PaymentRelayPool` | Forwards payments to any `IJBTerminal`, hiding the real payer's address. The terminal sees `msg.sender = PaymentRelayPool`. Also supports atomic announcement via `relayPaymentWithAnnouncement()` for revnets. |

## Key Functions

### ERC5564Announcer

| Function | What it does |
|----------|--------------|
| `announce(schemeId, stealthAddress, ephemeralPubKey, metadata)` | Emits `Announcement(schemeId, stealthAddress, msg.sender, ephemeralPubKey, metadata)`. No access control -- anyone can announce. |

### StealthRegistry

| Function | What it does |
|----------|--------------|
| `register(schemeId, stealthMetaAddress)` | Stores a stealth meta-address for `msg.sender` under the given scheme. Overwrites any existing registration. Emits `StealthMetaAddressSet`. |
| `stealthMetaAddressOf(account, schemeId)` | Returns the registered meta-address, or empty bytes if none. Pure lookup -- no state change. |

### StealthAnnouncementHook

| Function | What it does |
|----------|--------------|
| `afterPayRecordedWith(context)` | Extracts `(schemeId, ephemeralPubKey, viewTag)` from `context.payerMetadata` using `JBMetadataResolver.getDataFor(STEALTH_METADATA_ID, ...)`. Calls `ANNOUNCER.announce()` with the decoded data and `context.beneficiary` as the stealth address. |
| `supportsInterface(interfaceId)` | Returns `true` for `IJBPayHook` and `IERC165`. |

### PrivacyDataHookWrapper

| Function | What it does |
|----------|--------------|
| `beforePayRecordedWith(context)` | Delegates to `INNER_HOOK` (if set) to get weight and hook specs, then checks for stealth metadata via `JBMetadataResolver.getDataFor(PRIVACY_METADATA_ID, ...)`. If present, appends a `JBPayHookSpecification` for `ANNOUNCEMENT_HOOK` with `amount=0`. Returns augmented specs. |
| `beforeCashOutRecordedWith(context)` | Pure delegation to `INNER_HOOK`. If no inner hook, returns context defaults unchanged. |
| `hasMintPermissionFor(projectId, ruleset, addr)` | Delegates to `INNER_HOOK`. Returns `false` if no inner hook. |
| `supportsInterface(interfaceId)` | Returns `true` for `IJBRulesetDataHook` and `IERC165`. Delegates to `INNER_HOOK` for other interface IDs. |

### PaymentRelayPool

| Function | What it does |
|----------|--------------|
| `relayPayment(terminal, projectId, token, amount, beneficiary, minReturnedTokens, memo, metadata)` | Validates `msg.value == amount` for native token payments. Calls `IJBTerminal(terminal).pay{value: msg.value}(...)` with `msg.sender = PaymentRelayPool`. Returns `beneficiaryTokenCount`. |
| `relayPaymentWithAnnouncement(params)` | Same as `relayPayment` but first calls `ANNOUNCER.announce()` with the stealth parameters from the `RelayWithAnnouncementParams` struct. Atomic announce + pay in one transaction. |

## Integration Points

| Dependency | Import | Used For |
|------------|--------|----------|
| `nana-core-v6` | `IJBPayHook`, `JBAfterPayRecordedContext` | StealthAnnouncementHook implements `IJBPayHook` to receive post-payment callbacks |
| `nana-core-v6` | `IJBRulesetDataHook`, `JBBeforePayRecordedContext`, `JBBeforeCashOutRecordedContext` | PrivacyDataHookWrapper implements `IJBRulesetDataHook` for pre-payment and pre-cashout interception |
| `nana-core-v6` | `JBPayHookSpecification`, `JBCashOutHookSpecification` | Hook specification structs returned by data hook |
| `nana-core-v6` | `JBMetadataResolver` | Metadata ID computation (`getId("stealth", target)`) and data extraction (`getDataFor`) |
| `nana-core-v6` | `IJBTerminal` | PaymentRelayPool calls `terminal.pay()` to forward payments |
| `@openzeppelin/contracts` | `IERC165` | ERC-165 interface detection for hooks |

## Key Types

| Struct/Type | Fields | Used In |
|-------------|--------|---------|
| `RelayWithAnnouncementParams` (`src/PaymentRelayPool.sol`) | `terminal`, `projectId`, `token`, `amount`, `beneficiary`, `minReturnedTokens`, `memo`, `metadata`, `schemeId`, `ephemeralPubKey`, `announcementMetadata` | `relayPaymentWithAnnouncement(params)` -- avoids stack-too-deep without via_ir |

## Constants

| Constant | Contract | Value | Purpose |
|----------|----------|-------|---------|
| `NATIVE_TOKEN` | PaymentRelayPool | `0x000...EEEe` | Sentinel address for native ETH payments (matches JBConstants) |
| `ANNOUNCER` | StealthAnnouncementHook, PaymentRelayPool | Immutable | ERC5564Announcer singleton, set at construction |
| `STEALTH_METADATA_ID` | StealthAnnouncementHook | `JBMetadataResolver.getId("stealth", target)` | 4-byte metadata ID for stealth data lookups |
| `PRIVACY_METADATA_ID` | PrivacyDataHookWrapper | `JBMetadataResolver.getId("stealth", target)` | Same ID -- all contracts must agree on the same `metadataIdTarget` |
| `INNER_HOOK` | PrivacyDataHookWrapper | Immutable | Inner data hook to delegate to, or `address(0)` for standalone |
| `ANNOUNCEMENT_HOOK` | PrivacyDataHookWrapper | Immutable | StealthAnnouncementHook appended to pay specs |

## Events

| Event | Contract | When |
|-------|----------|------|
| `Announcement(schemeId*, stealthAddress*, caller*, ephemeralPubKey, metadata)` | ERC5564Announcer | `announce()` is called. `*` = indexed. |
| `StealthMetaAddressSet(account*, schemeId*, stealthMetaAddress)` | StealthRegistry | `register()` is called. `*` = indexed. |

## Errors

| Error | Contract | Trigger |
|-------|----------|---------|
| `PaymentRelayPool_MsgValueMismatch()` | PaymentRelayPool | `msg.value != amount` for native token payments in `relayPayment()` or `relayPaymentWithAnnouncement()` |

## Metadata Encoding

Stealth data is encoded in payer metadata using `JBMetadataResolver`:

```solidity
// All contracts must use the same metadataIdTarget (typically the announcer address).
bytes4 stealthId = JBMetadataResolver.getId("stealth", metadataIdTarget);

// Stealth payload: (schemeId, ephemeralPubKey, viewTag).
bytes memory stealthPayload = abi.encode(schemeId, ephemeralPubKey, viewTag);

// Pack into JBMetadataResolver format.
bytes4[] memory ids = new bytes4[](1);
bytes[] memory datas = new bytes[](1);
ids[0] = stealthId;
datas[0] = stealthPayload;
bytes memory metadata = JBMetadataResolver.createMetadata(ids, datas);
```

**Critical:** The `metadataIdTarget` address must be identical across all contracts that read or write stealth metadata. The deployment script uses `address(announcer)` as the canonical target.

## Gotchas

1. **metadataIdTarget must match everywhere.** `StealthAnnouncementHook`, `PrivacyDataHookWrapper`, and client-side metadata encoding must all use the same `metadataIdTarget` address to compute the same 4-byte metadata ID. Mismatch = stealth data silently ignored.

2. **PrivacyDataHookWrapper with `INNER_HOOK = address(0)` still works.** Standalone mode returns `context.weight` unchanged and an empty hook specs array. Only the announcement hook is appended when stealth metadata is present.

3. **StealthAnnouncementHook receives 0 ETH.** The `JBPayHookSpecification` sets `amount = 0`. The hook is called for the event, not for funds. The `afterPayRecordedWith` function is `payable` (required by the interface) but should never receive value.

4. **PaymentRelayPool does NOT support ERC-20 privacy payments well.** For ERC-20 tokens, the terminal pulls tokens from `msg.sender` (the relay pool) via Permit2. Tokens must be in the pool's balance before calling `relayPayment()`, creating an on-chain trace. **Use native ETH for privacy.**

5. **Metadata makes privacy payments distinguishable.** The `Pay` event includes payer metadata containing stealth data. An observer can distinguish privacy payments from regular payments, reducing the effective anonymity set to privacy-mode payments only.

6. **`relayPaymentWithAnnouncement` announces BEFORE paying.** The announcement event is emitted first, then the terminal payment executes. If the payment reverts, the announcement is also reverted (atomic transaction).

7. **StealthRegistry is permissionless.** Anyone can register a meta-address for their own account. Overwriting is allowed -- `register()` replaces the previous value. There is no access control beyond `msg.sender` scoping.

8. **ERC5564Announcer is fully stateless.** No storage, no access control. It only emits events. Can be called by anyone for any purpose -- not Juicebox-specific.

9. **Privacy tier design pattern is configuration-only.** No new contracts enforce denominations. Projects configure 721 tiers with fixed prices, unlimited supply, no discounts, and no reserves. The anonymity set equals the number of mints per tier.

10. **Cash outs via stealth addresses require ERC-2771 meta-transactions.** The stealth address holder signs a meta-tx, a trusted forwarder relays it, and `_msgSender()` extracts the stealth address for permission checks. This uses existing `JBMultiTerminal` ERC-2771 support -- no new contracts needed.

11. **`beforeCashOutRecordedWith` does NOT add privacy features.** The wrapper passes cash outs through to the inner hook unchanged. Privacy on the cash out side is handled via meta-transactions and fresh recipient addresses, not via this wrapper.

12. **Scheme ID 1 = secp256k1 per EIP-5564.** This is the standard scheme for Ethereum stealth addresses. The contracts accept any `uint256` scheme ID but the ecosystem convention is scheme 1.
