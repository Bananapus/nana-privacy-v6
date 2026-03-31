# Changelog

## Scope

This repo is new in the v6 tree and was not part of the deployed v5 ecosystem that the top-level changelog measures.

## Current v6 surface

- `ERC5564Announcer`
- `StealthAnnouncementHook`
- `StealthRegistry`

## Summary

- The repo introduces privacy-oriented primitives into the v6 codebase instead of replacing a deployed v5 package.
- The current repo includes both standalone stealth primitives and integration tests that exercise private-payment flows against core, omnichain, and revnet scenarios.
- The repo uses the same modern Solidity baseline as the rest of the v6 tree.

## Migration notes

- There is no deployed v5-to-v6 delta to port here.
- Use this repo as a v6-only surface and regenerate any ABI or integration assumptions from the current contracts.
