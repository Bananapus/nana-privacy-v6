# Architecture

## Purpose

`nana-privacy-v6` adds optional privacy building blocks on top of existing Juicebox flows. It does not try to redesign the core protocol. Instead it combines stealth-address announcements with fixed-denomination tiering patterns so projects can get recipient privacy, and, when paired with external ZK infrastructure, payer privacy as well.

## Boundaries

- The repo owns stealth meta-address registration and on-chain announcement.
- It does not provide the ZK payer layer; that is expected to come from external systems such as Railgun.
- Amount privacy is largely a configuration pattern built on `nana-721-hook-v6`, not a new accounting primitive.

## Main Components

| Component | Responsibility |
| --- | --- |
| `StealthRegistry` | Stores stealth meta-addresses by account and scheme |
| `ERC5564Announcer` | Stateless event emitter for stealth announcements |
| `StealthAnnouncementHook` | Pay hook that reads metadata and emits the announcement event |
| interfaces | Minimal EIP-5564 and registry surfaces |

## Runtime Model

```text
recipient publishes a meta-address
  -> payer derives a stealth destination off-chain
  -> payer submits a normal Juicebox payment with stealth metadata
  -> project's pay-hook stack includes StealthAnnouncementHook
  -> the project mints or routes value to the stealth address
  -> the hook emits the announcement the recipient needs to discover the payment
```

## Critical Invariants

- The hook should be side-effect-light. Its main job is to emit a correct announcement, not to own funds.
- Privacy depends on composition. If tier configuration leaks unique amounts or the payer path is public, the overall system is less private even if the hook works.
- Metadata conventions must stay stable across deployers and frontends for stealth discovery to work.

## Where Complexity Lives

- The contracts are small, but correctness depends on off-chain participants preparing and consuming the same metadata correctly.
- The real architectural difficulty is composition with external privacy systems and tier configuration discipline.

## Dependencies

- `nana-core-v6` pay-hook semantics and metadata encoding conventions
- `nana-721-hook-v6` when fixed-denomination privacy tiers are used
- External ZK systems for payer privacy

## Safe Change Guide

- Keep the contracts minimal. Privacy features are brittle when they become operationally clever.
- If you change metadata layout, update every deployer and client that prepares or reads stealth payloads.
- Do not accidentally introduce stateful funding logic into the announcement hook.
