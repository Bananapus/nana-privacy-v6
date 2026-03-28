# RISKS.md — nana-privacy-v6

## 1. Trust Assumptions

- **JBMultiTerminal**: The relay pool trusts the terminal to correctly process payments via `IJBTerminal.pay()`. A compromised terminal can steal forwarded ETH. The relay pool has no way to verify terminal authenticity beyond the caller-provided `terminal` address.
- **ERC5564Announcer**: The announcer is stateless and trustless — it only emits events. However, the privacy model trusts that announcement events are the sole mechanism for stealth address discovery. If the announcer contract is blocked or censored at the RPC level, recipients cannot discover payments.
- **StealthRegistry**: The registry trusts that accounts register valid meta-addresses. Malformed or adversarial meta-addresses cause stealth address computation to fail silently off-chain. The contract performs no validation of the meta-address format.
- **JBMetadataResolver**: All stealth metadata extraction depends on `JBMetadataResolver.getDataFor()` correctly parsing the payer metadata. A bug in the resolver library would break stealth detection.
- **Inner Hook (JB721TiersHook)**: The `PrivacyDataHookWrapper` delegates to `INNER_HOOK` for weight and hook specs. A malicious inner hook can return arbitrary weight values or hook specs, potentially redirecting funds. The inner hook is set at construction and cannot be changed.
- **Trusted Forwarder (ERC-2771)**: Private cash outs rely on `JBMultiTerminal` correctly extracting `_msgSender()` from ERC-2771 meta-transactions. A compromised trusted forwarder can impersonate any stealth address for cash outs.

## 2. Anonymity Set Risks

### 2.1 Small anonymity sets in early adoption

The anonymity set for a privacy tier equals the total number of mints of that tier across all time. A tier with 3 mints provides trivial privacy — an observer can narrow the payer/recipient to one of 3 possibilities. The anonymity set grows cumulatively and is never reduced (NFTs cannot be un-minted). Early projects should be transparent about weak privacy guarantees.

**Mitigation**: Projects can share privacy tier configurations (same tier IDs, same prices) across multiple projects to bootstrap larger sets. The relay pool is shared across all projects, so payer anonymity benefits from total relay pool usage.

### 2.2 Multi-tier mints leak total contribution

A payment minting 3× Tier 3 + 1× Tier 2 reveals the total contribution (3.1 ETH). Single-tier mints have the strongest privacy. Multi-tier mints in one transaction create a unique fingerprint that may be identifiable if the combination is rare.

**Mitigation**: Split large contributions across multiple transactions to different stealth addresses via different relay pool calls. Each transaction should mint a single tier for maximum privacy.

### 2.3 Metadata distinguishability

The `Pay` event includes payer metadata containing stealth data (under the `"stealth"` metadata ID). An observer can distinguish privacy-mode payments from regular payments by checking for this metadata ID. This means the effective anonymity set is limited to privacy-mode payments only, not all payments to the project.

### 2.4 Timing correlation

`PaymentRelayPool` is a stateless pass-through — it immediately forwards payments. An observer monitoring both the relay pool's receive and the terminal's `Pay` event sees them in the same transaction. If the relay pool is funded from a known address in a prior transaction, the timing correlation breaks privacy.

**Mitigation**: For ETH payments, the relay pool call is atomic (fund + forward in one tx), so there is no separate funding transaction. The attacker must correlate based on mempool observation, not on-chain state. For ERC-20 tokens, the token transfer to the relay pool IS visible on-chain — **use native ETH for privacy payments**.

## 3. Stealth Address Risks

### 3.1 Key management complexity

Stealth address recipients must:
1. Generate and securely store spending + viewing keypairs
2. Continuously scan `Announcement` events with their viewing key
3. Derive and manage individual stealth private keys for each received payment

Loss of the spending key means permanent loss of funds at all stealth addresses. Loss of the viewing key means inability to discover new payments. There is no recovery mechanism.

### 3.2 Stealth address reuse

If a payer reuses the same ephemeral keypair for two payments to the same recipient, the stealth addresses will be identical. This links the two payments, breaking privacy. Correct implementations must generate a fresh ephemeral keypair per payment. This is enforced off-chain — the contracts cannot detect reuse.

### 3.3 Gas at stealth addresses

Newly created stealth addresses have zero ETH balance. To transact (transfer NFTs, cash out), the address needs gas. Funding the stealth address from a known address creates a link. Private cash outs use ERC-2771 meta-transactions (trusted forwarder pays gas) to avoid this. For other operations, consider gas relayers or account abstraction.

## 4. Relay Pool Risks

### 4.1 Arbitrary terminal parameter

`PaymentRelayPool.relayPayment()` accepts an arbitrary `terminal` address. A malicious caller could pass a contract that accepts ETH but does not behave as a Juicebox terminal. The relay pool has no validation — it forwards `msg.value` to whatever address is provided. This is by design (the relay pool is a general-purpose forwarding tool), but callers must verify the terminal address off-chain.

### 4.2 ERC-20 token privacy limitation

For ERC-20 payments, the terminal calls `Permit2.transferFrom(msg.sender, ...)` where `msg.sender` is the relay pool. The tokens must be in the relay pool's balance before the call. Transferring ERC-20 tokens to the relay pool creates an on-chain trace (the `Transfer` event links the real payer to the pool). **Native ETH is the only token with strong privacy guarantees** because `msg.value` is part of the forwarding call itself.

### 4.3 Front-running relay pool transactions

A privacy payment in the mempool reveals: the relay pool is about to call `terminal.pay()` with a specific project ID, amount, and stealth address. A front-runner cannot extract value (no swap involved), but they learn the payment details before the transaction is mined. This is informational leakage, not a fund-loss risk.

## 5. Data Hook Wrapper Risks

### 5.1 Inner hook failure propagation

If `INNER_HOOK.beforePayRecordedWith()` reverts, the entire payment reverts. The wrapper does not catch inner hook failures. A buggy inner hook can block all privacy payments.

### 5.2 Hook spec array growth

The wrapper creates a new array of length `hookSpecifications.length + 1` and copies all inner hook specs. For an inner hook returning many specs, this adds gas proportional to the array length. No practical concern for typical deployments (1-3 specs), but an inner hook returning hundreds of specs would cause gas issues.

### 5.3 Metadata ID collision

If another system uses `JBMetadataResolver.getId("stealth", sameTarget)` for a different purpose, the wrapper would incorrectly detect privacy mode on non-privacy payments. This is unlikely given the specific string "stealth" and the use of the announcer address as `metadataIdTarget`.

## 6. Invariants

1. **PaymentRelayPool holds no funds**: After every `relayPayment()` or `relayPaymentWithAnnouncement()` call, the relay pool's ETH balance returns to its pre-call value. All `msg.value` is forwarded to the terminal. No ERC-20 tokens are stored (ERC-20 privacy is not recommended).

2. **ERC5564Announcer is stateless**: The announcer has no storage slots. It only emits events. It cannot be paused, upgraded, or drained.

3. **StealthRegistry is self-sovereign**: Only `msg.sender` can write their own stealth meta-address. No admin can write or delete another account's registration.

4. **PrivacyDataHookWrapper is transparent for non-privacy payments**: When no stealth metadata is present, the wrapper returns exactly what the inner hook returns (or context defaults if no inner hook). No weight modification, no extra hook specs.

5. **Announcement events are append-only**: Once emitted, `Announcement` events cannot be modified or censored on-chain. They are permanently available for recipient scanning via archive nodes.

## 7. Accepted Behaviors

### 7.1 Duplicate announcements in the core direct path

When using `relayPaymentWithAnnouncement` with a project that has `PrivacyDataHookWrapper` as its data hook, two `Announcement` events are emitted for the same payment — one from the relay pool and one from the hook. This is harmless (recipient scanning handles duplicates) and provides redundancy.

### 7.2 No validation of stealth meta-address format

`StealthRegistry.register()` accepts any `bytes` value, including empty bytes, malformed keys, or non-EIP-5564 data. The contract is a general-purpose registry — format validation is the responsibility of off-chain tooling.

### 7.3 Anyone can announce for any stealth address

`ERC5564Announcer.announce()` has no access control. Anyone can emit `Announcement` events for any stealth address with any data. This means announcement events are not authenticated — recipients must verify the ECDH derivation off-chain (checking that the ephemeral public key, when combined with their viewing key, produces the claimed stealth address). Spam announcements create scanning overhead but cannot steal funds.
