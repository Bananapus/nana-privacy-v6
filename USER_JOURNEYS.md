# User Journeys

Step-by-step flows for every major user interaction with the Juicebox V6 privacy system.

---

## 1. Full Private Payment (Relay + Stealth + Announcement)

A payer contributes to a project with maximum privacy: real payer hidden, recipient hidden behind a stealth address, and the contribution uses a fixed-denomination privacy tier.

**Entry point**: `PaymentRelayPool.relayPaymentWithAnnouncement(RelayWithAnnouncementParams calldata params)`

**Who can call**: Anyone. No access control.

**Prerequisites**:
- Recipient has registered a stealth meta-address via `StealthRegistry.register()`
- Project has privacy tiers configured (fixed-price 721 tiers with unlimited supply)
- Payer has computed a stealth address + ephemeral keypair off-chain (EIP-5564 ECDH)

**Parameters** (`RelayWithAnnouncementParams`):

| Field | Type | Description |
|-------|------|-------------|
| `terminal` | `address` | The `JBMultiTerminal` to pay |
| `projectId` | `uint256` | The project to contribute to |
| `token` | `address` | Payment token (`NATIVE_TOKEN` for ETH) |
| `amount` | `uint256` | Payment amount in wei |
| `beneficiary` | `address` | The stealth address (receives NFT) |
| `minReturnedTokens` | `uint256` | Minimum project tokens to receive |
| `memo` | `string` | Optional memo |
| `metadata` | `bytes` | JBMetadataResolver-encoded tier IDs + stealth data |
| `schemeId` | `uint256` | Stealth scheme (1 = secp256k1) |
| `ephemeralPubKey` | `bytes` | Ephemeral public key for recipient scanning |
| `announcementMetadata` | `bytes` | View tag + additional announcement data |

**Steps:**

1. **Off-chain**: Payer looks up recipient's stealth meta-address from `StealthRegistry.stealthMetaAddressOf(recipient, 1)`.

2. **Off-chain**: Payer computes stealth address + ephemeral keypair via ECDH (EIP-5564 scheme 1).

3. **Off-chain**: Payer selects privacy tier(s) matching the desired contribution (e.g., 3 × Tier 3 = 3 ETH).

4. **Off-chain**: Payer encodes tier IDs + stealth metadata using `JBMetadataResolver.createMetadata(ids, datas)`.

5. Payer calls `PaymentRelayPool.relayPaymentWithAnnouncement{value: 3 ether}(params)`.

6. Relay pool validates `msg.value == params.amount` (reverts with `PaymentRelayPool_MsgValueMismatch` if not).

7. Relay pool calls `ANNOUNCER.announce(schemeId, stealthAddress, ephemeralPubKey, announcementMetadata)`. Emits `Announcement` event.

8. Relay pool calls `IJBTerminal(terminal).pay{value: 3 ether}(projectId, token, amount, stealthAddress, minReturnedTokens, memo, metadata)`.

9. Terminal records payment with `payer = PaymentRelayPool` (real payer hidden).

10. Terminal calls `PrivacyDataHookWrapper.beforePayRecordedWith(context)`:
    - Delegates to `INNER_HOOK` (JB721TiersHook) which returns tier mint specs.
    - Detects stealth metadata via `JBMetadataResolver.getDataFor()`.
    - Appends `StealthAnnouncementHook` to hook specifications.

11. 721 hook mints NFT(s) to the stealth address.

12. Terminal calls `StealthAnnouncementHook.afterPayRecordedWith(context)`:
    - Extracts `(schemeId, ephemeralPubKey, viewTag)` from payer metadata.
    - Calls `ANNOUNCER.announce()` — second announcement (redundant but ensures announcement even without relay pool).

13. **Off-chain**: Recipient scans `Announcement` events using their viewing key, finds the match, and derives the stealth private key to control the stealth address.

**State changes**:
1. `StealthRegistry` — no change (was already registered)
2. `JBTerminalStore.balanceOf[terminal][projectId][token]` — incremented by payment amount
3. NFT minted to stealth address
4. Two `Announcement` events emitted (one from relay pool, one from hook)

**Events**:
- `Announcement(1, stealthAddress, relayPool, ephemeralPubKey, viewTag)` — from relay pool call
- `Pay(payer=relayPool, beneficiary=stealthAddress, amount=3 ether, ...)` — payer is relay pool
- `Announcement(1, stealthAddress, terminal, ephemeralPubKey, viewTag)` — from hook call

**Edge cases**:
- `PaymentRelayPool_MsgValueMismatch()` — reverts if `msg.value != amount` for native token
- If the terminal payment reverts, the entire transaction reverts (including the announcement)
- If stealth metadata is malformed, `abi.decode` in `StealthAnnouncementHook` will revert

**Result:** An on-chain observer sees: "The relay pool paid 3 ETH to project X, and stealth address 0x7f3a received 3 Tier-3 NFTs." They cannot determine who the real payer is, who the real recipient is, or distinguish this from any other 3× Tier-3 mint.

---

## 2. Relay-Only Payment (Payer Privacy, No Stealth)

A payer wants to hide their identity but the recipient uses a known address.

**Entry point**: `PaymentRelayPool.relayPayment(address terminal, uint256 projectId, address token, uint256 amount, address beneficiary, uint256 minReturnedTokens, string memo, bytes metadata)`

**Who can call**: Anyone.

**Steps:**

1. Payer calls `PaymentRelayPool.relayPayment{value: 1 ether}(terminal, projectId, NATIVE_TOKEN, 1 ether, recipientAddress, 0, "", metadata)`.

2. Relay pool validates `msg.value == amount`.

3. Relay pool calls `IJBTerminal(terminal).pay{value: 1 ether}(...)` with `beneficiary = recipientAddress`.

4. Terminal records `payer = PaymentRelayPool`. Normal payment flow — no stealth metadata, no announcement.

**State changes**:
1. `JBTerminalStore.balanceOf` — incremented
2. Tokens/NFTs minted to `recipientAddress`

**Events**:
- `Pay(payer=relayPool, beneficiary=recipientAddress, ...)` — real payer hidden

**Edge cases**:
- No stealth metadata → `PrivacyDataHookWrapper` does not append announcement hook (transparent pass-through)

**Result:** Observer sees relay pool as payer. Recipient is visible. Amount is visible unless privacy tiers are used.

---

## 3. Stealth-Only Payment (Recipient Privacy, No Relay)

A payer sends directly to a stealth address without using the relay pool. Payer identity is visible.

**Entry point**: `JBMultiTerminal.pay(uint256 projectId, address token, uint256 amount, address beneficiary, uint256 minReturnedTokens, string memo, bytes metadata)`

**Who can call**: Anyone (via the terminal directly).

**Steps:**

1. Payer computes stealth address off-chain and encodes stealth metadata.

2. Payer calls `JBMultiTerminal.pay{value: 1 ether}(projectId, ..., stealthAddress, ..., metadata)` directly.

3. Terminal records `payer = realPayerAddress` (not hidden).

4. `PrivacyDataHookWrapper.beforePayRecordedWith()` detects stealth metadata, appends `StealthAnnouncementHook`.

5. NFT minted to stealth address.

6. `StealthAnnouncementHook.afterPayRecordedWith()` emits `Announcement`.

**Events**:
- `Pay(payer=realPayerAddress, beneficiary=stealthAddress, ...)` — payer visible
- `Announcement(1, stealthAddress, terminal, ephemeralPubKey, viewTag)`

**Result:** Recipient is hidden behind stealth address. Payer is visible. For full privacy, combine with relay pool.

---

## 4. Revnet Private Payment (Relay + Atomic Announcement)

Revnets (REVDeployer) have no data hook extension point, so the announcement comes from the relay pool instead of a hook.

**Entry point**: `PaymentRelayPool.relayPaymentWithAnnouncement(RelayWithAnnouncementParams calldata params)`

**Who can call**: Anyone.

**Steps:**

1-4. Same off-chain preparation as Journey 1.

5. Payer calls `relayPaymentWithAnnouncement{value: amount}(params)`.

6. Relay pool emits `Announcement` via `ANNOUNCER.announce()`.

7. Relay pool calls `IJBTerminal(terminal).pay{value: amount}(...)`.

8. Revnet processes the payment normally (no data hook wrapper involved).

9. Project tokens minted to the stealth address.

**State changes**:
1. `Announcement` event emitted (from relay pool only — no hook in the revnet path)
2. Terminal balance incremented
3. Tokens minted to stealth address

**Result:** Same privacy as Journey 1 for payer and recipient identity. One fewer `Announcement` event (no hook path). The relay pool announcement is sufficient for recipient scanning.

---

## 5. Register Stealth Meta-Address

A recipient publishes their stealth meta-address so payers can compute stealth addresses for them.

**Entry point**: `StealthRegistry.register(uint256 schemeId, bytes calldata stealthMetaAddress)`

**Who can call**: Anyone (registers for `msg.sender` only).

**Parameters**:

| Field | Type | Description |
|-------|------|-------------|
| `schemeId` | `uint256` | The stealth scheme (1 = secp256k1 with view tags per EIP-5564) |
| `stealthMetaAddress` | `bytes` | Encoded `(spendingPubKey ++ viewingPubKey)` |

**Steps:**

1. Recipient generates a stealth meta-address keypair off-chain (spending key + viewing key).

2. Recipient calls `StealthRegistry.register(1, encodedMetaAddress)`.

3. Registry stores `_stealthMetaAddresses[msg.sender][1] = encodedMetaAddress`.

4. Emits `StealthMetaAddressSet(msg.sender, 1, encodedMetaAddress)`.

**State changes**:
1. `StealthRegistry._stealthMetaAddresses[msg.sender][schemeId]` — set or overwritten

**Events**:
- `StealthMetaAddressSet(account, schemeId, stealthMetaAddress)`

**Edge cases**:
- Overwriting an existing registration is allowed — no error, previous value replaced
- Empty `stealthMetaAddress` is accepted (effectively clears the registration)
- No validation of the meta-address format — the contract stores raw bytes

**Result:** Any payer can now call `stealthMetaAddressOf(recipient, 1)` to retrieve the meta-address and compute stealth addresses off-chain.

---

## 6. Private Cash Out (Stealth Address Holder)

A stealth address holder cashes out their NFT without revealing their real identity.

**Entry point**: `JBMultiTerminal.cashOutTokensOf(...)` via ERC-2771 meta-transaction

**Who can call**: The stealth address holder signs a meta-tx; a trusted forwarder relays it.

**Steps:**

1. **Off-chain**: Stealth address holder derives their stealth private key from the `Announcement` event data + their viewing/spending keys.

2. **Off-chain**: Holder creates and signs an ERC-2771 meta-transaction calling `cashOutTokensOf(stealthAddress, projectId, cashOutCount, tokenToReclaim, minTokensReclaimed, freshAddress, metadata)`.

3. Trusted forwarder submits the meta-transaction to `JBMultiTerminal`.

4. `JBMultiTerminal._msgSender()` extracts the stealth address from the ERC-2771 envelope.

5. Terminal validates permissions for the stealth address.

6. Terminal burns the holder's tokens and sends reclaim to `freshAddress` (a new, unlinked address).

**Result:** The forwarder pays gas (no ETH needed at the stealth address). Reclaim goes to a fresh address with no on-chain link to the stealth address. The only observer-visible connection is the `CashOut` event linking the stealth address to the fresh address — this is a one-time correlation that reveals nothing about the real recipient.

---

## Privacy Composition Matrix

| Layers Used | Payer Hidden? | Recipient Hidden? | Amount Hidden? | Contracts Involved |
|-------------|--------------|-------------------|----------------|-------------------|
| Relay only | Yes | No | No | `PaymentRelayPool` |
| Stealth only | No | Yes | No | `PrivacyDataHookWrapper` + `StealthAnnouncementHook` + `ERC5564Announcer` + `StealthRegistry` |
| Tiers only | No | No | Yes (per-tier) | 721 tier configuration |
| Relay + Stealth | Yes | Yes | No | `PaymentRelayPool` + `PrivacyDataHookWrapper` + `StealthAnnouncementHook` |
| Relay + Stealth + Tiers | Yes | Yes | Yes | All contracts + 721 tier configuration |
| Relay + Announcement (revnet) | Yes | Yes | No | `PaymentRelayPool` + `ERC5564Announcer` |
