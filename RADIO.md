# Native ESP32 radio work

The long-term target is a Wi-Fi path whose implementation is Abla source, not
an application binding to Espressif's precompiled `libnet80211`, `libpp`,
`libcore`, `libphy`, or `libcoexist` archives. That target is not complete yet.

The common `src/esp32/dma_descriptor.ab` module implements the native 12-byte
ESP peripheral-DMA descriptor layout with ordered volatile ownership transfer.
It is reusable by radio, I2S, SPI, camera, and other DMA-backed drivers.

`src/esp32/dma_descriptor_chain.ab` adds the null-terminated RX chain used by
the open ESP Wi-Fi driver. Its native-width core validates aligned 32-bit
descriptor and buffer ranges, rejects zero or excessive counts, proves both
last descriptor and last buffer cannot wrap, and publishes buffer and next
words before DMA ownership. The allocation-free packed chain handle remains
available for stateful consumers, while drivers with an already validated DMA
allocation can stay entirely in `u32` arithmetic. `make compare-rx-chain-size`
checks the exported 1600-byte Wi-Fi-buffer leaf with the exact compiler and
flags used for the C reference; the current Xtensa result is 114 bytes for
Abla versus 117 bytes for C, with no unresolved calls. When an Espressif GCC
`xtensa-esp32-elf-objdump` is available (or supplied as `XTENSA_OBJDUMP`), the
same gate also disassembles just those symbols; the current result is 42 Abla
instructions versus 43 C instructions.

The board-independent `src/wifi/ieee80211_logic.ab` module defines zero-storage
`u16` frame-control and sequence-control fields with typed accessors. The
reusable `src/checksum/crc32.ab` module implements reflected CRC-32/ISO-HDLC;
`src/wifi/ieee80211.ab` exposes it as the allocation-free 802.11 frame check
sequence over an existing DMA range. `make compare-wifi-fcs-size` checks the
same volatile-byte algorithm under identical Xtensa flags. The current leaf is
180 bytes and 54 instructions for Abla versus 184 bytes and 56 instructions
for C, with no unresolved calls.

The opt-in `src/esp32/radio/power_esp32.ab` module implements classic ESP32
power-domain, shared/Wi-Fi clock, reset, and MAC-state register primitives.
`src/xtensa/cpu.ab` supplies a compiler-lowered CCOUNT read and bounded delay,
so `powerOn(cpuFrequencyMegahertz)` performs the documented 10-microsecond
power-up interval without an ESP-IDF, ROM, C, or C++ call. The split operations
remain available for a scheduler-owned timer. Shared-clock ownership must also
be serialized by the caller; the framework does not silently add global state
or pretend that PHY initialization is complete.

`make compare-radio-power-size` compiles an equivalent C leaf with the same
Espressif LLVM target, CPU, optimization, section, frame-pointer, and unwind
settings. It compares only each function's `.text` and `.literal` sections and
fails if Abla grows beyond C. The first checked result is 169 bytes for each;
the emitted 141-byte bodies and 28-byte literal sections are byte-identical.

`src/xtensa/cpu.ab` also exposes nominal, single-register CPU interrupt numbers
and `u32` masks, the current core ID, and race-safe enable/disable operations.
The compiler lowers those operations directly to `rsr.prid`, `xsr.intenable`,
`wsr.intenable`, and `rsync`; there is no `xt_ints_on`, `xt_ints_off`, RTOS, or
C ABI dependency. `src/esp32/interrupt_matrix_esp32.ab` independently maps any
of the classic ESP32's 69 peripheral sources to either CPU through DPORT MMIO,
including the Wi-Fi MAC source and its conventional CPU interrupt line. It has
no import-time hardware side effect. `make compare-xtensa-interrupt-size`
checks equivalent C++ leaves under identical flags: enable is 24 Abla bytes
versus 25 C++ bytes and disable is 27 versus 28, with equal 9/10 instruction
counts. Core ID is 11 bytes and four instructions in both languages. The Abla
object has no unresolved calls.

`src/esp32/radio/rx_esp32.ab` validates a completed RX descriptor before any
frame is exposed: CPU ownership, successful EOF, 32-byte hardware header,
length within capacity, bounded 32-bit buffer address, and both legacy/HT
signal-length fields at header offset `0x18`. It samples descriptor flags once
and reads the signal word only after the bounds checks. The reusable logic is
separate for host tests. `make compare-radio-rx-size` compares the same
volatile descriptor/header algorithm against C++; after keeping addresses in
the ESP's native `u32` width, the current leaf is 103 bytes and 35 instructions
versus C++ at 108 bytes and 37 instructions, with no unresolved Abla calls.

`src/esp32/radio/rx_queue_esp32.ab` adds a zero-allocation view over 8 bytes of
caller-owned internal RAM. Removal and recycling are explicit two-phase
transactions around `RX_DESCR_RELOAD`: bounded polling can time out without
losing the old first descriptor or appending a buffer twice, and a detached
descriptor's stale link is cleared before DMA ownership is republished. Two
alignment bits in the last pointer encode the transaction kind. The caller
must serialize this trusted state against the Wi-Fi interrupt. The
native-width take leaf is 220 bytes/78 instructions versus equivalent C++ at
223/79, with no unresolved calls. The public open driver contains an unusual
`RX_DESCR_NEXT == 0x3ff00000` recycling fallback; that behavior remains a
hardware-validation item instead of being presented as verified here.

The first MAC slice is `src/esp32/radio/mac_esp32.ab`. It directly implements
the classic ESP32 MAC register operations for interrupt causes, RX DMA list
control, four-interface BSSID/receiver filtering, five TX queues, PLCP
parameters, and the MAC timer. Importing it has no hardware side effect, and
whole-program DCE removes it when the default package consumer does not use
native radio operations. It remains opt-in at runtime until shared-clock
ownership, PHY/calibration, and a complete interrupt-driven DMA path exist.

The register topology was independently expressed from these permissively
licensed source references:

- [`esp32` PAC 0.40.2](https://github.com/esp-rs/esp-pacs/tree/main/esp32),
  generated register descriptions (MIT or Apache-2.0)
- [`esp-wifi-hal`](https://github.com/esp32-open-mac/esp-wifi-hal)
  0.3.2 at commit
  `4347cf13adc907962cf9e21735c7cc8c943f6e1f` (MIT or Apache-2.0)
- [`esp32-open-mac`](https://github.com/esp32-open-mac/esp32-open-mac)
  at commit
  `20ce43d595be914b4d3f553b28352bc07e003fa1` (MIT)

No vendor archive code or disassembly is copied into the project. Archive
symbols, relocations, and instructions are evidence for dependency mapping and
differential tests. Source implementation comes from public register facts,
permissively licensed open drivers, protocol specifications, and behavior
measured on owned hardware.

The remaining dependency order is:

1. bind typed Abla interrupt handlers into the linker-owned Xtensa vector table
   without a C trampoline, then add interrupt-safe shared-clock ownership;
2. hardware-validate the implemented bounded RX removal/recycling path,
   including the open driver's sentinel fallback, then complete TX ownership;
3. open 802.11 management, authentication, association, and remaining data
   framing on top of the implemented common header fields and FCS;
4. hardware crypto plus WPA2 key management;
5. PHY/AGC/channel setup, RF calibration, coexistence, and regulatory limits;
6. a native network interface and IP stack boundary.

Nothing in this module transmits, initializes the radio, or changes the
connected Atom Echo unless application code explicitly calls a trusted method.
