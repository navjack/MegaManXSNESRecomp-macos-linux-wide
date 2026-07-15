#pragma once

#include <stdbool.h>
#include <stdint.h>

struct RendererFuncs;
struct SDL_Window;

void MacMetalRenderer_Create(struct RendererFuncs *funcs);

bool MacAudio_Init(int requested_frequency, int requested_samples,
                   int *actual_frequency, int *actual_channels,
                   int *frames_per_block);
void MacAudio_SetPaused(bool paused);
void MacAudio_SetVolume(float volume);
void MacAudio_Shutdown(void);

void MacGamepad_Poll(bool enable_player1, bool enable_player2, int deadzone,
                     uint32_t *player1, uint32_t *player2,
                     uint32_t *active_players);
