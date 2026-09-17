# Phase 4 - LayoutEditor Round-Trip & Data Preservation

## 1. Executive Summary

LayoutEditor previously rebuilt `PrebaseMap` and `Modifiers` from grid values.
That replaced every `TKeyMapping`, silently resetting `map_type` and discarding
metadata. The editor now merges its grid-owned values into existing mappings,
preserving non-UI values. New mappings receive the normal collection defaults;
deleted mappings are removed and their owned metadata is freed.

## 2. Original Data-Loss Path

```text
Load JSON -> TKeyboardLayout -> LoadPrebase/LoadModifiers -> grids
  -> SyncUIToModel -> PrebaseMap.Clear/Modifiers.Clear
  -> fresh TKeyMapping with default map_type and empty metadata
  -> Save JSON -> Reload
```

The old synchronization set `MapType` to `prebase` or `modifier` and called
`InitMetadata` for every grid row. A rich mapping's original `map_type` and
metadata therefore did not survive a save.

## 3. Root Cause

`TKeyMapping` is a record containing a manually owned `TDictionary` reference.
Calling `Clear` on the mapping dictionaries neither preserved the record fields
nor released their metadata dictionaries. Recreating records from UI columns
lost fields not represented by those columns and risked leaking metadata.

## 4. Editor-Owned Fields

The prebase grid owns the mapping name/key and glyph. The modifier grid owns
the mapping name, key, and glyph. `SyncUIToModel` also owns the ordinary
string-to-string maps and layout header controls as before.

## 5. Preserved Fields

For an existing prebase or modifier mapping with the same dictionary name,
the editor preserves:

* `map_type`
* the existing `Metadata` dictionary, including all entries
* a nil metadata reference when an existing mapping has no metadata

## 6. Implementation

`LayoutEditor/Utils/LayoutMappingSync.pas` provides a small non-visual merge
helper. `SyncUIToModel` projects each grid into `TEditorMapping` values and
passes those to the helper. Existing records are updated only for `Key` and
`Glyph`; new records use the appropriate `prebase` or `modifier` default.

## 7. Ownership / Memory Safety

The helper never deep- or shallow-clones metadata. For retained mappings it
keeps the original metadata reference in the same layout dictionary. For a
deleted mapping it retrieves the record, calls `FreeMetadata`, then removes
the dictionary entry. This matches `TKeyboardLayout.Destroy`, which frees the
metadata of remaining mappings. The full suite reports zero leaks.

## 8. Tests Added

`Tests.LayoutEditor.MappingSync` adds six regression tests:

* prebase edit preserves custom `map_type` and metadata
* modifier edit preserves custom `map_type` and multiple metadata values
* removal deletes the mapping
* a new mapping receives the collection default and empty metadata
* an existing mapping with nil metadata remains nil
* rich mappings survive synchronize -> JSON serialize -> reload while glyphs change

## 9. Edge Cases

Existing empty/nil metadata, populated metadata, multiple metadata values,
non-default map types, edits, deletions, and new mappings are covered. The
same merge behavior is applied to both mapping collections rebuilt by the
editor: prebase and modifiers. A replacement under a new dictionary name is a
new mapping and therefore intentionally receives normal defaults; it does not
inherit metadata from an unrelated entry.

## 10. Verification

The suite grew from 130 to 136 tests because of the six regression tests.
Both complete `verify.bat` runs passed:

```text
Tests:              136 passed, 0 failed, 0 errored, 0 leaked
Keyboard build:     PASS
LayoutEditor build: PASS
Layout validation:  PASS (9 layouts)
Installer:          PASS
Whitespace:         PASS
Verification run 1: PASS
Verification run 2: PASS
```

The installer continues to emit its pre-existing advisory/deprecation
warnings, but compiles successfully.

## 11. Files Changed

* `LayoutEditor/Utils/LayoutMappingSync.pas` - preservation merge and deletion ownership handling.
* `LayoutEditor/Forms/frmEditorMain.pas` - replaces destructive prebase/modifier rebuilds with the merge helper.
* `LayoutEditor/VittixIndicEditor.dpr` - includes the helper in the editor build.
* `Tests/Tests.LayoutEditor.MappingSync.pas` - focused regression tests.
* `Tests/VittixIndicTests.dpr` and `.dproj` - include the new test/helper in the test build.

## 12. Remaining Risks

The grid has no independent stable identity for a renamed dictionary key. Such
a rename is treated as deletion plus a new mapping, so it correctly frees the
old metadata and gives the new mapping defaults. This is the smallest behavior
consistent with the present UI; preserving metadata across a rename would
require the UI to expose or retain row identity.

## 13. Final Recommendation

READY FOR REVIEW
