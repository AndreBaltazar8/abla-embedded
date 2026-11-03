# TODO

- Recovered radio unit: `llc` aborts once on each run of `tools/build-recovered-radio`
  (`tools/esp-llvm-bin/llc` line 164), and the object still comes out. Moved from NovaKind
  on 2026-11-03; the build scripts belong here. Recheck against the current wrapper.

- `make imu-offsets` aborts in the Xtensa `llc` ("Cannot scavenge register without an emergency spill slot", on
  nvs `Storage::writeItem`). It's an LLVM bug: ablac's TODO.md has it, with the fix on its branch
  `llvm-xtensa-lea-scavenging`, waiting for a new prebuilt LLVM. With that `llc` it builds and links.
- `make wifi-connect` hits that abort too, then has two more problems. The Abla object needs over the compiler's
  4 GiB cap (it built with `ABLA_MAX_MEMORY_MB=12000`), and it doesn't link on the PlatformIO Arduino SDK (IDF 4.4),
  which lacks `_rtc_fast_reserved_*`, `_rtc_slow_reserved_*` and more. It needs moving to ESP-IDF 6.
- `make atom-echo` doesn't link for the same reason: `src/m5stack/atom_echo.ab` reaches the IDF 6 modules
  (`i2c_idf6.ab`, `sleep.ab`, `gpio.ab`), whose `linker_layout_esp32.ab` names symbols Arduino's linker script lacks.
- `make charger-aw32001` fails with `cannot lower ... nativeXtensaCoreId`: it builds for the C6 but imports the classic
  ESP32's `i2c_idf6.ab` and `serial.ab`, through `src/power/aw32001.ab` and `bq27220.ab`. The C6 has no `I2cBus`
  backend behind `i2cMaster` yet, only the software session in `i2c_session_esp32c6.ab`.
- `tools/build-callable-example` fails on 14 of 808 examples, the same on origin/master before these fixes (seen
  2026-11-01). Undefined 64-bit helpers on RV32: `__lshrdi3` (`esp32c5-spi-master`, `esp32c5-spi-pins`,
  `esp32c5-wake-pad`, `esp32c5-wake-session`, `esp32c61-spi-master`, `esp32c61-spi-pins`), `__ashldi3` (`imu-clock-c5`,
  `imu-clock-lp-c5`, `toughc5-rtc-interrupt`), `__udivdi3` (`corematrix-tone-controls`, `pmic-battery-level`).
  `esp32s3-sleep-quiesce` and `esp32s3-sleep-scheduler` stop after `place-internal-closure` reports "placed 0 sections".
  `paper-s3-sleep-cycle` fails with `call8: call target out of range` into `.iram1.abla.closure.text.*`.
- Abla's recovered code keeps its own `errno` (section `.tdata.abla_errno`), apart from the IDF libc's: an error an
  Abla-replaced libc call sets isn't seen by C code reading `errno`. The classic ESP32 images linked this way have not
  run on hardware. `src/esp32/platform_full_esp32.ab`, which replaces the libc, has to fill `.tdata.errno` again if
  it's ever linked into an image, because IDF's linker script asserts that stub's size.
- Two size checks fail, seen 2026-11-01. They couldn't run before these fixes (`radio-mac-registers` didn't compile on
  origin/master), so there's no baseline and it's unknown when they broke. `make check-xtensa-dispatcher-ownership`:
  "vendor dispatcher assembly was still selected from libxtensa.a". `make compare-radio-rx-queue-size`: "Abla Wi-Fi RX
  queue take uses more instructions than C++" (81 against 79), and it measures the Abla leaf's size as 0 bytes, so
  the leaf may be inlined away from what it looks for. The other 11 `compare-*` targets pass.
