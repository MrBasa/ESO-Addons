## Purpose

SavedVariables / data-shape migrations for the BasaTools suite (MatLog, LibScanner, shell settings, etc.).

## Operator messaging (required)

Whenever an **in-addon data migration** runs (schema rewrite, encode cutover, one-shot SV transform — not routine `PersistLog` / prune):

1. Call **`BasaTools.NotifyMigration(addonName, description, phase [, detail])`** from [`BasaToolsShared.lua`](../../BasaTools/BasaToolsShared.lua).
2. Emit **`phase = "start"`** before mutating SavedVariables / in-memory trees.
3. Emit **`phase = "ok"`** on success (optional short `detail`, e.g. row counts).
4. Emit **`phase = "fail"`** on failure with a concise `detail` (no secrets).

Messages go to system chat so the operator sees them on login / reload without opening the UI.

Do **not** spam NotifyMigration for normal encode debounce, day pruning, or UI filter writes.

## Ephemeral migrators

Prefer one-shot migrators: after a successful operator session confirms data, **delete** the migrator from the repo (or drop the import branch). Offline SV transforms (scripts) are fine for maintainer-only copies; still document what ran in chat when an in-game path exists.

## Notes

- Never bump `ZO_SavedVars:NewAccountWide` version solely to migrate — that wipes account-wide data. Use an internal schema flag or detect shape instead.
- Tools hard-`DependsOn: BasaTools`, so `NotifyMigration` is always available when MatLog / LibScanner / WritMatch load.
