# Privacy Runtime

## Core Roles

- [`src/ERC5564Announcer.sol`](../src/ERC5564Announcer.sol) emits announcement events for stealth discovery.
- [`src/StealthRegistry.sol`](../src/StealthRegistry.sol) stores stealth metadata for recipients.
- [`src/StealthAnnouncementHook.sol`](../src/StealthAnnouncementHook.sol) bridges Juicebox payment metadata into the announcement flow.

## High-Risk Areas

- Privacy scope confusion: recipient privacy and payer privacy are different concerns.
- Metadata distinguishability: using privacy-mode metadata can still create recognizable patterns.
- Fixed-denomination privacy: anonymity quality depends on the size and consistency of the denomination set.

## Tests To Trust First

- [`test/ERC5564Announcer.t.sol`](../test/ERC5564Announcer.t.sol)
- [`test/StealthRegistry.t.sol`](../test/StealthRegistry.t.sol)
- [`test/StealthAnnouncementHook.t.sol`](../test/StealthAnnouncementHook.t.sol)
- [`test/integration/`](../test/integration/)
