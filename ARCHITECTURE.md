# nana-privacy-v6 — Architecture

## Purpose

Privacy layer for Juicebox V6 payments. Hides who pays (relay pool breaks `msg.sender` link), who receives (EIP-5564 stealth addresses), and how much (721 tier fixed denominations). Three independent layers that compose without modifying any existing Juicebox contracts.

## Contract Map

```
src/
├── ERC5564Announcer.sol              — Stateless singleton: emits Announcement events for stealth payments
├── StealthRegistry.sol               — Stores stealth meta-addresses by account + scheme ID
├── StealthAnnouncementHook.sol       — IJBPayHook: extracts stealth data from payer metadata, emits announcement
├── PrivacyDataHookWrapper.sol        — IJBRulesetDataHook: wraps inner hook + appends announcement hook when privacy metadata present
├── PaymentRelayPool.sol              — Payer privacy: forwards payments to terminals as msg.sender, optional atomic announcement
└── interfaces/
    ├── IERC5564Announcer.sol         — Announcement event + announce() function
    └── IStealthRegistry.sol          — register() + stealthMetaAddressOf() + StealthMetaAddressSet event
```

## Key Data Flows

### Private Payment (Full Privacy — Relay + Stealth + Announcement)

```
Payer (off-chain)
  → Looks up recipient meta-address from StealthRegistry
  → Computes stealth address + ephemeral keypair (ECDH, EIP-5564)
  → Selects privacy tier(s) for denomination uniformity
  → Encodes tier IDs + stealth metadata in JBMetadataResolver format

PaymentRelayPool.relayPaymentWithAnnouncement(params)
  → ANNOUNCER.announce(schemeId, stealthAddress, ephemeralPubKey, viewTag)
  → IJBTerminal(terminal).pay{value: msg.value}(...)
      Terminal sees payer = PaymentRelayPool (real payer hidden)

JBMultiTerminal.pay(...)
  → JBTerminalStore.recordPaymentFrom(...)
    → PrivacyDataHookWrapper.beforePayRecordedWith(context)
      → INNER_HOOK.beforePayRecordedWith(context)  [if set — e.g., JB721TiersHook]
      → Detect stealth metadata via JBMetadataResolver.getDataFor()
      → Append StealthAnnouncementHook to pay hook specs (amount=0)
  → Mint NFT(s) to stealth address
  → StealthAnnouncementHook.afterPayRecordedWith(context)
    → ANNOUNCER.announce(schemeId, stealthAddress, ephemeralPubKey, viewTag)

Recipient (off-chain)
  → Scans Announcement events with viewing key
  → Finds match, derives stealth private key
  → Controls stealth address and its NFTs
```

### Relay-Only Payment (Payer Privacy, No Stealth)

```
Payer → PaymentRelayPool.relayPayment(terminal, projectId, ...)
  → IJBTerminal(terminal).pay{value: msg.value}(...)
    Terminal records payer = PaymentRelayPool
    Normal payment flow — no stealth, no announcement
```

### Stealth-Only Payment (Recipient Privacy, No Relay)

```
Payer → JBMultiTerminal.pay(..., stealthAddress, ..., metadata)
  → PrivacyDataHookWrapper detects stealth metadata
  → Appends StealthAnnouncementHook
  → NFT minted to stealth address
  → Announcement emitted
  Pay event shows payer = real payer address (not hidden)
```

### Private Cash Out (Stealth Address Holder)

```
Stealth address holder (off-chain)
  → Signs ERC-2771 meta-transaction for cashOutTokensOf
  → Trusted forwarder relays tx
  → JBMultiTerminal._msgSender() extracts stealth address
  → Permission check passes
  → Reclaim sent to a fresh address
```

## Deployer Compatibility

| Deployment Path | Privacy Mechanism | How It Works |
|----------------|-------------------|--------------|
| Direct core (JBController + JBMultiTerminal) | `PrivacyDataHookWrapper` wraps 721 hook | Set wrapper as `metadata.dataHook` in ruleset. Wrapper delegates to inner `JB721TiersHook` and appends announcement hook. |
| JBOmnichainDeployer | `PrivacyDataHookWrapper(innerHook=address(0))` | Pass as extra data hook. Standalone mode — no inner hook delegation. |
| REVDeployer (revnets) | `PaymentRelayPool` emits announcement directly | Revnets have no data hook slot. Use `relayPaymentWithAnnouncement()` which calls `ANNOUNCER.announce()` atomically. |
| Any path, no relay | Client calls `ERC5564Announcer.announce()` separately | Transaction after the payment. Less private (two transactions from same address). |

## Design Decisions

### No changes to existing contracts

All privacy functionality is implemented in new contracts that interact with existing Juicebox V6 interfaces. `PaymentRelayPool` calls `IJBTerminal.pay()`. `PrivacyDataHookWrapper` implements `IJBRulesetDataHook`. `StealthAnnouncementHook` implements `IJBPayHook`. This means privacy can be adopted incrementally without protocol upgrades or migrations.

### Relay pool as pass-through (no batching)

`PaymentRelayPool` immediately forwards payments — no delay, no queue, no batching. This simplifies the contract (no state, no withdrawal logic, no stuck funds) but creates a timing correlation risk: an observer monitoring the pool can match deposit and payment timestamps. Production deployments may add batching via a separate contract wrapping the relay pool.

### Metadata-driven privacy detection

The `PrivacyDataHookWrapper` detects privacy mode by checking for stealth metadata in payer metadata using `JBMetadataResolver.getDataFor()`. If the metadata ID is present, the announcement hook is appended. If absent, the wrapper is transparent — no privacy overhead on regular payments. This makes privacy opt-in per payment.

### Shared metadataIdTarget across contracts

All contracts that read or write stealth metadata must compute the same 4-byte metadata ID. This is enforced by using the same `metadataIdTarget` address (canonically `address(announcer)`) in `JBMetadataResolver.getId("stealth", metadataIdTarget)`. Mismatch breaks the system silently — the wrapper won't find the metadata the client encoded.

### RelayWithAnnouncementParams struct

`relayPaymentWithAnnouncement` requires 11 parameters (8 payment + 3 announcement). Passing them individually causes Yul stack-too-deep errors without `via_ir`. The `RelayWithAnnouncementParams` struct bundles all parameters into a single `calldata` pointer, keeping the function within the stack limit.

## Dependencies

- `@bananapus/core-v6` — Terminal, controller, and data hook interfaces; `JBMetadataResolver` library
- `@openzeppelin/contracts` — `IERC165` for interface detection
