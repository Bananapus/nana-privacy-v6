# Audit Instructions

This repo adds privacy-oriented payment helpers. Audit it as a metadata and announcement layer that must not silently break the underlying payment flow.

## Objective

Find issues that:
- lose or suppress expected stealth announcements
- mis-associate announcements with the wrong sender, beneficiary, or payment
- let malformed registry or announcement data corrupt private payment flows
- introduce reentrancy or denial-of-service around hook-based announcement logic

## Scope

In scope:
- `src/ERC5564Announcer.sol`
- `src/StealthAnnouncementHook.sol`
- `src/StealthRegistry.sol`
- `src/interfaces/`
- deployment scripts in `script/`

## System Model

The repo provides:
- a stealth registry for recipient keys or configuration
- an ERC-5564-style announcer
- a hook that emits stealth-payment announcements during compatible payment flows

It should add privacy metadata without altering who receives funds or how much value the underlying protocol moves.

## Critical Invariants

1. Announcement correctness
If the hook accepts and processes a stealth payload, the emitted announcement must correspond to the actual intended recipient metadata.

2. No silent payment corruption
Privacy behavior must not change terminal accounting, beneficiary routing, or project balances beyond its documented metadata role.

3. Registry integrity
Stealth registry updates and reads must not let one user impersonate another user’s stealth configuration.

## Threat Model

Prioritize:
- malformed metadata
- missing or stale registry entries
- announcement suppression
- reentrancy through hook callbacks

## Build And Verification

Standard workflow:
- `npm install`
- `forge build`
- `forge test`

The existing tests are mostly direct unit and integration flows with core, omnichain, and revnet compositions. Strong findings here show privacy guarantees silently failing or wrong-party attribution in emitted announcements.
