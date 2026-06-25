# Mega Man X Recomp — Enhancements

Player-facing features layered on top of the base recompilation. Each is
intended to be implemented game-side (in `src/`, no hand-edits to generated
code), mirroring the `MetroidNESRecomp` synthetic-SRAM pattern.

---

## Synthesized SRAM: password persistence (planned — not yet built)

**Status: idea only. Not implemented; not currently being built.**

Mega Man X has **no battery SRAM** — progress is preserved via a password.
Because of that, the launcher's generic **SAVES panel is intentionally hidden**
for this game (`gi.sram_path = NULL` in `src/main.c`); wiring it to a
`saves/*.srm` would advertise a battery save the cartridge doesn't have.

The eventual enhancement is to give MMX the same save UX as a battery game by
*synthesizing* SRAM on top of the password system, rather than faking a battery:

- **Save-anywhere capture** — periodically run the game's *own* password encoder
  out-of-band to produce a valid password for the current progress, and persist
  it to disk (one small file next to the exe).
- **History log** — append each distinct captured password (timestamped) so the
  player can return to any earlier state by re-entering an older password.
- **Launcher display/edit** — surface the last password in the launcher's SAVES
  panel (read-only, with an edit→confirm flow), reusing the shared RmlUi
  launcher / `sram_path` plumbing rather than adding game-specific UI.
- **Auto-prefill** — on the password-entry screen, inject the saved password
  automatically so the player never has to type it.

The captured/edited value must be a *real* MMX password (correct checksum) so it
round-trips cleanly through the game's own decode.

### Reference

See `../MetroidNESRecomp/ENHANCEMENTS.md` ("Synthetic SRAM: password save
system") for the worked-out NES version of this pattern — out-of-band encoder
call bracketed by `runtime_begin/end_post_nmi()` with zero-page + WRAM scratch
snapshotted/restored, `.srm` persistence, launcher SAVES panel, and entry-screen
prefill. The MMX implementation would follow the same shape against the SNES
password engine.

**Prerequisite reverse-engineering (not yet done):** locate MMX's password
encoder/decoder routines, the WRAM password buffer, the entry-screen tick +
cursor RAM, and the gameplay gate used to decide when capture is safe.
