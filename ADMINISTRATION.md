# Administration

Admin privileges and their scope in nana-privacy-v6.

## Roles

### None

There are no admin roles in nana-privacy-v6. All contracts are permissionless:

- **ERC5564Announcer**: Stateless singleton. No owner, no admin. Anyone can call `announce()`.
- **StealthRegistry**: Self-sovereign. Each account registers only their own meta-address via `msg.sender`. No admin can write, delete, or freeze registrations.
- **StealthAnnouncementHook**: No admin. Called by the terminal as a pay hook. Reads metadata and emits events.
- **PrivacyDataHookWrapper**: No admin. Immutable configuration set at construction. Delegates to inner hook and appends announcement hook when stealth metadata is detected.
- **PaymentRelayPool**: No admin. Anyone can call `relayPayment()` or `relayPaymentWithAnnouncement()` with any terminal and project.

## Privileged Functions

There are no privileged functions. No function in any contract requires ownership, admin role, or permission ID.

| Function | Required Role | Permission ID | Scope | What It Does |
|----------|--------------|---------------|-------|--------------|
| — | — | — | — | All functions are permissionless |

## Immutable Configuration

All configuration is set at construction and cannot be changed:

### ERC5564Announcer

No constructor parameters. No storage. Fully stateless.

### StealthRegistry

No constructor parameters. Storage is per-account (only `msg.sender` can write).

### StealthAnnouncementHook

| Property | Type | Set At | Mutable? | Description |
|----------|------|--------|----------|-------------|
| `ANNOUNCER` | `IERC5564Announcer` | Constructor | No | The ERC5564Announcer singleton for emitting announcements |
| `STEALTH_METADATA_ID` | `bytes4` | Constructor | No | Computed from `JBMetadataResolver.getId("stealth", metadataIdTarget)`. Determines which metadata key triggers announcements. |

### PrivacyDataHookWrapper

| Property | Type | Set At | Mutable? | Description |
|----------|------|--------|----------|-------------|
| `INNER_HOOK` | `IJBRulesetDataHook` | Constructor | No | The inner data hook to delegate to (typically `JB721TiersHook`), or `address(0)` for standalone mode |
| `ANNOUNCEMENT_HOOK` | `StealthAnnouncementHook` | Constructor | No | The hook appended to pay specs when stealth metadata is present |
| `PRIVACY_METADATA_ID` | `bytes4` | Constructor | No | Computed from `JBMetadataResolver.getId("stealth", metadataIdTarget)`. Must match the ID used by clients and `StealthAnnouncementHook`. |

### PaymentRelayPool

| Property | Type | Set At | Mutable? | Description |
|----------|------|--------|----------|-------------|
| `ANNOUNCER` | `IERC5564Announcer` | Constructor | No | The ERC5564Announcer singleton for atomic announcements in `relayPaymentWithAnnouncement()` |

## Admin Boundaries

Things that **no one** can do:

- **No one can pause or freeze the relay pool.** There is no pause mechanism. The pool always forwards payments.
- **No one can block stealth address registrations.** `StealthRegistry` has no allowlist, blocklist, or admin override.
- **No one can censor announcements.** `ERC5564Announcer` has no access control. Events are permanent once emitted.
- **No one can change the inner hook or announcement hook.** Both are immutable in `PrivacyDataHookWrapper`. To use a different hook, deploy a new wrapper.
- **No one can change the metadata ID target.** The 4-byte ID is computed at construction and stored as an immutable. Changing it requires deploying new contracts.
- **No one can withdraw funds from the relay pool.** The pool holds no funds — all ETH is forwarded in the same transaction. There is no withdrawal function.
- **No one can delete another account's stealth meta-address.** Each account controls only their own registration. Overwriting requires `msg.sender` to be the registered account.

## Upgrade Path

All contracts are non-upgradeable. To change behavior:

1. Deploy new contract(s) with updated configuration.
2. Update the project's ruleset to point to the new `PrivacyDataHookWrapper` (for core direct deployments).
3. Update client-side code to use the new relay pool or announcer address.
4. Old contracts remain functional — existing stealth addresses and announcements are unaffected.
