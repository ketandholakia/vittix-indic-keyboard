# Phase 5 - Schema & Semantic Validation Hardening

## Executive Summary

Validation now has an explicit schema contract: the parser, validator, and
runtime support schema `1.0`; an omitted legacy version defaults to `1.0`; and
any other declared version is rejected. The validator also documents runtime
limits without breaking legacy layouts: multi-key sequences and unknown
modifier rules are warnings, while the opt-in cross-map diagnostic now checks
the physical key for executable modifiers.

## Evidence and Final Rules

| Rule | Runtime evidence | Final behavior | Compatibility |
|---|---|---|---|
| Schema version | Parser/runtime implement the current model only | `1.0` accepted; other or empty version is an error | Omitted legacy version defaults to `1.0` |
| Cross-map overlap | Runtime order is reph, prebase, direct, postbase, halant | Remains opt-in because shipped legacy layouts intentionally overlap maps | The diagnostic uses `halant`/`reph` physical keys, not modifier names |
| Sequences | `ProcessKeyChar` never reads `Sequences` | Valid sequence data receives a warning | Existing sequence-bearing layouts stay loadable |
| Other modifiers | Runtime executes only `reph` and `halant` | Retained legacy modifier rules receive a warning | No data is removed or normalized |

## Data Flow and Consistency

`LayoutJson` supplies `CURRENT_LAYOUT_SCHEMA_VERSION` when `version` is
missing. `LayoutLoader` and LayoutEditor both call the shared
`TLayoutValidation` implementation. Validation is observational: it does not
change maps, metadata, `map_type`, version, or sequences.

The Phase 4 mapping-preservation helper was not changed. A rich mapping test
confirms validation leaves its custom `map_type` and metadata intact.

## Tests Added

Six focused validation tests cover:

* physical-key duplicate detection for an executable modifier when enabled;
* supported default version;
* unsupported version;
* empty/invalid version;
* compatible-but-warning sequence data;
* no mutation of rich mapping metadata or `map_type`.

Existing parser tests cover legacy omitted versions and JSON round trips.
All shipped layouts were validated by the complete pipeline; legacy layouts
with overlapping maps and sequences remain compatible.

## Verification

```text
Tests:              142 passed, 0 failed, 0 errored, 0 leaked
Keyboard build:     PASS
LayoutEditor build: PASS
Layout validation:  PASS (9 layouts)
Installer:          PASS
Whitespace:         PASS
Verification run 1: PASS
Verification run 2: PASS
```

The installer has pre-existing advisory/deprecation warnings but compiled
successfully. Generated logger test files were removed after verification.

## Files Changed

* `Shared/LayoutModel.pas` - declares the supported schema version constant.
* `Shared/LayoutJson.pas` - uses the constant for legacy omitted versions.
* `Shared/LayoutValidation.pas` - enforces schema support and accurately
  diagnoses runtime-executable modifier collisions and unsupported constructs.
* `Tests/Tests.Shared.LayoutValidation.pas` - adds the six focused regression tests.
* `PHASE5_SCHEMA_SEMANTIC_VALIDATION.md` - this report.

## Remaining Risks

General multi-key sequence execution and non-`reph`/`halant` modifier behavior
remain unsupported runtime features. They are retained for compatibility and
reported as warnings rather than silently claimed as executable.

## Final Recommendation

READY FOR REVIEW
