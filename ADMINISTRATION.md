# Administration

Admin privileges and their scope in nana-privacy-v6.

## At A Glance

| Item | Details |
|------|---------|
| Scope | Privacy support contracts with no owner or privileged runtime surface. |
| Operators | End users registering stealth metadata, relayers or hooks emitting announcements, and deployers choosing which hook address to integrate. |
| Highest-risk actions | Integrating the wrong hook address or metadata ID target and assuming those choices can be changed later. |
| Recovery posture | Behavior changes require deploying new contracts and moving integrations to them. Existing registrations and announcements remain as-is. |

## Routine Operations

- Verify the intended announcer and hook addresses before integrating them into deployers or client code.
- Treat stealth metadata IDs as part of the integration contract between off-chain tooling and the on-chain hook.
- Remember that the registry is self-sovereign: each account manages only its own stealth registration.

## One-Way Or High-Risk Actions

- The hook's metadata ID target is immutable after deployment.
- There is no admin who can censor announcements or rewrite stealth registrations.
- Existing emitted announcements are permanent event history.

## Recovery Notes

- If the wrong hook or announcer was deployed, integrate a new contract set and update clients or deployers to use it.
- There is no owner override to repair or erase old data in place.

## Roles

### None

There are no admin roles in nana-privacy-v6. All contracts are permissionless:

- **ERC5564Announcer**: Stateless singleton. No owner, no admin. Anyone can call `announce()`.
- **StealthRegistry**: Self-sovereign. Each account registers only their own meta-address via `msg.sender`. No admin can write, delete, or freeze registrations.
- **StealthAnnouncementHook**: No admin. Called by the terminal as a pay hook. Reads metadata and emits events. Deployers (REVDeployer, JBOmnichainDeployer, or custom) include this hook in their pay hook spec arrays.
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

## Admin Boundaries

Things that **no one** can do:

- **No one can block stealth address registrations.** `StealthRegistry` has no allowlist, blocklist, or admin override.
- **No one can censor announcements.** `ERC5564Announcer` has no access control. Events are permanent once emitted.
- **No one can change the metadata ID target.** The 4-byte ID is computed at construction and stored as an immutable in `StealthAnnouncementHook`. Changing it requires deploying a new hook.
- **No one can delete another account's stealth meta-address.** Each account controls only their own registration. Overwriting requires `msg.sender` to be the registered account.

## Upgrade Path

All contracts are non-upgradeable. To change behavior:

1. Deploy new contract(s) with updated configuration.
2. Update deployers to reference the new `StealthAnnouncementHook` in their hook spec arrays.
3. Update client-side code to use the new announcer address.
4. Old contracts remain functional -- existing stealth addresses and announcements are unaffected.
