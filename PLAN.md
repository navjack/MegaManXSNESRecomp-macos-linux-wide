# macOS-native Mega Man X Recomp Build

## Summary

Clone `mstan/MegaManXSNESRecomp` into the current project, add the pinned `snesrecomp` framework dependency, and produce a playable macOS build using:

- Metal for rendering
- `GameController.framework` for gamepads
- Core Audio AudioUnit output for sound
- Existing SDL2 only for the macOS window/event loop and keyboard input

The upstream project currently uses SDL2/OpenGL, SDL controllers, and SDL audio on macOS.[GitHub repository](https://github.com/mstan/MegaManXSNESRecomp)

## Key Changes

- Clone the upstream game repository into `/Volumes/4terrybi/coding/mega-man-x-recomp`.
- Clone the pinned `snesrecomp` revision into the sibling directory and create the expected `snesrecomp` link.
- Add a macOS Objective-C backend:
  - Create a Metal device, command queue, render pipeline, and triple-buffered textures.
  - Upload the PPU framebuffer each frame.
  - Render a correctly scaled 256×240 image with nearest/linear filtering based on configuration.
  - Present through SDL’s Metal view and drawable.
  - Preserve the existing renderer interface so game/runtime code remains backend-independent.
- Add native macOS gamepad handling:
  - Observe `GCController` connect/disconnect notifications.
  - Poll `GCExtendedGamepad` state once per frame.
  - Map buttons, D-pad, sticks, and triggers to the existing SNES input bit layout.
  - Apply the configured deadzone and preserve player assignment/configuration behavior.
  - Remove SDL game-controller initialization and event handling from macOS builds.
- Add native Core Audio output:
  - Use the default-output AudioUnit.
  - Configure signed 16-bit interleaved stereo output at the requested frequency.
  - Drive `RtlRenderAudio` from the AudioUnit render callback.
  - Preserve the existing APU locking and frame/audio pacing invariants.
  - Implement pause, shutdown, and volume behavior through the native audio path.
- Update CMake:
  - Compile Objective-C backend files only on Apple platforms.
  - Link `Metal`, `QuartzCore`, `GameController`, `AudioToolbox`, and required SDL2 Metal support.
  - Make Metal the default macOS output method.
  - Keep Windows/Linux SDL/OpenGL behavior unchanged.
- Update configuration and build scripts:
  - Add `OutputMethod = Metal` handling.
  - Add a macOS build target/script accepting the local ROM path.
  - Regenerate `src/gen/` from the supplied ROM before compiling.
  - Produce an `.app` bundle with the required framework linkage and `Info.plist`.
- Update README with macOS prerequisites, ROM regeneration, build commands, controller support, and native backend details.

## Test Plan

- Verify upstream clone, framework revision, and generated-source layout.
- Run ROM validation and regeneration successfully.
- Configure CMake for arm64 Release with no OpenGL dependency.
- Build the complete executable with Apple frameworks linked.
- Launch with the supplied ROM and verify:
  - Metal window creation and frame presentation.
  - Correct 4:3 scaling and filtering.
  - Keyboard controls.
  - Controller connect/disconnect and input mapping.
  - Audio output, pause/resume, and shutdown without callback errors.
  - Save/load state and fullscreen behavior.
- Run a short gameplay soak to detect audio underruns, frame pacing drift, or controller state sticking.
- Confirm the packaged `.app` launches outside the build directory.

## Assumptions

- The provided ROM is the legally dumped USA Rev 1 ROM expected by upstream.
- The macOS-native implementation is macOS-only; existing Windows/Linux backends remain intact.
- SDL2 remains a macOS dependency for windowing and keyboard/event processing.
- The first verified build targets the current Apple Silicon machine; universal packaging can be added after the native arm64 build is stable.
