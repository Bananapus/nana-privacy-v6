# Audit Instructions

You are auditing the Juicebox V6 privacy system — standalone contracts that add payer privacy, recipient privacy, and amount privacy to Juicebox payments without modifying existing protocol contracts. Your goal is to find bugs that leak private information, lose funds, or break the integration with Juicebox V6 terminals and hooks.

Read [RISKS.md](./RISKS.md) for known risks and trust assumptions. Then come back here.

## Scope

**In scope — all Solidity in `src/`:**
```
src/ERC5564Announcer.sol              # Stateless announcement singleton (~15 lines)
src/StealthRegistry.sol               # Stealth meta-address storage (~20 lines)
src/StealthAnnouncementHook.sol       # IJBPayHook: metadata extraction + announcement (~45 lines)
src/PrivacyDataHookWrapper.sol        # IJBRulesetDataHook: inner hook delegation + announcement hook injection (~110 lines)
src/PaymentRelayPool.sol              # Payer privacy relay + atomic announcement (~125 lines)
src/interfaces/IERC5564Announcer.sol  # Announcement interface
src/interfaces/IStealthRegistry.sol   # Registry interface
```

**Out of scope:** Test files (`test/`), deployment scripts (`script/`), OpenZeppelin dependencies (assume correct), nana-core-v6 contracts (assume correct), forge-std.

## Architecture

Five contracts form the privacy system:

### ERC5564Announcer (`src/ERC5564Announcer.sol`)

Stateless singleton. Emits `Announcement(schemeId, stealthAddress, caller, ephemeralPubKey, metadata)`. No storage, no access control. Anyone can call `announce()` with any parameters. One deployment per chain.

### StealthRegistry (`src/StealthRegistry.sol`)

Stores `mapping(address => mapping(uint256 => bytes))` — stealth meta-addresses indexed by account and scheme ID. Only `msg.sender` can write their own entry via `register()`. No admin, no deletion mechanism beyond overwriting.

### StealthAnnouncementHook (`src/StealthAnnouncementHook.sol`)

`IJBPayHook` implementation. Called by `JBMultiTerminal` after payment recording. Extracts stealth data from `context.payerMetadata` using `JBMetadataResolver.getDataFor(STEALTH_METADATA_ID, ...)`, decodes `(schemeId, ephemeralPubKey, viewTag)`, and calls `ANNOUNCER.announce()` with `context.beneficiary` as the stealth address.

**Immutables:** `ANNOUNCER` (ERC5564Announcer), `STEALTH_METADATA_ID` (4-byte metadata key).

### PrivacyDataHookWrapper (`src/PrivacyDataHookWrapper.sol`)

`IJBRulesetDataHook` implementation. Two operating modes:

1. **Wrapping mode** (`INNER_HOOK != address(0)`): Delegates `beforePayRecordedWith` to the inner hook (e.g., `JB721TiersHook`), gets weight + hook specs back, then checks for stealth metadata. If found, appends a `JBPayHookSpecification` for `ANNOUNCEMENT_HOOK` with `amount=0`. Cash out delegation is pure pass-through.

2. **Standalone mode** (`INNER_HOOK == address(0)`): Returns `context.weight` unchanged and an empty hook specs array. Only the announcement hook is appended when stealth metadata is present.

**Immutables:** `INNER_HOOK`, `ANNOUNCEMENT_HOOK`, `PRIVACY_METADATA_ID`.

### PaymentRelayPool (`src/PaymentRelayPool.sol`)

Forwards payments to any `IJBTerminal`. Two entry points:

1. `relayPayment(...)`: Validates `msg.value` for native tokens, calls `IJBTerminal(terminal).pay{value: msg.value}(...)`. The terminal sees `msg.sender = PaymentRelayPool`.

2. `relayPaymentWithAnnouncement(params)`: Same, but first emits an `Announcement` via `ANNOUNCER.announce()`. Uses `RelayWithAnnouncementParams` struct to avoid stack-too-deep.

**Immutables:** `ANNOUNCER`.

## Key Flows

### Metadata Detection (PrivacyDataHookWrapper)

```
PrivacyDataHookWrapper.beforePayRecordedWith(context)
  |
  +--> If INNER_HOOK != address(0):
  |      (weight, hookSpecs) = INNER_HOOK.beforePayRecordedWith(context)
  |    Else:
  |      weight = context.weight, hookSpecs = []
  |
  +--> (hasPrivacy, _) = JBMetadataResolver.getDataFor(PRIVACY_METADATA_ID, context.metadata)
  |
  +--> If hasPrivacy:
  |      Create augmented array (length + 1)
  |      Copy existing specs
  |      Append JBPayHookSpecification(ANNOUNCEMENT_HOOK, noop=false, amount=0, metadata="")
  |
  +--> Return (weight, augmentedSpecs)
```

### Relay Pool Payment

```
PaymentRelayPool.relayPaymentWithAnnouncement(params)
  |
  +--> If params.token == NATIVE_TOKEN && msg.value != params.amount: REVERT
  |
  +--> ANNOUNCER.announce(schemeId, beneficiary, ephemeralPubKey, announcementMetadata)
  |
  +--> IJBTerminal(params.terminal).pay{value: msg.value}(
  |      projectId, token, amount, beneficiary, minReturnedTokens, memo, metadata
  |    )
  |
  +--> Return beneficiaryTokenCount
```

### Stealth Data Extraction (StealthAnnouncementHook)

```
StealthAnnouncementHook.afterPayRecordedWith(context)
  |
  +--> (_, stealthData) = JBMetadataResolver.getDataFor(STEALTH_METADATA_ID, context.payerMetadata)
  |
  +--> (schemeId, ephemeralPubKey, viewTag) = abi.decode(stealthData, (uint256, bytes, bytes))
  |
  +--> ANNOUNCER.announce(schemeId, context.beneficiary, ephemeralPubKey, viewTag)
```

## Priority Audit Areas

| Priority | Target | Why |
|----------|--------|-----|
| 1 | **PaymentRelayPool fund forwarding** | All user ETH flows through here. Verify: `msg.value` is fully forwarded, no ETH can be trapped, no reentrancy risk from the terminal call, return value is correctly propagated. |
| 2 | **PrivacyDataHookWrapper metadata detection** | Controls whether the announcement hook fires. Verify: metadata ID computation is consistent, `getDataFor` correctly identifies presence/absence, the wrapper is truly transparent when no stealth metadata exists. |
| 3 | **StealthAnnouncementHook metadata decoding** | Extracts and re-emits stealth data. Verify: `abi.decode` handles malformed data (revert vs silent corruption), the decoded fields match what `announce()` expects, no data truncation or corruption. |
| 4 | **Hook spec array manipulation** | The wrapper creates a new array and copies specs. Verify: no off-by-one in array indexing, no spec duplication or loss, gas behavior with large inner hook spec arrays. |
| 5 | **ERC-20 payment path** | `PaymentRelayPool` forwards `msg.value` but does not handle ERC-20 token transfers. Verify: calling `relayPayment` with an ERC-20 token and `msg.value = 0` — does the terminal correctly pull from the pool via Permit2? Does this create a privacy leak? |
| 6 | **metadataIdTarget consistency** | All contracts must use the same `metadataIdTarget` to compute the same 4-byte ID. Verify: deployment script uses a consistent target, and mismatched targets cause silent failure (metadata not found) rather than incorrect data extraction. |

## Invariants to Verify

1. **Relay pool holds no ETH after a call**: `address(relayPool).balance` should be unchanged after `relayPayment()` or `relayPaymentWithAnnouncement()` completes (all `msg.value` forwarded to terminal).

2. **Wrapper transparency**: When payer metadata does NOT contain the stealth metadata ID, `beforePayRecordedWith` returns exactly the same `(weight, hookSpecifications)` as the inner hook (or `(context.weight, [])` if no inner hook).

3. **Announcement data integrity**: The `Announcement` event emitted by `StealthAnnouncementHook` contains exactly the same `(schemeId, ephemeralPubKey, viewTag)` that was encoded in the payer metadata, and `stealthAddress == context.beneficiary`.

4. **Self-sovereign registry**: For any `account` and `schemeId`, only a transaction where `msg.sender == account` can modify `_stealthMetaAddresses[account][schemeId]`.

5. **No storage in announcer**: `ERC5564Announcer` has zero storage slots. `SSTORE` is never called.

6. **metadataIdTarget agreement**: `StealthAnnouncementHook.STEALTH_METADATA_ID == PrivacyDataHookWrapper.PRIVACY_METADATA_ID` when both are constructed with the same `metadataIdTarget`.

## Anti-Patterns to Hunt

| Pattern | Where to Look | Why It's Dangerous |
|---------|--------------|-------------------|
| Trapped ETH in relay pool | `PaymentRelayPool.relayPayment()`, `.relayPaymentWithAnnouncement()` | If the terminal call reverts but ETH isn't returned to the caller, funds are stuck in the pool. |
| `abi.decode` on untrusted input | `StealthAnnouncementHook.afterPayRecordedWith()` | Malformed payer metadata could cause unexpected revert or decode garbage. The metadata is user-supplied via the terminal. |
| Metadata ID mismatch | Constructor of `StealthAnnouncementHook`, `PrivacyDataHookWrapper`, client-side encoding | If `metadataIdTarget` differs, stealth metadata is silently ignored — wrapper doesn't append the hook, so no announcement event fires. Privacy failure without any error. |
| Inner hook return value manipulation | `PrivacyDataHookWrapper.beforePayRecordedWith()` → `INNER_HOOK.beforePayRecordedWith()` | A malicious inner hook could return crafted `hookSpecifications` that conflict with the appended announcement hook. |
| `msg.value` without native token check | `PaymentRelayPool.relayPayment()` | Only validates `msg.value == amount` when `token == NATIVE_TOKEN`. What happens if `token != NATIVE_TOKEN` but `msg.value > 0`? The ETH is forwarded to the terminal — is it lost? |
| Stack-too-deep avoidance | `RelayWithAnnouncementParams` struct in `PaymentRelayPool` | The struct was introduced to avoid stack-too-deep. Verify no field is silently dropped or misordered in the struct definition vs. usage. |

## Coverage Gaps

The test suite covers core functionality but these areas have limited coverage:

- **Malformed metadata**: No tests with truncated, empty, or deliberately corrupted stealth metadata in payer metadata.
- **ERC-20 relay payments**: No tests verifying ERC-20 token privacy payments through the relay pool (by design — ETH is recommended, but the contracts don't prevent ERC-20 usage).
- **Integration with real JB721TiersHook**: Integration test scaffolds exist but use mock hooks. Full integration with a deployed 721 hook is not tested.
- **Multiple concurrent relay pool users**: No tests simulating multiple payers using the relay pool in the same block.
- **Gas limits**: No tests verifying behavior at high gas prices or with inner hooks returning many specs.

## How to Run Tests

```bash
cd nana-privacy-v6
npm install
forge build
forge test

# Run with high verbosity for debugging
forge test -vvvv --match-test testName

# Write a PoC
forge test --match-path test/audit/ExploitPoC.t.sol -vvv

# Specific test suites
forge test --match-contract ERC5564AnnouncerTest        # Announcer
forge test --match-contract StealthRegistryTest         # Registry
forge test --match-contract StealthAnnouncementHookTest # Hook
forge test --match-contract PrivacyDataHookWrapperTest  # Wrapper
forge test --match-contract PaymentRelayPoolTest        # Relay pool
```

## Compiler and Version Info

- **Solidity**: 0.8.28
- **EVM target**: Cancun
- **Optimizer**: 200 runs, no via_ir
- **Dependencies**: OpenZeppelin 5.x, nana-core-v6
- **Build**: `forge build` (Foundry)

## How to Report Findings

For each finding:

1. **Title** — one line, starts with severity (CRITICAL/HIGH/MEDIUM/LOW)
2. **Affected contract(s)** — exact file path and line numbers
3. **Description** — what is wrong, in plain language
4. **Trigger sequence** — step-by-step, minimal steps to reproduce
5. **Impact** — what an attacker gains, what a user loses
6. **Proof** — code trace showing the exact execution path, or a Foundry test
7. **Fix** — minimal code change that resolves the issue

**Severity guide:**
- **CRITICAL**: Direct fund loss or complete privacy breach. Exploitable with no preconditions.
- **HIGH**: Conditional fund loss, privacy leak under specific conditions, or broken invariant.
- **MEDIUM**: Partial privacy degradation, griefing, or integration-breaking edge case.
- **LOW**: Informational, minor gas inefficiency, or edge case with no material impact.
