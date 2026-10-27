# M5Unified capability parity

This document defines what it means for Abla Embedded to cover M5Unified. It
is based on M5Stack's upstream `M5Unified` 0.2.21 commit
`3eaaf828adfd0923c71ccc2e233a0199d9958faa` and its required `M5GFX` 0.2.28
commit `d91077b9a607b59404e4e4a49f775c792bfae382`.

The goal is behavioral and hardware capability parity, not a line-for-line
translation of its C++ object model. Abla applications should use small typed
values and extensions. A statically selected board must not pay for board
probing, virtual dispatch, heap wrappers, drivers for absent peripherals, or
other boards' pin tables.

## Boundary

M5Unified owns board identity and the composition of built-in devices. M5GFX
owns display and touch-controller implementations. ESP-IDF owns services such
as DMA, radio PHY, flash, and networking. Abla Embedded keeps the same useful
separation:

- `src/m5stack`: static board profiles, built-in device composition, pin maps,
  and board-specific power/enable sequencing;
- `src/esp32`: reusable GPIO, I2C, SPI, I2S, ADC, PWM, SD, sleep, networking,
  and target-specific native or MMIO implementations;
- device modules: reusable RTC, IMU, PMIC, IO-expander, touch, display, audio,
  and LED-controller drivers which are not intrinsically tied to M5Stack;
- examples: one independently buildable sample per capability class, plus
  representative complete board samples.

M5Unified deliberately leaves Wi-Fi, generic SPI/I2C devices, SD filesystem
APIs, and application protocols outside its own high-level API. They remain
part of Abla Embedded because this framework has a broader board-neutral role.

## Upstream inventory and parity

This inventory is not a completion certificate. A 2026-09-09 source audit
corrected stale missing-feature claims for wake leases, PMIC/touch buttons,
logging, storage and recent audio/IMU work. Do not treat an inventory omission
as proof that code needs implementing. Older rows still need a source/test/
hardware audit; source presence and callable target builds do not prove
physical behavior on an untested board.

### Follow-up source audit (2026-09-10)

The original M5Paper IT8951 display was a confirmed source gap. Its SPI
transport now exists in `display/it8951_protocol.ab`: command/argument bursts,
individual words, register writes and dummy-prefixed reads, with bounded BUSY
polling, explicit partial-read counts and CS-cleanup failure reporting.
`it8951_software_esp32` supplies pure-Abla mode-0 GPIO transport, assuming the
caller has configured and exclusively owns all five pins. The protocol model
checks exact word/framing order and injected failures at every exchange,
CS operation and readiness boundary. The read-only GET_DEV_INFO callable
builds for classic ESP32 with one export and zero undefined symbols.
`it8951_device` now decodes and validates the20-word device information,
including the32-bit byte-address span. Initialization sends RUN, enables packed
writes, and writes the reported image address high-word then low-word. It stops
at the first failure and reports the stage; no VCOM or fallback address is
applied. Its host model covers all44 exchange-failure positions, malformed
geometry/address reports, preserved response metadata and neighboring memory.
The actual software bit engine also passes mode-0 edge, MSB order, dummy-word,
continuous argument-CS and invalid-configuration checks. The initialization
callable has zero undefined symbols. The caller still supplies prior power,
reset and exclusive configured pins; this is not a managed panel lifecycle.
`it8951_image` adds physical4bpp rectangle upload with source stride and
unaligned nibble packing, explicit load-end, bounded LUTAFSR idle polling and
buffer-area refresh. A complete-frame example refreshes only after successful
loading. Unknown/FFFF LUT state and exhausted waits report errors; successful
refresh submission is not completion. Tiny refreshes are expanded within
panel bounds, requiring initialized adjacent image pixels. Host checks cover
136 rectangle layouts, all22 load and17 refresh exchange failures, edge
expansion and busy/faulted engines; classic ESP32 callable has zero undefined
symbols. `it8951_color` now converts RGB888 or big-endian RGB565 into
caller-owned4bpp buffers using the upstream IT8951 Bayer matrix, quality/fast
thresholds, channel expansion and inversion. Source/destination stride and
padding are respected; alias/admission errors leave output unchanged. Host
checks compare4,194,304 RGB565 quantization cases and136 buffer layouts; the
CPU callable has zero undefined symbols. `it8951_rotation` supports all eight
full-image rotations/mirrors through the shared EPD coordinate mapping, with
disjoint caller-owned4bpp buffers and preserved padding. A1,768-layout host
comparison against upstream's mirror-then-counterclockwise sequence passes;
its classic ESP32 callable also has zero undefined symbols. Conversion occurs
before rotation; mirrored orientations must use
`it8951ConvertRgbForRotationOwned`, which mirrors the Bayer Y coordinate as
upstream does before reversing source traversal. The earlier generic
conversion-then-mirror recommendation missed that phase change. A4,032-layout
composed color/rotation regression now covers RGB888/RGB565, both quantization
modes and inversion, and confirms cases that differ from the old path. The
unrotated conversion regression and native size remain unchanged.
Checked controller standby/sleep and standby resume are available in
`it8951_power`. Low-power entry first waits for idle LUT engines; busy/faulted
controllers or transport failures do not trigger the power command. Host
failure cases and a zero-undefined ESP32 callable pass. Sleep wake requires
external reset and initialization, not just SYS_RUN. These functions do not
own board rails or pins: M5Paper's SPI is shared with SD and GPIO2 is board
power hold. `it8951_session` now retains controller context and faults in40
caller-owned bytes. It tracks complete-frame validity, pending refresh,
standby and sleep; rejects refresh after partial loads; preserves context on
failed detach; and requires an actual external reset before reset-recovery.
Successful reset-recovery invalidates the old image. Composed host tests and
a complete open/load/refresh/wait/standby/detach callable pass with zero
undefined symbols. This session borrows rather than acquires power, pads and
the shared bus. Managed board power/reset and physical M5Paper operation
remain unfinished. Raw transport use must obey the same session ownership.

Classic ESP32 now has a checked40-byte GPIO lease for output-capable pads
(`esp32/gpio/lease_esp32`). It extends the existing probe admission/RTC hold
checks with full output-route, latch and open-drain preservation. Restoration
disables GPIO output first and retains the snapshot on failed readback for
explicit retry. Host checks cover all output-capable pads,32 configuration
combinations and23 dropped-write positions; the callable has zero undefined
symbols. Existing input-only probe behavior is unchanged. This is a prerequisite
for M5Paper composition, not automatic ownership of its power or shared bus.

`m5stack/paper_display_owner_esp32` now composes seven pin leases, shared SD
SPI preparation,8ms/64ms reset timing and the retained IT8951 session. A312-byte
parent holds the canonical bus gate through initialization and until reverse
pin restoration completes. Partial acquisition, controller faults and failed
restoration retain ownership; an attached controller blocks teardown. Sleep/
fault recovery now performs the real reset sequence before reinitializing and
checks the expected960x540 geometry. The lifecycle model and full native
open/restore/recovery callable pass with zero undefined symbols. The shared
SD command-stream regression passes after extracting its already-held-gate
primitive. SD preparation retains upstream's weak acknowledgement semantics
and can reset an unresponsive card; it is not SD/filesystem initialization.
Caller-owned stable board power and stopped prior SD/pad users remain required;
GPIO2 power hold and GPIO5 external5V are never modified. Physical M5Paper
validation and broader graphics/peripheral parity remain unverified.

IT8951 raw image-memory readback now implements MEM_BST_RD_T/MEM_BST_RD_S
and dummy-prefixed word reads. The session adapter restricts reads to the
reported image span, rejects aliases and unaligned addresses, and fault-latches
transport failures. Tests cover exact command/address/count order, all14 word
failures, prefix preservation and session admission/fault behavior; the native
callable has zero undefined symbols. `it8951_read_rect` now reconstructs
preclipped logical RGB888/RGB565 rectangles in all eight orientations, including
inversion and the upstream raw-byte grayscale expansion. Each physical row is
staged before publication; failures report completed physical rows and latch
the session fault. Padded32-byte bursts near the image end shift backwards
instead of reading beyond the reported buffer. This checked API requires a
4-byte-aligned image span large enough for each padded burst; unsupported
layouts fail before I/O. Model checks cover64 orientation/format/inversion/
corner layouts and every exchange failure, with preserved destination padding.
The native callable has zero undefined symbols. Physical readback remains
unverified; this does not establish complete M5GFX graphics parity.

`it8951_vcom` adds raw calibration reads and an explicit guarded setter.
Writes require an expected-current match; unchanged values are read-only
successes, and transport failures fault-latch the session. Startup never calls
the setter, and the example only reads. Host checks cover every16-bit response,
all13 transfer-failure positions, mismatch/no-op behavior and session safety;
the read-only native callable has zero undefined symbols. Raw protocol range
validation is not electrical suitability: replacement calibration must come
from the actual panel specification. No physical calibration was changed.

M5Paper parent-aware frame operations now protect the312-byte parent, child
session and shared gate from buffer aliases, and recheck retained gate ownership
before I/O. `shutdownOwned` waits, enters standby, detaches the child and restores
pins; failed restoration can resume without repeating controller commands.
The composed model uploads a full259,200-byte image and exercises refresh/wait,
token-loss admission, alias rejection, restoration retry and shutdown failure/
reset recovery. The complete frame callable has zero undefined symbols. These
are model/native-build results, not physical M5Paper display evidence.

Managed physical partial uploads/refreshes now exist for both IT8951 sessions
and M5Paper parents. They require a previously initialized complete image,
preserve that guarantee after successful partial writes, and clear it on failed
uploads. Refresh-in-progress blocks new writes; parent wrappers retain gate and
metadata checks. Host checks cover every19-word tiny-upload failure, recovery,
initial-background admission, last-pixel refresh and invalid requests without
I/O. The native partial-update callable has zero undefined symbols. Physical
partial-refresh appearance and timing remain unverified.

CoreS3/CoreS3SE now have explicit nominal scalar profiles in
`m5stack/core_s3_profile.ab`, forwarding I2C, speaker, microphone, touch and RTC
configuration to the shared registry. These are not initialized devices or
ownership tokens; built-in touch/PMIC buttons are not represented as fake GPIOs.
The profile host fixture passes. The CoreS3 speaker-profile callable reduces
to one constant return in optimized LLVM with no runtime lookup or allocation.
Other typed board facades and physical board validation remain separate work.

The same configuration-only pattern now covers Nesso N1 and UnitC6L
(`c6_board_profile.ab`), ToughC5 (`tough_c5_profile.ab`), and CoreP4X/Tab5/Tab5X
(`p4_board_profile.ab`). Only applicable profiles are exposed: no C6 microphone
or RTC facade, no fake I2S speaker for ToughC5's PM1 buzzer, and no guessed
Tab5 touch controller. Tab5 touch selection still requires the existing probe
and panel evidence. Host checks cover identities, shared maps and pin order;
C5/C6/P4 callable builds have zero undefined symbols. This does not establish
physical board behavior or complete driver coverage.

CoreS3/CoreS3SE connector, SD and M-Bus pins are also available through
`core_s3_pins_esp32s3.ab`, using the native S3 scalar `Pin` implementation.
These accessors do not claim shared pins or configure peripherals. M-Bus
lookup now uses packed integer constants: native testing exposed unwanted
string-runtime dependencies in the former string-table representation.
All 256 board values across 34 valid/boundary positions pass the lookup
regression; the S3 callable includes variable-position lookup and GPIO input
with zero undefined symbols. Physical connector testing remains unverified.

Native connector/I2C/SD/M-Bus facades now also cover the six C5/C6/P4 profiles
above (`c6_board_pins_esp32c6`, `tough_c5_pins_esp32c5`,
`p4_board_pins_esp32p4`). Only mapped connectors are exposed. P4's opt-in
`gpio_pin_esp32p4` supplies the same scalar `Pin` methods as C5/C6; it preserves
the existing low-level requirement that callers acquire clocks, release holds
and stop prior peripheral/LP users. Host tests exercise all 55 P4 pins and
invalid boundaries, existing dropped-write checks, and all six board maps.
Representative native input examples build without undefined symbols on each
target. These checks do not prove physical pin behavior or free-pin ownership.

Scalar GPIO button logic is shared without importing a platform clock.
`button_esp32c5`, `button_esp32c6`, and `button_esp32p4` add checked
`updateAtOwned(milliseconds)` results: consume the returned button/events only
when `valid()` is true. A failed read leaves the prior state unchanged and is
not a release sample. Invalid pin numbers no longer wrap onto a real GPIO;
replacing state preserves the destination's pin and polarity. Native fixtures
cover 2,000 timed updates with injected read failures and constructor/admission
boundaries; all three callable targets have zero undefined symbols. Classic
ESP32 retains its existing timer-backed API through the shared logic; its
full-platform compilation was not rerun as part of this check.

Checked button facades also cover S3 and C61. The classic standalone button
compatibility build now passes without undefined symbols: volatile device
access/fence primitives were separated from the assembly parser, and the
millisecond conversion uses the existing pure-Abla unsigned divider rather
than a compiler-library helper. The conversion matches the previous result
across 100,000 full-width samples, rounding boundaries and the maximum counter;
optimized LLVM retains the volatile accesses and ordering fence. This is a
callable-build check, not a new Atom firmware flash or physical timer test.

The older backlog below is not a list of absent implementations. Current
source inspection and targeted reruns confirm:

- FAT case-only rename exists in `fat_rename_case.ab`: short-name case flags,
  mixed-case LFN promotion, and existing-LFN updates. The `fat-short-case`
  and `fat-rename-case` host fixtures pass, including uncertain-write cases.
  Directory renames share the implementation. The `fat-directory-case` fixture
  now covers 255-unit existing LFNs across FAT16 and mirrored/active-only FAT32,
  all three sector-write failures before/after commit, exact-name no-ops and
  malformed parent rejection. Child/dot entries, metadata and both FAT copies
  remain unchanged. The separate `fat-directory-short-case` fixture covers
  FAT16 directory case flags and mixed-case LFN promotion, preserving children,
  including duplicate-name rejection and pre/post-commit publication failures.
- PowerHub external-port bus configuration already exists in
  `power/powerhub_bus.ab`, matching upstream's contiguous five-byte register
  write. This source audit does not establish physical supply behavior.
- C5 I2S now has source-mux ownership, reset bootstrap, finite transfer and
  circular-stream lifecycles, and composed audio setup/cleanup. Combined
  MMIO models and zero-undefined native callable examples are available.
  Root-clock stability and physical C5 audio remain unverified prerequisites.
- ToughC5's built-in buzzer uses PM1, not an I2S codec. Managed timed-tone
  playback retains the power owner until acknowledged silence and frequency
  restoration; parent close and sleep admission reject retained tones.

`FatVolume.auditAllocation` now holds one generation-checked volume gate
through a complete allocation-tree walk and all-cluster ownership sweep.
It reports cross-links/cycles, orphaned allocations, invalid parent links,
short file chains and transport/budget failures without writing the medium.
FAT16 and FAT12/FAT32 integration fixtures pass, including FAT12 straddles,
multi-sector roots, active-only FAT selection, 4GiB-boundary file sizes,
every physical-read failure and exact budget boundaries. All filesystem users
must obey the same gate. Optional mirrored-FAT comparison now runs after the
sweep under that same gate and total read budget; disabled mirroring is
reported separately, not asserted identical. This establishes allocation
consistency for the selected FAT, not full filesystem certification:
header/FSInfo validity and LFN/name validation remain outside this scan. Physical card validation is
still separate.
Recheck implementations before selecting any older backlog item for coding.

P4 low-level update (2026-09-09): calibrated ADC sampling now has a complete
retained software lifecycle, read-only eFuse decoding, and exact integer
voltage conversion (3,276,800 host-oracle comparisons). The monolithic callable
example has zero undefined symbols; physical ADC accuracy remains unverified.
P4 hardware I2C0/1 clock ownership, checked timing/controller configuration,
FIFO access, bounded command batches and streaming write/read/probe transfers
are implemented and host/target checked. Streaming includes register prefixes,
repeated START, final-byte NACK and one deadline across all FIFO chunks.
P4 pin routing now has a retained 40-byte lease with checked restoration of
both pads and input routes; all 55 pins, both layouts/ports and changed-write
failure/retry cases pass the host model. A retained 72-byte exclusive polling
session now combines clock acquisition, controller setup, timing, pins and
streaming with fault-latched transfers and ordered retryable cleanup. Lifecycle
model and full callable LLVM build pass; it assumes dedicated controller and
initially safed pads, not transparent borrowing of a live bus. An opt-in hardware
provider now binds that session to the existing I2cBus/I2cDevice API with an
atomic admission gate, generation-checked device slots and per-device timing.
The unchanged CoreP4X M5IOE1 driver passes a host caller-buffer transaction and
compiles with the real hardware provider. Default P4 board control entrypoints
still use software I2C. Opt-in retained hardware control-bus constructors now
cover CoreP4X and Tab5/Tab5X, using the common pin registry and ordered IOMUX,
session and provider cleanup. Host stage-failure/retry checks and callable
target builds pass. Address-only hardware probes now allow continued scanning
after a confirmed NACK only when STOP completed and the controller/FIFOs are
idle/empty; interrupted transfers remain fault-latched. Host command and
provider checks pass. Explicit recovery now waits for controller idle and
observed high bus lines before clearing stale FIFOs/commands, with an optional
single-master-only STOP for this owner's halted NACK. Arbitration never forces
STOP; failed cleanup retains ownership. Host fault/retry and callable checks
pass; stuck-slave bus-clear pulses and physical transfers remain unverified/
incomplete. The existing cross-board RTC driver is now exercised through the
hardware provider for CoreP4X/Tab5/Tab5X: RX8130 initialization, leap-day round
trip, invalid data and every initialization-transfer failure pass a host
register model. Normal stack-buffer APIs run unchanged on a guarded low-address
host stack; its C runner is test-only and never linked into firmware. A full
control-bus/RTC callable build is available; physical RTC behavior remains
unverified. The unchanged ST7123 touch driver also passes hardware-provider
register-model integration, including 16-bit register addressing, sparse
70-byte reports, coordinate decoding and failed reads. The Tab5 callable
composition requires an already identified ST panel and completed power/reset;
it does not replace panel detection or claim physical touch validation. The
existing Tab5 detector now also compiles with hardware I2C using an opt-in
prepared-scan backend: ready checks are read-only, only an owned ordinary NACK
may be recovered, and other/recovery faults stop scanning. Register-model tests
cover known/unknown ST firmware, absent ST with GT response, and failure paths;
a GT response still requires independent display identity confirmation.
BMI270 startup/frame sampling also passes hardware-provider integration, with
every startup-transfer failure checked. Shared driver startup now distinguishes
transport failures from a valid non-matching optional magnetometer identity;
reset/init polling uses checked reads and accepts readiness on the final poll.
The P4 callable uses an explicit calibrated 1ms ROM-delay profile. Physical IMU
validation remains pending. Full prepared IMU-owner discovery, snapshot updates
and cleanup now compile with the P4 hardware bus; the integration model covers
fallback to BMI270 at0x69, absent external magnetometers, transport/recovery
faults, scratch alias rejection and retaining previous samples after failed
reads. Expanded register-model checks cover BMM150 alone, AK8963 alone and
both present (AK preference and BMM handle release), magnetic freshness,
AK overflow preserving prior samples, and arbitration at every optional-sensor
startup transfer. MPU6050/6886/9250 and SH200Q primary discovery also pass the
provider model, including their big-/little-endian snapshot layouts and
arbitration at every responding primary startup transfer. These tests exercise
representative combinations, not every possible sensor pairing or physical
sensor behavior.
P4 EXT1 wake configuration now has a retained scalar lease: per-pin polarity
for 16 RTC pads, filter preservation, disable-before-change ordering and
retryable restoration. Status acknowledgment is explicit, not part of open.
Host register tests and a callable LLVM build pass; this does not configure
LP pad ownership, enable PMU sleep triggers or implement sleep entry itself.
A separate LP wake-pad scalar lease now parks output, configures input/pulls
and safely switches HP/LP mux ownership, with retryable restoration. Host tests
cover all16 pads, layouts1/3, all pull modes and changed-write faults. LP clocks
must remain pinned; a separate scalar clock lease now acquires IOMUX/LP-IOMUX/
LP-GPIO gates and restores only acquired gates after child teardown. All16
initial gate combinations and partial open/close retries pass the host model.
The combined160B EXT1/pad/clock lease now exists in
`src/esp32/power/wake_session_p4_sequence.ab`, including retained failures
and ordered cleanup. Its host fixture `tests/wake-session-p4-native.ab` passed
again on 2026-09-09 using the emitted host object directly
(`build/tests/parity-wake-audit-check.log`). Physical wake remains unverified.
These are
foundations, not a claim of I2C parity.

P4 software-I2C leases now expose explicit `recoverOwned(clearStuck)` and
return an updated scalar lease. Recovery can reopen a fully configured bus
that failed the initial idle check; failed setup/partial teardown cannot drive
the pads. Passive recovery is the default. Opt-in single-master clearing uses
the existing bounded nine-clock/STOP implementation; failure retains both pads
for retry or close. Host line/lifecycle/integration checks and an independent
RISC-V callable build pass. This does not add GPIO clearing to the P4 hardware
I2C provider, nor prove physical bus recovery.
The software provider also exposes `i2cSoftwareRecoverSetup(clearStuck)` for
an unpublished busy-bus open: recovery retains the consumed epoch and pad
leases, publishes only after observed idle, and rejects setup/readback and
closing failures. Status9 remains device-pool cleanup failure; recovery clock
timeout uses10. A real pool-lock failure regression verifies that failed
handle revocation cannot be converted into a ready bus by recovery. Provider
fault/retry, stale-handle, lock-contention and abort tests pass, as does the
standalone provider-recovery RISC-V build (zero undefined symbols).
An explicit lower-level `esp32p4I2cClearIdleOwned` now clears a stuck slave
on an already-idle HP hardware controller. It refuses active/arbitrating
controllers, saves both current GPIO configurations in a separate40-byte
record, uses bounded open-drain recovery, restores both pads, then runs the
existing passive controller/FIFO recovery. Transfer admission remains closed
on failure; restore retries do not repeat slave clocks. Lifecycle198 cases,
GPIO/session regressions and a standalone RISC-V build pass. The opt-in
hardware provider now exposes `I2cBus.clearIdleStatus(record)`, holds its
admission lock during each operation, and reserves the same record across
restoration retries. A pending clear blocks ordinary close, transfer, probe,
and passive recovery. Alias checks cover the enlarged36-byte provider state,
device slots, enclosing board state and pending40-byte clear record. Provider
lifecycle/alias tests, existing Tab5 touch and IMU-owner integrations, and the
standalone provider-clear RISC-V build pass. Busy-controller quiescing and
physical verification remain unfinished. It is not automatic recovery.
The next recovery primitive, `esp32p4I2cFsmResetOwned`, uses P4's native
self-clearing CTR.FSM_RST rather than resetting peripheral clocks/registers.
It preserves configuration and FIFO evidence, refuses arbitration/interrupt
ownership conflicts, and waits for reset completion and idle under a bounded
cycle deadline. An already completed reset is not retriggered. Both-port host
register models (8192 cases) and a416-byte RISC-V callable build pass. It does
not itself clear bus lines or reopen the session. The hardware provider now
composes it through explicit `I2cBus.abortAndClearStatus(record)`: only a
failed, fully routed session is eligible, abort failures never clock slaves,
and restoration retries skip abort. One provider lock covers abort and clear;
the original transfer error remains available after recovery. Provider phase,
abort-failure and retry tests plus the complete native RISC-V callable build
pass. Physical timeout/reset/clear behavior remains unverified.
The complete abort/clear composition also passes a shared register model,
running actual provider, FSM-reset, GPIO capture/configuration/restoration,
line clocking and passive FIFO/command-cleanup implementations together.
Both controller ports and the GPIO31/32 bank boundary are exercised, including
slave release on clocks1..9, permanent SDA hold, dropped changed GPIO writes,
and restoration retries with no repeated reset/clock sequence. Exact GPIO
restoration and preservation of timing/filter registers are checked. Hardware
bindings are shared between the model and native facade; MMIO/time are the
model boundaries, not replacement high-level success callbacks.

P4 multi-phase I2C jobs now reuse the S3/C5 immutable phase-table API through
`jobs_esp32p4.ab`. The retained-session entrypoint in `session_jobs_p4.ab`
validates table/payload disjointness from the session and fault-latches any
execution failure. It does not replace the provider admission lock: callers
must retain exclusive ownership, stable clocks and immutable buffers.
The shared-register stream fixture covers both ports, FIFO boundary lengths,
write/read/probe/read phases, read-final NACK before repeated START, one final
STOP, and NACK/arbitration/timeout/FIFO faults in every batch. Failed sessions
reject replay. Existing stream and generic-job regressions pass. Native RV32
raw/session callable examples have zero undefined symbols. The opt-in
`hardware_jobs_esp32p4.ab` provider now exposes `I2cBus.runJobsStatus`, holding
one lock through protected-buffer admission, timing selection and all phases.
The table carries per-phase addresses; caller selects one frequency supported
by every addressed device. State/device-slot/enclosing-record/pending-clear
aliases, stale epochs, restore exclusion, timeout overflow and timing failure
are checked before execution. Provider lifecycle tests and existing FIFO and
provider regressions pass; the full callable build has zero undefined symbols.
Physical P4 job validation remains outstanding. The provider fixture models
the wire/session boundary; the separate FIFO fixture runs actual chunk logic.
The FIFO fixture additionally composes the real provider, timing register
setup, retained session, jobs and chunk execution behind shared MMIO hooks.
Both ports at1k/100k/400kHz cover distinct-address write/read/probe/read phases,
all six batch positions for NACK/arbitration/timeout/FIFO failures, timing
readback failure and an exhausted whole-job deadline. Every MMIO access checks
the provider lock. Six controls and156 failures pass; session creation/close
hardware hooks remain outside this integration model.

GC9A01 write-path addition: `gc9a01_software.ab` provides240x240 init,
clipped RGB565 fill/blit using the upstream230-byte init program. Odd rotations
reset RASET toFFFFFFFF before the normal window; transport never closes with
NOP. All8 rotations and generic blit regressions pass in host GPIO models;
C61 callable has zero undefined symbols. Caller owns power/reset/configured
pads and initialized rotation. `gc9a01_read.ab` additionally implements
separate-MISO RAMRD with16 dummy clocks and strided RGB888 wire-order or
big-endian RGB565 output. All rotations, both formats, padding and admission
checks pass a GPIO model; callable build has zero undefined symbols. Panels
must expose a readable separately wired SDO for the default path. Explicit
`sharedDataLine=true` instead reads through MOSI after checked input setup,
confirms CS release before restoring GPIO output-low, and faults the gate on
setup/cleanup failure. `gc9a01SharedReadRecover` performs checked restoration
without replay, requiring all bus users quiesced and unrelated faults ruled
out. Both wiring modes and all rotations/formats pass host tests; six partial
setup/cleanup failures and recovery retries verify no unconfirmed bus drive.
Shared and separate read callable builds have zero undefined symbols.
`gc9a01_session.ab` now binds configured pins, canonical gate and initialized
rotation in an exclusive caller-owned64-byte record. Fill/blit/read use that
rotation; MADCTL updates publish it only after success. Own shared-read faults
support checked recovery, while detach retries retain a faulted gate until CS
release succeeds. Session/data alias refusal, live-open refusal, busy rotation,
read fault/recovery and detach retry pass the GPIO model; a complete lifecycle
callable has zero undefined symbols. Reset/power/backlight remain borrowed,
other fault classes are not automatically reset, and physical validation is
outstanding. Detach does not sleep or power off the display.
`gc9a01_power.ab` adds retained sleep/wake and upstream idle-mode, display
enable and inversion commands. Sleep transitions hold the SPI gate through
120ms settling before publishing asleep/ready; drawing and rotation remain
blocked while asleep or transitioning. A failed confirmed-CS cleanup faults
the session without pretending sleep/wake completed. Command traces, duplicate
sleep/wake no-ops, busy admission, blocked operations and cleanup failure pass
the GPIO model; the expanded lifecycle callable has zero undefined symbols.
Timing follows sections6.2.3/4 of the
[GC9A01A datasheet](https://cdn-learn.adafruit.com/assets/assets/000/135/078/original/GC9A01A.pdf).
External reset/rails/backlight and physical validation remain caller/platform work.

`gc9107_software.ab` adds the upstream GC9107 init program and RGB565 fill/blit,
with validated128x160 address memory and the GC9xxx odd-rotation workaround.
`m5stack/atom_gc9107.ab` explicitly selects the AtomS3/AtomS3R GC9107 variant,
including board pins and128x128 visible crop at row32. It does not change
default detection or assume all units use GC9107: ST7735 variants also exist.
Eight-rotation init/offset/clipping tests and an Xtensa callable pass with
zero undefined symbols. These board panels are marked unreadable upstream;
no read facade is exposed. Reset/backlight/pad setup and physical validation
remain caller responsibilities.

`atom_s3_panel.ab` classifies a caller-supplied successful RDDID for AtomS3/R:
ST7735 IDs7683/897C or GC9107 ID079100, with no unknown-ID fallback. Its scalar
profile selects initialization, inversion, crop and internal rotation (ST7735
offset_rotation2 with132x132 memory and2/1 crop; GC9107 row32 crop). Unknown
profiles refuse GPIO access. Both boards, all rotations, exhaustive16-bit ID
classification and init/fill traces pass; the Xtensa callable has zero undefined
symbols. This is not a hardware probe; low-speed S3R retry, reset/backlight
ownership and physical validation remain separate.
`atom_s3_panel_probe.ab` now performs one explicit software RDDID transaction
on those borrowed configured pads: eight deselected idle clocks, command04,
one dummy bit, then four bytes assembled in upstream FIFO byte order. The
reusable `spi/software_register_read.ab` checks shared-data setup and CS/output
restoration, faults on cleanup failures, and provides explicit no-replay
recovery. Eighty GPIO-model cases cover both boards, three recognized IDs plus
all-ones unknown, input/CS/output failures and two minimum edge delays. The
Xtensa read callable has zero undefined symbols. This is not the upstream8MHz
hardware probe; a software-timed unknown result does not prove panel absence.
Fast-first/slow-retry detection and physical validation remain outstanding.
Native S3 phase execution now supports explicit single-line receive SIO:
USER.bit17 enabled, full-duplex disabled, and normal subsequent phases clear
SIO. A separate routing helper connects SPID input and output on MOSI with
peripheral OE, after checked CS release. Both ports,64 receive lengths,four
dummy counts, config-write failure and routing failure stages pass host tests;
native transfer/routing callables have zero undefined symbols. These are
primitives, not a complete panel probe: caller owns clock setup, CS/D-C phase
sequencing and all routes; partial route/transfer failures retain ownership.
`spi/register_read_esp32s3.ab` composes native deselected idle clocks, D/C-low
register command and D/C-high dummy/shared-data receive under one gate. It
requires each hardware phase to complete before changing D/C. Cleanup never
changes selection while UPDATE/START may still be active; failure reports
retain phase and cleanup-pending evidence. Both-controller register/GPIO
models cover all phase timeouts/FIFO errors and six GPIO-write failure points,
including partial writes. The native callable has zero undefined symbols.
Clock setup, fast/slow retry, pad ownership and physical validation remain
outside this read primitive.

| Capability | Upstream behavior to cover | Abla status |
| --- | --- | --- |
| Board identity | Canonical IDs, explicit selection, optional safe detection, fallback | Full canonical ID registry and aliases; Atom Echo typed profile; host-verified detection decisions for every upstream ESP32 family, kept behind explicit imports; exact ESP32-C6 eFuse detection and allocation-free ESP32-S3 GPIO/I2C/XCLK detection are independently build-verified; other hardware adapters and remaining typed profiles pending |
| Pin maps | Internal/external I2C, Ports A-E, SD SPI/SDMMC, RGB, power hold, M-Bus | Complete upstream registry for all board IDs, including Tab5X aliasing and allocation-free 30-pin M-Bus lookup |
| GPIO/button | Debounce, press/release, hold, click count, power/expander/touch buttons | Board source registry, scalar GPIO buttons, checked expander reads, touch-frame button mapping, and PMIC event adapters exist (`button_frame`, `power_button`). PMIC model regression refreshed; physical per-board event behavior remains unverified. |
| I2C | Two buses, probe/scan, start/restart/stop, register and bulk transactions | Native streaming implementations exist alongside IDF adapters. Caller-owned multi-phase jobs support S3 and C5 main/low-power controllers: START/repeated START, addressed write/read/probe phases, final-read NACK before restart, and one shared deadline. Host sequencing and monolithic Xtensa/RISC-V target checks pass, including 16-byte LP FIFO chunking; physical job validation and other target adapters remain |
| SPI | Shared bus/device configuration needed by displays and SD | Native S3 CPU-buffer transfers and gate/CS ownership exist alongside IDF adapters. Checked command/address/dummy phases include blocking and non-blocking setup/hold timing. A caller-owned cooperative queue provides FIFO ordering, completion backpressure and fault halting; it is not ISR/SMP-safe or DMA-backed. Integrated host models and monolithic Xtensa builds pass; physical validation and other target adapters remain |
| Display | Built-in and external displays, drawing, brightness, rotation | SPI LCD/RGB565 drawing and controller modules, CoreS3 display composition, and P4 DSI/DPI ownership/startup modules exist. Representative callable builds and host models are recorded; full controller/board parity and physical validation remain incomplete |
| Touch | Multi-point state, hold, drag/flick, touch-button mapping | FT5x06, GT911, CST816S, CST3530, CHSC6540 and ST7123 modules, board polling and touch-button adapters exist. Per-controller physical validation and full behavior parity remain to audit |
| Speaker | I2S/DAC/buzzer output, tone, raw PCM/WAV, volume, mixing, board enable callbacks | Atom Echo voice was physically confirmed by the user. PCM/WAV channels, mixing/resampling, millihertz phase-continuous default tones, squared volume mapping and CoreS3/ES8311/P4 tone staging are host/native checked. Borrowed unsigned8 mono/stereo custom tone waveforms have sample, lifecycle, alias and staging tests. A shared two-slot PCM/tone source queue now has host handoff, block-size independence, cancellation and whole-queue preflight tests plus a zero-undefined native callable object; the 1..8-lane mixed-source bank now has host/native checks for stereo/mono mixing, gain-before-clipping and cross-lane ownership, and CoreS3 DMA staging now has modeled retry/handoff/short-transfer checks plus a native callable build; ES8311 mixed-queue mono/stereo windows also have sample/retry/timeout/cleanup model checks and a native build, and shared P4 mixed-queue staging now has Tab5/CoreP4X handoff/retry/timeout/cleanup model checks and native RV32 builds. Other board/output parity and physical validation remain incomplete. |
| Microphone | I2S/PDM/ADC capture, mono/stereo conversion, sample-rate conversion | Atom Echo pure-Abla record/network/playback physically confirmed by the user; CoreS3 microphone stream/DMA and callable record/replay example exist. Other capture modes/boards still require scope and hardware verification |
| LED | RGB strips, PMIC LED, Paper mono LED, PowerHub LED, brightness/buffering | All four backends are allocation-free in Abla-owned state and build-verified with common method names; IDF RMT uses built-in byte/copy encoders without M5Unified's custom allocated callback object |
| Power | External/USB rails, charge settings/status, battery/VBUS telemetry, vibration, power-off and timed sleep | Board-specific AXP/PM1/GPIO/expander rail and charging modules exist; checked expander port-latch readback covers Tab5/Tab5X/CoreP4X/CoreMatrix/Nesso. Core2/StopWatch vibration, PM1/StampPLC external telemetry and PowerHub bus-supply configuration have host tests and monolithic target checks. This is not full Power_Class parity: board power-off/timed/light-sleep composition and representative physical power validation remain to audit and complete. Latch readback is not measured supply voltage |
| PMIC/fuel gauge | AXP192, AXP2101, IP5306, AW32001, BQ27220, INA226, INA3221, M5PM1, PY32 PMIC | All distinct upstream classes have allocation-free register drivers and independently buildable examples; PY32 PMIC is only a deprecated alias for M5PM1 |
| RTC | PCF8563, RX8130, PowerHub RTC; date/time, alarms, timer IRQ, low-voltage status | All three date/time and alarm devices ported; PCF8563/RX8130 timers build-verified; PowerHub timer/status remain unavailable upstream and in Abla |
| IMU | MPU6886, SH200Q, BMI270, BMM150, AK8963; axes, calibration, NVS offsets | All five driver families, packed axes, snapshots, calibration and offset storage exist. Owner-wide primary/companion clock changes now have partial-success reporting with S3, shared software-I2C and C5 HP/LP providers. Host checks and native examples exist; physical sensor and broader target validation remain incomplete. |
| IO expander | M5IOE1 and PI4IOE5V6408 direction, pull, I/O, IRQ | Both devices, including M5IOE1 PWM, implemented with checked I2C read-modify-write and build-verified |
| SD/storage | Board SD pin/type mapping and SDMMC/SDSPI operations | Native S3 SPI-SD owners and PaperMono SDMMC startup/SCR/width/transfer-clock/close composition exist. Generation-guarded SPI FAT and owner-guarded PaperMono FAT reads are modeled and target compiled. FAT12/16/32, long-name UTF16/UTF8 paths and bounded file reads exist; a data-only in-place overwrite primitive has native S3 SPI-SD integration, FIFO-model CMD24/CRC/readback and stale-handle checks, plus a zero-undefined Xtensa callable build. Checked in-place overwrites now re-read and compare directory snapshots, update archive/time metadata, and distinguish uncertain metadata writes after confirmed data writes; host and native FIFO-model checks pass. A generation-checked volume gate now serializes complete read/write transactions with modeled nested-access, remount and fault checks plus a native build; all users must share that gate. Cluster reservation, file growth/shrink, short-name creation with directory extension, and explicit-alias VFAT creation now have native builds and host failure/order tests. Automatic bounded LFN aliases and up to two-cluster directory growth are implemented under one volume gate; collision retries, 255-unit publication and all13 two-cluster write failures pass host checks, with a zero-undefined native build. Generation-checked file handles now provide single-component LFN/ASCII lookup, snapshot-checked read-at/overwrite-at and close/reopen under the volume gate. Host stale-mount, concurrent-access, metadata-change, failure and lookup-location checks plus native read/write builds pass. Handle resize now integrates bounded zero-filled growth and chain-planned shrink, refreshing snapshots only on full success; host growth/truncation/regrowth, stale and partial-write tests and native build pass. UTF16 path-open now holds one gate through full resolution and handle snapshot publication; long-directory names, dot/parent traversal, invalid paths and I/O failures are host checked and native compiled. Integrated host workflows now cover FAT12 and mirrored/active-only FAT32: LFN create/path-open, three-cluster growth, patterned write/read, shrink/regrow zeroing, full release and remount/reopen; FAT12 neighboring nibbles, FAT32 reserved bits, inactive FAT and unrelated FSInfo bytes are checked. Bounded directory enumeration now reconstructs LFNs across sectors/clusters, returns raw short metadata and ASCII names with NT case flags, and leaves unknown OEM encodings raw; host checks and native build pass. Strict UTF8 handle opening now reuses caller-owned conversion storage; accented and emoji paths, malformed encodings, capacity and mount-buffer overlap checks pass with a native build. Automatic-alias directory creation now initializes and writes child dot/parent entries before parent-name publication, with nested directory/file access and all5 FAT16 write-failure points checked plus a native build. Directory creation can also grow cluster-backed parents by up to two clusters under the same gate; the 255-unit-name case and all17 write failures pass host checks with a native build. Fixed FAT12/16 roots remain non-growable. Cross-format mkdir workflows now pass on FAT12 and mirrored/active-only FAT32: nested directories, parent traversal, file creation/growth/write/read, explicit FAT32 root normalization and retained reserved bits/inactive FAT. File/empty-directory removal now validates snapshots/chains/dot entries, unlinks LFNs before freeing storage, and refuses nonempty directories. Cross-format workflows and46 injected write failures (including committed-but-failed writes) pass; native removal build has zero undefined symbols. File rename/move preserves metadata and allocation, including read-only files; cross-parent and publish/unlink failure checks pass. Directory rename/move validates ancestry and updates dot-parent entries; cross-format workflows and24 injected failures pass with native builds. Growing file/directory rename now extends full cluster-backed destinations without reallocating source storage; 255-unit names, child preservation and58 pre/post-commit write failures pass, with native builds. Case-only file rename is implemented and host-tested; directory-specific case-change integration, whole-volume integrity certification and physical card validation remain incomplete. |
| Logging/timer | Serial/display logging and timer callbacks | Direct UART serial, logging policy/source/dump and RGB565 display-log console adapters exist. Display-console model regression refreshed. Cooperative ten-timer scheduler exists; board framebuffer publication, full logging-policy parity and physical display logging still need audit. |

`Complete` means the public Abla API exists, every relevant example builds,
the generated native ABI is checked where a vendor boundary remains, and at
least one representative real device is tested for hardware-dependent classes.
Profiles without available hardware are marked build-verified rather than
hardware-verified.

## Board scope

C61 native GPIO0..29 now has direct MMIO reads/writes and checked digital
configuration using its own register map, not P4/C5 addresses. Configuration
refuses individual holds, RTC-owned pins0..6 and enabled USB pads12/13; global
holds, stable clocks and board pin reservations remain caller prerequisites.
GPIO OE is parked and selected before latch/mux changes; only owned fields
are changed. All30 pins, sixteen direction/level/driver/input combinations,
three pull modes, dropped writes and ownership refusals pass host tests. A
524-byte RISC-V callable has zero undefined symbols. Clock ownership, C61 I2C
binding and physical CoreMatrix verification remain incomplete.
C61 GPIO/IOMUX now also has a retained scalar clock lease for PCR APB and
functional gates plus the GPIO gate. It borrows pre-enabled gates, refuses
reset/invalid-source states, never changes source selection, and restores
only acquired gates after all children close. All8 initial gate combinations,
all3 valid sources, noisy fields and partial-open/close retry tests pass; the
RISC-V callable is520 bytes with zero undefined symbols. Clock-source startup,
LP ownership, bus integration and physical validation remain separate work.
C61 now binds native GPIO to the shared software-I2C line/transaction engine
with a retained scalar bus lifecycle. Admission checks both pads and GPIO/
IOMUX gates before mutation; failures retain attempted pad ownership for close.
Explicit recovery distinguishes busy lines from clock timeout. Register-model
tests cover all30 adjacent pin pairs, setup writes dropped individually, held/
RTC/USB/clock conflicts, address NACK/STOP and recovery. Independent lifecycle
and transfer RISC-V builds pass with zero undefined symbols. The only delay
boundary is C61 ROM0x4000003c, requiring already-calibrated pinned CPU timing.
This is not a hardware-I2C controller implementation, common I2cDevice provider
binding, C61 boot image or physical CoreMatrix validation.
C61 software buses now support caller-owned generation-checked device pools.
Allocation, frequency limits, descriptor matching, transfer-buffer guards and
handle revocation are shared with P4 in `i2c/software_devices.ab`; the existing
P4 API remains compatible. Failed device cleanup retains pad ownership and
cannot be mistaken for a recoverable bus timeout. C61 and P4 device/lifecycle
tests and the existing P4 provider tests pass; both native callable builds
have zero undefined symbols. The high-level C61 I2cBus/I2cDevice provider is
implemented in `esp32/i2c/software_provider_c61.ab`, sharing the board-neutral
software provider. CoreMatrix wire-model checks exercise actual board drivers,
device handles, register transactions and owner cleanup through this provider.

CoreMatrix charge-current selection now follows the pinned upstream IOE0 G3
sequence: clear both pulls, then input below a650mA request or latch-low,
push-pull, output at/above650. Each transport failure stops the sequence and
is reported; unrelated pin bits are preserved. This is a discrete selector,
not a measured/programmed current guarantee, and request0 does not disable
charging. The lower circuit rate is deliberately not guessed. The existing
11011 register-model cases are supplemented by managed owner integration:
`M5CoreMatrixControl.setChargeCurrentOwned` resolves its own IOE0 handle and
rejects unready owners or unconfirmed exclusive access before bus activity.
The CoreMatrix wire fixture covers 100 low/high selection cases including
every address/register/data NACK, before and after possible data-write commit,
with unrelated-register preservation, exact stage errors and cleanup checks.
The independent C61 callable build passes with one export and zero undefined
symbols. An explicit expander-owner import fixes a dependency that the larger
test import graph had masked. This is NOT a C61 boot image; physical charging
and complete CoreMatrix board validation remain unverified.

CoreMatrix now composes prepared IMU discovery and snapshot updates with its
managed C61 control bus. Admission rejects nonexclusive access, unready board
control, board/provider buffer overlap and already-open IMU owners. The IMU
borrows the bus, with its storage address retained in board control until
`closeImuOwned` succeeds. Board teardown refuses a retained child, including
failed discovery or interrupted cleanup, before releasing PMIC/expanders or
clock/pad leases. Wrong-child and nonexclusive close attempts do nothing;
cleanup can be retried after a busy provider gate becomes available.
The C61 timing adapter uses calibrated ROM millisecond waits, not a classic
ESP32 scheduler or ROM address. A shared wire model exercises actual provider
transactions: absent sensors, BMI270 discovery at0x69, byte-exact8192-byte
configuration upload, first/middle/last upload-byte NACKs, absent optional
magnetometers, acceleration/gyro snapshots, CoreMatrix axis mapping, all six
status/frame address-register NACK positions and retained previous samples.
Existing control/charge wire regressions pass. The combined open/update/close
C61 callable has one export and zero undefined symbols; physical CoreMatrix
IMU operation remains unverified.

CoreMatrix managed button polling now resolves PM1 from its live control owner
and samples KEY1/2/3 coherently in one register18 read. The scalar frame reports
only A/B/C valid; nonexclusive access, closed control, provider contention and
transport failure leave all channels unknown. No PMIC events are acknowledged.
The C61 wire model covers all256 input bytes, every read-address/register NACK,
unchanged device registers, one transaction per poll, admission and shared
M5Button state continuity/redebouncing after unknown samples. The independent
C61 callable builds with one export and zero undefined symbols. Physical
CoreMatrix button behavior is not yet verified.

Reusable monochrome page-canvas drawing now supports preclipped rectangles,
MSB-first packed bitmaps with explicit row stride, transparent zero/one bits,
and all eight rotated/mirrored orientations. CoreMatrix exposes buffered
`fillRect` and `drawBitmap`, with explicit `display` publication. Host checks
cover160 dimension/orientation/mode combinations including non-page-aligned
heights, padding preservation, invalid input and alias rejection before writes.
The C61 bitmap/publication callable has zero undefined symbols after replacing
an unwanted64-bit shift helper with32-bit mask arithmetic. This does not claim
full M5GFX drawing parity or physical display validation.

The monochrome canvas additionally clips signed32 origins to rotated bounds,
preserving source row/bit offsets without repacking. CoreMatrix rectangle and
bitmap methods now clip automatically. Entire bitmap bounds/aliasing are
validated even for off-screen no-ops. 1440 placement/orientation/mode cases
pass, including extreme origins and unaligned left edges, alongside the160
strict-canvas regressions. A clipped packed bitmap also passes through the
real C61 provider/TM1680 wire model; drawing performs no transfers until
explicit display publication. Native callable compilation remains zero-undefined.

External OLED transport now includes SSD1306/SSD1315 horizontal addressing and
SH110x page addressing in `display/oled_i2c.ab`. Pinned UnitMiniOLED geometry
is72x40 at column28; UnitOLED is64x128 at column32. Borrowed-device operations
cover initialization, upstream brightness mapping, inversion, sleep and whole
page-frame publication with acknowledged-page counts on failure. No implicit
retry, bus ownership or read-probe is hidden in these operations. Host tests
check four geometries, every publication-transaction failure, immutable frame
data, all256 brightness levels with failed transfers, initialization and basic
controls. The real C61 software-provider callable has one export and zero
undefined symbols. Physical OLED operation, retained board ownership and full
M5GFX rendering parity remain unverified/incomplete.

OLED publication now also passes through the actual C61 software-I2C provider
in a bit-level write-only-slave model. Both unit profiles exercise every wire
byte NACK, before and after possible payload commit:3032 successful/failing
publication cases verify address/control/data bytes, acknowledged-page counts,
immediate stop on failure, unchanged framebuffers and idle STOP completion.
Device release and existing CoreMatrix control/charge regressions pass. These
are transport models, not a claim that either physical OLED has been tested.

OLED devices now have a caller-owned32-byte lifecycle record with retained
device/profile, original initialization error and last publication result.
Initialization and sleep failures retain the handle for explicit retryable
cleanup; successful close releases only the device, never the borrowed bus.
Software-provider state and owner-buffer aliasing are rejected. Wire tests
cover every initialization-byte NACK for both profiles, all shutdown-byte
NACKs after each attempt, retained handle/error checks, repeated admission,
display/closed-state checks and allocation blocked by provider contention.
The independent C61 owner callable has one export and zero undefined symbols.
Physical reset/power and closing the owner before its bus remain caller duties.

OLED publication now supports physical dirty rectangles through the same
driver and owner. Y expands to complete pages; SSD X expands to four-column
boundaries, while SH110x retains exact X bounds. Expanded bytes come from the
unchanged full framebuffer. Partial-page counts are relative to the requested
transfer. Wire checks cover page-crossing regions, nonzero first pages and
bottom-right edges, every byte failure before/after possible commit, invalid
rectangles and exact addressing/data bytes. Full-frame and lifecycle wire
regressions pass; the C61 region callable has zero undefined symbols.

Original UnitGLASS now has a separate MCU-protocol driver: page-picture
staging/draw/SHOW, STOP-separated firmware/key reads, sleep/inversion and
explicit buzzer frequency/duty/enable commands. It does not misidentify this
unit as SSD1306 or GLASS2. Borrowed-device operations synchronously honor key
selection, draw and SHOW processing waits, including uncertain writes, without
hidden retries. Tests check exact packet fields, all transaction failures in
a two-page partial update, suppressed SHOW after failed staging/draw, read
ordering/waits, control failures and unchanged framebuffers. The C61 callable
compiles with one export and zero undefined symbols. Physical UnitGLASS,
bit-level integration and managed-owner composition remain unverified.

UnitGLASS now also passes a C61 bit-level provider model at its upstream0x3D
address: firmware/key reads use two separate START/STOP transactions and the
required delay, while partial display tests cover every command/data/address
NACK before/after possible payload commit. All waits occur with the bus idle;
failed staging/draw never reaches SHOW.108 read/publication cases pass, along
with3032 OLED wire regressions after adding read support to the shared model.
Physical UnitGLASS behavior and managed-owner composition remain unverified.

UnitGLASS now has a scalar device owner retaining firmware identity and the
original open error. Opening reads firmware, explicitly disables the buzzer,
normalizes inversion and wakes the display. Closing disables the buzzer before
sleep and device release; any failed stage retains the handle for retry.
Software-provider buffers are excluded from scratch and framebuffer use.
Wire tests cover all12 open-byte failure positions, all six shutdown-byte
failure positions after each attempt, exact retained identity/error/handle,
admission, key access and blocked allocation. The C61 lifecycle callable has
one export and zero undefined symbols. Bus ordering, power/reset ownership and
physical UnitGLASS validation remain caller responsibilities or outstanding.

UnitLCD protocol foundations now include checked119/137 identity, bounded
command-queue capacity polling, brightness/rotation/power/sleep/byte-swap
controls, inversion, and explicit-color16-bit pixel/rectangle packets. Commands
are sent only after confirmed capacity; query failures abort and queue-pressure
polls are bounded with2ms spacing. No stale credit cache or hidden command
retries. Host checks cover readiness/failure at every poll position, exhaustion,
command-write failure, all eight rotation bounds, identity failures and packet
encoding. The C61 callable has zero undefined symbols. Raw16 color byte order
and current controller rotation are explicit caller contracts; image streams,
readback, copy, managed ownership and physical validation remain incomplete.

UnitLCD now additionally supports queue-admitted rectangle copy and raw16-bit
readback. Readback requires a fully drained255-slot queue before setting both
window axes; the entire64800-byte frame fits one repeated-START transfer.
Window-write failure and read failure are distinct, and failed reads explicitly
leave potentially partial output. Tests cover all eight rotated full-frame
layouts, every admission/window/read failure (including a13-byte partial read),
exact copy packets, bounds and scratch/output alias rejection. The C61 read
callable has zero undefined symbols. This proves protocol-model behavior,
not physical colors, overlap semantics or device timing on real UnitLCD.

UnitLCD raw16 image upload now sends bounded per-row packets with explicit
source stride, independent queue admission and window setup for every row.
It reports completed rows separately from query/window/pixel failure; the
failing row may be partially visible and is never silently retried.50 modeled
success/failure cases cover widths1/2/7/135/240, padded input, every transaction
stage, immutable source, starvation and alias/input rejection. The full-frame
C61 upload callable has zero undefined symbols. Compressed/alpha streams,
managed lifecycle, real-provider wire tests and physical validation remain.

UnitLCD now passes the actual C61 software-provider bit-level model at0x3E:
identity and full64800-byte readback use repeated START, all13 read-path
address/command failure positions abort correctly, and every upload-byte
failure is checked before/after possible payload commit. Exact row windows,
raw data, partial-row counts and queue-starvation suppression are verified.
Shared OLED wire regressions also pass. This is not evidence of physical LCD
color accuracy, bus timing margins or on-device command execution.

UnitLCD RLE encoding now supports opaque1..4-byte pixels, runs up to255 and
literal blocks, with exact-size preflight and alias/space rejection before
mutation. The row uploader accepts explicit RLE mode while raw remains the
default.200 encoder round-trip cases cover run/literal boundaries254/255/256,
long continuations, multi-byte equality and exact/short destination capacity.
The C61 compressed-upload callable has zero undefined symbols. Compressed
wire integration passes 1,822 control/fault cases across widths1/2/3/135/240,
including every transmitted-byte NACK before/after modeled acceptance,
exact partial-row status and immutable source. Raw wire regression also passes.
Physical image rendering remains unverified.

UnitLCD now has a scalar owned lifecycle with explicit identity, power, wake,
byte-swap, rotation, normal inversion and brightness initialization. Failed
steps retain the device, original initialization error and transport/queue
detail. Close sleeps, drains the queue and releases only after success;
failure retains ownership for explicit retry. The software-provider adapter
rejects private transport buffers. A callable C61 example has one export and
zero undefined symbols. Wire tests cover all38 initialization byte faults
before/after modeled acceptance, each followed by all9 cleanup byte faults,
exact initialization packets, identity mismatch, queue starvation and retry.
Raw/RLE and CoreMatrix wire regressions pass. No physical UnitLCD lifecycle
verification yet; explicit reset and additional pixel formats remain work.

UnitLCD row uploads now share one wire-format implementation for RGB332,
RGB565, RGB888 and ARGB8888, with raw or RLE encoding, explicit source stride,
bounded scratch and unchanged source bytes. The existing write16 API is a
constant-format wrapper. 25,072 modeled wire control/fault cases cover all
four formats and widths1/2/3/135/240, including every transmitted-byte NACK
before/after modeled acceptance, exact packet bytes and partial-row status.
Lifecycle and RGB565 raw/RLE regressions pass. The generic C61 callable has
one export and zero undefined symbols. Physical channel order/blending is unverified.

UnitLCD alpha-only raw/RLE uploads now use explicit1..4-byte wire color,
re-established before every row's window under exclusive access. Invalid color,
buffer or geometry inputs cause no I/O; color-write errors have a separate
status and preserve the completed-row count. 648 modeled wire control/fault
cases cover all four color formats and both encodings, including NACKs before
and after modeled acceptance. Existing pixel/lifecycle/RGB565 regressions pass;
the C61 alpha callable has one export and zero undefined symbols. Actual
alpha blending remains device-side and has not been physically verified.

UnitLCD row-based readback now covers RGB332/RGB565/RGB888 with explicit
destination stride, bounded queue admission and independent row windows.
Each read is at most720bytes, allowing complete97,200-byte RGB888 images
without exceeding the software transport's65,535-byte read limit. Existing
single-transaction read16 remains available. 240 full-frame host scenarios
cover all3formats/8orientations, first/middle/final-row failures and partial
read prefixes; padding and untouched regions are checked. 162 C61 wire
control/fault cases verify command bytes, returned row counts and transport
cleanup. The callable example has one export and zero undefined symbols.
No fabricated32-bit/alpha read format; physical readback remains unverified.

Explicit UnitLCD pre-initialization reset now validates the old identity,
drains the queue, sends FF7789FF, waits300ms, and performs at most8 bounded
NOP/32ms/new-identity observations. A reset-write failure still settles300ms
because it may have committed. Success requires a fresh valid identity, not
the pre-reset result. The result carries status, attempted observations and
fresh firmware. Reset invalidates configuration and must not be called behind
a live owner. 656 host scenarios cover readiness budgets and transport faults;
the guarded C61 callable has one export and zero undefined symbols. Reset
wire integration now passes80 control/fault cases through the real C61 provider
model: all17 transmitted-byte faults before/after modeled acceptance, delayed
identity readiness across budgets1..8, exact packets and idle-only300ms/32ms
settling. A distinct post-reset firmware value verifies fresh identity handling.
CoreMatrix wire regressions also pass. Physical reset timing remains unverified.

CoreMatrix matrix ownership now retains a parent-control lease from before
rail setup until successful panel cleanup. Parent close rejects before touching
PMIC, expanders or transport while that lease exists; failed panel initialization
and shutdown retain it. A second matrix owner is rejected without I/O. Wire
tests cover wrong-order teardown, duplicate ownership, failed opens and retry;
control and IMU ownership regressions pass. The existing64-byte control layout
is preserved, with a reserved bit beside the original initialization error.

CoreMatrix SD also retains a parent-control lease before power setup and until
the SPI master closes successfully, including failed initialization and active
controller cleanup. Parent teardown cannot release shared GPIO clocks while
SD retains resources. SD owner storage is now40bytes (previously32) to retain
the exact control binding; allocation and overlap checks and the example are
updated. Host SD and combined I2C/SPI wire models pass, including power-failure
and retry paths; matrix/control regressions pass. Native C61 build has zero
undefined symbols. No physical SD/card operations were performed.

CoreMatrix buzzer routing is established from M5Stack's UIFlow PWM-speaker
patch: IOE GPIO11/PWM3, power gate GPIO2 (zero-based Abla10/channel2/pin1).
Board-level silent setup disables power/PWM before configuring the routes;
cleanup attempts both independent silence paths and reports each result.
90 wire-model control/fault cases pass with unchanged shared frequency and
unrelated pins. The C61 example has zero undefined symbols. Timed playback
integration, parent lifetime protection and physical sound remain outstanding.

CoreMatrix now has a56-byte timed-tone owner integrating silent setup, IOE
PWM3, rounded volume duty and power-gate enable last. Cooperative polling
stops at a wrap-safe deadline; explicit close supports cancellation. Parent
control is retained until both silence paths and captured-frequency restoration
are acknowledged; failures preserve ownership and diagnostics for retry.
148 modeled start/cleanup control/fault cases pass, including uncertain writes,
duplicate owners, wrong-order teardown and timer wrap. The C61 callable has
one export and zero undefined symbols. Nonzero-volume bounded tones are
implemented; PCM is not supported by this PWM path. Physical sound remains
unverified, and callers must poll and serialize all shared PWM users.

CoreMatrix tone controls now support deadline-preserving volume changes,
zero-volume stop/release, busy rejection and explicit replacement after
successful cleanup. Invalid replacement requests leave the active tone intact;
cleanup failures block the new tone and retain the parent lease. All255
nonzero volume values and32 volume-update wire-fault cases pass, alongside
replacement/cancellation and existing tone lifecycle tests. The callable
control example has zero undefined symbols. Physical sound remains unverified.

An opt-in board-target selection gate now classifies all63 ESP-host IDs across
ESP32/S3/C3/C6/C5/P4/H2/C61. External display IDs and non-ESP hosts are not
accepted as ESP targets. Unknown observations may use a compatible fallback;
an explicit wrong-target selection is rejected without silent substitution.
5,665 ID/target pairs and aliases pass host checks. The C61 callable gate has
zero undefined symbols and performs no probing. Existing detection entrypoints
remain unchanged; callers must explicitly use this gate before hardware setup.

PM1 S3 control now offers opt-in retained RX8130 ownership on ChainCaptain,
PaperMono and StopWatch. Parent cleanup refuses while the child is retained;
failed RTC initialization/release retains its exact device, and mismatched or
stale close requests do no I/O. The existing independent RTC API is unchanged.
24 lifecycle scenarios use the real device pool and modeled parent wire with
RTC initialization outcomes injected; parent wire regressions also pass.
The S3 callable has zero undefined symbols. This is not physical RTC proof or
a change to alarm policy; callers must consume desired wake evidence first.

Retained RTC integration now also exercises the actual RX8130 driver through
the software I2C provider and bit-level model:78 initialization/fault cases
across the three boards, exact register changes with neighboring bytes intact,
leap-day date/time decoding, and rejected-release retention/retry. The previous
RTC-begin mock is not used by this added fixture. Parent wire regressions pass;
physical RTC and S3 bus timing remain unverified.

The audited board ID registry contains 35 display-board IDs, 29 non-display
board IDs, and 10 external-display IDs, plus deprecated aliases. Coverage
includes the current M5Stack families rather than only the original ESP32
products:

- Core: Basic/Core2/CoreS3/CoreS3SE/CoreP4X/Core Matrix/Chan and Station;
- Stick, Atom, Stamp, Nano, Capsule, Cardputer, Dial, DinMeter, AirQ, VAMeter,
  TimerCam, StopWatch, Chain Captain, PowerHub, DualKey, PLC and Unit PoE;
- Paper, Tough, Tab5 and their current variants;
- external Atom/Module/Unit LCD, OLED, GLASS, RCA and HDMI displays.

Deprecated aliases such as Atom Echo map to their canonical board identity
(`M5AtomVoice`) without duplicating implementation.

## API rules

- Logical operations keep the same names across boards: `buttonA`, `display`,
  `touch`, `speaker`, `microphone`, `rtc`, `imu`, `power`, `internalI2c`,
  `externalI2c`, `sd`, and named ports.
- Hardware that is absent has no fake implementation. Capability-specific
  extensions exist only on board types that provide the capability.
- Pins, buses, devices, and statically selected boards remain nominal scalar
  values when their identity fits in a register.
- Driver configuration uses typed constructors instead of opaque annotations
  or application-visible packed offsets.
- Native ABI declarations use the target's exact integer and pointer widths.
  Build checks inspect LLVM declarations for boundaries where an ABI mismatch
  can compile and fail silently on hardware.
- Open driver logic is progressively moved into Abla. Vendor PHY/radio blobs
  and services that cannot yet be replaced remain explicit documented
  boundaries rather than being described as Abla source.

## Validation order

1. Finish the remaining target-specific board detectors and static profiles,
   plus PMIC/expander/touch button adapters.
2. Add raw I2C jobs, queued SPI, SDMMC/filesystems, and board power policy on
   top of the completed blocking bus and PMIC foundations.
3. Extend speaker/microphone support beyond blocking PCM.
4. Audit and extend existing display/touch foundations and controller ports;
   do not treat the former 'not implemented' inventory as current evidence.
5. Complete the profile/examples matrix and repeat whole-firmware size and
   instruction audits against the C++ reference.

The connected Atom Echo is the reference hardware for the first stage. Its
profile maps button A to GPIO39, RGB to GPIO27, I2S BCLK/WS/speaker/microphone
to GPIO19/33/22/23, and Grove Port A SCL/SDA to GPIO32/26.
