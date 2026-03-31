# Nana Privacy Risk Register

This file focuses on the privacy-model risks in the standalone privacy layer: anonymity-set weakness, stealth-address leakage, and the gap between cryptographic privacy goals and what on-chain observers can still infer.

## How to use this file

- Read `Priority risks` first; the sharpest failures here are usually metadata leaks, not broken transfers.
- Use the detailed sections for anonymity-set and stealth-address reasoning.
- Treat `Accepted Behaviors` as explicit statements of what the system does not try to hide.

## Priority risks

| Priority | Risk | Why it matters | Primary controls |
|----------|------|----------------|------------------|
| P0 | Small anonymity sets | Privacy weakens sharply if too few users share denominations or timing windows. | Denomination design, user education, and honest disclosure of set-size limits. |
| P1 | Metadata leakage outside the crypto layer | Timing, denomination choice, bridge behavior, or downstream 721 activity can deanonymize otherwise-private flows. | Operational guidance, wallet hygiene, and conservative documentation of privacy guarantees. |
| P1 | Stealth-address implementation mistakes | A subtle mismatch in stealth-address derivation or handling can burn funds or reveal recipients. | Tight test coverage, standard adherence, and explicit invariants around derivation and delivery. |


## 1. Trust Assumptions

- **JBMultiTerminal**: The privacy system trusts terminals to correctly process payments. A compromised terminal can steal forwarded ETH. External ZK relayers (e.g., Railgun) have their own terminal verification mechanisms.
- **ERC5564Announcer**: The announcer is stateless and trustless — it only emits events. However, the privacy model trusts that announcement events are the sole mechanism for stealth address discovery. If the announcer contract is blocked or censored at the RPC level, recipients cannot discover payments.
- **StealthRegistry**: The registry trusts that accounts register valid meta-addresses. Malformed or adversarial meta-addresses cause stealth address computation to fail silently off-chain. The contract performs no validation of the meta-address format.
- **JBMetadataResolver**: All stealth metadata extraction depends on `JBMetadataResolver.getDataFor()` correctly parsing the payer metadata. A bug in the resolver library would break stealth detection.
- **Trusted Forwarder (ERC-2771)**: Private cash outs rely on `JBMultiTerminal` correctly extracting `_msgSender()` from ERC-2771 meta-transactions. A compromised trusted forwarder can impersonate any stealth address for cash outs.

## 2. Anonymity Set Risks

### 2.1 Small anonymity sets in early adoption

The anonymity set for a privacy tier equals the total number of mints of that tier across all time. A tier with 3 mints provides trivial privacy — an observer can narrow the payer/recipient to one of 3 possibilities. The anonymity set grows cumulatively and is never reduced (NFTs cannot be un-minted). Early projects should be transparent about weak privacy guarantees.

**Mitigation**: Projects can share privacy tier configurations (same tier IDs, same prices) across multiple projects to bootstrap larger sets. ZK relayer anonymity sets (e.g., Railgun's shielded pool) are shared across all projects and all DeFi protocols.

### 2.2 Multi-tier mints leak total contribution

A payment minting 3× Tier 3 + 1× Tier 2 reveals the total contribution (3.1 ETH). Single-tier mints have the strongest privacy. Multi-tier mints in one transaction create a unique fingerprint that may be identifiable if the combination is rare.

**Mitigation**: Split large contributions across multiple transactions to different stealth addresses. Each transaction should mint a single tier for maximum privacy.

### 2.3 Metadata distinguishability

The `Pay` event includes payer metadata containing stealth data (under the `"stealth"` metadata ID). An observer can distinguish privacy-mode payments from regular payments by checking for this metadata ID. This means the effective anonymity set is limited to privacy-mode payments only, not all payments to the project.

### 2.4 Timing correlation

Without ZK infrastructure, an observer can correlate the funding transaction with the payment transaction. ZK relayers like Railgun break this link by pooling funds in a shielded pool — the time between deposit and withdrawal is variable and unlinkable. **Use ZK infrastructure for payer privacy.**

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

## 4. Invariants

1. **ERC5564Announcer is stateless**: The announcer has no storage slots. It only emits events. It cannot be paused, upgraded, or drained.

2. **StealthRegistry is self-sovereign**: Only `msg.sender` can write their own stealth meta-address. No admin can write or delete another account's registration.

3. **StealthAnnouncementHook is transparent for non-privacy payments**: When no stealth metadata is present, the hook no-ops gracefully -- no event emitted, no revert.

4. **Announcement events are append-only**: Once emitted, `Announcement` events cannot be modified or censored on-chain. They are permanently available for recipient scanning via archive nodes.

## 5. Accepted Behaviors

### 5.1 StealthAnnouncementHook no-ops without stealth metadata

When `StealthAnnouncementHook` is included in a pay-hook chain, it returns silently on non-privacy payments — no event, no revert. This is intentional: the hook checks for stealth metadata via `JBMetadataResolver.getDataFor()` and returns early if not found. The current repo does not, by itself, guarantee that upstream deployers permanently include this hook; integrators must wire it in explicitly where they want stealth announcements.

### 5.2 No validation of stealth meta-address format

`StealthRegistry.register()` accepts any `bytes` value, including empty bytes, malformed keys, or non-EIP-5564 data. The contract is a general-purpose registry — format validation is the responsibility of off-chain tooling.

### 5.3 Anyone can announce for any stealth address

`ERC5564Announcer.announce()` has no access control. Anyone can emit `Announcement` events for any stealth address with any data. This means announcement events are not authenticated — recipients must verify the ECDH derivation off-chain (checking that the ephemeral public key, when combined with their viewing key, produces the claimed stealth address). Spam announcements create scanning overhead but cannot steal funds.
