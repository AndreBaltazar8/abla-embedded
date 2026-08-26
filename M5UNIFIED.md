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

| Capability | Upstream behavior to cover | Abla status |
| --- | --- | --- |
| Board identity | Canonical IDs, explicit selection, optional safe detection, fallback | Atom Echo explicit profile only |
| Pin maps | Internal/external I2C, Ports A-E, SD SPI/SDMMC, RGB, power hold, M-Bus | Atom Echo internal/external I2C, Port A, RGB, and power workaround |
| GPIO/button | Debounce, press/release, hold, click count, power/expander/touch buttons | Packed pure `ButtonState` covers GPIO behavior; PMIC/expander/touch sources pending |
| I2C | Two buses, probe/scan, start/restart/stop, register and bulk transactions | IDF 6 bus/device, probe, bulk and register transactions build-verified; raw job API pending |
| SPI | Shared bus/device configuration needed by displays and SD | Not implemented |
| Display | Built-in and external displays, drawing, brightness, rotation | Not implemented; belongs in an Abla display layer informed by M5GFX |
| Touch | Multi-point state, hold, drag/flick, touch-button mapping | Not implemented |
| Speaker | I2S/DAC/buzzer output, tone, raw PCM/WAV, volume, mixing, board enable callbacks | Blocking raw I2S output; Atom Echo slot/ABI fix under hardware validation |
| Microphone | I2S/PDM/ADC capture, mono/stereo conversion, sample-rate conversion | Blocking PDM capture; corrected IDF 6 ABI under hardware validation |
| LED | RGB strips, PMIC LED, Paper mono LED, PowerHub LED, brightness/buffering | One RGB LED value |
| Power | External/USB rails, charge settings/status, battery/VBUS telemetry, vibration, power-off and timed sleep | Deep sleep and one GPIO wake source only |
| PMIC/fuel gauge | AXP192, AXP2101, IP5306, AW32001, BQ27220, INA226, INA3221, M5PM1, PY32 PMIC | Not implemented |
| RTC | PCF8563, RX8130, PowerHub RTC; date/time, alarms, timer IRQ, low-voltage status | Not implemented |
| IMU | MPU6886, SH200Q, BMI270, BMM150, AK8963; axes, calibration, NVS offsets | Not implemented |
| IO expander | M5IOE1 and PI4IOE5V6408 direction, pull, I/O, IRQ | Not implemented |
| SD/storage | Board SD pin/type mapping and SDMMC/SDSPI operations | Not implemented |
| Logging/timer | Serial/display logging and timer callbacks | Direct UART serial only |

`Complete` means the public Abla API exists, every relevant example builds,
the generated native ABI is checked where a vendor boundary remains, and at
least one representative real device is tested for hardware-dependent classes.
Profiles without available hardware are marked build-verified rather than
hardware-verified.

## Board scope

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

1. Atom Echo speaker and microphone end-to-end hardware proof.
2. Generic I2C/SPI plus button state machines, because most remaining devices
   depend on them.
3. RTC, IMU, PMIC, IO-expander, LED, SD, and power drivers.
4. Speaker/microphone feature parity beyond blocking PCM.
5. Display/touch foundations and representative M5GFX controller ports.
6. Static board profiles, detection as an optional module, examples, size and
   instruction audits.

The connected Atom Echo is the reference hardware for the first stage. Its
profile maps button A to GPIO39, RGB to GPIO27, I2S BCLK/WS/speaker/microphone
to GPIO19/33/22/23, and Grove Port A SCL/SDA to GPIO32/26.
