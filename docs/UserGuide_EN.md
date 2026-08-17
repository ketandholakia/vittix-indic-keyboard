# Vittix Indic Keyboard Layout File Guide

This guide explains how to create and edit keyboard layout JSON files used by the Vittix Indic Keyboard application.

## Where layout files go

Place layout files under:

```text
layouts\<group>\<layout-name>.json
```

Examples:

```text
layouts\devnagari\krutidev_010.json
layouts\gujarati\remington.json
layouts\custom\press_custom_1.json
```

At runtime, the keyboard app loads all `*.json` files under the configured layouts folder, including subfolders. The subfolder name becomes the layout `Group` shown in the app.

## Minimum valid layout file

Use this as a starting template:

```json
{
  "layout_id": "my-layout-id",
  "name": "My Layout",
  "script": "Devanagari",
  "encoding": "legacy",
  "font_family": "My Font",
  "layout_type": "standard",
  "properties": {},
  "direct": {},
  "prebase": {},
  "postbase": {},
  "modifiers": {},
  "sequences": {}
}
```

An empty file is invalid. The root JSON value must be an object.

## Top-level fields

### `layout_id`

Unique internal identifier for the layout.

Example:

```json
"layout_id": "krutidev-010"
```

### `name`

User-facing display name.

Example:

```json
"name": "KrutiDev Devanagari 010"
```

### `script`

The script/language family.

Known values used in the project:

- `Devanagari`
- `Gujarati`
- `Tamil`
- `Bengali`
- `Kannada`
- `Malayalam`
- `Oriya`
- `Punjabi`
- `Telugu`
- `Sinhala`

### `encoding`

Describes the font/output style.

Common values:

- `legacy`
- `unicode`

### `font_family`

The font name expected for preview/output.

Examples:

- `Kruti Dev 010`
- `Gopika`
- `SHREE-GUJ-0708`

### `layout_type`

Free-form classification string.

Examples:

- `standard`
- `remington`
- `phonetic`
- `custom`

### `properties`

Optional key-value metadata. Values must be scalar JSON values, typically strings.

Current known keys:

- `HotkeySwitch`
- `HotkeyAction`

Example:

```json
"properties": {
  "HotkeySwitch": "Ctrl+Alt+K",
  "HotkeyAction": "Toggle"
}
```

## Mapping sections

### `direct`

Maps a typed key directly to output text.

Format:

```json
"direct": {
  "a": "v",
  "k": "d",
  "h": "g"
}
```

Notes:

- Keys are case-sensitive.
- Values are strings.
- Use this for simple one-key mappings.

### `prebase`

Used for characters that should be handled before the base consonant or that need special composition behavior.

Format:

```json
"prebase": {
  "f": {
    "key": "f",
    "glyph": "િ",
    "map_type": "i-matra",
    "metadata": {}
  }
}
```

Accepted fields inside each entry:

- `key`: physical input key
- `glyph`: output glyph
- `map_type`: preferred field name
- `type`: legacy alias also accepted by the loader
- `metadata`: optional object with extra string values

Notes:

- The JSON object key and the inner `key` value should normally match.
- Older layout files in this repo often use `type` instead of `map_type`.
- If both are missing, the loader defaults to `prebase`.

### `postbase`

Maps keys to post-base vowel signs or similar output that comes after the base letter.

Format:

```json
"postbase": {
  "A": "ા",
  "i": "િ",
  "o": "ો"
}
```

### `modifiers`

Defines special modifier rules such as halant or reph behavior.

Format:

```json
"modifiers": {
  "halant": {
    "key": "\\",
    "glyph": "્",
    "map_type": "join_next",
    "metadata": {}
  },
  "reph": {
    "key": "Z",
    "glyph": "ર્",
    "map_type": "move_to_cluster_start",
    "metadata": {}
  }
}
```

Accepted fields inside each entry:

- `key`
- `glyph`
- `map_type`: preferred field name
- `behavior`: legacy alias also accepted by the loader
- `metadata`

Notes:

- Existing layouts often use `behavior` instead of `map_type`.
- If both are missing, the loader defaults to `modifier`.

### `sequences`

Defines multi-key combinations.

Format:

```json
"sequences": {
  "k\\s": "ક્ષ",
  "t\\r": "ત્ર",
  "Zk": "ર્ક"
}
```

Notes:

- Keys are sequence strings, not arrays.
- Backslash in JSON must be escaped as `\\`.
- Use this for conjuncts, ligatures, or special combinations.

## Complete example

```json
{
  "layout_id": "sample-gujarati-layout",
  "name": "Sample Gujarati Layout",
  "script": "Gujarati",
  "encoding": "unicode",
  "font_family": "Shruti",
  "layout_type": "phonetic",
  "properties": {
    "HotkeySwitch": "Ctrl+Alt+K",
    "HotkeyAction": "Toggle"
  },
  "direct": {
    "k": "ક",
    "g": "ગ",
    "a": "અ"
  },
  "prebase": {
    "f": {
      "key": "f",
      "glyph": "િ",
      "map_type": "i-matra",
      "metadata": {}
    }
  },
  "postbase": {
    "A": "ા",
    "i": "િ",
    "o": "ો"
  },
  "modifiers": {
    "halant": {
      "key": "\\",
      "glyph": "્",
      "map_type": "join_next",
      "metadata": {}
    },
    "reph": {
      "key": "Z",
      "glyph": "ર્",
      "map_type": "move_to_cluster_start",
      "metadata": {}
    }
  },
  "sequences": {
    "k\\s": "ક્ષ",
    "t\\r": "ત્ર"
  }
}
```

## Creating a new layout

1. Copy an existing layout file that is close to what you need.
2. Change `layout_id`, `name`, `font_family`, and `layout_type`.
3. Update the `direct` map first so basic typing works.
4. Add `prebase` and `postbase` mappings for vowel signs and matras.
5. Add `modifiers` for halant, reph, or other script-specific behaviors.
6. Add `sequences` for conjuncts or ligatures.
7. Save the file as UTF-8 JSON.
8. Place it under the correct `layouts\<group>\` folder.
9. Restart the keyboard app or rebuild/copy the layout into the output folder if you are testing from `build\Win32`.

## Using the Layout Editor

The Layout Editor can create and save layout files, but the saved file still follows the same JSON format described above.

Editor fields map roughly as follows:

- Layout name box -> `name`
- Font selection -> `font_family`
- Script selection -> `script`
- Properties grid -> `properties`
- Direct grid -> `direct`
- Prebase grid -> `prebase`
- Postbase grid -> `postbase`
- Modifiers grid -> `modifiers`
- Sequences grid -> `sequences`
- Hotkey fields -> `properties.HotkeySwitch` and `properties.HotkeyAction`

## Rules and limitations

- The root JSON must be an object.
- Top-level section names are case-sensitive.
- Scalar map values must be strings, numbers, booleans, or null. Objects and arrays are not accepted where a plain value is expected.
- Duplicate keys in the same JSON object are invalid and may load unpredictably.
- Empty files will fail to load.
- Invalid JSON in one file can prevent that layout from loading.
- The app scans every `*.json` file in the layouts folder tree, so do not keep broken scratch files there.

## Troubleshooting

### Error: `Layout file is empty`

The file exists but contains no JSON. Replace it with a valid object.

### Error: `Layout file does not contain a valid JSON object`

The file contains invalid JSON or the root is not a JSON object.

### Error about scalar value/object

A field like `direct`, `postbase`, `sequences`, or `properties` contains an object/array where a plain value was expected.

Bad:

```json
"direct": {
  "k": { "glyph": "ક" }
}
```

Good:

```json
"direct": {
  "k": "ક"
}
```

## Recommended workflow

For fastest results:

1. Start from an existing layout in the same script.
2. Edit only a few keys at a time.
3. Keep the file in UTF-8.
4. Test after each small change.
5. Add sequences last, after base mappings work.

## Reference files in this repo

Useful examples:

- [layouts/devnagari/krutidev_010.json](d:/ketan/github/vittix-indic-keyboard/layouts/devnagari/krutidev_010.json)
- [layouts/devnagari/shreelipi_0708.json](d:/ketan/github/vittix-indic-keyboard/layouts/devnagari/shreelipi_0708.json)
- [layouts/gujarati/remington.json](d:/ketan/github/vittix-indic-keyboard/layouts/gujarati/remington.json)
- [Keyboard/Layout/LayoutLoader.pas](d:/ketan/github/vittix-indic-keyboard/Keyboard/Layout/LayoutLoader.pas)
- [LayoutEditor/IO/LayoutJsonIO.pas](d:/ketan/github/vittix-indic-keyboard/LayoutEditor/IO/LayoutJsonIO.pas)
