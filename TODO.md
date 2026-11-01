# TODO

- `make check` (`tools/check-source`) dies at its first compile, `--emit-llvm tests/package-import.ab`, seen
  2026-11-01 with ablac 0.2.27. "Illegal instruction" is ablac's own: `tests/package-import.ab` imports all of
  `src/esp32.ab`, which needs over 4 GiB, and `build/ablac` caps itself at 4096 MB (`ABLA_MAX_MEMORY_MB`). With
  `ABLA_MAX_MEMORY_MB=16000` it gets as far as 79 semantic errors, the same on ablac 0.2.25, so nothing after that
  first compile has been checked: calls whose module isn't imported (`common_esp32.ab` to
  `esp32RecoveredI2sPlatformAcquireOccupation`, `sntp_esp32.ab` to `esp32RecoveredSntp*`, `esp32Clock*`),
  initialization cycles among recovered data (`esp32Data_*`, vtables in `src/esp32/storage`), and
  `region.noescape-effect` on `nvs_flash_init`, `esp_sleep_enable_ext0_wakeup` and `esp_deep_sleep_start`. It
  needs a lower memory need or a higher cap in the script as well as those errors fixed.
- `tools/build-example imu` and `led-paper-mono` fail on master with 130 semantic errors, also calls whose module
  isn't imported (`esp32RecoveredUxListRemove`, `esp32RecoveredAtomicLoad8`, ...) from `src/esp32/freertos`,
  `clock`, `cpu`, `system`, `gpio`, all files that came with `a584e2c`. Seen with ablac 0.2.27. mono-life's and
  `tools/build-callable-example`'s builds work, so `make <example>` is what's broken, not the firmware.
