# ESO API stubs: wiki enrichment (Phase B proposal)

This repository generates LuaLS/EmmyLua stubs in [`.shared/eso-api-stubs/eso_api.lua`](../.shared/eso-api-stubs/eso_api.lua) from **UESP ESO Data** plus a small **hand-maintained** prefix. **Phase A** (current) adds optional `---@see https://wiki.esoui.com/wiki/...` lines using [`.shared/eso-api-stubs/wiki_title_map.json`](../.shared/eso-api-stubs/wiki_title_map.json) and simple name heuristics.

## Phase B — short summaries in hovers

**Goal:** Improve IntelliSense beyond a bare wiki link by pulling a **short plain-text excerpt** from the [ESOUI wiki](https://wiki.esoui.com/) into `---` comment lines above stubs.

**Suggested approach**

1. **MediaWiki API** — Use `api.php` on `wiki.esoui.com` (or the site’s documented API entry point) with `action=query` + `prop=extracts` or `revisions`, rather than scraping HTML, to get stable structured content.
2. **Local cache** — Store responses under something like `.shared/eso-api-stubs/.wiki-cache/` (gitignored) as JSON keyed by normalized wiki title, so regeneration does not hammer the wiki and works offline after the first fetch.
3. **Extraction** — Take the **lead section** or first paragraph only (avoid huge hovers and multi-megabyte stub files).
4. **Rate limits** — Throttle requests; batch where the API allows; respect `robots.txt` / site terms.
5. **Mapping** — Reuse and extend `wiki_title_map.json`; Phase B may need a **merge** step: UESP symbol → wiki title → cached extract → Lua `---` lines.
6. **Fallback** — If no extract is available, keep Phase A `---@see` only.

**Out of scope for Phase B**

- Inline full wiki article bodies in `eso_api.lua` (hurts LuaLS performance and repo size).
- Fuzzy full-text search over the entire wiki without maintenance budget (consider that a later “Phase C”).

## References

- Stub generator: [`scripts/generate_eso_api_stubs.py`](../scripts/generate_eso_api_stubs.py)
- Cursor rule: [`ESO-LuaAPI-RULE.md`](../../.cursor/rules/ESO-LuaAPI-RULE.md)
