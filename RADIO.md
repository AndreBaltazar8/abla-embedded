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
counts. Core ID is 11 bytes and four instructions in both languages.

The compiler also exposes the linker-owned `_xt_interrupt_table` address as a
native `u32`; no foreign registration function is declared or called. The
target-only `src/esp32/interrupt_handler_esp32.ab` layer accepts only interrupts
dispatched at levels 1 through 3, reads PRID once, and rejects cross-core
installation. It disables only the selected line, writes the zero argument
before publishing the handler address with ordered volatile stores, then
restores the line only when it was previously enabled. The complete Wi-Fi-MAC
installer is 97 bytes and 33 instructions for Abla versus 99 bytes and 33
instructions for equivalent C++. The object has no unresolved calls; the
dispatcher table is its sole unresolved data symbol.

The opt-in `src/xtensa/dispatcher_owned.ab` module closes that data dependency
for a classic dual-core ESP32 build. Compiler lowering emits the initialized
64-entry interrupt table as interleaved `{handler, argument}` words, with the
argument initialized to its dispatcher index, plus the 128-entry exception
table. The same Abla module supplies the exact `xt_ints_on` and `xt_ints_off`
ABI required by existing Espressif libraries and vector code. Those two names
are deliberately exported because they are a real compatibility ABI; normal
Abla callers continue to use typed interrupt masks without an annotation.

`make check-xtensa-dispatcher-ownership` performs a relocatable link against
the installed classic-ESP32 `libxtensa.a`, forcing references to all four
symbols. The link map proves `xtensa_intr_asm.S.obj` is excluded while the
separate C dispatcher consumer is still selected. The tables are exactly
1,024 bytes in both implementations. Abla's enable/disable leaves are 24/27
bytes and 9/10 instructions, exactly tying the vendor assembly. This is a
build-only proof; the owned dispatcher is not linked into or flashed onto the
Atom Echo firmware yet.

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

`src/esp32/radio/tx_esp32.ab` validates that descriptors fit PLCP0's 20-bit
classic-ESP32 internal-DRAM window, then publishes buffer and null-link words
before the final DMA-ownership store. Descriptor length includes the four-byte
FCS generated by the MAC, while the checked caller range covers the MPDU. TX
status sampling exposes typed pending, complete, timeout, collision, conflict,
and invalid outcomes without allocation; terminal acknowledgement clears all
three slot bits before resetting PLCP0. `make compare-radio-tx-size` checks the
native descriptor-preparation leaf against equivalent optimized C++; both are
97 bytes and 31 instructions with no unresolved calls. Starting RF transmission
remains opt-in and has not been run on the connected Atom Echo.

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
- [ESP-IDF `xtensa_intr.c`](https://github.com/espressif/esp-idf/blob/master/components/xtensa/xtensa_intr.c)
  and
  [`xtensa_intr_asm.S`](https://github.com/espressif/esp-idf/blob/master/components/xtensa/xtensa_intr_asm.S),
  used to verify the public two-word dispatcher layout, interrupt-level gate,
  and core-interleaved table indexing

No vendor archive code or disassembly is copied into the project. Archive
symbols, relocations, and instructions are evidence for dependency mapping and
differential tests. Source implementation comes from public register facts,
permissively licensed open drivers, protocol specifications, and behavior
measured on owned hardware.

The compiler and framework now produce a typed, native no-argument Xtensa
handler entry from a named top-level Abla function and install it directly.
The entry, its literal pool, and its direct Abla call graph reside in
`.iram1.*`; the build-only Wi-Fi MAC acknowledge handler ties equivalent C++
at 21 bytes and 8 instructions. Both occupy 29 total code-plus-literal IRAM
bytes. No export, boxed function value, C trampoline, registration call, or
unresolved call remains. The optional Abla-owned dispatcher module also closes
the table and interrupt-mask assembly boundary in a relocatable link. The
Xtensa vector object, the C dispatcher management/unhandled routines, and
platform startup still remain external boundaries.

The remaining dependency order is:

1. replace the remaining vector assembly and C dispatcher
   management/unhandled routines, then add interrupt-safe shared-clock
   ownership;
2. hardware-validate the implemented bounded RX removal/recycling path and TX
   ownership/outcomes, including the open driver's RX sentinel fallback;
3. open 802.11 management, authentication, association, and remaining data
   framing on top of the implemented common header fields and FCS;
4. hardware crypto plus WPA2 key management;
5. PHY/AGC/channel setup, RF calibration, coexistence, and regulatory limits;
6. a native network interface and IP stack boundary.

Nothing in this module transmits, initializes the radio, or changes the
connected Atom Echo unless application code explicitly calls a trusted method.
