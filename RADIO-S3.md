# ESP32-S3 radio recovery plan

Goal: the same as `RADIO.md` for the classic ESP32: Wi-Fi as Abla source in
one LLVM unit, so the linker tree-shakes it like any other code. This page
records what the S3 shares with the classic recovery (measured 2026-10-28 on
ESP-IDF 6.0.2) and how to make recovery a repeatable per-chip pipeline instead
of a one-off.

## What the S3 shares with the classic ESP32

`tools/compare-xtensa-archives` disassembles both chips' archives with
relocations and normalizes encodings (Code Density widened, the classic
`memw` errata workaround dropped, literals resolved to what they load, branch
targets as instruction indexes). Functions present in both builds:

| Archive | Shared | Identical | Reordered | Layout only | Different | S3 only |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `libnet80211.a` | 1,097 | 320 | 97 | 164 | 516 | 64 |
| `libpp.a` | 556 | 244 | 37 | 34 | 241 | 126 |
| `libcoexist.a` | 52 | 28 | 0 | 3 | 21 | 25 |
| `libphy.a` | 0 | – | – | – | – | all 20 members |

- **Identical / reordered** (661 functions): the classic recovered Abla is
  correct for the S3 as is, once its ABI symbol is linked.
- **Layout only** (201): same logic, different structure offsets. Example:
  `chm_end_op_timeout_process` reads `g_osi_funcs_p` slot 236 on the ESP32 and
  228 on the S3 (`wifi_osi_funcs_t` is 8 bytes shorter). Reusable with a
  per-chip offset table instead of literal offsets.
- **Different** (778): includes register-allocation noise; an upper bound on
  real porting work. Refine the normalizer before treating these as new.
- **PHY**: no shared members. The S3 `libphy.a` (28 members, ~42 KB of code,
  plus `libbtbb.a`) is new work, as are the classic-only PHY/RTC/MAC-HAL files
  (`phy_chip_v7*`, `rtc_esp32.ab`, `mac_hal_esp32.ab`) and the hand-written
  `phy_rom_*` primitives.

## The S3 uses ROM much more

On the classic ESP32 these archives call ROM only for libc-level helpers. On
the S3, `libpp.a` resolves 60 of 62 external references into ROM and
`libnet80211.a` 37 of 60, mostly Wi-Fi state pointers and function tables
(`g_ic_ptr`, `g_config_func`, `BasicOFDMSched_ptr`, `coexist_funcs`). Part of
the S3 MAC lives in mask ROM. The repository already treats ROM as a
platform interface (like MMIO), so ROM-resident code needs no recovery, but
recovered code must match the ROM's data layouts exactly. The S3 ROM linker
script (`esp32s3.rom.ld`, ~127 Wi-Fi/PP/PHY entries) is the interface list.

## What the existing tooling already does on S3 input

Trial (build/s3-recovery-trial, `ieee80211_action_vendor.o` from the S3
`libnet80211.a`): `reconstruct-xtensa-object` works unchanged with
`--objdump xtensa-esp32s3-elf-objdump`; migrate + `lift-xtensa-leaves-to-abla`
+ `lower-xtensa-boundaries-to-abla` + `structurize-acyclic-recovered-functions`
lifted 8 of 12 functions to typed Abla with no tool changes. The remaining 4
are the cases the classic recovery handled in later passes (dynamic `callx8`
stack arguments, module data definitions).

Classic-only assumptions to parameterize (from a tooling survey):

- archive paths `esp_wifi/lib/esp32/...` and per-corpus tables in
  `lower-recovered-jump-tables` (`DISPATCHES`), `lower-recovered-constant-pools`
  (`POOLS`), `lower-xtensa-tail-forwards-to-abla` (`FORWARDS`),
  `repair-lifted-function-entry-offsets`, `reconstruct-xtensa-object`
  (`COMPATIBILITY_SYMBOLS`);
- `lower-esp32-fixed-addresses` (`FIXED`: classic peripheral and ROM-data
  addresses such as UART0 0x3FF40000);
- the `esp32Recovered` / `esp32Data_` naming and `src/esp32/...` outputs;
- `direct-recovered-xtensa-calls` ABI-to-Abla mapping (classic modules);
- `tools/idf/xtensa-monolithic-link.cmake` (returns unless `IDF_TARGET` is
  `esp32`), `prepare-esp32-vector-literals`, `check-classic-clock-link`.

## Making recovery repeatable per chip

1. **Chip profile** (`tools/recovery/<chip>.toml` or similar): objdump, archive
   root, output directory/prefix (`src/esp32s3/...`, `esp32s3Recovered`), ROM
   linker scripts, fixed-address table, and the per-corpus tables above moved
   out of the tools.
2. **One driver** (`tools/recover-member <chip> <archive> <member>`) running
   the existing passes in order to a fixpoint, instead of by hand.
3. **Reuse first**: run `compare-xtensa-archives` against an already recovered
   chip; link identical/reordered functions to the existing Abla, generate
   offset tables for layout-only ones, and only lift the rest.
4. **Ledger per chip** (like `esp32-opaque-radio-parity.tsv`) with the same
   parity/link-boundary checks, plus a hardware run (Paper Mono for the S3).

Suggested order for the S3: driver + profile; `libnet80211`/`libpp` reuse;
lift the remainder; then PHY (new; start from the S3 ROM PHY interface and the
28 `libphy.a` members) and `libcoexist`; first hardware milestone is the same
as m5echo's (association, DHCP, TLS, audio round trip).
