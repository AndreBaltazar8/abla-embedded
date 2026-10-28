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

## Status (2026-10-28): recovered libnet80211 + libpp + libcoexist run on hardware

`tools/recover-member esp32s3 <archive> all` lifts every member;
`tools/assemble-recovered-unit esp32s3 libnet80211 libpp libcoexist` builds one
Abla unit (about 85% of functions typed Abla, the rest raw Xtensa inside Abla).
Linked into mono-life (`idf.py -B build-radio -D ABLA_RADIO_OBJECT=.../unit.o`)
the link map takes no member from the three archives, and the Paper Mono
associates (WPA2), gets DHCP, completes TLS and plays the echo reply, with
beacon-timeout counts matching the stock build. Image: 997,632 bytes vs
917,024 stock (exports and raw bodies still block dead-code elimination).

Bugs found on the way, all fixed generically in the tools:

- raw-assembly callees were rewritten into zero-argument direct Abla calls
  (direct-recovered-xtensa-calls now skips them);
- switch tables: lowered automatically (discovery mode of
  lower-recovered-jump-tables, including assembler-defined, shared and
  section-local tables); tables of raw functions point at labels;
- `symbol+addend` split into `movi`+`addi` broke mergeable string sections and
  section-entry rebasing (one literal per symbol+addend via `.set` aliases;
  recovered data sections are not mergeable);
- weak functions stay weak (ESP-IDF overrides some with strong C);
- ABI-named data stays assembler-defined while raw code references it;
- memory access after `memw` is volatile (GCC's marker for MMIO); LLVM had
  narrowed a 32-bit MAC register read to `l16ui`.

### Size of the lifted code (eight archives, `EXPORTS=all`: 1,013,088 -> 1,000,224 bytes)

Lifted code is about 33% larger than GCC's for the same functions (213,860 bytes
of text in the Espressif members, 266,193 + 19,020 literal bytes from the unit).
Measured causes and the tool-side fixes (see `tools/` for each):

- every call to a recovered function passed the caller's own ten dead stack
  words (`direct-recovered-xtensa-calls`; register-only callees now get zeros):
  -4.2 KB;
- the structurizer copies a join tail into every arm
  (`merge-recovered-join-tails` hoists tails shared by the arms of an
  `if`/`when`; the function records how many call copies it merged and
  `lint-recovered-unit` credits them in DRIFT-CALL): -3.5 KB;
- LLVM inlines exported recovered functions into callers while the function
  itself must stay (`mark-recovered-noinline`): -3.2 KB;
- LLVM 23.1 never selects EXTUI or BBCI/BNONE (`esp-llvm-bin/fuse-xtensa-extui`,
  liveness-checked rewrite of the final assembly): -2.0 KB.

Not worth it: sharing literal-pool words across functions (the image keeps only
19 KB of literals; sharing saved nothing after `--gc-sections`), the opt inline
threshold, `ipsccp<func-spec>`, jump-threading/simplifycfg knobs (each within
+-2 KB). What remains is mostly register-machine overhead (twice the `mov.n`,
junk register arguments to indirect calls, 16-parameter ABI functions kept alive
by their exported aliases, so LLVM's dead-argument elimination cannot narrow them).

### Remaining Wi-Fi archives (libcore, libespnow, libmesh, libsmartconfig, libwapi)

All five are in the profiles and recover with `recover-member` (libcore 4
functions, libespnow 43, libmesh 548, libsmartconfig 98, libwapi 21; none
failed). The main "not lifted" reason is a dynamic `CALLX8` that may consume
untyped outgoing stack arguments (390 of 548 functions in libmesh), plus
assembler-owned nested definitions; those stay raw Xtensa inside Abla.
Linked with `libnet80211 libpp libcoexist libcore libespnow libmesh` the link
takes no member from any of them (image 1,007,936 bytes, +9.9 kB over the
libnet80211/libpp/libcoexist-only 998,064). libsmartconfig and libwapi are not
linked by the app at all; recovering them anyway keeps them alive through
exports (+51 kB), so leave them out of the app unit. Fix found on the way:
llvm-mc gives literal pools alignment 1, which GNU ld misplaces after odd-sized
narrow-encoded sections ("dangerous relocation: l32r: misaligned literal
target"); the llc wrapper now aligns them to 4 for esp32s3.

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

1. **Chip profile** (`tools/recovery/<chip>.toml`, done for `esp32` and
   `esp32s3`): objdump, ESP-IDF archives, ROM linker scripts and the
   reference chip. Still to move in: the fixed-address table and the
   per-corpus tables above.
2. **One driver** (`tools/recover-member <chip> <archive> <member>`, done):
   extracts the member, classifies every function (`rom`, `identical`,
   `reordered`, `layout`, `different`, `new`) against the reference chip,
   finds the reference's recovered Abla through the link selectors, then
   reconstructs and runs migrate / lift / lower boundaries / structurize until
   a round changes nothing. Writes `reuse.tsv` and `status.tsv` under
   `build/recovery/<chip>/<archive>/<member>/`; `--classify-only` stops after
   the reuse table. First runs:

   | Member | Functions | Reusable Abla | Lifted | Rounds |
   | --- | ---: | ---: | ---: | ---: |
   | `libnet80211/ieee80211_action_vendor.o` | 12 | 5 | 8 of 12 | 2 |
   | `libnet80211/wl_chm.o` | 22 | 11 | 18 of 22 | 3 |
   | `libpp/pm.o` | 147 | 15 | 124 of 144 | 3 |
   | `libpp/trc.o` | 68 | 33 | 63 of 71 | 3 |

   "Lifted" means typed Abla with `$xtensa` boundary calls left; the later
   classic passes (direct calls, data lowering, jump tables) are not in the
   driver yet, and the output has not been compiled.
3. **Reuse first**: link identical/reordered functions to the existing Abla
   (`reuse.tsv` names the file and line), generate offset tables for
   layout-only ones, and only lift the rest.
4. **Ledger per chip** (like `esp32-opaque-radio-parity.tsv`) with the same
   parity/link-boundary checks, plus a hardware run (Paper Mono for the S3).

Suggested order for the S3: driver + profile; `libnet80211`/`libpp` reuse;
lift the remainder; then PHY (new; start from the S3 ROM PHY interface and the
28 `libphy.a` members) and `libcoexist`; first hardware milestone is the same
as m5echo's (association, DHCP, TLS, audio round trip).
