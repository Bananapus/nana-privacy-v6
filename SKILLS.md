# Nana Privacy V6

## Use This File For

- Use this file when the task involves stealth-address announcements, recipient privacy plumbing, or fixed-denomination privacy surfaces layered onto Juicebox flows.
- Start here, then open the announcer, registry, or hook based on which privacy layer is involved.

## Read This Next

| If you need... | Open this next |
|---|---|
| Repo overview and privacy model | [`README.md`](./README.md), [`ARCHITECTURE.md`](./ARCHITECTURE.md) |
| Announcement surface | [`src/ERC5564Announcer.sol`](./src/ERC5564Announcer.sol) |
| Registry behavior | [`src/StealthRegistry.sol`](./src/StealthRegistry.sol) |
| Juicebox hook integration | [`src/StealthAnnouncementHook.sol`](./src/StealthAnnouncementHook.sol), [`src/interfaces/`](./src/interfaces/) |
| Unit or integration coverage | [`test/ERC5564Announcer.t.sol`](./test/ERC5564Announcer.t.sol), [`test/StealthRegistry.t.sol`](./test/StealthRegistry.t.sol), [`test/StealthAnnouncementHook.t.sol`](./test/StealthAnnouncementHook.t.sol), [`test/integration/`](./test/integration/) |

## Repo Map

| Area | Where to look |
|---|---|
| Main contracts | [`src/`](./src/) |
| Interfaces | [`src/interfaces/`](./src/interfaces/) |
| Scripts | [`script/`](./script/) |
| Tests | [`test/`](./test/) |

## Purpose

Privacy-oriented helper layer for Juicebox V6 focused on stealth recipient announcements and fixed-denomination patterns, without changing the core protocol.

## Reference Files

- Open [`references/runtime.md`](./references/runtime.md) when you need the separation between payer privacy, recipient privacy, and denomination privacy, or the main runtime roles of each contract.
- Open [`references/operations.md`](./references/operations.md) when you need integration pointers, test breadcrumbs, or the common stale assumptions about what this repo does not provide.

## Working Rules

- Start in [`src/StealthAnnouncementHook.sol`](./src/StealthAnnouncementHook.sol) when the issue is Juicebox integration, not just stealth metadata storage.
- Treat this repo as additive privacy plumbing. It does not make the whole payment flow private by itself.
- When a task mentions payer privacy, confirm whether the real requirement lives outside this repo.
