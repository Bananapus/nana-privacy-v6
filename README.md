# Nana Privacy V6

`nana-privacy-v6` provides privacy-oriented helper contracts for Juicebox V6. It focuses on recipient privacy through stealth addresses and on amount privacy through fixed-denomination 721 tiers, while leaving payer privacy to external shielded infrastructure.

Docs: <https://docs.juicebox.money>
Architecture: [ARCHITECTURE.md](./ARCHITECTURE.md)

## Overview

This package layers onto existing Juicebox deployments without changing core protocol contracts.

It separates privacy into three concerns:

- payer privacy, expected to come from an external system such as a shielded relay
- recipient privacy, provided by EIP-5564-style stealth address announcements
- amount privacy, achieved by using fixed-price 721 tiers as denomination buckets

Projects can adopt one layer or all three.

Use this repo when privacy should be added without changing core protocol contracts. Do not read it as a complete privacy system by itself; payer privacy still depends on external infrastructure.

If the issue is in core payment accounting or 721 issuance, start in the underlying protocol repo first. This package only adds the privacy-oriented layer on top.

## Key Contracts

| Contract | Role |
| --- | --- |
| `ERC5564Announcer` | Stateless announcement contract for stealth-address discovery. |
| `StealthRegistry` | Registry where recipients publish stealth meta-addresses. |
| `StealthAnnouncementHook` | Pay hook that emits stealth announcements when privacy metadata is present. |

## Mental Model

This repo is intentionally small:

1. a registry for recipient stealth metadata
2. an announcer for discovery events
3. a pay hook that bridges Juicebox payment metadata into that announcement flow

## Install

```bash
npm install nana-privacy-v6
```

## Development

```bash
npm install
forge build
forge test
```

## Deployment Notes

This repo composes with core, 721-hook, Omnichain, and Revnet deployment paths. The contracts stay small so privacy remains opt-in rather than invasive.

## Repository Layout

```text
src/
  ERC5564Announcer.sol
  StealthAnnouncementHook.sol
  StealthRegistry.sol
  interfaces/
test/
  unit and integration scaffolds for core, revnet, and omnichain compositions
script/
  Deploy.s.sol
```

## Risks And Notes

- stealth announcements hide recipient identity, not the fact that a payment happened
- fixed-denomination privacy is only as strong as the size of the anonymity set around each tier
- metadata patterns can still distinguish privacy-mode payments from ordinary ones
- payer privacy is out of scope unless the caller also uses a separate shielded execution path
