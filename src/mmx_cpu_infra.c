#include "common_cpu_infra.h"
#include "mmx_rtl.h"

const RtlGameInfo kSmwGameInfo = {
  .title = "smw",
  .initialize = NULL,
  .run_frame = &RunOneFrameOfGame,
  .draw_ppu_frame = &MmxDrawPpuFrame,
  .save_name_prefix = "save",
  /* .sav v5: persist the fiber scheduler's task-resume contexts and rebuild
   * the fibers after load — states become loadable from any game mode and
   * from a fresh process. */
  .state_save_extra = &MmxStateSaveExtra,
  .state_load_extra = &MmxStateLoadExtra,
  .on_state_loaded = &MmxOnStateLoaded,
};
