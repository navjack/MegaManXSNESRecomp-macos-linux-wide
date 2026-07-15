# Implementation scratch state

## Current task

Implement the macOS-native Mega Man X Recomp build in the workspace:

- Metal rendering
- Apple GameController.framework gamepads
- Core Audio AudioUnit sound
- SDL retained on macOS only for window/event/keyboard handling
- Windows/Linux paths preserved

## Workspace/import status

- Workspace: `/Volumes/4terrybi/coding/mega-man-x-recomp`
- Upstream game tree imported from `https://github.com/mstan/MegaManXSNESRecomp.git` at main commit `243e2c42fe16d4938e8ee3123b54755cc246b2aa`.
- Framework cloned as sibling `../snesrecomp` and symlinked as `./snesrecomp`.
- Framework revision from current `snesrecomp.pin`: `f6e300193e9d68950b4982753f4169165e138e14`.
- Existing user files preserved: `PLAN.md`, `roms/`.
- Verified ROM: `roms/Mega Man X (U) (V1.1) [!].smc`.
- Verified SHA-256: `b8f70a6e7fb93819f79693578887e2c11e196bdf1ac6ddc7cb924b1ad0be2d32`.

## Edits already made

- Added `src/macos_backend.h` declaring Metal renderer, native audio, and native gamepad APIs.
- Added `src/macos_backend.m` implementing:
  - SDL Metal view + CAMetalLayer renderer.
  - Runtime Metal shader/pipeline and triple textures.
  - Aspect-preserving quad rendering with configurable filtering.
  - Default-output AudioUnit callback calling `RtlRenderAudio`.
  - Native volume/pause/shutdown.
  - `GCController` polling using `GCExtendedGamepad`.
- Local commits are being made at integration checkpoints. Baseline is
  `30f6887`; runtime integration is `c6f7b91`; native backend build/link
  checkpoint is `3aac80a`.
- Generated USA sources are present locally in ignored `src/gen/` and the
  arm64 target has configured successfully.
- Native arm64 build succeeded in `build-macos-native/` and through
  `tools/build-macos.sh --rom ... --regen --no-dmg`.
- Packaged smoke test reached `renderer initialized: metal`, native audio at
  32040 Hz, `entering main loop`, and `first frame simulated`; the deliberate
  timeout returned 124 with no runtime error.
- Packaged app contains `Contents/Frameworks/libSDL2-2.0.0.dylib` and uses
  `@executable_path/../Frameworks/libSDL2-2.0.0.dylib`. Strict codesign
  verification is valid immediately after packaging but becomes invalid after
  first launch because upstream launcher writes config/keybinds and copies the
  selected ROM into the executable directory.

## Immediate remaining work

1. Rebuild after wireless-controller discovery addition and commit final state.

## Important existing seams

- `RendererFuncs` is in `snesrecomp/runner/src/util.h` and accepts opaque `SDL_Window *`.
- `DrawPpuFrameWithPerf()` calls `BeginDraw(width,height,pixels,pitch)` then `RtlDrawPpuFrame()` then `EndDraw()`.
- `RtlApuLock()` in `src/main.c` locks `g_audio_mutex`; native AudioUnit callback must not take an outer audio mutex before calling `RtlRenderAudio`.
- Existing SDL audio callback owns a buffer and calls `RtlRenderAudio`; Apple path should bypass that buffer and render directly into AudioUnit output.
- Existing SDL controller state is accumulated in `g_pad_buttons`; native path can populate equivalent player input words once per frame.

## Toolchain

- Darwin arm64 host.
- CMake `/opt/homebrew/bin/cmake`, version 4.3.4.
- `/usr/bin/clang`.
- Metal compiler available through `xcrun --find metal`.
