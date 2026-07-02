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

---

## LLE task-scheduler tier: production-readiness (deferred — infra built, not shippable yet)

**Status: swappable HLE/LLE built and validated as a dev/accuracy tier
(`SNESRECOMP_MMX_SCHED_LLE=1`, default HLE). NOT yet production-shippable.**

The MMX cooperative task scheduler at `$00:8099` can now run two ways (see
`RunOneFrameOfGame` in `src/mmx_rtl.c`):

- **HLE (default):** `MmxSchedulerTick` — a hand-written C-host scheduler with
  per-slot Windows fibers for coroutine resume. Fast; ships today.
- **LLE (`SNESRECOMP_MMX_SCHED_LLE=1`):** runs the *real* `$8099` scheduler under
  interp816 via `interp_bridge_run_scheduler` (engine `interp_bridge.c`), yielding
  at the `$8080A1` vblank-spin. The interpreter handles the infinite loop,
  coroutine stack-switching, and `JMP ($0032,X)` dispatch faithfully.

Co-sim finding: the LLE stays aligned with the bsnes oracle noticeably longer
than the HLE, confirming it is the more faithful path. But it is **not yet
shippable**, for two reasons:

1. **Performance — no-bounce interpretation.** The scheduler LLE currently runs
   in "no-bounce" mode (interpret *everything*, never bounce `JSR` targets to
   compiled bodies), because the yield primitive `$808100` is a coroutine switch
   that saves S and `BRA`s back into the loop without returning — bouncing it via
   the paired ABI corrupts the stack. Pure interpretation is correct but
   **slideshow-slow in gameplay** (attract/intro is watchable; live play crawls).
   **TODO: selective bounce** — bounce leaf game routines (which return normally)
   to their compiled bodies, and interpret ONLY the scheduler + coroutine
   machinery (the `$8099` loop, `$80DA`/`$80E9` dispatch, and the `$808100`/`$810C`
   yields). This needs a "don't-bounce" PC set (or a returns-normally predicate)
   threaded into `interp_bridge_run_scheduler`.

2. **Validation surface.** LLE has only been exercised on the attract/intro via
   the headless co-sim. Shipping it requires full-gameplay validation (all game
   modes, stages, bosses, pause/menu) plus a determinism + no-regression pass.

Even fully optimized, LLE does not by itself converge to bsnes — the residual is
frame-model interrupt *timing* (NMI/raster-IRQ/scheduler interleaving), tracked
separately. So the LLE tier's value is accuracy investigation + validating/
tightening the shipping HLE, not a guaranteed player-facing win over the HLE.
