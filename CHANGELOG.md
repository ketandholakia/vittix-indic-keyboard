## Unreleased

- Fixed stale engine key buffers, shared the sequence-length limit with the editor, and hardened layout JSON parsing so malformed input fails cleanly.
- Changed the app whitelist to fail closed when empty, so an empty whitelist no longer allows every foreground app; added warnings in the settings and tray UI before saving an empty allowed-process list.
- Added editor validation for overlong sequence keys so layouts cannot define sequences the runtime engine will never match.
- Restored batched `SendInput` behavior for multi-character Unicode output so grapheme clusters stay atomic again.
- Moved the `FromJSON` nil-check inside the allocation guard so malformed layout JSON now frees the partially constructed layout instead of leaking it.
- Removed dead translator code, routed typing through the shared SendInput helper, and added basic logging around hook and layout initialization.
- Tightened small robustness issues in engine state initialization and backup naming so repeated runs do not overwrite recent backups.
- Manual repro for the key-buffer bug: type a direct consonant such as `k`, then type a sequence starter/prefix that previously left residue in `KeyBuffer`, and then type the matching conjunct trigger. Before the fix, the stale buffer could combine into the wrong sequence; after the fix, the direct mapping clears the buffer and the expected glyph path is preserved.
