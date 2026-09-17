# Vittix Indic Keyboard - Tray menu and Layout Editor redesign

Design deliverables that accompany the review in [`../docs/UI_UX_IMPROVEMENT_PLAN.md`](../docs/UI_UX_IMPROVEMENT_PLAN.md).

## Files

| File | What it is |
|---|---|
| `V1 Vittix Tray and Editor Redesign-Infinite Canvas.html` | Full design delivery: project brief, the design token set, and six screens (tray menu, three editor modes, empty state, settings dialog). Pan, zoom, drag. |
| `V1 Vittix Tray and Editor Redesign-Interactive Prototype.html` | Clickable target design. Open the tray menu from the taskbar, switch sections, edit a mapping, run validation. |
| `archive/` | Previous versions. Nothing is overwritten in place; each revision moves the active file here first. |

## How to open

Open either `.html` file directly in a browser. No build step, no dependencies, no server.

## What the interactive prototype actually does

Tray (bottom-right of the taskbar):

- Click the tray icon to open the menu; click away or press `Escape` to close.
- `Typing enabled` toggles the engine. The icon, the tooltip, the status line and the menu checkmark all follow.
- `Layouts` and `Allowed apps` expand in place. Picking a layout updates the header and the checked radio.
- Toggling an allowed app updates the list immediately instead of after a rebuild.

Editor:

- The rail switches between Direct, Prebase, Postbase, Modifiers, Sequences (legacy), Keyboard and Output preview.
- The search filters rows and reports `n of 412`. Zero matches produces a real empty state with a clear action, not a blank table.
- Clicking a row or a key on the virtual keyboard drives the inspector. The inspector shows where the glyph resolves from and warns before a direct entry shadows a prebase mapping.
- `Apply` writes the change, marks the document modified and enables Undo. `Revert` restores the stored value.
- `Validate` populates the Problems dock. Clicking an issue selects the offending row.
- `New` and `Open` ask before discarding unsaved changes.

## Deliberate scope

- The prototype models the mapping table, not the full 412-entry layout. It ships 12 representative rows plus live filtering, editing, undo, validation and section switching.
- Light theme only. The token set is the seam for a dark variant later.
- No photographic assets: a keyboard layout editor has no image content, so the surfaces are drawn entirely with type, rules and shape.
