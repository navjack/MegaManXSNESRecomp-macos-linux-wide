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
- Audio diagnosis: the first native callback called `RtlRenderAudio` once per
  Core Audio callback, incorrectly consuming one 534-native-sample SNES block
  for arbitrary callback sizes such as 512 frames. The fix restores a host-rate
  block buffer/cursor and queries the default output nominal sample rate before
  configuring AudioUnit, so partial callbacks do not advance the SNES clock.
- Follow-up hardening uses the AudioUnit negotiated client rate/channels for
  the final block-size calculation and reports device rate, negotiated format,
  and callback frame size once in the host breadcrumb log.

## NTSC-CRT + ImGui work in progress

- Vendored `third_party/ntsc-crt/` at upstream commit
  `c1fdabf4584a92314e9d7523eab124e253bda07c` and `third_party/imgui/` at
  upstream commit `b62bfd6b06de958e4630b715225b7e8409bfd0f9`.
- Added an Apple-only Dear ImGui Metal/SDL2 menu in `src/macos_ui.mm`.
  `F1` toggles it and the menu owns keyboard input while open.
- Added optional SNES NTSC encode/decode display processing to the Metal
  backend. It defaults off and exposes scanlines, phosphor blend, noise, and
  hue controls. Dot-crawl phase advances every frame.
- CMake now enables C++/Objective-C++ on Apple and compiles ImGui plus
  NTSC-CRT only for the macOS target. The arm64 Release target builds and
  links Metal, GameController, CoreAudio, AudioToolbox, and SDL2.
- README documents the mode and the macOS F1/load-state key conflict.

## Immediate remaining work

1. Commit the 4:3/integer scaling, save-state menu, and host resampler fixes
   after final status check.

## Follow-up facts from the scaling/audio audit

- The rendered game surface is 256x224 by default (240-line mode is a
  separate PPU option). macOS now presents it through a 320x240 4:3 base
  surface, selecting only integer scales and centering unused drawable space.
- NTSC-CRT receives the contiguous PPU BGRA framebuffer with its actual width
  and height, `raw=0`, color enabled, and persistent IIR/field state. The
  previous integration accidentally zeroed `NTSC_SETTINGS` every frame,
  reinitializing the filter state; that is fixed.
- The existing S-DSP path already contains the canonical BRR predictor filters
  and 4-tap Gaussian table. The host-rate conversion was nearest-sample hold;
  it now linearly reconstructs non-native output rates while retaining the
  native 534-sample cadence.
- The existing SPC700 core executes instructions with the canonical cycle
  table and correct taken-branch timing, but it is instruction-cycle stepped,
  not a sub-cycle bsnes-style micro-op core. No claim of sub-cycle accuracy is
  made without replacing that core and revalidating the APU timing surface.

## CRT/icon cleanup checkpoint

- NTSC-CRT now decodes into a 320x240 intermediate instead of the 256x224
  source-sized buffer, then the Metal path scales that result by an integer
  factor. This preserves the filter's horizontal sampling resolution and its
  4:3 output geometry.
- CRT output alpha is explicitly set opaque after demodulation because the
  library documents alpha as unused and does not write it.
- Added `assets/MegaManX.icns` and bundle `resources/Info.plist`. The icon is
  derived from the supplied in-game Mega Man X sprite screenshot and is copied
  into the app's Resources directory by CMake.

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
