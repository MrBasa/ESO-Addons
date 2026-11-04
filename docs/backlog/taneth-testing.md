# Backlog: Taneth automated tests for BasaTools suite

## Status

Deferred follow-up — **not** part of the MatLog optimization workstream. Tracked here so the idea is not lost.

## Why

[Taneth](https://www.esoui.com/downloads/info3584-1.1.0.html) (sirinsidiator; ESOUI tip is currently **2.0.0**, Mocha/busted-style) can run suites in-game (`/taneth`) and offline via [ESOLua](https://codeberg.org/sirinsidiator/ESOLua). That fits pure MatLog logic after the module split:

- Compact key / source / kind helpers (`MatLog_Data`, `MatLog_Classify`)
- LibDataEncode round-trip of a sample `matlog` tree
- Hireling subject / classify fixtures (no UI / XML)

Spies/stubs/mocks and lifecycle hooks in Taneth 2.0 make bag-diff helpers testable with fakes later.

## Non-goals

- Shipping Taneth (or ESOLua) inside the GitHub suite zip
- Driving ZO_ScrollList / XML panels under Taneth
- Blocking releases on in-game test green

## Planned layout (when picked up)

1. Install Taneth + ESOLua on the maintainer workstation (Linux path notes for Proton/ESOLua).
2. Add a repo `tests/` tree (e.g. `tests/MatLog_Data_spec.lua`) that early-returns if `Taneth` is missing.
3. Exclude `tests/` from [`scripts/package_basatools_suite.sh`](../../scripts/package_basatools_suite.sh).
4. VS Code / Cursor task: run Taneth offline against MatLog modules (+ stubs for game APIs as needed).
5. Optional: document `/taneth MatLog` for in-game smoke after a Steam deploy.

## Prerequisites from optimization work

- MatLog split into `MatLog_*.lua` modules (done)
- Compact SV + LibDataEncode path (done)
- Shared helpers on BasaTools (done)
