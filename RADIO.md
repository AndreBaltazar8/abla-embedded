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

`src/wifi/ieee80211_management_logic.ab` adds allocation-free management
subtypes and capability fields, bounded information-element iteration and
construction, supported-rate and channel elements, and RSN suite parsing and
construction. Its RSN surface represents the complete standard cipher and key
management selectors needed by WEP/TKIP compatibility, WPA2 personal and
enterprise, SAE/WPA3, OWE, FILS, Suite B, and protected management frames;
this is protocol representation and validation, not a claim that their crypto
or state machines are already complete. The same primitives serve scan/STA
and beacon/probe/association/SoftAP paths. A native-width structural validator
keeps a validated ESP packet address and length in `u32`; it is 156 bytes
versus equivalent C++ at 158, with both at 59 Xtensa instructions and no
unresolved calls. `make compare-wifi-management-size` enforces both gates.
Packed 48-bit MAC addresses and writers for the common three-address header,
open/shared/FT/SAE/FILS authentication body, association and reassociation
requests/responses, beacon/probe fixed fields, and disassociation/deauthentication
reasons now make those paths construct real frames without allocation. Queue
duration, sequence allocation, action bodies, and security state remain owned
by their respective higher layers rather than hidden in the wire writer.

`src/wifi/connection_logic.ab` supplies shared STA and SoftAP transitions for
candidate selection, open/shared/FT/SAE/FILS authentication, association, key
authorization, retry exhaustion, disassociation/deauthentication, channel
iteration, and wrap-safe deadlines. Its native authentication leaf is 94 bytes
and 34 Xtensa instructions versus equivalent C++ at 109 bytes and 40
instructions, with no unresolved calls. Peer storage, cryptographic exchange,
roaming policy, and frame scheduling remain explicit higher-layer work.

`src/esp32/crypto/aes_esp32.ab` owns classic ESP32 hardware AES-128, AES-192,
and AES-256 block encryption in Abla: DPORT clock/reset sequencing, key and
text register access, bounded completion polling, and aligned native-width
input validation. The primitive deliberately requires caller serialization
because the engine is shared by Wi-Fi, TLS, SHA, secure boot, and both cores.
It has no ESP-IDF, mbedTLS, C, or C++ call. `make compare-esp32-aes-size`
checks the complete AES-128 operation against semantically equivalent optimized
C++; both currently emit 361 bytes and 118 Xtensa instructions with no
unresolved symbols.

`src/esp32/crypto/ccm_esp32.ab` builds allocation-free AES-CCM over that engine
for the 13-byte nonce and two-byte message length used by CCMP. It supports the
standard CCM associated-data encodings applicable to ESP32-addressable buffers,
AES-128/192/256 keys, even tags
from 4 through 16 bytes (plus CCM*'s zero-tag transform), caller-selected
bounded polling, constant-time tag comparison, and plaintext clearing after an
authentication failure. `src/wifi/ccmp_logic.ab` and
`src/esp32/wifi/ccmp_esp32.ab` add 48-bit packet numbers, header validation,
three- and four-address AAD, management/data/QoS nonces, CCMP-128/CCMP-256
frame transforms, mutable-header masking, SPP A-MSDU authentication, key
identifiers, strict or explicitly same-PN replay handling, and protected-bit
handling. Stable one-pointer 32-bit request entries are the hardware boundary;
they require no C trampoline and avoid passing several packed 64-bit buffer
views through the Xtensa ABI. `make compare-wifi-ccmp-size` keeps the replay
leaf at or below equivalent C++; both currently emit 72 bytes and 27
instructions with no unresolved symbols.

AES-128, AES-256, standard CCM ciphertext and tags, direct and full-frame
decrypt, replay rejection, tampered-MIC rejection, and failure clearing were
run successfully on the connected ESP32-PICO-D4. The complete stateful packet
surface was then run on the same device: caller-owned key initialization,
atomic PN reservation, out-of-place encrypt/decrypt, in-place encap/decap,
per-TID replay commit and rejection, MIC-failure rollback, and both direct and
stateful ESP-NOW zero-tag decryption all passed.

The `ieee80211_crypto_ccmp.o` row is complete at both the reusable and exact
vendor boundaries. `src/esp32/wifi/crypto_ccmp_dispatch_esp32.ab` supplies
`ieee80211_ccmp_encrypt`, `ieee80211_ccmp_decrypt`,
`ieee80211_decrypt_espnow_pkt`, and the exact 24-byte `ccmp` descriptor. Its
encap and decap callbacks use module-private C-ABI addresses rather than public
linker names. It reads the vendor-owned key/mbuf layout directly,
uses the allocation-free Abla CCM engine instead of the original
allocate-copy-free provider callbacks, and commits replay state only after
authentication. The M5Echo link map assigns all six symbols to `abla_app.o`
and does not retain `ieee80211_crypto_ccmp.o`; the image then completed WPA2
association, DHCP, server authentication, speech request, and playback on the
connected ESP32-PICO-D4. The reusable 216-byte caller-owned state and stable
request ABIs remain available to non-vendor users. ESP-NOW peer lookup remains
part of the peer-table object that supplies `get_iav_key`; it is not silently
counted as CCMP implementation work.

`src/esp32/wifi/rfid_esp32.ab` owns the complete six-function
`ieee80211_rfid.o` ABI. It reproduces the NVS mode gate and the callback slot
at `g_ic + 452`, including null rejection, reset/unregister, and the guarded
three-argument receive dispatch. The opaque archive member is absent from the
M5Echo link map; the replacement added only 16 bytes to the application image
and the device again completed WPA2, server authentication, speech, and
playback. This boundary retains no opaque algorithm of its own.

`src/esp32/wifi/legacy_crypto_esp32.ab` supplies the exact `wep` and `tkip`
descriptors with module-private encap and decap callback addresses. It preserves the
vendor key/mbuf offsets, 24-byte cipher descriptors, WEP and TKIP IV byte
ordering, global software-crypto gate, 48-bit PN progression, per-TID replay
state, and header/trailer pointer adjustment. Both original archive members
are absent from the M5Echo link map, and the combined image passed the full
WPA2 voice smoke path. These replacements currently cost 368 bytes over the
preceding image and therefore still need instruction-level size work.

The same legacy module emits the exact 24-byte `sms4` descriptor and
module-private Abla callbacks for its 18-byte WAPI header, alternating PN step, fixed
`36 5c` suffix, per-TID replay commit, and 16-byte trailer decap. The original
`ieee80211_crypto_sms4.o` is absent from the M5Echo link map and the
replacement costs 64 bytes over the preceding image. The original stale-PN
warning was routed through the separately opaque `wifi_log` boundary; until
that logger is replaced and the warning is restored, the SMS4 row remains
partial even though its archive member is no longer linked.

`src/esp32/radio/crypto_table_logic.ab` and
`src/esp32/radio/crypto_table_esp32.ab` replace the nine-symbol
`libpp.a:hal_crypto.o` boundary. The portable part round-trips interface,
cipher, key ID, algorithm selection, and peer-address fields. The ESP32 part
owns the exact `0x3ff73800` control block and 25 40-byte key slots at
`0x3ff74400`, including init, enable/disable, validity, active-key reporting,
clear, set, and get. Unaligned keys are packed directly, removing the original
allocate-zero-copy-free workaround. The object is absent from the M5Echo link
map, and live WPA2 plus the voice path passed. Warning-only alignment and
allocation messages remain part of the pending `wifi_log` replacement, so the
ledger conservatively keeps diagnostic parity partial.

`src/wifi/ieee80211_protocol_logic.ab` and
`src/esp32/wifi/ieee80211_protocol_esp32.ab` replace all seven functions and
the one-byte public setting from `libnet80211.a:ieee80211_proto.o`. The Abla
implementation preserves callback registration, TID extraction, short-slot
updates, all seven ERP-rate searches, four WME access categories and the
optional contention override, station/BSSID state, the original diagnostic,
and the state transition. Generic typed Xtensa call signatures make the
remaining radio callbacks direct LLVM calls without platform-named compiler
annotations or `extern:"c"` declarations. The member is absent from the
M5Echo map. Its five live functions use 115 instructions versus 101 in the
member; 10 of the 14-instruction delta are identical export-initialization
guards, isolating a general compiler optimization rather than hiding it in the
platform layer.

`src/crypto/block_modes.ab`, `src/esp32/crypto/cmac_gmac_esp32.ab`,
`src/wifi/bip_logic.ab`, and `src/esp32/wifi/bip_packet_esp32.ab` implement the
management-frame integrity portion of `ieee80211_crypto.o`. The portable layer
owns CMAC doubling, GHASH, constant-time comparison, management AAD, MMIE,
48-bit packet numbers, and replay state. The classic-ESP32 layer uses the
hardware AES engine for AES-CMAC and AES-GMAC with 128-, 192-, or 256-bit keys
and supports split AAD without allocation. Its one-pointer request records are
also used internally: packed buffer arguments otherwise exceed the six-word
Xtensa register window and make later stack arguments unstable.

Standard BIP-CMAC-128, BIP-GMAC-128, and BIP-GMAC-256 tags passed on the
connected ESP32-PICO-D4. The same full packet KAT passed first verification,
replay rejection, tamper rejection without committing replay state, and a
successful retry after restoring the frame.
`src/esp32/wifi/crypto_dispatch_esp32.ab` now supplies the complete retained
`ieee80211_crypto.o` ABI: attach/availability/key leaves, generic
encap/decap callback dispatch, the exact seven-entry MIC-length table, all
three BIP paths, and the writable 44-byte provider-table symbol. Its BIP path
keeps Espressif's big-endian internal replay-counter ordering while using the
allocation-free Abla CMAC/GMAC engine. The M5Echo link map assigns every ABI
symbol and the table to `abla_app.o`, does not retain `ieee80211_crypto.o`,
and the resulting image completed WPA2 association, server authentication,
speech request, and playback on the connected device. This row is complete;
the provider callbacks themselves remain separately tracked implementation
work where their original definitions live.

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
table and classic ESP32's 32-byte read-only interrupt-level table. The Abla
modules supply `xt_ints_on`, `xt_ints_off`, `xt_unhandled_interrupt`,
`xt_int_has_handler`, `xt_set_interrupt_handler`, and
`xt_set_exception_handler`, the exact ABI names required by existing
Espressif libraries and vector code. Those names are deliberately exported
because they are a real compatibility ABI; normal Abla callers continue to use
typed interrupt masks and checked installers without annotations.

The same ownership module supplies the complete low-level Xtensa interrupt
register ABI: `xthal_get_intenable`, `xthal_set_intenable`, both public names
for reading `INTERRUPT`, `xthal_set_intset`, and `xthal_set_intclear`. Normal
Abla code uses `xtensaEnabledInterrupts`, `xtensaPendingInterrupts`, and the
typed `XtensaInterruptMask` operations instead. Each typed wrapper is one
direct `rsr` or `wsr` instruction, without a foreign call, box, allocation, or
runtime helper. These operations are ordinary Abla wrappers over generic typed
inline assembly declared by `src/xtensa/assembly.ab`; that module also owns and
registers the `$xtensa` subparser. Adding an instruction or register does not
change `ablac`. The two non-windowed context leaves save and restore the
classic ESP32's 48-byte extra register state as source-owned naked Abla
functions. The same package defines the classic ESP32 register-window spill
implementation as a naked `$xtensa` leaf, selected only when the ownership
module is imported. Its three compatibility symbols follow Tensilica's permissively
licensed [window-spill source](https://chromium.googlesource.com/chromiumos/third_party/sound-open-firmware/+/refs/heads/stabilize-13099.101.B%5E/src/arch/xtensa/smp/hal/windowspill_asm.S),
specialized to the ESP32's 64 physical registers. LLVM still sees ordinary
function-local assembly and can eliminate unused paths.

The Abla unhandled-interrupt fallback is automatically placed in IRAM with its
direct call graph. Instead of calling ROM `printf` and returning to a possibly
still-asserted source, it masks the unexpected CPU interrupt line. The generic
exception panic handler remains supplied by the platform because it owns the
complete saved-frame and crash-reporting policy.

`make check-xtensa-dispatcher-ownership` performs a relocatable link against
the installed classic-ESP32 `libxtensa.a` and `libxt_hal.a`, forcing references
to all 20 owned ABI names. The link map proves `xtensa_intr_asm.S.obj`,
`xtensa_intr.c.obj`, `interrupts--intlevel.o`, and all five relevant
`int_asm--*.o` register-access members are excluded, along with
`state_asm--save_extra_nw.o`, `state_asm--restore_extra_nw.o`, and
`windowspill_asm.o`. The two
dispatcher tables are exactly 1,024 bytes and the level table exactly 32 bytes
in both implementations. Abla's enable/disable leaves are 24/27 bytes and 9/10
instructions, exactly tying the vendor assembly. All six exported register
access names tie at 8 bytes and 3 instructions apiece. The save and restore
leaves are byte-identical at 62 bytes and 25 instructions each. The primary
window-spill entry is 269 bytes/102 decoded instructions versus the HAL's
273/106, while the
35-byte wrapper matches after normalizing its identical literal/call relocation
slots. Its compatibility alias has the exact primary address, and the full unit
occupies 308 runtime bytes including the literal versus the HAL's 315. The
management/default unit is 222 runtime bytes versus vendor C at 253.
The handler query is 38 bytes/12 instructions versus 43/14; the interrupt
setter is 81/28 versus 84/28; and the exception setter is 60/21 versus 61/21.
This is a build-only proof; the owned dispatcher is not linked into or flashed
onto the Atom Echo firmware yet.

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
- [ESP-IDF 4.4.7 `xtensa_intr.c`](https://github.com/espressif/esp-idf/blob/v4.4.7/components/xtensa/xtensa_intr.c)
  and
  [`xtensa_intr_asm.S`](https://github.com/espressif/esp-idf/blob/v4.4.7/components/xtensa/xtensa_intr_asm.S),
  used to verify the public two-word dispatcher layout, interrupt-level gate,
  and core-interleaved table indexing
- [ESP-IDF Xtensa HAL declarations](https://github.com/espressif/esp-idf/blob/master/components/xtensa/include/xtensa/hal.h),
  used to verify the public interrupt-register compatibility ABI

CCMP mutable-header masking, QoS/SPP A-MSDU nonce construction, and replay
edge behavior were independently cross-checked against
[Linux mac80211 `wpa.c`](https://github.com/torvalds/linux/blob/master/net/mac80211/wpa.c).
That protocol reference is not copied into this project.

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
unresolved call remains. The optional Abla-owned dispatcher modules also close
the table, interrupt-level data, mask-helper assembly, interrupt-register HAL,
extra-state save/restore, register-window spill, and C management/default
boundaries in a relocatable link. The FreeRTOS vector/context objects, platform
exception panic path, and startup still remain external boundaries.

The remaining dependency order is:

1. replace the remaining vector/context assembly and platform exception path,
   then add interrupt-safe shared-clock ownership;
2. hardware-validate the implemented bounded RX removal/recycling path and TX
   ownership/outcomes, including the open driver's RX sentinel fallback;
3. open 802.11 management, authentication, association, and remaining data
   framing on top of the implemented common header fields and FCS;
4. finish the generic cipher dispatcher and the remaining WPA crypto-provider
   primitives around the implemented AES, CCMP-128/256, CMAC, GMAC, and BIP,
   then add WPA2 key management;
5. PHY/AGC/channel setup, RF calibration, coexistence, and regulatory limits;
6. a native network interface and IP stack boundary.

`esp32-opaque-radio-parity.tsv` is the non-prunable compatibility ledger. It
records all 62 members observed across the unpruned opaque ESP32 radio
archives, including two linked members with zero attributed image bytes, and
the 277,357 bytes attributed to the other members in the baseline firmware.
Disabling SoftAP, WPA3, enterprise, NAN, mesh, coexistence, or another feature
may prove whole-program elimination for one application, but never removes its
row or changes replacement status. `tools/check-esp32-opaque-radio-parity`
validates the fixed full inventory and can additionally reject an unknown
opaque member in a supplied `ESP32_LINK_MAP`. A row reaches `complete` only
with source, tests, and hardware evidence for its entire surface. The
six-symbol `ieee80211_crypto_ccmp.o`, full `ieee80211_crypto.o`, and full
`ieee80211.o` rows currently meet that bar. The last of those is now
`src/esp32/wifi/ieee80211_core_esp32.ab`: it owns `g_ic`, interface lifecycle,
mode transitions, PMF/SA Query, information-element parsing, transmit metadata,
and attach/detach orchestration. The original 3,836-byte archive member is not
included in the M5Echo link, and the replacement was physically verified
through WPA2 association, server authentication, speech transfer, and audio
playback on 2026-08-28.

The core calls crypto, protocol, vendor-action, RFID reset, random-MAC, NAN,
and lifecycle helpers as ordinary Abla functions. Those helpers have no export
annotation. Exact linker names remain only where another still-opaque archive
member enters the Abla implementation; they are migration ABI boundaries, not
public package APIs. Replacing each caller cluster removes the corresponding
boundary and lets LLVM prune the entire unused path.

`tools/check-linker-boundaries` enforces that distinction after the final
link. It reads GNU ld's cross-reference table and rejects every linker-visible
definition from the Abla object that has no caller outside that object. The
M5Echo audit exposed and removed four stale data definitions (`s_tbttstart`,
`ieee80211_opcap`, and two net80211 revision words); its remaining 142 visible
function and data definitions all have concrete non-Abla callers. This is a
migration count, not an API target: it must fall as those caller objects move
into the same Abla/LLVM unit, leaving only unavoidable image entry and hardware
vector roots.

`src/esp32/wifi/ieee80211_phy_esp32.ab` now replaces the complete classic
ESP32 `ieee80211_phy.o` policy layer. It preserves the 11b/11a/11g hardware
rate order, user-supported-rate masks, PHY type and display modes, interface
trace mode, low-rate policy, and per-interface vendor-LoRa enable state. The
success path constructs the twelve rate codes directly instead of allocating
and copying a temporary 212-byte table. Deinitialization, rate construction,
mode names, and user-rate handling are internal Abla; only `ieee80211_phy_init`,
`ieee80211_phy_mode_show`, and `ieee80211_phy_type_get` retain exact names
because other opaque net80211 members still call them. The original 1,496-byte
member is absent from the M5Echo map, the image fell by 672 bytes to 871,216
bytes, and the flashed Atom Echo completed WPA2 association, DHCP, server
authentication, speech transfer, and audio playback on 2026-08-28.

`src/esp32/radio/packet_timer_esp32.ab` now replaces the complete classic
ESP32 `pp_timer.o`. Its callback slot and dispatch helpers have internal
linkage. The three exact linker names that remain are each called by an opaque
packet-processing or power-management member: timer dispatch, post-callback
registration, and post-callback invocation. Direct typed dispatch eliminates
the original writable 120-byte callback table and fourteen forwarding
functions. The 581-byte attributed archive member is absent from the M5Echo
map, the application image fell another 208 bytes to 871,008 bytes, and the
flashed Atom Echo completed boot, WPA2 association, DHCP, server
authentication, speech transfer, and audio playback on 2026-08-28.

Nothing in this module transmits, initializes the radio, or changes the
connected Atom Echo unless application code explicitly calls a trusted method.
